(* open Core_kernel *)

(* open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint *)

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

(* Foreign field element limb size *)
let limb_bits = 88

(* Foreign field element limb size 2^L where L=88 *)
let two_to_limb = Bignum_bigint.(pow (of_int 2) (of_int limb_bits))

(* 2^2L *)
let two_to_2limb = Bignum_bigint.(pow (of_int 2) (of_int Int.(mul 2 limb_bits)))

(* 2^3L *)
let two_to_3limb = Bignum_bigint.(pow (of_int 2) (of_int Int.(mul 3 limb_bits)))

(* Binary modulus *)
let binary_modulus = two_to_3limb

(* Foreign field modulus is abstract on two parameters
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

(* Foreign field element base type - not used directly *)
module type Foreign_field_element_base = sig
  type 'field t

  module Cvar = Snarky_backendless.Cvar

  (* Create foreign field element from Cvar limbs *)
  val of_limbs : 'field Cvar.t limbs -> 'field t

  (* Convert foreign field element into Cvar limbs *)
  val to_limbs : 'field t -> 'field Cvar.t limbs

  (* Map foreign field element's Cvar limbs into some other limbs with the mapping function func *)
  val map : 'field t -> ('field Cvar.t -> 'g) -> 'g limbs

  (* Convert foreign field element into field limbs *)
  val to_field_limbs :
    'field.
    (module Snark_intf.Run with type field = 'field) -> 'field t -> 'field limbs

  (* Convert foreign field element into bignum_bigint limbs *)
  val to_bignum_bigint_limbs :
    'field.
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t limbs

  (* Convert foreign field element into a bignum_bigint *)
  val to_bignum_bigint :
    'field.
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t
end

module Foreign_field_element_base = struct
  module Cvar = Snarky_backendless.Cvar

  type 'field t = 'field Cvar.t limbs

  let of_limbs x = x

  let to_limbs x = x

  let map x func =
    match to_limbs x with
    | Compact (l0, l1) ->
        Compact (func l0, func l1)
    | Standard (l0, l1, l2) ->
        Standard (func l0, func l1, func l2)
    | Extended (l0, l1, l2, l3) ->
        Extended (func l0, func l1, func l2, func l3)

  let to_field_limbs (type field)
      (module Circuit : Snark_intf.Run with type field = field) x =
    let open Circuit in
    map x (fun cvar -> As_prover.read Field.typ cvar)

  let to_bignum_bigint_limbs (type field)
      (module Circuit : Snark_intf.Run with type field = field) x =
    let open Circuit in
    map x (fun cvar ->
        Common.field_to_bignum_bigint (module Circuit)
        @@ As_prover.read Field.typ cvar )

  let to_bignum_bigint (type field)
      (module Circuit : Snark_intf.Run with type field = field) (x : field t) =
    let limbs = to_bignum_bigint_limbs (module Circuit) x in
    match limbs with
    | Compact (l01, l2) ->
        Bignum_bigint.(l01 + (two_to_2limb * l2))
    | Standard (l0, l1, l2) ->
        Bignum_bigint.(l0 + (two_to_limb * l1) + (two_to_2limb * l2))
    | Extended (l0, l1, l2, l3) ->
        Bignum_bigint.(
          l0 + (two_to_limb * l1) + (two_to_2limb * l2) + (two_to_3limb * l3))
end

(* Limbs structure helpers *)
let to_compact x =
  match x with Compact (l0, l1) -> (l0, l1) | _ -> assert false

let to_standard x =
  match x with Standard (l0, l1, l2) -> (l0, l1, l2) | _ -> assert false

let to_extended x =
  match x with
  | Extended (l0, l1, l2, l3) ->
      (l0, l1, l2, l3)
  | _ ->
      assert false

(* Foreign field element type (standard limbs) *)
module Foreign_field_element : sig
  include Foreign_field_element_base
  (* Specialization of base type to standard_limbs *)

  (* Create foreign field element from standard_limbs *)
  val of_limbs : 'field Cvar.t standard_limbs -> 'field t

  (* Convert a foreign field element into tuple of 3 field standard_limbs *)
  val to_limbs : 'field t -> 'field Cvar.t standard_limbs

  (* Map foreign field element's Cvar limbs into some other standard_limbs with the mapping function func *)
  val map : 'field t -> ('field Cvar.t -> 'g) -> 'g standard_limbs

  (* Convert foreign field element into field standard_limbs *)
  val to_field_limbs :
    'field.
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field standard_limbs

  (* Convert foreign field element into bignum_bigint standard_limbs *)
  val to_bignum_bigint_limbs :
    'field.
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t standard_limbs

  (* Convert foreign field element into a bignum_bigint *)
  (* Included from Foreign_field_element_base *)
end = struct
  module Cvar = Snarky_backendless.Cvar

  type 'field t = 'field Cvar.t standard_limbs

  let of_limbs x =
    to_standard @@ Foreign_field_element_base.of_limbs (Standard x)

  let to_limbs x = Foreign_field_element_base.to_limbs x

  let map x func =
    to_standard @@ Foreign_field_element_base.map (Standard x) func

  let to_field_limbs (type field)
      (module Circuit : Snark_intf.Run with type field = field) x =
    to_standard
    @@ Foreign_field_element_base.to_field_limbs (module Circuit) (Standard x)

  let to_bignum_bigint_limbs (type field)
      (module Circuit : Snark_intf.Run with type field = field) x =
    to_standard
    @@ Foreign_field_element_base.to_bignum_bigint_limbs
         (module Circuit)
         (Standard x)

  let to_bignum_bigint (type field)
      (module Circuit : Snark_intf.Run with type field = field) (x : field t) =
    let l0, l1, l2 = to_bignum_bigint_limbs (module Circuit) x in
    Bignum_bigint.(l0 + (two_to_limb * l1) + (two_to_2limb * l2))
end

let foreign_field_mul (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (left_input : f Foreign_field_element.t)
    (_right_input : f Foreign_field_element.t)
    (_foreign_modulus : f Foreign_field_element.t) =
  let open Circuit in
  let _left_input0, _left_input1, _left_input2 =
    Foreign_field_element.to_limbs left_input
  in
  let _unused =
    exists Field.typ ~compute:(fun () ->
        let _left_input0, _left_input1, _left_input2 =
          Foreign_field_element.to_field_limbs (module Circuit) left_input
        in
        let _bi =
          Foreign_field_element.to_bignum_bigint (module Circuit) left_input
        in
        let _limbs =
          Foreign_field_element.map left_input (fun x ->
              As_prover.read Field.typ x )
        in
        Field.Constant.zero )
  in
  ()
