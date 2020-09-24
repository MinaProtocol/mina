(** The transition frontier is the data structure for tracking active forks
 *  at the "frontier" of the blockchain being constructed by the network.
 *  It includes support for extensions (incremental views on top of this
 *  data structure), persistence (saving/loading the data structure
 *  to/from disk), and various queries.
 *)

open Async_kernel
open Coda_base
open Frontier_base
module Breadcrumb = Breadcrumb
module Diff = Diff
module Hash = Frontier_hash
module Extensions = Extensions
module Persistent_root = Persistent_root
module Persistent_frontier = Persistent_frontier
module Root_data = Root_data

include Frontier_intf.S

type Structured_log_events.t += Added_breadcrumb_user_commands
  [@@deriving register_event]

(* This is the max length which is used when the transition frontier is initialized
 * via `load`. In other words, this will always be the max length of the transition
 * frontier as long as the `For_tests.load_with_max_length` is not used *)
val global_max_length : Genesis_constants.t -> int

val load :
     ?retry_with_fresh_db:bool
  -> logger:Logger.t
  -> verifier:Verifier.t
  -> consensus_local_state:Consensus.Data.Local_state.t
  -> persistent_root:Persistent_root.t
  -> persistent_frontier:Persistent_frontier.t
  -> precomputed_values:Precomputed_values.t
  -> unit
  -> ( t
     , [> `Failure of string
       | `Bootstrap_required
       | `Persistent_frontier_malformed ] )
     Deferred.Result.t

val close : t -> unit Deferred.t

val add_breadcrumb_exn : t -> Breadcrumb.t -> unit Deferred.t

val persistent_root : t -> Persistent_root.t

val persistent_frontier : t -> Persistent_frontier.t

val root_snarked_ledger : t -> Ledger.Db.t

val extensions : t -> Extensions.t

val genesis_state_hash : t -> State_hash.t

module For_tests : sig
  open Signature_lib

  val equal : t -> t -> bool

  val load_with_max_length :
       max_length:int
    -> ?retry_with_fresh_db:bool
    -> logger:Logger.t
    -> verifier:Verifier.t
    -> consensus_local_state:Consensus.Data.Local_state.t
    -> persistent_root:Persistent_root.t
    -> persistent_frontier:Persistent_frontier.t
    -> precomputed_values:Precomputed_values.t
    -> unit
    -> ( t
       , [> `Failure of string
         | `Bootstrap_required
         | `Persistent_frontier_malformed ] )
       Deferred.Result.t

  val gen_genesis_breadcrumb :
       ?logger:Logger.t
    -> ?verifier:Verifier.t
    -> precomputed_values:Precomputed_values.t
    -> unit
    -> Breadcrumb.t Quickcheck.Generator.t

  val gen_persistence :
       ?logger:Logger.t
    -> ?verifier:Verifier.t
    -> precomputed_values:Precomputed_values.t
    -> unit
    -> (Persistent_root.t * Persistent_frontier.t) Quickcheck.Generator.t

  val gen :
       ?logger:Logger.t
    -> ?verifier:Verifier.t
    -> ?trust_system:Trust_system.t
    -> ?consensus_local_state:Consensus.Data.Local_state.t
    -> precomputed_values:Precomputed_values.t
    -> ?root_ledger_and_accounts:Ledger.t
                                 * (Private_key.t option * Account.t) list
    -> ?gen_root_breadcrumb:( Breadcrumb.t
                            * ( Coda_base.State_hash.t
                              * Coda_state.Protocol_state.value )
                              list )
                            Quickcheck.Generator.t
    -> max_length:int
    -> size:int
    -> unit
    -> t Quickcheck.Generator.t

  val gen_with_branch :
       ?logger:Logger.t
    -> ?verifier:Verifier.t
    -> ?trust_system:Trust_system.t
    -> ?consensus_local_state:Consensus.Data.Local_state.t
    -> precomputed_values:Precomputed_values.t
    -> ?root_ledger_and_accounts:Ledger.t
                                 * (Private_key.t option * Account.t) list
    -> ?gen_root_breadcrumb:( Breadcrumb.t
                            * ( Coda_base.State_hash.t
                              * Coda_state.Protocol_state.value )
                              list )
                            Quickcheck.Generator.t
    -> ?get_branch_root:(t -> Breadcrumb.t)
    -> max_length:int
    -> frontier_size:int
    -> branch_size:int
    -> unit
    -> (t * Breadcrumb.t list) Quickcheck.Generator.t
end
