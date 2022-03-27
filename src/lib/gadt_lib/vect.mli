type ('el, 'n) t =
  | [] : ('el, Peano.zero) t
  | ( :: ) : 'el * ('el, 'n) t -> ('el, 'n Peano.succ) t

val is_empty : ('a, 'n) t -> bool

val to_list : ('a, 'n) t -> 'a list

val map : f:('a -> 'b) -> ('a, 'n) t -> ('b, 'n) t

val map2 : f:('a -> 'b -> 'c) -> ('a, 'n) t -> ('b, 'n) t -> ('c, 'n) t

val fold : init:'b -> f:('b -> 'a -> 'b) -> ('a, 'n) t -> 'b

val fold_map :
  init:'b -> f:('b -> 'a -> 'b * 'c) -> ('a, 'n) t -> 'b * ('c, 'n) t

module Quickcheck_generator : sig
  val map :
       f:('a -> 'b Core_kernel.Quickcheck.Generator.t)
    -> ('a, 'n) t
    -> ('b, 'n) t Core_kernel.Quickcheck.Generator.t
end
