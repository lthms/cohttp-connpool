# `cohttp-connpool-eio`

This library provides a connection pool for `cohttp-eio`, enabling efficient
reuse of HTTP connections within an Eio application. This helps reduce latency
and resource overhead by minimizing the need to establish new TCP connections
for each request.

```ocaml
open Eio.Std

let () =
  Eio_main.run @@ fun env ->
  Switch.run ~name:"pool lifetime" @@ fun sw ->
  let pool =
    Cohttp_connpool_eio.make ~sw ~https:None ~net:env#net ~n:5
      (Uri.of_string "http://example.com")
  in
  Switch.run ~name:"request lifetime" @@ fun sw ->
  let response, body = Cohttp_connpool_eio.get ~sw pool "/some/path" in
  Eio.traceln "Status: %s" (Cohttp.Code.string_of_status response.status);
  Eio.traceln "Body: %s"
    (Eio.Buf_read.(parse_exn take_all) body ~max_size:max_int)
```

