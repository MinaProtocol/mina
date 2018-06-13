module Interval : sig
  type t = int * int
end

type t [@@deriving eq]

val empty : t

val of_interval : Interval.t -> t

val of_intervals_exn : Interval.t list -> t

val disjoint_union_exn : t -> t -> t

val disjoint : t -> t -> bool
