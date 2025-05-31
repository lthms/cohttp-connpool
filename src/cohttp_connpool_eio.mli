type t

val make : sw:Eio.Std.Switch.t -> net:_ Eio.Net.t -> n:int -> Uri.t -> t

val get :
  sw:Eio.Std.Switch.t ->
  ?headers:Http.Header.t ->
  t ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t
