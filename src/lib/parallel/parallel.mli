open Core
open Async

val init_master : unit -> unit

val worker_command : Command.t

val worker_command_name : string

val run_connection :
     logger:Logger.t
  -> error_message:string
  -> on_success:('a -> 'b)
  -> ('a, Error.t) result Deferred.t
  -> 'b Deferred.t
