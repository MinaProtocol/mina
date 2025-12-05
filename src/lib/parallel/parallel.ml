open Core
open Async
open Rpc_parallel_unauthenticated

let initialized = ref false

let worker_command_name = "parallel-worker"

let worker_command = Expert.worker_command

let init_master () =
  if not !initialized then (
    let rpc_heartbeat_config =
      Rpc.Connection.Heartbeat_config.create
        ~send_every:(Time_ns.Span.of_sec 10.) ~timeout:(Time_ns.Span.of_min 15.)
        ()
    in
    Expert.start_master_server_exn
      ~rpc_handshake_timeout:(Time_float.Span.of_min 10.)
      ~rpc_heartbeat_config ~worker_command_args:[ worker_command_name ] () ;
    initialized := true )
