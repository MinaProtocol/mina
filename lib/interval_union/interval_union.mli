module Interval : sig
  type t = int * int
end

type t
[@@deriving eq]

val of_interval : Interval.t -> t

val disjoint_union_exn : t -> t -> t

val disjoint : t -> t -> bool
