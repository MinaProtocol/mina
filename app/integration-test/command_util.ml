open Core
open Async

let local_machine_host = "127.0.0.1"

let default_log_dir = "/tmp/coda/integration-logs"

let run master_command =
  Random.self_init () ;
  Command.group ~summary:"Task"
    [ ( "task"
      , Command.async ~summary:"Master Node invokes and runs a Worker"
          master_command )
    ; (Parallel.worker_command_name, Parallel.worker_command) ]
  |> Command.run ;
  never_returns (Scheduler.go ())

let config_arguments =
  let open Command.Let_syntax in
  let%map_open host =
    flag "host"
      (optional_with_default local_machine_host string)
      ~doc:
        (sprintf "ip address of running program (default: %s)"
           local_machine_host)
  and executable_path =
    flag "path" ~doc:"path of executable within host" (required string)
  and log_dir =
    flag "log-directory"
      ~doc:
        (sprintf
           "master host's log directory for worker host's console output \
            (default: ~/%s)"
           default_log_dir)
      (optional file)
  in
  {Spawner.Config.host; executable_path; log_dir}
