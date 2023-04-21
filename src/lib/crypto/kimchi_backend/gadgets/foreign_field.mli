module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

(** Conventions used
 *     1. Functions prefixed with "as_prover_" only happen during proving
 *        and not during circuit creation
 *     2. Functions suffixed with "_as_prover" can only be called outside
 *        the circuit.  Specifically, this means within an exists, within
 *        an as_prover or in an "as_prover_" prefixed function)
 *)

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
  val to_field_limbs_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field limbs_type

  (** Convert foreign field element into Bignum_bigint.t limbs *)
  val to_bignum_bigint_limbs_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t limbs_type

  (** Convert foreign field element into a Bignum_bigint.t *)
  val to_bignum_bigint_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t

  (* Check that the foreign element is smaller than a given field modulus *)
  val fits_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field standard_limbs
    -> bool
end

module Element : sig
  (** Foreign field element type (standard limbs) *)
  module Standard : sig
    include Element_intf with type 'a limbs_type = 'a standard_limbs

    (** Convert a standard foreign element into extended limbs *)
    val as_prover_extend :
         (module Snark_intf.Run with type field = 'field)
      -> 'field t
      -> 'field Cvar.t extended_limbs
  end

  (** Foreign field element type (extended limbs) *)
  module Extended : Element_intf with type 'a limbs_type = 'a extended_limbs

  (** Foreign field element type (compact limbs) *)
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

(* Type of operation *)
type op_mode = Add | Sub

(** This function adds a FFAdd gate to perform bound addition  (part of the check that the
 *  value is less than the foreign modulus)
 *
 *    Inputs:
 *      value                 := the value to check
 *      external_checks       := Optional context to track required external checks.
 *                               When omitted, creates and returns new external_checks structure.
 *                               Otherwise, appends new required external checks to supplied structure.
 *      foreign_field_modulus := the modulus of the foreign field
 *
 *    Outputs:
 *      Bound addition gate (an ForeignFieldAdd gate) is added
 *      Returns bound value and External_checks containing multi-range-check for bound
 *)
val bound_addition :
     (module Snark_intf.Run with type field = 'f)
  -> ?external_checks:'f External_checks.t (* external_checks *)
  -> 'f Element.Standard.t (* value *)
  -> 'f standard_limbs (* foreign_field_modulus *)
  -> 'f Element.Standard.t * 'f External_checks.t
(* result, external_checks *)

(** Definition of a gadget for a chain of foreign field sums (additions or subtractions)
 *
 *    Inputs:
 *      inputs                := All the inputs to the chain of sums
 *      operations            := List of operation modes Add or Sub indicating whether th
 *                               corresponding addition is a subtraction
 *      foreign_field_modulus := The modulus of the foreign field (all the same)
 *
 *    Outputs:
 *      Inserts the gates (described below) into the circuit
 *      Returns the final result of the chain of sums
 *
 *    For n+1 inputs, the gadget creates n foreign field addition gates, followed by a final
 *    foreign field addition gate for the bound check. An additional multi range check must be performed.
 *    By default, the range check takes place right after the final Raw row.
 *)
val sum_chain :
     (module Snark_intf.Run with type field = 'f)
  -> 'f Element.Standard.t list (* inputs *)
  -> op_mode list (* operations *)
  -> 'f standard_limbs (* foreign_field_modulus *)
  -> 'f Element.Standard.t
(* result *)

(** Definition of a gadget for a single foreign field addition
 *
 *    Inputs:
 *      operation             := operation mode Add or Sub indicating whether the corresponding addition is a subtraction (default: Add)
 *      left_input            := 3 limbs foreign field element
 *      right_input           := 4 limbs foreign field element
 *      foreign_field_modulus := The modulus of the foreign field
 *
 *    Outputs:
 *      Inserts the gates (described below) into the circuit
 *      Returns the result of the addition as a 3 limbs element
 *
 *  It adds a FFAdd gate,
 *  followed by a Zero gate,
 *  a FFAdd gate for the bound check,
 *  a Zero gate after this bound check,
 *  and a Multi Range Check gadget.
 *)
val add :
     (module Snark_intf.Run with type field = 'f)
  -> 'f Element.Standard.t (* left_input *)
  -> 'f Element.Standard.t (* right_input *)
  -> 'f standard_limbs (* foreign_field_modulus *)
  -> 'f Element.Standard.t
(* result *)

(** Definition of a gadget for a single foreign field subtraction
 *
 *    Inputs:
 *      left_input            := 3 limb foreign field element
 *      right_input           := 4 limb foreign field element
 *      foreign_field_modulus := the modulus of the foreign field
 *
 *    Outputs:
 *      Inserts the gates (described below) into the circuit
 *      Returns the result of the subtraction as a 3 limbs element
 *
 *   It adds a FFAdd gate,
 *   followed by a Zero gate,
 *   a FFAdd gate for the bound check,
 *   a Zero gate after this bound check,
 *   and a Multi Range Check gadget.
 *)
val sub :
     (module Snark_intf.Run with type field = 'f)
  -> 'f Element.Standard.t (* left_input *)
  -> 'f Element.Standard.t (* right_input *)
  -> 'f standard_limbs (* foreign_field_modulus *)
  -> 'f Element.Standard.t
(* result *)

(** Foreign field multiplication gadget
 *   Constrains that
 *
 *     left_input * right_input = quotient * foreign_field_modulus + remainder
 *
 *   where remainder is the product.
 *
 *   Inputs:
 *     external_checks       := Optional context to track required external checks.
 *                              When omitted, creates and returns new external_checks structure.
 *                              Otherwise, appends new required external checks to supplied structure.
 *     left_input            := Multiplicand foreign field element
 *     right_input           := Multiplicand foreign field element
 *     foreign_field_modulus := Must be less than than max foreign field modulus
 *
 *   Outputs:
 *     Inserts the ForeignFieldMul gate, followed by Zero gate into the circuit
 *     Tuple of product and External_checks necessary to make multiplication sound
 *)
val mul :
     (module Snark_intf.Run with type field = 'f)
  -> ?external_checks:'f External_checks.t (* external_checks *)
  -> 'f Element.Standard.t (* left_input *)
  -> 'f Element.Standard.t (* right_input *)
  -> 'f standard_limbs (* foreign_field_modulus *)
  -> 'f Element.Standard.t * 'f External_checks.t
(* remainder, external_checks *)
