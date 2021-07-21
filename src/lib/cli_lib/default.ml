(** Default values for cli flags *)

open Core

let work_reassignment_wait = 420000

let max_connections = 50

let validation_queue_size = 150

(** default directory for persistent application data files, eg. databases *)
let app_data_dir = List.hd_exn @@ XDGBaseDir.Data.system_files "mina"

(** default directory for ephemeral runtime state, eg. process locks *)
let runtime_dir =
  XDGBaseDir.Runtime.user_file "mina" |> Option.value ~default:"/tmp/mina"

(** default directory for state files, eg. logs *)
let state_dir = XDGBaseDir.State.user_file "mina"

(** default directory for user configuration files *)
let user_conf_dir = XDGBaseDir.Config.user_file "mina"

(** default directory for user data files, eg. wallets *)
let user_data_dir = XDGBaseDir.Data.user_file "mina"
