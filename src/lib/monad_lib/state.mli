open Base

include Monad.S2

val run_state : ('a, 's) t -> 's -> 'a * 's

val eval_state : ('a, 's) t -> 's -> 'a

val exec_state : ('a, 's) t -> 's -> 's

val get : ('s, 's) t

val getf : ('s -> 'a) -> ('a, 's) t

val put : 's -> (unit, 's) t

val modify : f:('s -> 's) -> (unit, 's) t

val with_state : ('s -> 'a * 's) -> ('a, 's) t

val fold_m : f:('b -> 'a -> ('b, 's) t) -> init:'b -> 'a list -> ('b, 's) t

val map_m : f:('a -> ('b, 's) t) -> 'a list -> ('b list, 's) t

val filter_map_m : f:('a -> ('b option, 's) t) -> 'a list -> ('b list, 's) t

val concat_map_m : f:('a -> ('b list, 's) t) -> 'a list -> ('b list, 's) t
