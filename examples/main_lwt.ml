open Lwt.Syntax

let () =
  Lwt_main.run
  @@
  let t =
    Cohttp_connpool_lwt_unix.make ~n:2 (Uri.of_string "http://localhost:11434")
  in

  let* () = Cohttp_connpool_lwt_unix.warm t in

  let* () = Lwt_unix.sleep 1.0 in

  let* () =
    Lwt_switch.with_switch (fun sw ->
        let* resp, body = Cohttp_connpool_lwt_unix.get ~sw t "/api/version" in

        let+ _ = Cohttp_lwt.Body.to_string body in
        let headers = Cohttp.Response.headers resp in
        Format.printf "Headers from first response:\n%s"
          (Cohttp.Header.to_string headers))
  in

  let* () = Lwt_unix.sleep 1.0 in

  (* 2. This second call to the same host will reuse the connection
          established by the first call, thanks to our Connpool. *)
  let* () =
    Lwt_switch.with_switch (fun sw ->
        let* _resp, body2 = Cohttp_connpool_lwt_unix.get ~sw t "/api/version" in
        let* body = Cohttp_lwt.Body.to_string body2 in
        Format.printf "%s" body;

        Lwt.return_unit)
  in

  let* () = Lwt_unix.sleep 1.0 in

  Lwt.return_unit
