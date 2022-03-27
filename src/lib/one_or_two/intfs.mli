type 'a t = [ `One of 'a | `Two of 'a * 'a ]

module type Monadic2 = sig
  type ('a, 'e) m

  val sequence : ('a, 'e) m t -> ('a t, 'e) m

  val map : 'a t -> f:('a -> ('b, 'e) m) -> ('b t, 'e) m

  val fold :
    'a t -> init:'accum -> f:('accum -> 'a -> ('accum, 'e) m) -> ('accum, 'e) m
end

module type Monadic = sig
  type 'a m

  val sequence : 'a m t -> 'a t m

  val map : 'a t -> f:('a -> 'b m) -> 'b t m

  val fold : 'a t -> init:'accum -> f:('accum -> 'a -> 'accum m) -> 'accum m
end
