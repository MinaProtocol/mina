open Coda_base
open Frontier_base

type t

include Intf.Extension_intf with type t := t and type view = t

val is_empty : t -> bool

val lookup : t -> State_hash.t -> Root_data.Limited.t option

val mem : t -> State_hash.t -> bool

val most_recent : t -> Root_data.Limited.t option

val oldest : t -> Root_data.Limited.t option
