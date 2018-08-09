open Core
open Async

let local_machine_host = "127.0.0.1"

let default_log_dir = "/tmp/coda/integration-logs"

let host_flag =
  let open Command.Param in
  flag "host"
    (optional_with_default local_machine_host string)
    ~doc:
      (sprintf "ip address of running program (default: %s)" local_machine_host)

let executable_path_flag =
  let open Command.Param in
  flag "path" ~doc:"path of executable within host"
    (optional_with_default Sys.executable_name string)

let config_arguments =
  let open Command.Let_syntax in
  let%map host = host_flag and
  executable_path = executable_path_flag in
  {Config.id= (); host; executable_path}
