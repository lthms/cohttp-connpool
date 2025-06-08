module Lwt_tests : sig
  type t = Lwt_switch.t -> unit Lwt.t

  val make_server :
    sw:Lwt_switch.t ->
    ?port:int ->
    ?conn_closed:(Cohttp_lwt_unix.Server.conn -> unit) ->
    (Cohttp_lwt_unix.Server.conn ->
    Http.Request.t ->
    Cohttp_lwt_unix.Server.body ->
    Cohttp_lwt_unix.Server.response Lwt.t) ->
    Uri.t Lwt.t

  val register : string -> t -> unit
  val run : unit -> unit Lwt.t
end = struct
  type t = Lwt_switch.t -> unit Lwt.t

  let close_conn = function
    | Conduit_lwt_unix.TCP { fd; _ }, _ ->
        Lwt_unix.shutdown fd SHUTDOWN_ALL;
        Lwt_unix.close fd
    | _ -> Lwt.return_unit

  let port = ref 50000

  let next_port () =
    let res = !port in
    incr port;
    res

  let make_server ~sw ?(port = next_port ()) ?conn_closed callback =
    let stop, r = Lwt.task () in
    let server =
      Cohttp_lwt_unix.Server.make ?conn_closed
        ~callback:(fun conn req body ->
          let open Lwt.Syntax in
          (* Cohttp_connpool_lwt_unix does not seem to close its persistent
             connections when the server is stopped... let's do that manually.
             *)
          if Lwt.state stop <> Sleep then
            let* () = close_conn conn in
            assert false
          else callback conn req body)
        ()
    in
    let endpoint = Uri.make ~scheme:"http" ~host:"localhost" ~port () in
    let server =
      Cohttp_lwt_unix.Server.create ~mode:(`TCP (`Port port)) ~stop server
    in
    Lwt_switch.add_hook (Some sw) (fun () ->
        Lwt.wakeup r ();
        server);
    Lwt.return endpoint

  let tests = ref []
  let register name test = tests := (name, test) :: !tests

  let run () =
    let open Lwt.Syntax in
    Lwt_list.iter_s
      (fun (name, test) ->
        let* () = Lwt_io.eprintf "* Starting `%s`\n%!" name in
        Lwt_switch.with_switch @@ fun sw ->
        Lwt.catch
          (fun () ->
            let* () = test sw in
            Lwt_io.eprintf "-> SUCCESS\n%!")
          (fun exn ->
            let* () = Lwt_switch.turn_off sw in
            Lwt_io.printf "-> FAILED with %s\n%!" (Printexc.to_string exn)))
      !tests
end

let warm_established_reusable_connections () =
  Lwt_tests.register "warm established reusable connections" @@ fun sw ->
  let open Lwt.Syntax in
  let performed_requests = ref 0 in
  let closed_connections = ref 0 in
  let* endpoint =
    Lwt_tests.make_server ~sw
      ~conn_closed:(fun _conn -> incr closed_connections)
      (fun _conn _ _ ->
        incr performed_requests;
        Cohttp_lwt_unix.Server.respond_string ~status:`OK ~body:"" ())
  in
  let t = Cohttp_connpool_lwt_unix.make ~n:2 endpoint in
  let* () = Cohttp_connpool_lwt_unix.warm t in

  assert (!performed_requests = 2);
  assert (!closed_connections = 0);

  let* _ = Cohttp_connpool_lwt_unix.Strict.get t "" in

  assert (!performed_requests = 3);
  assert (!closed_connections = 0);

  Lwt.return_unit

let connection_close_prevents_reuse () =
  Lwt_tests.register "connection_close_prevents_reuse" @@ fun sw ->
  let open Lwt.Syntax in
  let performed_requests = ref 0 in
  let closed_connections = ref 0 in
  let* endpoint =
    Lwt_tests.make_server ~sw
      ~conn_closed:(fun _conn -> incr closed_connections)
      (fun _conn _ _ ->
        incr performed_requests;
        Cohttp_lwt_unix.Server.respond_string
          ~headers:(Cohttp.Header.of_list [ ("connection", "close") ])
          ~status:`OK ~body:"" ())
  in
  let t = Cohttp_connpool_lwt_unix.make ~n:2 endpoint in

  let* _ = Cohttp_connpool_lwt_unix.Strict.get t "" in

  assert (!performed_requests = 1);
  assert (!closed_connections = 1);

  Lwt.return_unit

let server_restarts_gracefully_handled () =
  Lwt_tests.register "server restarts are gracefully handled by the pool"
  @@ fun _sw ->
  let open Lwt.Syntax in
  let performed_requests = ref 0 in
  let closed_connections = ref 0 in

  let* t, port =
    Lwt_switch.with_switch @@ fun sw ->
    let* endpoint =
      Lwt_tests.make_server ~sw
        ~conn_closed:(fun _conn -> incr closed_connections)
        (fun _conn _ _ ->
          incr performed_requests;
          Cohttp_lwt_unix.Server.respond_string ~status:`OK ~body:"answered" ())
    in
    let t = Cohttp_connpool_lwt_unix.make ~n:2 endpoint in
    let+ () = Cohttp_connpool_lwt_unix.warm t in
    (t, Option.get @@ Uri.port endpoint)
  in

  (* The server was closed by the switch, this should fail *)
  let has_raised_an_exception = ref false in
  let* _ =
    Lwt.catch
      (fun () ->
        let* _ = Cohttp_connpool_lwt_unix.Strict.get t "" in
        Lwt.return_unit)
      (function
        | Unix.Unix_error (ECONNREFUSED, _, _) ->
            has_raised_an_exception := true;
            Lwt.return_unit
        | _ -> Lwt.return_unit)
  in

  assert !has_raised_an_exception;
  assert (!closed_connections = 2);
  assert (!closed_connections = 2);

  (* We restart it *)
  Lwt_switch.with_switch @@ fun sw ->
  let* _endpoint =
    Lwt_tests.make_server ~sw ~port
      ~conn_closed:(fun _conn -> incr closed_connections)
      (fun _conn _ _ ->
        incr performed_requests;
        Cohttp_lwt_unix.Server.respond_string ~status:`OK ~body:"" ())
  in

  (* and try to make a request *)
  let* resp, _ = Cohttp_connpool_lwt_unix.Strict.get t "" in
  assert (Cohttp.Response.status resp = `OK);

  assert (!performed_requests = 3);
  assert (!closed_connections = 2);
  Lwt.return_unit

let () =
  warm_established_reusable_connections ();
  connection_close_prevents_reuse ();
  server_restarts_gracefully_handled ()

let tests_cohttp_connpool env =
  Lwt_eio.with_event_loop ~clock:env#clock @@ fun () ->
  Lwt_eio.run_lwt @@ fun () -> Lwt_tests.run ()

let () = Eio_main.run @@ fun env -> tests_cohttp_connpool env
