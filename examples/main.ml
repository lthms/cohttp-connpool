(* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. *)

open Eio

(* -------- *)

(* Borrowed from cohttp-eio example
   https://github.com/mirage/ocaml-cohttp/blob/main/cohttp-eio/examples/client_tls.ml *)

let authenticator =
  match Ca_certs.authenticator () with
  | Ok x -> x
  | Error (`Msg m) ->
      Fmt.failwith "Failed to create system store X509 authenticator: %s" m

let https ~authenticator =
  let tls_config =
    match Tls.Config.client ~authenticator () with
    | Error (`Msg msg) -> failwith ("tls configuration problem: " ^ msg)
    | Ok tls_config -> tls_config
  in
  fun uri raw ->
    let host =
      Uri.host uri
      |> Option.map (fun x -> Domain_name.(host_exn (of_string_exn x)))
    in
    Tls_eio.client_of_flow ?host tls_config raw

(* -------- *)

let () =
  Mirage_crypto_rng_unix.use_default ();
  Eio_main.run @@ fun env ->
  Switch.run ~name:"connection pool" @@ fun sw ->
  let connpool =
    Cohttp_connpool_eio.make
      ~https:(Some (https ~authenticator))
      ~sw ~net:env#net ~n:10
      (Uri.of_string "https://soap.coffee/~lthms")
  in
  Cohttp_connpool_eio.warm connpool;
  Fiber.both
    (fun () ->
      let _, body = Cohttp_connpool_eio.Strict.get connpool "/posts" in
      Format.printf "%s\n%!" body)
    (fun () ->
      let _, body = Cohttp_connpool_eio.Strict.get connpool "/posts" in
      Format.printf "%s\n%!" body)
