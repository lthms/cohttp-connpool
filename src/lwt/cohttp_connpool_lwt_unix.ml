(* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. *)

type t = {
  cache : Cohttp_lwt_unix.Connection_cache.t;
  pool_size : int;
  endpoint : Uri.t;
}

let make ~n uri =
  let cache = Cohttp_lwt_unix.Connection_cache.create ~parallel:n () in
  { cache; endpoint = uri; pool_size = n }

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

let call ~sw ?body ?(chunked = false) ?(headers = Cohttp.Header.init ()) t
    ?query ?userinfo m route =
  let open Lwt.Syntax in
  let headers =
    if chunked then Cohttp.Header.add headers "transfer-encoding" "chunked"
    else headers
  in
  let uri = make_uri ?query ?userinfo t.endpoint route in
  let* resp, body =
    Cohttp_lwt_unix.Connection_cache.call ?body ~headers t.cache m uri
  in
  if m <> `HEAD then
    Lwt_switch.add_hook (Some sw) (fun () -> Cohttp_lwt.Body.drain_body body);
  Lwt.return (resp, body)

let get ~sw ?chunked ?headers t ?query ?userinfo route =
  call ~sw ?chunked ?headers ?query ?userinfo t `GET route

let head ~sw ?chunked ?headers t ?query ?userinfo route =
  let open Lwt.Syntax in
  let+ resp, _ = call ~sw ?chunked ?headers ?query ?userinfo t `HEAD route in
  resp

let warm t =
  Lwt_switch.with_switch @@ fun sw ->
  Lwt_list.iter_p
    (fun _ ->
      let open Lwt.Syntax in
      let* _ = head ~sw t "" in
      Lwt.return_unit)
    (Seq.ints 0 |> Seq.take t.pool_size |> List.of_seq)

module Strict = struct
  let call ?body ?chunked ?headers t ?query ?userinfo m route =
    Lwt_switch.with_switch @@ fun sw ->
    let open Lwt.Syntax in
    let* resp, body =
      call ~sw ?body ?chunked ?headers t ?query ?userinfo m route
    in
    let+ body = Cohttp_lwt.Body.to_string body in
    (resp, body)

  let get ?chunked ?headers t ?query ?userinfo route =
    let open Lwt.Syntax in
    let+ resp, _ = call ?chunked ?headers ?query ?userinfo t `GET route in
    resp
end
