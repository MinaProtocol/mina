open Core

(* We use this container interface rather than the default Core libraries because we do not expose
  slow methods that are derived by Container.Make0, such as length and mem, but are fast using 
  each database's internal implementation  *)

module type S = sig
  type t

  type elt

  val iter : t -> f:(elt -> unit) -> unit

  val fold : t -> init:'accum -> f:('accum -> elt -> 'accum) -> 'accum

  val fold_result :
       t
    -> init:'accum
    -> f:('accum -> elt -> ('accum, 'e) Result.t)
    -> ('accum, 'e) Result.t

  val exists : t -> f:(elt -> bool) -> bool

  val for_all : t -> f:(elt -> bool) -> bool

  val count : t -> f:(elt -> bool) -> int

  val find : t -> f:(elt -> bool) -> elt option

  val find_map : t -> f:(elt -> 'a option) -> 'a option

  val to_list : t -> elt list

  val to_array : t -> elt array

  val min_elt : t -> compare:(elt -> elt -> int) -> elt option

  val max_elt : t -> compare:(elt -> elt -> int) -> elt option
end
