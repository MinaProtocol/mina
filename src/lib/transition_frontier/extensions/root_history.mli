(** The root history extension provides a historical view into previous roots the
 *  transition frontier has maintained. The root history will store at most the
 *  [2*k] historical roots.
 *)

open Mina_base
open Frontier_base

type t

include Intf.Extension_intf with type t := t and type view = t

val is_empty : t -> bool

val lookup : t -> State_hash.t -> Root_data.Historical.t option

val mem : t -> State_hash.t -> bool

val most_recent : t -> Root_data.Historical.t option

val oldest : t -> Root_data.Historical.t option

val to_list : t -> Root_data.Historical.t list

val get_staged_ledger_aux_and_pending_coinbases_at_hash :
     t
  -> State_hash.t
  -> Frontier_base.Network_types
     .Get_staged_ledger_aux_and_pending_coinbases_at_hash_result
     .Data
     .Stable
     .Latest
     .t
     option
