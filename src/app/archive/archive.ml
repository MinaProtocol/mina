open Core
open Async
open Cli_lib
open Archive_lib
open Pipe_lib

let default_hasura_port = 9000

module Processor = Processor.Make (struct
  let headers = String.Map.of_alist_exn []

  let preprocess_variables_string =
    String.substr_replace_all ~pattern:{|"constraint_"|}
      ~with_:{|"constraint"|}
end)

let setup_server ~logger ~hasura_endpoint ~server_port =
  let where_to_listen =
    Tcp.Where_to_listen.bind_to All_addresses (On_port server_port)
  in
  let reader, writer = Strict_pipe.create ~name:"archive" Synchronous in
  let implementations =
    [ Async.Rpc.Rpc.implement Rpc.t (fun () archive_diff ->
          Strict_pipe.Writer.write writer archive_diff ) ]
  in
  let processor = Processor.create hasura_endpoint in
  Processor.run processor reader |> don't_wait_for ;
  Deferred.ignore
  @@ Tcp.Server.create
       ~on_handler_error:
         (`Call
           (fun _net exn ->
             Logger.error logger ~module_:__MODULE__ ~location:__LOC__
               "Exception while handling TCP server request: $error"
               ~metadata:
                 [ ("error", `String (Exn.to_string_mach exn))
                 ; ("context", `String "rpc_tcp_server") ] ))
       where_to_listen
       (fun address reader writer ->
         let address = Socket.Address.Inet.addr address in
         Async.Rpc.Connection.server_with_close reader writer
           ~implementations:
             (Async.Rpc.Implementations.create_exn ~implementations
                ~on_unknown_rpc:`Raise)
           ~connection_state:(fun _ -> ())
           ~on_handshake_error:
             (`Call
               (fun exn ->
                 Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                   "Exception while handling RPC server request from \
                    $address: $error"
                   ~metadata:
                     [ ("error", `String (Exn.to_string_mach exn))
                     ; ("context", `String "rpc_server")
                     ; ("address", `String (Unix.Inet_addr.to_string address))
                     ] ;
                 Deferred.unit )) )
  |> don't_wait_for ;
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Archive process ready. Clients can now connect" ;
  Async.never ()

let command =
  let open Command.Let_syntax in
  let%map_open log_json = Flag.Log.json
  and log_level = Flag.Log.level
  and server_port = Flag.Port.Archive.server
  and hasura_endpoint = Flag.Uri.Archive.hasura in
  fun () ->
    let logger = Logger.create () in
    Stdout_log.setup log_json log_level ;
    setup_server ~logger ~hasura_endpoint:hasura_endpoint.value
      ~server_port:
        (Option.value server_port.value ~default:server_port.default)

let () =
  Command.run
    (Command.async
       ~summary:"Run an archive process that can store all of the data of Coda"
       command)
