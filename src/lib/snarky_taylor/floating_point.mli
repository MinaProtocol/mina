open Snarky
open Snark

type 'f t

val constant : m:('s, 'f) m -> value:Bigint.t -> precision:int -> 'f t

val powers : m:('s, 'f) m -> 'f t -> int -> 'f t array

val mul : m:('s, 'f) m -> 'f t -> 'f t -> 'f t

val add : m:('s, 'f) m -> 'f t -> 'f t -> 'f t

val sub : m:('s, 'f) m -> 'f t -> 'f t -> 'f t

val add_signed : m:('s, 'f) m -> 'f t -> [`Pos | `Neg] * 'f t -> 'f t

val of_quotient :
     m:('s, 'f) m
  -> precision:int
  -> top:'f Integer.t
  -> bottom:'f Integer.t
  -> top_is_less_than_bottom:unit
  -> 'f t

val of_bits : m:('s, 'f) m -> 'f Cvar.t Boolean.t list -> precision:int -> 'f t

val precision : _ t -> int

val to_bignum : m:('s, 'f) m -> 'f t -> unit -> Bignum.t

val le : m:('s, 'f) m -> 'f t -> 'f t -> 'f Cvar.t Boolean.t
