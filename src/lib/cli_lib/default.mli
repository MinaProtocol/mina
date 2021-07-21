(** Default values for cli flags *)

val work_reassignment_wait : int

val max_connections : int

val validation_queue_size : int

(** default directory for persistent application data files, eg. databases *)
val app_data_dir : string

(** default directory for ephemeral runtime state, eg. process locks *)
val runtime_dir : string

(** default directory for state files, eg. logs *)
val state_dir : string

(** default directory for user configuration files *)
val user_conf_dir : string

(** default directory for user data files, eg. wallets *)
val user_data_dir : string
