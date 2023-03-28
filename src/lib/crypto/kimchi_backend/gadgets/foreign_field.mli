module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

(** Foreign field modulus is abstract on two parameters
 *   - Field type
 *   - Limbs structure
 *
 *   There are 3 specific limb structures required
 *     - Compact mode  : 2 limbs where the lowest is 2L bits and the highest is L bits
 *     - Extended mode : 4 limbs of L-bits each, used by bound addition (i.e. Matthew's trick)
 *     - Normal mode   : 3 limbs of L-bits each
 *)

type 'field compact_limbs = 'field * 'field

type 'field standard_limbs = 'field * 'field * 'field

type 'field extended_limbs = 'field * 'field * 'field * 'field

type 'field limbs =
  | Compact of 'field compact_limbs
  | Standard of 'field standard_limbs
  | Extended of 'field extended_limbs

(** Convert generic limbs into compact limbs *)
val to_compact : 'f limbs -> 'f compact_limbs

(** Convert generic limbs into standard limbs *)
val to_standard : 'f limbs -> 'f standard_limbs

(** Convert generic limbs into extended limbs *)
val to_extended : 'f limbs -> 'f extended_limbs

(** Foreign field element base type - not used directly *)
module type Foreign_field_element_base = sig
  type 'field t

  module Cvar = Snarky_backendless.Cvar

  (** Create foreign field element from Cvar limbs *)
  val of_limbs : 'field Cvar.t limbs -> 'field t

  (** Convert foreign field element into Cvar limbs *)
  val to_limbs : 'field t -> 'field Cvar.t limbs

  (** Map foreign field element's Cvar limbs into some other limbs with the mapping function func *)
  val map : 'field t -> ('field Cvar.t -> 'g) -> 'g limbs

  (** Convert foreign field element into field limbs *)
  val to_field_limbs :
    (module Snark_intf.Run with type field = 'field) -> 'field t -> 'field limbs

  (** Convert foreign field element into Bignum_bigint.t limbs *)
  val to_bignum_bigint_limbs :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t limbs

  (** Convert foreign field element into a Bignum_bigint.t *)
  val to_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t
end

(** Foreign field element type (standard limbs) *)
module Foreign_field_element : sig
  (** Specialization of base type to standard_limbs *)
  include Foreign_field_element_base

  (** Create foreign field element from standard_limbs *)
  val of_limbs : 'field Snarky_backendless.Cvar.t standard_limbs -> 'field t

  (** Create foreign field element from Bignum_bigint.t *)
  val of_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> Bignum_bigint.t
    -> 'field t

  (** Convert a foreign field element into tuple of 3 field standard_limbs *)
  val to_limbs : 'field t -> 'field Snarky_backendless.Cvar.t standard_limbs

  (** Map foreign field element's Cvar limbs into some other standard_limbs with the mapping function func *)
  val map :
    'field t -> ('field Snarky_backendless.Cvar.t -> 'g) -> 'g standard_limbs

  (** Convert foreign field element into field standard_limbs *)
  val to_field_limbs :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field standard_limbs

  (** Convert foreign field element into bignum_bigint standard_limbs *)
  val to_bignum_bigint_limbs :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t standard_limbs

  (* Convert foreign field element into a bignum_bigint *)
  (* to_bignum_bigint included from Foreign_field_element_base *)
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
 *     - left_input and right_input must be in [0, foreign_field_modulus)
 *     - foreign_field_modulus must be less than than max foreign field modulus
 *)
val mul :
     (module Snark_intf.Run with type field = 'f)
  -> 'f Foreign_field_element.t (* left_input *)
  -> 'f Foreign_field_element.t (* right_input *)
  -> 'f standard_limbs (* foreign_field_modulus *)
  -> 'f Foreign_field_element.t * 'f External_checks.t
(* remainder, external_checks *)
