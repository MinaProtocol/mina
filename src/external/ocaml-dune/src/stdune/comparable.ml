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

module Operators (X : S) = struct
  type t = X.t

  let (=) a b =
    match X.compare a b with
    | Eq -> true
    | Gt | Lt -> false

  let (>=) a b =
    match X.compare a b with
    | Gt | Eq -> true
    | Lt -> false

  let (>) a b =
    match X.compare a b with
    | Gt -> true
    | Lt | Eq -> false

  let (<=) a b =
    match X.compare a b with
    | Lt | Eq -> true
    | Gt -> false

  let (<) a b =
    match X.compare a b with
    | Lt -> true
    | Gt | Eq -> false
end
