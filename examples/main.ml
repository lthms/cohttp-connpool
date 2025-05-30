open Eio

let () =
  Eio_main.run @@ fun env ->
  Switch.run ~name:"connection pool" @@ fun sw ->
  let connpool =
    Cohttp_connpool_eio.make ~sw ~net:env#net ~n:10
      (Uri.of_string "http://google.com")
  in
  let _, str = Cohttp_connpool_eio.get connpool "/" in
  Format.printf "%s\n%!" str
