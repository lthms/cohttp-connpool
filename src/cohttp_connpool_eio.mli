type t

val make : sw:Eio.Std.Switch.t -> net:_ Eio.Net.t -> n:int -> Uri.t -> t
val head : ?headers:Http.Header.t -> t -> string -> Http.Response.t

val get :
  sw:Eio.Std.Switch.t ->
  ?headers:Http.Header.t ->
  t ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t

val post :
  sw:Eio.Std.Switch.t ->
  ?body:Cohttp_eio.Body.t ->
  ?chunked:bool ->
  ?headers:Http.Header.t ->
  t ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t

val put :
  sw:Eio.Std.Switch.t ->
  ?body:Cohttp_eio.Body.t ->
  ?chunked:bool ->
  ?headers:Http.Header.t ->
  t ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t

val patch :
  sw:Eio.Std.Switch.t ->
  ?body:Cohttp_eio.Body.t ->
  ?chunked:bool ->
  ?headers:Http.Header.t ->
  t ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t

val delete :
  sw:Eio.Std.Switch.t ->
  ?body:Cohttp_eio.Body.t ->
  ?chunked:bool ->
  ?headers:Http.Header.t ->
  t ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t

val call :
  sw:Eio.Std.Switch.t ->
  ?body:Cohttp_eio.Body.t ->
  ?chunked:bool ->
  ?headers:Http.Header.t ->
  t ->
  Http.Method.t ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t
