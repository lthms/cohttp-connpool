(* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. *)

type t
(** A pool of persistent HTTP connections to a single host. *)

val make : n:int -> Uri.t -> t

val call :
  sw:Lwt_switch.t ->
  ?body:Cohttp_lwt.Body.t ->
  ?chunked:bool ->
  ?headers:Http.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  Http.Method.t ->
  string ->
  (Http.Response.t * Cohttp_lwt.Body.t) Lwt.t

val head :
  sw:Lwt_switch.t ->
  ?headers:Http.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  Http.Response.t Lwt.t

val get :
  sw:Lwt_switch.t ->
  ?headers:Http.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  (Http.Response.t * Cohttp_lwt.Body.t) Lwt.t

val post :
  sw:Lwt_switch.t ->
  ?body:Cohttp_lwt.Body.t ->
  ?chunked:bool ->
  ?headers:Cohttp.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  (Cohttp.Response.t * Cohttp_lwt.Body.t) Lwt.t

val put :
  sw:Lwt_switch.t ->
  ?body:Cohttp_lwt.Body.t ->
  ?chunked:bool ->
  ?headers:Cohttp.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  (Cohttp.Response.t * Cohttp_lwt.Body.t) Lwt.t

val patch :
  sw:Lwt_switch.t ->
  ?body:Cohttp_lwt.Body.t ->
  ?chunked:bool ->
  ?headers:Cohttp.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  (Cohttp.Response.t * Cohttp_lwt.Body.t) Lwt.t

val delete :
  sw:Lwt_switch.t ->
  ?body:Cohttp_lwt.Body.t ->
  ?chunked:bool ->
  ?headers:Cohttp.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  (Cohttp.Response.t * Cohttp_lwt.Body.t) Lwt.t

val warm : t -> unit Lwt.t

module Strict : sig
  val call :
    ?body:Cohttp_lwt.Body.t ->
    ?chunked:bool ->
    ?headers:Http.Header.t ->
    t ->
    ?query:(string * string list) list ->
    ?userinfo:string ->
    Http.Method.t ->
    string ->
    (Http.Response.t * string) Lwt.t

  val get :
    ?headers:Http.Header.t ->
    t ->
    ?query:(string * string list) list ->
    ?userinfo:string ->
    string ->
    (Http.Response.t * string) Lwt.t

  val post :
    ?body:Cohttp_lwt.Body.t ->
    ?chunked:bool ->
    ?headers:Cohttp.Header.t ->
    t ->
    ?query:(string * string list) list ->
    ?userinfo:string ->
    string ->
    (Cohttp.Response.t * string) Lwt.t

  val put :
    ?body:Cohttp_lwt.Body.t ->
    ?chunked:bool ->
    ?headers:Cohttp.Header.t ->
    t ->
    ?query:(string * string list) list ->
    ?userinfo:string ->
    string ->
    (Cohttp.Response.t * string) Lwt.t

  val patch :
    ?body:Cohttp_lwt.Body.t ->
    ?chunked:bool ->
    ?headers:Cohttp.Header.t ->
    t ->
    ?query:(string * string list) list ->
    ?userinfo:string ->
    string ->
    (Cohttp.Response.t * string) Lwt.t

  val delete :
    ?body:Cohttp_lwt.Body.t ->
    ?chunked:bool ->
    ?headers:Cohttp.Header.t ->
    t ->
    ?query:(string * string list) list ->
    ?userinfo:string ->
    string ->
    (Cohttp.Response.t * string) Lwt.t
end
