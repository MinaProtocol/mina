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
open Coda_base
open Coda_transition
open Frontier_base

type t

module Error : sig
  type not_found_member =
    [ `Root
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

  type not_found = [`Not_found of not_found_member]

  type t = [not_found | `Invalid_version]

  val not_found_message : not_found -> string

  val message : t -> string
end

val create : logger:Logger.t -> directory:string -> t

val close : t -> unit

val check :
     t
  -> ( unit
     , [> `Not_initialized
       | `Invalid_version
       | `Corrupt of
         [> `Not_found of
            [> `Best_tip
            | `Best_tip_transition
            | `Frontier_hash
            | `Root
            | `Root_transition
            | `Transition of State_hash.t
            | `Arcs of State_hash.t
            | `Protocol_states_for_root_scan_state ] ] ] )
     Result.t

val initialize : t -> root_data:Root_data.Limited.t -> unit

val add :
     t
  -> transition:External_transition.Validated.t
  -> ( unit
     , [> `Not_found of
          [> `Parent_transition of State_hash.t | `Arcs of State_hash.t] ] )
     Result.t

val move_root :
     t
  -> new_root:Root_data.Limited.t
  -> garbage:State_hash.t list
  -> ( State_hash.t
     , [> `Not_found of [> `New_root_transition | `Old_root_transition]] )
     Result.t

val get_transition :
     t
  -> State_hash.t
  -> ( External_transition.Validated.t
     , [> `Not_found of [> `Transition of State_hash.t]] )
     Result.t

val get_arcs :
     t
  -> State_hash.t
  -> (State_hash.t list, [> `Not_found of [> `Arcs of State_hash.t]]) Result.t

val get_root : t -> (Root_data.Minimal.t, [> `Not_found of [> `Root]]) Result.t

val get_protocol_states_for_root_scan_state :
     t
  -> ( Coda_state.Protocol_state.value list
     , [> `Not_found of [> `Protocol_states_for_root_scan_state]] )
     Result.t

val get_root_hash : t -> (State_hash.t, [> `Not_found of [> `Root]]) Result.t

val get_best_tip :
  t -> (State_hash.t, [> `Not_found of [> `Best_tip]]) Result.t

val set_best_tip :
  t -> State_hash.t -> (State_hash.t, [> `Not_found of [> `Best_tip]]) Result.t

val crawl_successors :
     t
  -> State_hash.t
  -> init:'a
  -> f:('a -> External_transition.Validated.t -> ('a, 'b) Deferred.Result.t)
  -> ( unit
     , [> `Crawl_error of 'b
       | `Not_found of [> `Arcs of State_hash.t | `Transition of State_hash.t]
       ] )
     Deferred.Result.t
