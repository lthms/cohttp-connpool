type t
(** A pool of persistent HTTP connections to a single host. *)

exception Broken_pool

val make :
  sw:Eio.Std.Switch.t ->
  https:
    (Uri.t ->
    [ `Generic ] Eio.Net.stream_socket_ty Eio.Std.r ->
    _ Eio.Flow.two_way)
    option ->
  net:_ Eio.Net.t ->
  n:int ->
  Uri.t ->
  t
(** [make ~sw ?https ~net ~n uri] creates a new connection pool. The pool will
    contain up to [n] persistent connections to the host specified by [uri].

    @raise Broken_pool
      in case it is not possible to acquire a valid connection from the pool

    @param sw
      The Eio switch to use for managing resources. All connections will be
      disposed of on [sw]’s release.
    @param https
      An optional function to upgrade connections to HTTPS. If [None], only HTTP
      connections are supported.
    @param net The Eio network context to use for establishing connections.
    @param n
      The maximum number of persistent connections to maintain in the pool.
    @param uri
      The base URI for the host to connect to. This URI's scheme, host, and port
      will be used.
    @return A new connection pool instance. *)

val call :
  sw:Eio.Std.Switch.t ->
  ?body:Cohttp_eio.Body.t ->
  ?chunked:bool ->
  ?headers:Http.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  Http.Method.t ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t
(** [call ~sw ?body ?chunked ?headers t ?query ?userinfo meth path] makes an
    HTTP request using a connection from the pool.

    This function is a general-purpose method for making HTTP requests with any
    HTTP method and handling the full response, including the body. Connections
    are reused from the pool if available and suitable.

    @raise Broken_pool
      in case it is not possible to acquire a valid connection from the pool

    @param sw
      The Eio switch to use for managing resources. The connection will be put
      back in the pool on [sw]’s release
    @param body The request body to send.
    @param chunked
      Whether the request body should be sent with chunked transfer encoding.
    @param headers Optional HTTP headers to include in the request.
    @param t The connection pool instance.
    @param query Optional query parameters to append to the URL path.
    @param userinfo
      Optional user info to include in the URL (e.g., for basic authentication).
    @param meth The HTTP method to use for the request (e.g., `GET`, `POST`).
    @param path
      The path component of the URL. This will be combined with the pool's base
      URI.
    @return
      A tuple containing the HTTP response and its body. The body will be
      consumed on [sw]’s release, in order to enable the reuse of the
      connection. *)

val head :
  ?headers:Http.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  Http.Response.t
(** [head ?headers t ?query ?userinfo path] makes an HTTP HEAD request using a
    connection from the pool.

    This function is used to retrieve only the headers of a resource, without
    fetching the actual body. It's useful for checking resource existence,
    metadata, or for caching purposes. Connections are reused from the pool if
    available and suitable.

    @raise Broken_pool
      in case it is not possible to acquire a valid connection from the pool

    @param headers Optional HTTP headers to include in the request.
    @param t The connection pool instance.
    @param query Optional query parameters to append to the URL path.
    @param userinfo
      Optional user info to include in the URL (e.g., for basic authentication).
    @param path
      The path component of the URL. This will be combined with the pool's base
      URI.
    @return The HTTP response containing only the headers. *)

val get :
  sw:Eio.Std.Switch.t ->
  ?headers:Http.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t
(** [get ~sw ?headers t ?query ?userinfo path] makes an HTTP GET request using a
    connection from the pool.

    This function is used to retrieve resources from the server. Connections are
    reused from the pool if available and suitable.

    @raise Broken_pool
      in case it is not possible to acquire a valid connection from the pool

    @param sw
      The Eio switch to use for managing resources. The connection will be put
      back in the pool on [sw]’s release
    @param headers Optional HTTP headers to include in the request.
    @param t The connection pool instance.
    @param query Optional query parameters to append to the URL path.
    @param userinfo
      Optional user info to include in the URL (e.g., for basic authentication).
    @param path
      The path component of the URL. This will be combined with the pool's base
      URI.
    @return
      A tuple containing the HTTP response and its body. The body will be
      consumed on [sw]’s release, in order to enable the reuse of the
      connection. *)

val post :
  sw:Eio.Std.Switch.t ->
  ?body:Cohttp_eio.Body.t ->
  ?chunked:bool ->
  ?headers:Http.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t
(** [post ~sw ?body ?chunked ?headers t ?query ?userinfo path] makes an HTTP
    POST request using a connection from the pool.

    This function is used to send data to the server, typically for creating or
    updating resources. Connections are reused from the pool if available and
    suitable.

    @raise Broken_pool
      in case it is not possible to acquire a valid connection from the pool

    @param sw
      The Eio switch to use for managing resources. The connection will be put
      back in the pool on [sw]’s release
    @param body The request body to send.
    @param chunked
      Whether the request body should be sent with chunked transfer encoding.
    @param headers Optional HTTP headers to include in the request.
    @param t The connection pool instance.
    @param query Optional query parameters to append to the URL path.
    @param userinfo
      Optional user info to include in the URL (e.g., for basic authentication).
    @param path
      The path component of the URL. This will be combined with the pool's base
      URI.
    @return
      A tuple containing the HTTP response and its body. The body will be
      consumed on [sw]’s release, in order to enable the reuse of the
      connection. *)

val put :
  sw:Eio.Std.Switch.t ->
  ?body:Cohttp_eio.Body.t ->
  ?chunked:bool ->
  ?headers:Http.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t
(** [put ~sw ?body ?chunked ?headers t ?query ?userinfo path] makes an HTTP PUT
    request using a connection from the pool.

    This function is typically used to create or update a resource at a specific
    URI. Unlike POST, PUT is idempotent. Connections are reused from the pool if
    available and suitable.

    @raise Broken_pool
      in case it is not possible to acquire a valid connection from the pool

    @param sw
      The Eio switch to use for managing resources. The connection will be put
      back in the pool on [sw]’s release
    @param body The request body to send.
    @param chunked
      Whether the request body should be sent with chunked transfer encoding.
    @param headers Optional HTTP headers to include in the request.
    @param t The connection pool instance.
    @param query Optional query parameters to append to the URL path.
    @param userinfo
      Optional user info to include in the URL (e.g., for basic authentication).
    @param path
      The path component of the URL. This will be combined with the pool's base
      URI.
    @return
      A tuple containing the HTTP response and its body. The body will be
      consumed on [sw]’s release, in order to enable the reuse of the
      connection. *)

val patch :
  sw:Eio.Std.Switch.t ->
  ?body:Cohttp_eio.Body.t ->
  ?chunked:bool ->
  ?headers:Http.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t
(** [patch ~sw ?body ?chunked ?headers t ?query ?userinfo path] makes an HTTP
    PATCH request using a connection from the pool.

    This function is used to apply partial modifications to a resource. Unlike
    PUT, which replaces a resource entirely, PATCH applies a set of changes.
    Connections are reused from the pool if available and suitable.

    @raise Broken_pool
      in case it is not possible to acquire a valid connection from the pool

    @param sw
      The Eio switch to use for managing resources. The connection will be put
      back in the pool on [sw]’s release
    @param body The request body to send.
    @param chunked
      Whether the request body should be sent with chunked transfer encoding.
    @param headers Optional HTTP headers to include in the request.
    @param t The connection pool instance.
    @param query Optional query parameters to append to the URL path.
    @param userinfo
      Optional user info to include in the URL (e.g., for basic authentication).
    @param path
      The path component of the URL. This will be combined with the pool's base
      URI.
    @return
      A tuple containing the HTTP response and its body. The body will be
      consumed on [sw]’s release, in order to enable the reuse of the
      connection. *)

val delete :
  sw:Eio.Std.Switch.t ->
  ?body:Cohttp_eio.Body.t ->
  ?chunked:bool ->
  ?headers:Http.Header.t ->
  t ->
  ?query:(string * string list) list ->
  ?userinfo:string ->
  string ->
  Http.Response.t * Cohttp_eio.Body.t
(** [delete ~sw ?body ?chunked ?headers t ?query ?userinfo path] makes an HTTP
    DELETE request using a connection from the pool.

    This function is used to delete a specified resource on the server.
    Connections are reused from the pool if available and suitable.

    @raise Broken_pool
      in case it is not possible to acquire a valid connection from the pool

    @param sw
      The Eio switch to use for managing resources. The connection will be put
      back in the pool on [sw]’s release
    @param body The request body to send.
    @param chunked
      Whether the request body should be sent with chunked transfer encoding.
    @param headers Optional HTTP headers to include in the request.
    @param t The connection pool instance.
    @param query Optional query parameters to append to the URL path.
    @param userinfo
      Optional user info to include in the URL (e.g., for basic authentication).
    @param path
      The path component of the URL. This will be combined with the pool's base
      URI.
    @return
      A tuple containing the HTTP response and its body. The body will be
      consumed on [sw]’s release, in order to enable the reuse of the
      connection. *)
