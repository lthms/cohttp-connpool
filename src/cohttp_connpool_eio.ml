type connection = {
  client : Cohttp_eio.Client.t;
  sw : Eio.Switch.t;
  endpoint : Uri.t;
  socket : [ `Generic ] Eio.Net.stream_socket_ty Eio.Resource.t;
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

let make_connection ~sw ~net endpoint =
  let net = (net :> [ `Generic ] Eio.Net.ty Eio.Std.r) in
  let sockaddr = tcp_address ~net endpoint in
  let socket = Eio.Net.connect ~sw net sockaddr in
  {
    client = Cohttp_eio.Client.make_generic (fun ~sw:_ _uri -> socket);
    sw;
    endpoint;
    socket;
    alive = true;
  }

let make ~sw ~net ~n uri =
  {
    pool =
      Eio.Pool.create
        ~validate:(fun conn -> conn.alive)
        ~dispose:(fun conn ->
          Eio.traceln "disposing";
          Eio.Net.close conn.socket)
        n
        (fun () -> make_connection ~sw ~net uri);
    pool_size = n;
  }

exception Invalidated_socket
exception Broken_pool

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
            conn.alive <- false;
            raise Invalidated_socket
        with Invalidated_socket -> use (n - 1))
    | _otherwise -> raise Broken_pool
  in
  use t.pool_size

let get ?headers t route =
  use t @@ fun conn ->
  let uri = Uri.with_path conn.endpoint route in
  let response, body =
    Cohttp_eio.Client.get ?headers ~sw:conn.sw conn.client uri
  in
  (response, Eio.Buf_read.(parse_exn take_all) body ~max_size:max_int)
