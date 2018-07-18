open Core_kernel

module Interval : sig
  type t = int * int [@@deriving eq, sexp]
end

type t [@@deriving eq, sexp]

val empty : t

val of_interval : Interval.t -> t

val of_intervals_exn : Interval.t list -> t

val disjoint_union_exn : t -> t -> t

val disjoint : t -> t -> bool

val to_interval : t -> Interval.t Or_error.t
