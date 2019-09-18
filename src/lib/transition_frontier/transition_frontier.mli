open Async_kernel
open Pipe_lib
open Coda_base
open Frontier_base

module Breadcrumb = Breadcrumb
module Diff = Diff
module Hash = Frontier_hash
module Extensions = Extensions
module Persistent_root = Persistent_root
module Persistent_frontier = Persistent_frontier

include Frontier_intf.S

type config =
  { logger: Logger.t
  ; verifier: Verifier.t
  ; consensus_local_state: Consensus.Data.Local_state.t }

val load :
     ?retry_with_fresh_db:bool
  -> config
  -> persistent_root:Persistent_root.t
  -> persistent_frontier:Persistent_frontier.t
  -> ( t
     , [> `Failure of string
       | `Bootstrap_required
       | `Persistent_frontier_malformed ] )
     Deferred.Result.t

val wait_for_transition : t -> State_hash.t -> unit Deferred.t

val persistent_root : t -> Persistent_root.t

val persistent_frontier : t -> Persistent_frontier.t

val root_snarked_ledger : t -> Ledger.Db.t

val previous_root : t -> Breadcrumb.t option

val oldest_breadcrumb_in_history : t -> Breadcrumb.t option

val snark_pool_refcount_pipe :
     t
  -> (int * int Transaction_snark_work.Statement.Table.t)
     Pipe_lib.Broadcast_pipe.Reader.t

type best_tip_diff =
  { new_user_commands: User_command.t list
  ; removed_user_commands: User_command.t list }

val best_tip_diff_pipe : t -> best_tip_diff Pipe_lib.Broadcast_pipe.Reader.t

val root_history_path_map :
  t -> State_hash.t -> f:(Breadcrumb.t -> 'a) -> 'a Non_empty_list.t option

val find_in_root_history : t -> State_hash.t -> Breadcrumb.t option

val close : t -> unit Deferred.t

module For_tests : sig
  val load_with_max_length : 
         ?retry_with_fresh_db:bool
      -> max_length:int
      -> config
      -> persistent_root:Persistent_root.t
      -> persistent_frontier:Persistent_frontier.t
      -> ( t
         , [> `Bootstrap_required
           | `Persistent_frontier_malformed
           | `Failure of string ] )
         Deferred.Result.t

  (* TODO: remove *)
  val identity_pipe : t -> Diff.Lite.E.t Broadcast_pipe.Reader.t
end
