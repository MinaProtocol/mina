type 'a t = 'a list

include module type of struct include ListLabels end

val is_empty : _ t -> bool

val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

val filter_opt : 'a option t -> 'a t

val filteri : 'a t -> f:(int -> 'a -> bool) -> 'a t

val concat_map : 'a t -> f:('a -> 'b t) -> 'b t

val     partition_map : 'a t -> f:('a -> ('b, 'c) Either.t) -> 'b t * 'c t
val rev_partition_map : 'a t -> f:('a -> ('b, 'c) Either.t) -> 'b t * 'c t

type ('a, 'b) skip_or_either =
  | Skip
  | Left  of 'a
  | Right of 'b

val filter_partition_map
  :  'a t
  -> f:('a -> ('b, 'c) skip_or_either)
  -> 'b t * 'c t
val rev_filter_partition_map
  :  'a t
  -> f:('a -> ('b, 'c) skip_or_either)
  -> 'b t * 'c t

val find     : 'a t -> f:('a -> bool     ) -> 'a option
val find_exn : 'a t -> f:('a -> bool     ) -> 'a
val find_map : 'a t -> f:('a -> 'b option) -> 'b option

val last : 'a t -> 'a option

val        sort : 'a t -> compare:('a -> 'a -> Ordering.t) -> 'a t
val stable_sort : 'a t -> compare:('a -> 'a -> Ordering.t) -> 'a t

val compare : 'a t -> 'a t -> compare:('a -> 'a -> Ordering.t) -> Ordering.t

val assoc : ('a * 'b) t -> 'a -> 'b option

val singleton : 'a -> 'a t

val nth : 'a t -> int -> 'a option

val physically_equal : 'a t -> 'a t -> bool
