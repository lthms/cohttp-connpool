type connection = {
  client : Cohttp_eio.Client.t;
  sw : Eio.Switch.t;
  endpoint : Uri.t;
  socket : [ `Generic ] Eio.Net.stream_socket_ty Eio.Resource.t;
  mutable alive : bool;
}

type t = { pool_size : int; pool : connection Eio.Pool.t }

(* from Eio.Net *)
let tcp_address ~net uri =
  let service =
    match Uri.port uri with
    | Some port -> Int.to_string port
    | _ -> Uri.scheme uri |> Option.value ~default:"http"
  in
  match
    Eio.Net.getaddrinfo_stream ~service net
      (Uri.host_with_default ~default:"localhost" uri)
  with
  | ip :: _ -> ip
  | [] -> failwith "failed to resolve hostname"

let make_connection ~sw ~net endpoint =
  let net = (net :> [ `Generic ] Eio.Net.ty Eio.Std.r) in
  let sockaddr = tcp_address ~net endpoint in
  let socket = Eio.Net.connect ~sw net sockaddr in
  {
    client = Cohttp_eio.Client.make_generic (fun ~sw:_ _uri -> socket);
    sw;
    endpoint;
    socket;
    alive = true;
  }

let make ~sw ~net ~n uri =
  {
    pool =
      Eio.Pool.create
        ~validate:(fun conn -> conn.alive)
        ~dispose:(fun conn ->
          Eio.traceln "disposing";
          Eio.Net.close conn.socket)
        n
        (fun () -> make_connection ~sw ~net uri);
    pool_size = n;
  }

exception Invalidated_socket
exception Broken_pool

let invalidates_socket = function
  | Eio.Io (Eio.Net.E (Connection_reset _), _) | End_of_file | Failure _ -> true
  | _otherwise -> false

let use t k =
  let rec use = function
    | n when 0 < n -> (
        try
          Eio.Pool.use t.pool @@ fun conn ->
          try k conn
          with exn when invalidates_socket exn ->
            conn.alive <- false;
            raise Invalidated_socket
        with Invalidated_socket -> use (n - 1))
    | _otherwise -> raise Broken_pool
  in
  use t.pool_size

let get_conn ~sw t =
  let x, rx = Eio.Promise.create () in
  let never, _ = Eio.Promise.create () in
  Eio.Fiber.fork_daemon ~sw (fun () ->
      use t @@ fun conn ->
      Eio.Promise.resolve rx conn;
      Eio.Promise.await never);
  Eio.Promise.await x

let concat_path p1 p2 =
  String.concat "/"
  @@ (String.split_on_char '/' p1 |> List.filter (( <> ) ""))
  @ (String.split_on_char '/' p2 |> List.filter (( <> ) ""))

let make_uri uri ?query ?userinfo route =
  let uri = Uri.with_path uri (concat_path (Uri.path uri) route) in
  let uri =
    match query with Some query -> Uri.with_query uri query | None -> uri
  in
  let uri =
    match userinfo with
    | Some userinfo -> Uri.with_userinfo uri (Some userinfo)
    | None -> uri
  in
  uri

let call ~sw t ?query ?userinfo route h =
  let conn = get_conn ~sw t in
  let uri = make_uri conn.endpoint ?query ?userinfo route in
  let response, body = h conn uri in
  Eio.Switch.on_release sw (fun () ->
      (* We force the full body to be read, so that the next  *)
      ignore (Eio.Buf_read.(parse_exn take_all) body ~max_size:max_int));
  (response, body)

let head ?headers t ?query ?userinfo route =
  Eio.Switch.run @@ fun sw ->
  let conn = get_conn ~sw t in
  let uri = make_uri conn.endpoint ?query ?userinfo route in
  Cohttp_eio.Client.head ?headers ~sw:conn.sw conn.client uri

let get ~sw ?headers t ?query ?userinfo route =
  call ~sw t ?query ?userinfo route @@ fun conn uri ->
  Cohttp_eio.Client.get ?headers ~sw:conn.sw conn.client uri

let post ~sw ?body ?chunked ?headers t ?query ?userinfo route =
  call ~sw t ?query ?userinfo route @@ fun conn uri ->
  Cohttp_eio.Client.post ?body ?chunked ?headers ~sw:conn.sw conn.client uri

let delete ~sw ?body ?chunked ?headers t ?query ?userinfo route =
  call ~sw t ?query ?userinfo route @@ fun conn uri ->
  Cohttp_eio.Client.delete ?body ?chunked ?headers ~sw:conn.sw conn.client uri

let put ~sw ?body ?chunked ?headers t ?query ?userinfo route =
  call ~sw t ?query ?userinfo route @@ fun conn uri ->
  Cohttp_eio.Client.put ?body ?chunked ?headers ~sw:conn.sw conn.client uri

let patch ~sw ?body ?chunked ?headers t ?query ?userinfo route =
  call ~sw t ?query ?userinfo route @@ fun conn uri ->
  Cohttp_eio.Client.patch ?body ?chunked ?headers ~sw:conn.sw conn.client uri

let call ~sw ?body ?chunked ?headers t ?query ?userinfo m route =
  call ~sw t ?query ?userinfo route @@ fun conn uri ->
  Cohttp_eio.Client.call ?body ?chunked ?headers ~sw:conn.sw conn.client m uri
