open Core
open Async

(** Methods for the client to interact with Mina protocol *)

let print_rpc_error error =
  eprintf "RPC connection error: %s\n" (Error.to_string_hum error)

let dispatch ~(compile_config : Mina_compile_config.t) rpc query
    (host_and_port : Host_and_port.t) =
  Deferred.Or_error.try_with_join ~here:[%here] (fun () ->
      Tcp.with_connection (Tcp.Where_to_connect.of_host_and_port host_and_port)
        ~timeout:(Time.Span.of_sec 1.) (fun _ r w ->
          let open Deferred.Let_syntax in
          match%bind
            Rpc.Connection.create
              ~handshake_timeout:compile_config.rpc_handshake_timeout
              ~heartbeat_config:
                (Rpc.Connection.Heartbeat_config.create
                   ~timeout:compile_config.rpc_heartbeat_timeout
                   ~send_every:compile_config.rpc_heartbeat_send_every () ) r w
              ~connection_state:(fun _ -> ())
          with
          | Error exn ->
              return
                (Or_error.errorf
                   !"Error connecting to the daemon on %{sexp:Host_and_port.t} \
                     using the RPC call, %s,: %s"
                   host_and_port (Rpc.Rpc.name rpc) (Exn.to_string exn) )
          | Ok conn ->
              Rpc.Rpc.dispatch rpc conn query ) )

let dispatch_join_errors ~compile_config rpc query port =
  let open Deferred.Let_syntax in
  let%map res = dispatch ~compile_config rpc query port in
  Or_error.join res

(** Call an RPC, passing handlers for a successful call and a failing one. Note
    that a successful *call* may have failed on the server side and returned a
    failing result. To deal with that, the success handler returns an
    Or_error. *)
let dispatch_with_message ~compile_config rpc query port ~success ~error
    ~(join_error : 'a Or_error.t -> 'b Or_error.t) =
  let fail err = eprintf "%s\n%!" err ; exit 18 in
  let%bind res = dispatch ~compile_config rpc query port in
  match join_error res with
  | Ok x ->
      printf "%s\n" (success x) ;
      Deferred.unit
  | Error e ->
      fail (error e)

let dispatch_pretty_message (type t)
    (module Print : Cli_lib.Render.Printable_intf with type t = t)
    ?(json = true) ~compile_config ~(join_error : 'a Or_error.t -> t Or_error.t)
    ~error_ctx rpc query port =
  let%bind res = dispatch ~compile_config rpc query port in
  Cli_lib.Render.print (module Print) json (join_error res) ~error_ctx
  |> Deferred.return
