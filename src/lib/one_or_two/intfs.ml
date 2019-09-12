type 'a t = [`One of 'a | `Two of 'a * 'a]

(** One_or_two operations in a two-parameter monad. *)
module type Monadic2 = sig
  type ('a, 'e) m

  val sequence : ('a, 'e) m t -> ('a t, 'e) m

  val map : 'a t -> f:('a -> ('b, 'e) m) -> ('b t, 'e) m

  val fold :
    'a t -> init:'accum -> f:('accum -> 'a -> ('accum, 'e) m) -> ('accum, 'e) m
end

(** One_or_two operations in a single parameter monad. *)
module type Monadic = sig
  type 'a m

  include Monadic2 with type ('a, 'e) m := 'a m
end
