module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

(** Foreign field modulus is abstract on two parameters
 *    Field type
 *    Limbs structure
 *
 *   There are 3 specific limb structures required
 *     Standard mode := 3 limbs of L-bits each
 *     Extended mode := 4 limbs of L-bits each, used by bound addition (i.e. Matthew's trick)
 *     Compact mode  := 2 limbs where the lowest is 2L bits and the highest is L bits
 *)

type 'field standard_limbs = 'field * 'field * 'field

type 'field extended_limbs = 'field * 'field * 'field * 'field

type 'field compact_limbs = 'field * 'field

type 'field limbs =
  | Standard of 'field standard_limbs
  | Extended of 'field extended_limbs
  | Compact of 'field compact_limbs

(** Foreign field element base type - not used directly *)
module type Element_intf = sig
  type 'field t

  type 'a limbs_type

  module Cvar = Snarky_backendless.Cvar

  (** Create foreign field element from Cvar limbs *)
  val of_limbs : 'field Cvar.t limbs_type -> 'field t

  (** Create foreign field element from Bignum_bigint.t *)
  val of_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> Bignum_bigint.t
    -> 'field t

  (** Convert foreign field element into Cvar limbs *)
  val to_limbs : 'field t -> 'field Cvar.t limbs_type

  (** Map foreign field element's Cvar limbs into some other limbs with the mapping function func *)
  val map : 'field t -> ('field Cvar.t -> 'g) -> 'g limbs_type

  (** Convert foreign field element into field limbs *)
  val to_field_limbs :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field limbs_type

  (** Convert foreign field element into Bignum_bigint.t limbs *)
  val to_bignum_bigint_limbs :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t limbs_type

  (** Convert foreign field element into a Bignum_bigint.t *)
  val to_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t
end

module Element : sig
  (* Foreign field element type (standard limbs) *)
  module Standard : Element_intf with type 'a limbs_type = 'a standard_limbs

  (* Foreign field element type (extended limbs) *)
  module Extended : Element_intf with type 'a limbs_type = 'a extended_limbs

  (* Foreign field element type (compact limbs) *)
  module Compact : Element_intf with type 'a limbs_type = 'a compact_limbs
end

(** Structure for tracking external checks that must be made
 *  (using other gadgets) in order to acheive soundess for a
 *  given multiplication
 *)
module External_checks : sig
  type 'field t

  val create : (module Snark_intf.Run with type field = 'field) -> 'field t
end

(** Foreign field multiplication gadget
 *   Constrains that
 *
 *     left_input * right_input = quotient * foreign_field_modulus + remainder
 *
 *   where remainder is the product.
 *
 *   Inputs:
 *     left_input            := multiplicand in [0, foreign_field_modulus)
 *     right_input           := multiplicand in [0, foreign_field_modulus)
 *     foreign_field_modulus := must be less than than max foreign field modulus
 *   Outputs: tuple of product and required external checks
 *)
val mul :
     (module Snark_intf.Run with type field = 'f)
  -> 'f Element.Standard.t (* left_input *)
  -> 'f Element.Standard.t (* right_input *)
  -> 'f standard_limbs (* foreign_field_modulus *)
  -> 'f Element.Standard.t * 'f External_checks.t
(* remainder, external_checks *)
