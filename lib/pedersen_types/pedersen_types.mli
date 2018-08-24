module Four : sig
  type t
end

module Triple : sig
  type 'a t = 'a * 'a * 'a
 
  val get : bool t -> Four.t 
end

module Quadruple  : sig
  type 'a t = 'a * 'a * 'a * 'a

  val get : 'a t -> Four.t -> 'a
end

type ('s, 'b) fold = init:'s -> f:('s -> 'b -> 's) -> 's

type 'b poly_fold = { fold : 's. ('s, 'b) fold }

type bit_fold = bool poly_fold

type triple_fold = bool Triple.t poly_fold

val triple_fold_of_bit_fold : bit_fold -> triple_fold