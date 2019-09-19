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

(* This is the max length which is used when the transition frontier is initialized
 * via `load`. In other words, this will always be the max length of the transition
 * frontier as long as the `For_tests.load_with_max_length` is not used *)
val global_max_length : int

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

val close : t -> unit Deferred.t

val add_breadcrumb_exn : t -> Breadcrumb.t -> unit Deferred.t

val persistent_root : t -> Persistent_root.t

val persistent_frontier : t -> Persistent_frontier.t

val root_snarked_ledger : t -> Ledger.Db.t

val extensions : t -> Extensions.t

module For_tests : sig
  val load_with_max_length :
       max_length:int
    -> ?retry_with_fresh_db:bool
    -> config
    -> persistent_root:Persistent_root.t
    -> persistent_frontier:Persistent_frontier.t
    -> ( t
       , [> `Bootstrap_required
         | `Persistent_frontier_malformed
         | `Failure of string ] )
       Deferred.Result.t
end
