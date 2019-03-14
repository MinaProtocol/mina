open Snarky
open Snark

type 'f t

val constant : m:'f m -> Bigint.t -> 'f t

val shift_left : m:'f m -> 'f t -> int -> 'f t

val of_bits : m:'f m -> 'f Cvar.t Boolean.t list -> 'f t

val div_mod : m:'f m -> 'f t -> 'f t -> 'f t * 'f t

val to_field : 'f t -> 'f Cvar.t
