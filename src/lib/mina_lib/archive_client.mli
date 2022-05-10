open Core
open Pipe_lib

val dispatch_precomputed_block :
     ?max_tries:int
  -> Host_and_port.t Cli_lib.Flag.Types.with_name
  -> Mina_block.Precomputed.t
  -> unit Async.Deferred.Or_error.t

val dispatch_extensional_block :
     ?max_tries:int
  -> Host_and_port.t Cli_lib.Flag.Types.with_name
  -> Archive_lib.Extensional.Block.t
  -> unit Async.Deferred.Or_error.t

val run :
     logger:Logger.t
  -> frontier_broadcast_pipe:
       Transition_frontier.t option Broadcast_pipe.Reader.t
  -> Host_and_port.t Cli_lib.Flag.Types.with_name
  -> unit
