open Snarky_backendless
open Snark
open Snarky_integer

type 'field_var t

val constant :
  m:('f, 'field_var) m -> value:Bigint.t -> precision:int -> 'field_var t

val powers : m:('f, 'field_var) m -> 'field_var t -> int -> 'field_var t array

val mul : m:('f, 'field_var) m -> 'field_var t -> 'field_var t -> 'field_var t

val add : m:('f, 'field_var) m -> 'field_var t -> 'field_var t -> 'field_var t

val sub : m:('f, 'field_var) m -> 'field_var t -> 'field_var t -> 'field_var t

val add_signed :
     m:('f, 'field_var) m
  -> 'field_var t
  -> [ `Pos | `Neg ] * 'field_var t
  -> 'field_var t

val of_quotient :
     m:('f, 'field_var) m
  -> precision:int
  -> top:('f, 'field_var) Integer.t
  -> bottom:('f, 'field_var) Integer.t
  -> top_is_less_than_bottom:unit
  -> 'field_var t

val of_bits :
     m:('f, 'field_var) m
  -> 'field_var Boolean.t list
  -> precision:int
  -> 'field_var t

val precision : _ t -> int

val to_bignum : m:('f, 'field_var) m -> 'field_var t -> unit -> Bignum.t

val le :
  m:('f, 'field_var) m -> 'field_var t -> 'field_var t -> 'field_var Boolean.t
