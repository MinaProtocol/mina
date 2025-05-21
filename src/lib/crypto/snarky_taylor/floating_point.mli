open Snarky_backendless
open Snark
open Snarky_integer

type 'v t

val constant : m:('f, 'v) m -> value:Bigint.t -> precision:int -> 'v t

val powers : m:('f, 'v) m -> 'v t -> int -> 'v t array

val mul : m:('f, 'v) m -> 'v t -> 'v t -> 'v t

val add : m:('f, 'v) m -> 'v t -> 'v t -> 'v t

val sub : m:('f, 'v) m -> 'v t -> 'v t -> 'v t

val add_signed : m:('f, 'v) m -> 'v t -> [ `Pos | `Neg ] * 'v t -> 'v t

val of_quotient :
     m:('f, 'v) m
  -> precision:int
  -> top:('f, 'v) Integer.t
  -> bottom:('f, 'v) Integer.t
  -> top_is_less_than_bottom:unit
  -> 'v t

val of_bits : m:('f, 'v) m -> 'v Boolean.t list -> precision:int -> 'v t

val precision : _ t -> int

val to_bignum : m:('f, 'v) m -> 'v t -> unit -> Bignum.t

val le : m:('f, 'v) m -> 'v t -> 'v t -> 'v Boolean.t
