module Peano : sig
  type zero = unit

  type 'n succ = unit -> 'n

  type _0 = zero

  type _1 = _0 succ

  type _2 = _1 succ

  type _3 = _2 succ

  type _4 = _3 succ

  type _5 = _4 succ

  type _6 = _5 succ

  type 'n gt_0 = 'n succ

  type 'n gt_1 = 'n succ gt_0

  type 'n gt_2 = 'n succ gt_1

  type 'n gt_3 = 'n succ gt_2

  type 'n gt_4 = 'n succ gt_3

  type 'n gt_5 = 'n succ gt_4

  type 'n gt_6 = 'n succ gt_5

  type 'n t = Z : zero t | S : 'n t -> 'n succ t

  val _0 : zero t

  val _1 : _1 t

  val _2 : _2 t

  val _3 : _3 t

  val _4 : _4 t

  val _5 : _5 t

  val _6 : _6 t
end

module Vect : sig
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
end
