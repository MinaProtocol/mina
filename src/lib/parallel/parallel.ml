open Core
open Async

let initialized = ref false

let worker_command_name = "parallel-worker"

let worker_command = Rpc_parallel.Expert.worker_command

let init_master () =
  if not !initialized then (
    let rpc_heartbeat_config =
      Rpc.Connection.Heartbeat_config.create
        ~send_every:(Time_ns.Span.of_sec 10.) ~timeout:(Time_ns.Span.of_min 5.)
    in
    Rpc_parallel.Expert.start_master_server_exn
      ~rpc_handshake_timeout:(Time.Span.of_min 10.) ~rpc_heartbeat_config
      ~worker_command_args:[worker_command_name] () ;
    initialized := true )

let kill ~logger ~prompt error =
  let message = sprintf !"%s: %s!" prompt (Error.to_string_hum error) in
  Logger.fatal logger !"%s!" message ;
  failwithf !"%s!" message ()

let run_connection ~logger ~error_message ~on_success action =
  match%map action with
  | Error e -> kill ~logger ~prompt:error_message e
  | Ok result -> on_success result
