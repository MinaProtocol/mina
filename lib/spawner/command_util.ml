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
  let%map_open host = host_flag
  and executable_path = executable_path_flag
  and log_dir =
    flag "log-directory"
      ~doc:
        (sprintf
           "master host's log directory for worker host's console output \
            (default: %s)"
           default_log_dir)
      (optional_with_default default_log_dir file)
  in
  {Config.id= (); host; executable_path; log_dir}
