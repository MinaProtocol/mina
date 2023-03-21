(* open Core_kernel *)

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

(* Foreign field element limb size *)
let limb_bits = 88

(* Foreign field element limb size 2^L where L=88 *)
let two_to_limb = Bignum_bigint.(pow (of_int 2) (of_int limb_bits))

let two_to_limb_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) =
  Common.bignum_bigint_to_field (module Circuit) two_to_limb

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

(* Convert Bignum_bigint.t to Bignum_bigint standard_limbs *)
let bignum_bigint_to_standard_limbs (bigint : Bignum_bigint.t) :
    Bignum_bigint.t standard_limbs =
  let l12, l0 = Common.bignum_bigint_div_rem bigint two_to_limb in
  let l2, l1 = Common.bignum_bigint_div_rem l12 two_to_limb in
  (l0, l1, l2)

(* Convert Bignum_bigint.t to field standard_limbs *)
let bignum_bigint_to_field_standard_limbs (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (bigint : Bignum_bigint.t) : f standard_limbs =
  let l0, l1, l2 = bignum_bigint_to_standard_limbs bigint in
  ( Common.bignum_bigint_to_field (module Circuit) l0
  , Common.bignum_bigint_to_field (module Circuit) l1
  , Common.bignum_bigint_to_field (module Circuit) l2 )

(* Convert Bignum_bigint.t to Bignum_bigint compact_limbs *)
let bignum_bigint_to_compact_limbs (bigint : Bignum_bigint.t) :
    Bignum_bigint.t compact_limbs =
  let l2, l01 = Common.bignum_bigint_div_rem bigint two_to_2limb in
  (l01, l2)

(* Convert Bignum_bigint.t to field compact_limbs *)
let bignum_bigint_to_field_compact_limbs (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (bigint : Bignum_bigint.t) : f compact_limbs =
  let l01, l2 = bignum_bigint_to_compact_limbs bigint in
  ( Common.bignum_bigint_to_field (module Circuit) l01
  , Common.bignum_bigint_to_field (module Circuit) l2 )

(* Convert field standard_limbs to Bignum_bigint.t standard_limbs *)
let field_standard_limbs_to_bignum_bigint_standard_limbs (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_limbs : f standard_limbs) : Bignum_bigint.t standard_limbs =
  let l0, l1, l2 = field_limbs in
  ( Common.field_to_bignum_bigint (module Circuit) l0
  , Common.field_to_bignum_bigint (module Circuit) l1
  , Common.field_to_bignum_bigint (module Circuit) l2 )

(* Convert field standard_limbs to Bignum_bigint.t *)
let field_standard_limbs_to_bignum_bigint (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_limbs : f standard_limbs) : Bignum_bigint.t =
  let l0, l1, l2 =
    field_standard_limbs_to_bignum_bigint_standard_limbs
      (module Circuit)
      field_limbs
  in
  Bignum_bigint.(l0 + (two_to_limb * l1) + (two_to_2limb * l2))

(* Convert string standard_limbs to field standard_limbs *)
let string_to_field_standard_limbs (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (value : string) : f standard_limbs =
  let bigint = Bignum_bigint.of_string value in
  bignum_bigint_to_field_standard_limbs (module Circuit) bigint

(* Foreign field element base type - not used directly *)
module type Foreign_field_element_base = sig
  type 'field t

  module Cvar = Snarky_backendless.Cvar

  (* Create foreign field element from Cvar limbs *)
  val of_limbs : 'field Cvar.t limbs -> 'field t

  (* Create foreign field element from Bignum_bigint.t *)
  val of_bignum_bigint :
    'field.
       (module Snark_intf.Run with type field = 'field)
    -> Bignum_bigint.t
    -> 'field t

  (* Create foreign field element from string *)
  val of_string :
    'field.
    (module Snark_intf.Run with type field = 'field) -> string -> 'field t

  (* Convert foreign field element into Cvar limbs *)
  val to_limbs : 'field t -> 'field Cvar.t limbs

  (* Map foreign field element's Cvar limbs into some other limbs with the mapping function func *)
  val map : 'field t -> ('field Cvar.t -> 'g) -> 'g limbs

  (* Convert foreign field element into field limbs *)
  val to_field_limbs :
    'field.
    (module Snark_intf.Run with type field = 'field) -> 'field t -> 'field limbs

  (* Convert foreign field element into Bignum_bigint.t limbs *)
  val to_bignum_bigint_limbs :
    'field.
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t limbs

  (* Convert foreign field element into a Bignum_bigint.t *)
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

  let of_bignum_bigint (type field)
      (module Circuit : Snark_intf.Run with type field = field) _x : field t =
    failwith "not implemented"

  let of_string (type field)
      (module Circuit : Snark_intf.Run with type field = field) _x : field t =
    failwith "not implemented"

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
  (* Specialization of base type to standard_limbs *)
  include Foreign_field_element_base

  (* Create foreign field element from standard_limbs *)
  val of_limbs : 'field Cvar.t standard_limbs -> 'field t

  (* Create foreign field element from Bignum_bigint.t *)
  (* of_bignum_bigint included from Foreign_field_element_base *)

  (* Create foreign field element from string *)
  (* of_string included from Foreign_field_element_base *)

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
  (* to_bignum_bigint included from Foreign_field_element_base *)
end = struct
  module Cvar = Snarky_backendless.Cvar

  type 'field t = 'field Cvar.t standard_limbs

  let of_limbs x = x

  let of_bignum_bigint (type field)
      (module Circuit : Snark_intf.Run with type field = field) x : field t =
    let open Circuit in
    let l12, l0 = Common.bignum_bigint_div_rem x two_to_limb in
    let l2, l1 = Common.bignum_bigint_div_rem l12 two_to_limb in
    let l0 =
      Field.constant @@ Common.bignum_bigint_to_field (module Circuit) l0
    in
    let l1 =
      Field.constant @@ Common.bignum_bigint_to_field (module Circuit) l1
    in
    let l2 =
      Field.constant @@ Common.bignum_bigint_to_field (module Circuit) l2
    in
    of_limbs (l0, l1, l2)

  let of_string (type field)
      (module Circuit : Snark_intf.Run with type field = field) x : field t =
    of_bignum_bigint (module Circuit) @@ Bignum_bigint.of_string x

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

(* Compute non-zero intermediate products
 *
 * For more details see the "Intermediate products" Section of
 * the [Foreign Field Multiplication RFC](../rfcs/foreign_field_mul.md) *)
let compute_intermediate_products (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (left_input : f Foreign_field_element.t)
    (right_input : f Foreign_field_element.t) (quotient : f standard_limbs)
    (neg_foreign_field_modulus : f standard_limbs) : f * f * f =
  let open Circuit in
  let left_input0, left_input1, left_input2 =
    Foreign_field_element.to_field_limbs (module Circuit) left_input
  in
  let right_input0, right_input1, right_input2 =
    Foreign_field_element.to_field_limbs (module Circuit) right_input
  in
  let quotient0, quotient1, quotient2 = quotient in
  let ( neg_foreign_field_modulus0
      , neg_foreign_field_modulus1
      , neg_foreign_field_modulus2 ) =
    neg_foreign_field_modulus
  in
  ( (* p0 = a0 * b0 + q0 + f'0 *)
    Field.Constant.(
      (left_input0 * right_input0) + (quotient0 * neg_foreign_field_modulus0))
  , (* p1 = a0 * b1 + a1 * b0 + q0 * f'1 + q1 * f'0 *)
    Field.Constant.(
      (left_input0 * right_input1)
      + (left_input1 * right_input0)
      + (quotient0 * neg_foreign_field_modulus1)
      + (quotient1 * neg_foreign_field_modulus0))
  , (* p2 = a0 * b2 + a2 * b0 + a1 * b1 - q0 * f'2 + q2 * f'0 + q1 * f'1 *)
    Field.Constant.(
      (left_input0 * right_input2)
      + (left_input2 * right_input0)
      + (left_input1 * right_input1)
      + (quotient0 * neg_foreign_field_modulus2)
      + (quotient2 * neg_foreign_field_modulus0)
      + (quotient1 * neg_foreign_field_modulus1)) )

(* Compute intermediate sums
 *   For more details see the "Optimizations" Section of
 *   the [Foreign Field Multiplication RFC](../rfcs/foreign_field_mul.md) *)
let compute_intermediate_sums (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (quotient : f standard_limbs) (neg_foreign_field_modulus : f standard_limbs)
    : f * f =
  let open Circuit in
  let quotient0, quotient1, quotient2 = quotient in
  let ( neg_foreign_field_modulus0
      , neg_foreign_field_modulus1
      , neg_foreign_field_modulus2 ) =
    neg_foreign_field_modulus
  in
  (* let q01 = q0 + 2^L * q1 *)
  let quotient01 =
    Field.Constant.(
      quotient0 + (two_to_limb_field (module Circuit) * quotient1))
  in

  (* f'01 = f'0 + 2^L * f'1 *)
  let neg_foreign_field_modulus01 =
    Field.Constant.(
      neg_foreign_field_modulus0
      + (two_to_limb_field (module Circuit) * neg_foreign_field_modulus1))
  in
  ( (* q'01 = q01 + f'01 *)
    Field.Constant.(quotient01 + neg_foreign_field_modulus01)
  , (* q'2 = q2 + f'2 *)
    Field.Constant.(quotient2 + neg_foreign_field_modulus2) )

(* Compute witness variables related for foreign field multplication *)
let compute_witness_variables (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (products : Bignum_bigint.t standard_limbs)
    (remainder : Bignum_bigint.t standard_limbs) : f * f * f * f * f * f =
  let products0, products1, products2 = products in
  let remainder0, remainder1, remainder2 = remainder in

  (* C1-C2: Compute components of product1 *)
  let product1_hi, product1_lo =
    Common.bignum_bigint_div_rem products1 two_to_limb
  in
  let product1_hi_1, product1_hi_0 =
    Common.bignum_bigint_div_rem product1_hi two_to_limb
  in

  (* C3-C5: Compute v0 = the top 2 bits of (p0 + 2^L * p10 - r0 - 2^L * r1) / 2^2L
   *   N.b. To avoid an underflow error, the equation must sum the intermediate
   *        product terms before subtracting limbs of the remainder. *)
  let carry0 =
    Bignum_bigint.(
      ( products0
      + (two_to_limb * product1_lo)
      - remainder0 - (two_to_limb * remainder1) )
      / two_to_2limb)
  in

  (* C6-C7: Compute v1 = the top L + 3 bits (p2 + p11 + v0 - r2) / 2^L
   *   N.b. Same as above, to avoid an underflow error, the equation must
   *        sum the intermediate product terms before subtracting the remainder. *)
  let carry1 =
    Bignum_bigint.(
      (products2 + product1_hi + carry0 - remainder2) / two_to_limb)
  in
  (* Compute v10 and v11 *)
  let carry1_hi, carry1_lo = Common.bignum_bigint_div_rem carry1 two_to_limb in

  ( Common.bignum_bigint_to_field (module Circuit) product1_lo
  , Common.bignum_bigint_to_field (module Circuit) product1_hi_0
  , Common.bignum_bigint_to_field (module Circuit) product1_hi_1
  , Common.bignum_bigint_to_field (module Circuit) carry0
  , Common.bignum_bigint_to_field (module Circuit) carry1_lo
  , Common.bignum_bigint_to_field (module Circuit) carry1_hi )

(* Perform integer bound addition computation x' = x + f' *)
let compute_bound (x : Bignum_bigint.t)
    (neg_foreign_field_modulus : Bignum_bigint.t) : Bignum_bigint.t =
  let x_bound = Bignum_bigint.(x + neg_foreign_field_modulus) in
  assert (Bignum_bigint.(x_bound < binary_modulus)) ;
  x_bound

(* Compute bound witness carry bit *)
let compute_bound_witness_carry (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (sums : Bignum_bigint.t compact_limbs)
    (bound : Bignum_bigint.t compact_limbs) : f =
  let sums01, _sums2 = sums in
  let bound01, _bound2 = bound in

  (* C9: witness data is created by externally by called and multi-range-check gate *)

  (* C10-C11: Compute q'_carry01 = (s01 - q'01)/2^2L *)
  let quotient_bound_carry, _ =
    Common.bignum_bigint_div_rem Bignum_bigint.(sums01 - bound01) two_to_2limb
  in
  Common.bignum_bigint_to_field (module Circuit) quotient_bound_carry

let array24_to_tuple24 array =
  match array with
  | [| a1
     ; a2
     ; a3
     ; a4
     ; a5
     ; a6
     ; a7
     ; a8
     ; a9
     ; a10
     ; a11
     ; a12
     ; a13
     ; a14
     ; a15
     ; a16
     ; a17
     ; a18
     ; a19
     ; a20
     ; a21
     ; a22
     ; a23
     ; a24
    |] ->
      ( a1
      , a2
      , a3
      , a4
      , a5
      , a6
      , a7
      , a8
      , a9
      , a10
      , a11
      , a12
      , a13
      , a14
      , a15
      , a16
      , a17
      , a18
      , a19
      , a20
      , a21
      , a22
      , a23
      , a24 )
  | _ ->
      assert false

let mul (type f) (module Circuit : Snark_intf.Run with type field = f)
    (left_input : f Foreign_field_element.t)
    (right_input : f Foreign_field_element.t)
    (foreign_field_modulus : f standard_limbs) : f Foreign_field_element.t =
  (* * (f External_checks.t) *)
  let open Circuit in
  (* Compute gate coefficients
   *   This happen when circuit is created / not part of witness (e.g. exists, As_prover code)
   *)
  let foreign_field_modulus0, foreign_field_modulus1, foreign_field_modulus2 =
    foreign_field_modulus
  in
  let ( neg_foreign_field_modulus
      , ( neg_foreign_field_modulus0
        , neg_foreign_field_modulus1
        , neg_foreign_field_modulus2 ) ) =
    let foreign_field_modulus =
      field_standard_limbs_to_bignum_bigint
        (module Circuit)
        foreign_field_modulus
    in
    (* Compute negated foreign field modulus f' = 2^t - f public parameter *)
    let neg_foreign_field_modulus =
      Bignum_bigint.(binary_modulus - foreign_field_modulus)
    in
    ( neg_foreign_field_modulus
    , bignum_bigint_to_field_standard_limbs
        (module Circuit)
        neg_foreign_field_modulus )
  in

  (* Compute witness values *)
  let ( left_input0
      , left_input1
      , left_input2
      , right_input0
      , right_input1
      , right_input2
      , carry1_lo
      , carry1_hi
      , product1_hi_1
      , carry0
      , quotient0
      , quotient1
      , quotient2
      , quotient_bound_carry
      , remainder0
      , remainder1
      , remainder2
      , quotient_bound01
      , quotient_bound2
      , _remainder_bound0
      , _remainder_bound1
      , _remainder_bound2
      , product1_lo
      , product1_hi_0 ) =
    exists (Typ.array ~length:24 Field.typ) ~compute:(fun () ->
        (* Compute quotient remainder and negative foreign field modulus *)
        let quotient, remainder =
          (* Bignum_bigint computations *)
          let left_input =
            Foreign_field_element.to_bignum_bigint (module Circuit) left_input
          in
          let right_input =
            Foreign_field_element.to_bignum_bigint (module Circuit) right_input
          in
          let foreign_field_modulus =
            field_standard_limbs_to_bignum_bigint
              (module Circuit)
              foreign_field_modulus
          in
          (* Compute quotient and remainder using foreign field modulus *)
          let quotient, remainder =
            Common.bignum_bigint_div_rem
              Bignum_bigint.(left_input * right_input)
              foreign_field_modulus
          in
          (quotient, remainder)
        in

        (* Compute the intermediate products *)
        let products =
          let quotient =
            bignum_bigint_to_field_standard_limbs (module Circuit) quotient
          in
          let neg_foreign_field_modulus =
            bignum_bigint_to_field_standard_limbs
              (module Circuit)
              neg_foreign_field_modulus
          in
          let product0, product1, product2 =
            compute_intermediate_products
              (module Circuit)
              left_input right_input quotient neg_foreign_field_modulus
          in

          ( Common.field_to_bignum_bigint (module Circuit) product0
          , Common.field_to_bignum_bigint (module Circuit) product1
          , Common.field_to_bignum_bigint (module Circuit) product2 )
        in

        (* Compute the intermediate sums *)
        let sums =
          let quotient =
            bignum_bigint_to_field_standard_limbs (module Circuit) quotient
          in
          let neg_foreign_field_modulus =
            bignum_bigint_to_field_standard_limbs
              (module Circuit)
              neg_foreign_field_modulus
          in
          let sum01, sum2 =
            compute_intermediate_sums
              (module Circuit)
              quotient neg_foreign_field_modulus
          in
          ( Common.field_to_bignum_bigint (module Circuit) sum01
          , Common.field_to_bignum_bigint (module Circuit) sum2 )
        in

        (* Compute witness variables *)
        let ( product1_lo
            , product1_hi_0
            , product1_hi_1
            , carry0
            , carry1_lo
            , carry1_hi ) =
          compute_witness_variables
            (module Circuit)
            products
            (bignum_bigint_to_standard_limbs remainder)
        in

        (* Compute bounds for multi-range-checks on quotient and remainder *)
        let quotient_bound = compute_bound quotient neg_foreign_field_modulus in
        let remainder_bound =
          compute_bound remainder neg_foreign_field_modulus
        in

        (* Compute quotient bound addition witness variables *)
        let quotient_bound_carry =
          compute_bound_witness_carry
            (module Circuit)
            sums
            (bignum_bigint_to_compact_limbs quotient_bound)
        in

        (* Compute the rest of the witness data *)
        let left_input0, left_input1, left_input2 =
          Foreign_field_element.to_field_limbs (module Circuit) left_input
        in
        let right_input0, right_input1, right_input2 =
          Foreign_field_element.to_field_limbs (module Circuit) right_input
        in
        let quotient0, quotient1, quotient2 =
          bignum_bigint_to_field_standard_limbs (module Circuit) quotient
        in
        let remainder0, remainder1, remainder2 =
          bignum_bigint_to_field_standard_limbs (module Circuit) remainder
        in
        let quotient_bound01, quotient_bound2 =
          bignum_bigint_to_field_compact_limbs (module Circuit) quotient_bound
        in
        let remainder_bound0, remainder_bound1, remainder_bound2 =
          bignum_bigint_to_field_standard_limbs (module Circuit) remainder_bound
        in

        [| left_input0
         ; left_input1
         ; left_input2
         ; right_input0
         ; right_input1
         ; right_input2
         ; carry1_lo
         ; carry1_hi
         ; product1_hi_1
         ; carry0
         ; quotient0
         ; quotient1
         ; quotient2
         ; quotient_bound_carry
         ; remainder0
         ; remainder1
         ; remainder2
         ; quotient_bound01
         ; quotient_bound2
         ; remainder_bound0
         ; remainder_bound1
         ; remainder_bound2
         ; product1_lo
         ; product1_hi_0
        |] )
    |> array24_to_tuple24
  in

  (* TODO: Witness hist module

     [@@deriving hlist]
     Circuit.Typ.of_hlistable
     module Witness_vars: sig
       type 'a t
       val convert : 'a t -> 'a ....
     end = struct
       type 'a t = 'a array (* make it abstract *)

       let typ ty = Typ.array ~length:27 Field.typ
     end *)

  (* TODO: external checks module *)

  (* TODO: refactor Circuit into module template function / functor *)

  (* Create ForeignFieldMul gate *)
  with_label "foreign_field_mul" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (ForeignFieldMul
                 { (* Current row *) left_input0
                 ; left_input1
                 ; left_input2
                 ; right_input0
                 ; right_input1
                 ; right_input2
                 ; carry1_lo
                 ; carry1_hi
                 ; carry0
                 ; quotient0
                 ; quotient1
                 ; quotient2
                 ; quotient_bound_carry
                 ; product1_hi_1
                 ; (* Next row *) remainder0
                 ; remainder1
                 ; remainder2
                 ; quotient_bound01
                 ; quotient_bound2
                 ; product1_lo
                 ; product1_hi_0
                 ; (* Coefficients *) foreign_field_modulus0
                 ; foreign_field_modulus1
                 ; foreign_field_modulus2
                 ; neg_foreign_field_modulus0
                 ; neg_foreign_field_modulus1
                 ; neg_foreign_field_modulus2
                 } )
        } ) ;
  Foreign_field_element.of_limbs (remainder0, remainder1, remainder2)

(*********)
(* Tests *)
(*********)

let%test_unit "foreign_field_mul gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in

  (* Helper to test foreign_field_mul gadget
   *   Inputs:
   *     - left_input
   *     - right_input
   *     - foreign_field_modulus
   *     - expected product
   *)
  let test_mul (left_input : string) (right_input : string)
      (foreign_field_modulus : string) (expected : string) : unit =
    Printf.printf "test_mul\n" ;
    let _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          (* Prepare test inputs *)
          let foreign_field_modulus =
            string_to_field_standard_limbs
              (module Runner.Impl)
              foreign_field_modulus
          in
          let left_input =
            Foreign_field_element.of_string (module Runner.Impl) left_input
          in
          let right_input =
            Foreign_field_element.of_string (module Runner.Impl) right_input
          in
          let result =
            Foreign_field_element.of_string (module Runner.Impl) expected
          in
          (* Create the gadget *)
          let product =
            mul
              (module Runner.Impl)
              left_input right_input foreign_field_modulus
          in
          (* Check product matches expected result *)
          as_prover (fun () ->
              let expected =
                Foreign_field_element.to_field_limbs (module Runner.Impl) result
              in
              let product =
                Foreign_field_element.to_field_limbs
                  (module Runner.Impl)
                  product
              in
              assert (expected = product) ) ;
          () )
    in
    ()
  in

  (* Positive tests *)
  let secp256k1_modulus =
    "115792089237316195423570985008687907853269984665640564039457584007908834671663"
  in
  let secp256k1_max =
    "115792089237316195423570985008687907853269984665640564039457584007908834671662"
  in
  (* 0 * 0 == 0 *)
  test_mul "0" "0" secp256k1_modulus "0" ;
  (* max * 1 == max *)
  test_mul secp256k1_max "1" secp256k1_modulus secp256k1_max ;
  (* Negative tests *)
  (* 0 * 0 == 1 *)
  assert (Common.is_error (fun () -> test_mul "0" "0" secp256k1_modulus "1")) ;

  ()
