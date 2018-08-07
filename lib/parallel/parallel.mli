open Async

val init_master : unit -> unit

val worker_command : Command.t

val worker_command_name : string
