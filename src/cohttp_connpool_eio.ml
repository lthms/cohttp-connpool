(* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. *)

type connection = {
  client : Cohttp_eio.Client.t;
  sw : Eio.Switch.t;
  endpoint : Uri.t;
  raw_socket : [ `Generic ] Eio.Net.stream_socket_ty Eio.Resource.t;
  socket : Eio.Flow.two_way_ty Eio.Std.r;
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

let make_connection ~wrap ~sw ~net endpoint =
  let net = (net :> [ `Generic ] Eio.Net.ty Eio.Std.r) in
  let wrap =
    (wrap
      :> [ `Generic ] Eio.Net.stream_socket_ty Eio.Resource.t ->
         Eio.Flow.two_way_ty Eio.Std.r)
  in
  let sockaddr = tcp_address ~net endpoint in
  let raw_socket = Eio.Net.connect ~sw net sockaddr in
  let socket = wrap raw_socket in
  {
    client = Cohttp_eio.Client.make_generic (fun ~sw:_ _uri -> socket);
    sw;
    endpoint;
    raw_socket;
    socket;
    alive = true;
  }

let dispose conn =
  if conn.alive then (
    (try Eio.Flow.shutdown conn.socket `All with _ -> ());
    Eio.Net.close conn.raw_socket);
  conn.alive <- false

let make ~sw ~https ~net ~n uri =
  let https =
    (https
      :> (Uri.t ->
         [ `Generic ] Eio.Net.stream_socket_ty Eio.Std.r ->
         Eio.Flow.two_way_ty Eio.Std.r)
         option)
  in
  let wrap =
    match Uri.scheme uri with
    | Some "http" -> fun x -> (x :> Eio.Flow.two_way_ty Eio.Std.r)
    | Some "https" -> (
        match https with
        | Some wrap -> wrap uri
        | None -> raise (Invalid_argument "missing HTTPS information"))
    | Some unsupported ->
        raise
          (Invalid_argument Format.(sprintf "unsupported scheme %s" unsupported))
    | None -> raise (Invalid_argument "missing scheme")
  in
  {
    pool =
      Eio.Pool.create
        ~validate:(fun conn -> conn.alive)
        n
        (fun () -> make_connection ~wrap ~sw ~net uri);
    pool_size = n;
  }

exception Invalidated_socket (* private *)
exception Broken_pool (* public *)

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
            dispose conn;
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
  if Http.Header.get_connection_close (Http.Response.headers response) then
    dispose conn;
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

let warm t path =
  Eio.Switch.run ~name:"Cohttp_eio.warm" @@ fun sw ->
  Eio.Fiber.List.iter
    (fun _ -> ignore (call ~sw t `HEAD path))
    (Seq.ints 0 |> Seq.take t.pool_size |> List.of_seq)

module Strict = struct
  let call ?body ?chunked ?headers t ?query ?userinfo m route =
    Eio.Switch.run ~name:"Cohttp_connpool_eio.Strict.call" @@ fun sw ->
    let status, body =
      call ~sw ?body ?chunked ?headers t ?query ?userinfo m route
    in
    (status, Eio.Buf_read.(parse_exn take_all) body ~max_size:max_int)

  let get ?headers t ?query ?userinfo route =
    Eio.Switch.run ~name:"Cohttp_connpool_eio.Strict.get" @@ fun sw ->
    let status, body = get ~sw ?headers t ?query ?userinfo route in
    (status, Eio.Buf_read.(parse_exn take_all) body ~max_size:max_int)

  let post ?body ?chunked ?headers t ?query ?userinfo route =
    Eio.Switch.run ~name:"Cohttp_connpool_eio.Strict.post" @@ fun sw ->
    let status, body =
      post ~sw ?body ?chunked ?headers t ?query ?userinfo route
    in
    (status, Eio.Buf_read.(parse_exn take_all) body ~max_size:max_int)

  let put ?body ?chunked ?headers t ?query ?userinfo route =
    Eio.Switch.run ~name:"Cohttp_connpool_eio.Strict.put" @@ fun sw ->
    let status, body =
      put ~sw ?body ?chunked ?headers t ?query ?userinfo route
    in
    (status, Eio.Buf_read.(parse_exn take_all) body ~max_size:max_int)

  let patch ?body ?chunked ?headers t ?query ?userinfo route =
    Eio.Switch.run ~name:"Cohttp_connpool_eio.Strict.patch" @@ fun sw ->
    let status, body =
      patch ~sw ?body ?chunked ?headers t ?query ?userinfo route
    in
    (status, Eio.Buf_read.(parse_exn take_all) body ~max_size:max_int)

  let delete ?body ?chunked ?headers t ?query ?userinfo route =
    Eio.Switch.run ~name:"Cohttp_connpool_eio.Strict.delete" @@ fun sw ->
    let status, body =
      delete ~sw ?body ?chunked ?headers t ?query ?userinfo route
    in
    (status, Eio.Buf_read.(parse_exn take_all) body ~max_size:max_int)
end
