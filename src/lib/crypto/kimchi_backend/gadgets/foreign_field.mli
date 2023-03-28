module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

type 'a circuit_variable = 'a Snarky_backendless.Cvar.t

type 'field compact_limbs = 'field * 'field

type 'field standard_limbs = 'field * 'field * 'field

type 'field extended_limbs = 'field * 'field * 'field * 'field

type 'field limbs =
  | Compact of 'field compact_limbs
  | Standard of 'field standard_limbs
  | Extended of 'field extended_limbs

(* Foreign field element base type - not used directly *)
module type Foreign_field_element_base = sig
  type 'field t

  type 'a lbs

  (* Create foreign field element from Cvar limbs *)
  val of_limbs : 'field circuit_variable lbs -> 'field t

  (* Create foreign field element from Bignum_bigint.t *)
  val of_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> Bignum_bigint.t
    -> 'field t

  (* Convert foreign field element into Cvar limbs *)
  val to_limbs : 'field t -> 'field circuit_variable lbs

  (* Map foreign field element's Cvar limbs into some other limbs with the mapping function func *)
  val map : 'field t -> ('field circuit_variable -> 'g) -> 'g lbs

  (* Convert foreign field element into field limbs *)
  val to_field_limbs :
    (module Snark_intf.Run with type field = 'field) -> 'field t -> 'field lbs

  (* Convert foreign field element into Bignum_bigint.t limbs *)
  val to_bignum_bigint_limbs :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t lbs

  (* Convert foreign field element into a Bignum_bigint.t *)
  val to_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t
end

module Foreign_field_element :
  Foreign_field_element_base with type 'a lbs := 'a standard_limbs

module External_checks : sig
  type 'field t

  val create :
       (module Snarky_backendless.Snark_intf.Run with type field = 'field)
    -> 'field t
end
