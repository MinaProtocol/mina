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

(** Send a hard fork runtime configuration to the archive process.

    The archive derives the fork block's identity and the genesis ledger's
    location from the configuration alone, so this is the only message the
    hand-over needs. Delivery is best effort; the caller is expected to repeat
    it rather than to rely on a single attempt. *)
val dispatch_hardfork_config :
     ?max_tries:int
  -> logger:Logger.t
  -> Host_and_port.t Cli_lib.Flag.Types.with_name
  -> config_json:string
  -> unit Async.Deferred.Or_error.t

val run :
     logger:Logger.t
  -> precomputed_values:Precomputed_values.t
  -> frontier_broadcast_pipe:
       Transition_frontier.t option Broadcast_pipe.Reader.t
  -> Host_and_port.t Cli_lib.Flag.Types.with_name
  -> unit
