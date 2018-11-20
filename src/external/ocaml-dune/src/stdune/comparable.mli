module type S = sig
  type t
  val compare : t -> t -> Ordering.t
end

module type OPS = sig
  type t
  val (=) : t -> t -> bool
  val (>=) : t -> t -> bool
  val (>) : t -> t -> bool
  val (<=) : t -> t -> bool
  val (<) : t -> t -> bool
end

module Operators (X : S) : OPS with type t = X.t
