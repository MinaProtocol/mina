open Snarky
open Snark

type 'f t

val constant : m:('s, 'f) m -> Bigint.t -> 'f t

val shift_left : m:('s, 'f) m -> 'f t -> int -> 'f t

val of_bits : m:('s, 'f) m -> 'f Cvar.t Boolean.t list -> 'f t

val div_mod : m:('s, 'f) m -> 'f t -> 'f t -> 'f t * 'f t

val to_field : 'f t -> 'f Cvar.t

val create : value:'f Cvar.t -> upper_bound:Bigint.t -> 'f t
