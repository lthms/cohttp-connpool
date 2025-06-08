(* Redefinition of Cohttp_lwt_unix.Connection_cache pending
   https://github.com/mirage/ocaml-cohttp/issues/1112 fix *)
module Make (Connection : Cohttp_lwt.S.Connection) (Sleep : Cohttp_lwt.S.Sleep) =
struct
  exception Retry = Cohttp_lwt.Connection.Retry

  module Net = Connection.Net
  module IO = Net.IO
  open IO

  type ctx = Net.ctx

  type t = {
    cache : (Net.endp, Connection.t) Hashtbl.t;
    ctx : ctx;
    keep : int64;
    retry : int;
    parallel : int;
    depth : int;
    proxy : Uri.t option;
  }

  let create ?(ctx = Lazy.force Net.default_ctx) ?(keep = 60_000_000_000L)
      ?(retry = 2) ?(parallel = 4) ?(depth = 100) ?proxy () =
    {
      cache = Hashtbl.create ~random:true 10;
      ctx;
      keep;
      retry;
      parallel;
      depth;
      proxy;
    }

  let rec get_connection self endp =
    let finalise connection =
      let rec remove keep =
        let current = Hashtbl.find self.cache endp in
        Hashtbl.remove self.cache endp;
        if current == connection then
          List.iter (Hashtbl.add self.cache endp) keep
        else remove (current :: keep)
      in
      remove [];
      Lwt.return_unit
    in
    let create () =
      Connection.connect ~persistent:true ~finalise ~ctx:self.ctx endp
      >>= fun connection ->
      let timeout = ref Lwt.return_unit in
      let rec busy () =
        Lwt.cancel !timeout;
        if Connection.length connection = 0 then (
          timeout :=
            Sleep.sleep_ns self.keep >>= fun () ->
            Connection.close connection;
            (* failure is ignored *)
            Lwt.return_unit);
        Lwt.on_termination (Connection.notify connection) busy
      in
      busy ();
      Lwt.return connection
    in
    match Hashtbl.find_all self.cache endp with
    | [] ->
        create () >>= fun connection ->
        Hashtbl.add self.cache endp connection;
        Lwt.return connection
    | conns -> (
        let rec search length = function
          | [ a ] -> (a, length + 1)
          | a :: b :: tl when Connection.length a < Connection.length b ->
              search (length + 1) (a :: tl)
          | _ :: tl -> search (length + 1) tl
          | [] -> assert false
        in
        match search 0 conns with
        | shallowest, _ when Connection.length shallowest = 0 ->
            Lwt.return shallowest
        | _, length when length < self.parallel ->
            create () >>= fun connection ->
            Hashtbl.add self.cache endp connection;
            Lwt.return connection
        | shallowest, _ when Connection.length shallowest < self.depth ->
            Lwt.return shallowest
        | _ ->
            Lwt.try_bind
              (fun () -> Lwt.choose (List.map Connection.notify conns))
              (fun _ -> get_connection self endp)
              (fun _ -> get_connection self endp))

  let prepare self ?headers ?absolute_form meth uri =
    match self.proxy with
    | None ->
        let absolute_form = Option.value ~default:false absolute_form in
        Net.resolve ~ctx:self.ctx uri >>= fun endp ->
        Lwt.return (endp, absolute_form, headers)
    | Some proxy_uri ->
        let absolute_form =
          Option.value
            ~default:
              (not
                 (meth = `CONNECT
                 || (meth = `OPTIONS && Uri.path_and_query uri = "*")))
            absolute_form
        in
        Net.resolve ~ctx:self.ctx proxy_uri >>= fun endp ->
        Lwt.return (endp, absolute_form, headers)

  let call self ?headers ?body ?absolute_form meth uri =
    prepare self ?headers ?absolute_form meth uri
    >>= fun (endp, absolute_form, headers) ->
    let rec request retry =
      get_connection self endp >>= fun conn ->
      Lwt.catch
        (fun () -> Connection.call conn ?headers ?body ~absolute_form meth uri)
        (function
          | Retry -> (
              match body with
              | Some (`Stream _) -> raise Retry
              | None | Some `Empty | Some (`String _) | Some (`Strings _) ->
                  if retry <= 0 then raise Retry else request (retry - 1))
          | e -> Lwt.reraise e)
    in
    request self.retry
end

include
  Make
    (Cohttp_lwt_unix.Connection)
    (struct
      (* : Mirage_time.S *)
      let sleep_ns ns = Lwt_unix.sleep (Int64.to_float ns /. 1_000_000_000.)
    end)
