open Eio

let () =
  Eio_main.run @@ fun env ->
  Switch.run ~name:"connection pool" @@ fun sw ->
  let connpool =
    Cohttp_connpool_eio.make ~https:None ~sw ~net:env#net ~n:10
      (Uri.of_string "http://google.com")
  in
  let str =
    Switch.run ~name:"request" @@ fun sw ->
    let _, body = Cohttp_connpool_eio.get connpool ~sw "/" in
    Eio.Buf_read.(parse_exn take_all) body ~max_size:max_int
  in
  Format.printf "%s\n%!" str
