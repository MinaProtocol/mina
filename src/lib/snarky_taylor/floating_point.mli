open Snarky_backendless
open Snark
open Snarky_integer

type 'f t

val constant : m:'f m -> value:Bigint.t -> precision:int -> 'f t

val powers : m:'f m -> 'f t -> int -> 'f t array

val mul : m:'f m -> 'f t -> 'f t -> 'f t

val add : m:'f m -> 'f t -> 'f t -> 'f t

val sub : m:'f m -> 'f t -> 'f t -> 'f t

val add_signed : m:'f m -> 'f t -> [`Pos | `Neg] * 'f t -> 'f t

val of_quotient :
     m:'f m
  -> precision:int
  -> top:'f Integer.t
  -> bottom:'f Integer.t
  -> top_is_less_than_bottom:unit
  -> 'f t

val of_bits : m:'f m -> 'f Cvar.t Boolean.t list -> precision:int -> 'f t

val precision : _ t -> int

val to_bignum : m:'f m -> 'f t -> unit -> Bignum.t

val le : m:'f m -> 'f t -> 'f t -> 'f Cvar.t Boolean.t
