(** This module implements the RocksDB interface for interacting with the
 *  persistent frontier's database. This interface includes all of the
 *  basic low level interactions with the database, as well as functionality
 *  for checking the database for structural errors (corruption). Errors
 *  returned from this module come in the form of polymorphic variants.
 *  The [Error] module is provided as a simple interface for converting
 *  these polymorphic variant errors into human readable strings.
 *)

open Async_kernel
open Core_kernel
open Mina_base
open Frontier_base

type t

type batch_t

val with_batch : t -> f:(batch_t -> 'a) -> 'a

module Error : sig
  type not_found_member =
    [ `Root
    | `Root_hash
    | `Root_common
    | `Best_tip
    | `Frontier_hash
    | `Root_transition
    | `Best_tip_transition
    | `Parent_transition of State_hash.t
    | `New_root_transition
    | `Old_root_transition
    | `Transition of State_hash.t
    | `Arcs of State_hash.t
    | `Protocol_states_for_root_scan_state ]

  type not_found = [ `Not_found of not_found_member ]

  type raised = [ `Raised of Error.t ]

  type t = [ not_found | raised | `Invalid_version ]

  val not_found_message : not_found -> string

  val message : t -> string
end

val create : logger:Logger.t -> directory:string -> t

val close : t -> unit

val check :
     t
  -> genesis_state_hash:State_hash.t
  -> ( Frozen_ledger_hash.t
     , [> `Not_initialized
       | `Invalid_version
       | `Genesis_state_mismatch of State_hash.t
       | `Corrupt of
         [> `Not_found of
            [> `Best_tip
            | `Best_tip_transition
            | `Frontier_hash
            | `Root
            | `Root_transition
            | `Transition of State_hash.t
            | `Arcs of State_hash.t
            | `Protocol_states_for_root_scan_state ]
         | `Raised of Core_kernel.Error.t ] ] )
     Result.t

val initialize : t -> root_data:Root_data.Limited.t -> unit

val find_arcs_and_root :
     t
  -> arcs_cache:State_hash.t list State_hash.Table.t
  -> parent_hashes:State_hash.t list
  -> ( State_hash.t
     , [> `Not_found of [> `Arcs of State_hash.t | `Old_root_transition ] ] )
     result

val add :
     arcs_cache:State_hash.t list State_hash.Table.t
  -> transition:Mina_block.Validated.t
  -> batch_t
  -> unit

val move_root :
     old_root_hash:State_hash.t
  -> new_root:Root_data.Limited.Stable.Latest.t
  -> garbage:State_hash.t list
  -> batch_t
  -> unit

val get_transition :
     proof_cache_db:Proof_cache_tag.cache_db
  -> t
  -> State_hash.t
  -> ( Mina_block.Validated.t
     , [> `Not_found of [> `Transition of State_hash.t ] ] )
     Result.t

val get_arcs :
     t
  -> State_hash.t
  -> (State_hash.t list, [> `Not_found of [> `Arcs of State_hash.t ] ]) Result.t

val get_root :
     t
  -> (Root_data.Minimal.Stable.Latest.t, [> `Not_found of [> `Root ] ]) Result.t

val get_protocol_states_for_root_scan_state :
     t
  -> ( Mina_state.Protocol_state.value list
     , [> `Not_found of [> `Protocol_states_for_root_scan_state ] ] )
     Result.t

val get_root_hash : t -> (State_hash.t, [> `Not_found of [> `Root ] ]) Result.t

val get_best_tip :
  t -> (State_hash.t, [> `Not_found of [> `Best_tip ] ]) Result.t

val set_best_tip : State_hash.t -> batch_t -> unit

val crawl_successors :
     proof_cache_db:Proof_cache_tag.cache_db
  -> t
  -> State_hash.t
  -> init:'a
  -> f:('a -> Mina_block.Validated.t -> ('a, 'b) Deferred.Result.t)
  -> ( unit
     , [> `Crawl_error of 'b
       | `Not_found of [> `Arcs of State_hash.t | `Transition of State_hash.t ]
       ] )
     Deferred.Result.t
