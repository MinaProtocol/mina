(** The root history extension provides a historical view into previous roots the
 *  transition frontier has maintained. The root history will store at most the
 *  [2*k] historical roots.
 *)

open Coda_base
open Frontier_base

type t

include Intf.Extension_intf with type t := t and type view = t

val is_empty : t -> bool

val lookup : t -> State_hash.t -> Root_data.Historical.t option

val mem : t -> State_hash.t -> bool

val most_recent : t -> Root_data.Historical.t option

val oldest : t -> Root_data.Historical.t option

val to_list : t -> Root_data.Historical.t list
