type t

val make : sw:Eio.Std.Switch.t -> net:_ Eio.Net.t -> n:int -> Uri.t -> t
val get : ?headers:Http.Header.t -> t -> string -> Http.Response.t * string
