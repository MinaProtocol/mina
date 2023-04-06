open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

let two_to_limb_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) =
  Common.(bignum_bigint_to_field (module Circuit) two_to_limb)

(* 2^2L *)
let two_to_2limb = Bignum_bigint.(pow Common.two_to_limb (of_int 2))

(* 2^3L *)
let two_to_3limb = Bignum_bigint.(pow Common.two_to_limb (of_int 3))

(* Binary modulus *)
let binary_modulus = two_to_3limb

(* Maximum foreign field modulus m = sqrt(2^t * n), see RFC for more details
 *   For simplicity and efficiency we use the approximation m = floor(sqrt(2^t * n))
 *     * Distinct from this approximation is the maximum prime foreign field modulus
 *       for both Pallas and Vesta given our CRT scheme:
 *       926336713898529563388567880069503262826888842373627227613104999999999999999607 *)
let max_foreign_field_modulus (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) :
    Bignum_bigint.t =
  (* m = floor(sqrt(2^t * n)) *)
  let product =
    (* We need Zarith for sqrt *)
    Bignum_bigint.to_zarith_bigint
    @@ Bignum_bigint.(binary_modulus * Circuit.Field.size)
    (* Zarith.sqrt truncates (rounds down to int) ~ floor *)
  in
  Bignum_bigint.of_zarith_bigint @@ Z.sqrt product

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
  let l12, l0 = Common.(bignum_bigint_div_rem bigint two_to_limb) in
  let l2, l1 = Common.(bignum_bigint_div_rem l12 two_to_limb) in
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
  Bignum_bigint.(l0 + (Common.two_to_limb * l1) + (two_to_2limb * l2))

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
    (module Snark_intf.Run with type field = 'field) -> 'field t -> 'field limbs

  (* Convert foreign field element into Bignum_bigint.t limbs *)
  val to_bignum_bigint_limbs :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t limbs

  (* Convert foreign field element into a Bignum_bigint.t *)
  val to_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t
end

module Foreign_field_element_base = struct
  module Cvar = Snarky_backendless.Cvar

  type 'field t = 'field Cvar.t limbs

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
    map x (As_prover.read Field.typ)

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
        Bignum_bigint.(l0 + (Common.two_to_limb * l1) + (two_to_2limb * l2))
    | Extended (l0, l1, l2, l3) ->
        Bignum_bigint.(
          l0 + (Common.two_to_limb * l1) + (two_to_2limb * l2)
          + (two_to_3limb * l3))
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
  val of_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> Bignum_bigint.t
    -> 'field t

  (* Convert a foreign field element into tuple of 3 field standard_limbs *)
  val to_limbs : 'field t -> 'field Cvar.t standard_limbs

  (* Map foreign field element's Cvar limbs into some other standard_limbs with the mapping function func *)
  val map : 'field t -> ('field Cvar.t -> 'g) -> 'g standard_limbs

  (* Convert foreign field element into field standard_limbs *)
  val to_field_limbs :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field standard_limbs

  (* Convert foreign field element into bignum_bigint standard_limbs *)
  val to_bignum_bigint_limbs :
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
    let l12, l0 = Common.(bignum_bigint_div_rem x two_to_limb) in
    let l2, l1 = Common.(bignum_bigint_div_rem l12 two_to_limb) in
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
    Foreign_field_element_base.to_bignum_bigint (module Circuit) (Standard x)
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
    Common.(bignum_bigint_div_rem products1 two_to_limb)
  in
  let product1_hi_1, product1_hi_0 =
    Common.(bignum_bigint_div_rem product1_hi two_to_limb)
  in

  (* C3-C5: Compute v0 = the top 2 bits of (p0 + 2^L * p10 - r0 - 2^L * r1) / 2^2L
   *   N.b. To avoid an underflow error, the equation must sum the intermediate
   *        product terms before subtracting limbs of the remainder. *)
  let carry0 =
    Bignum_bigint.(
      ( products0
      + (Common.two_to_limb * product1_lo)
      - remainder0
      - (Common.two_to_limb * remainder1) )
      / two_to_2limb)
  in

  (* C6-C7: Compute v1 = the top L + 3 bits (p2 + p11 + v0 - r2) / 2^L
   *   N.b. Same as above, to avoid an underflow error, the equation must
   *        sum the intermediate product terms before subtracting the remainder. *)
  let carry1 =
    Bignum_bigint.(
      (products2 + product1_hi + carry0 - remainder2) / Common.two_to_limb)
  in
  (* Compute v10 and v11 *)
  let carry1_hi, carry1_lo =
    Common.(bignum_bigint_div_rem carry1 two_to_limb)
  in

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

let tuple24_of_array array =
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

(* Structure for tracking external checks that must be made
 * (using other gadgets) in order to acheive soundess for a
 * given multiplication *)
module External_checks = struct
  module Cvar = Snarky_backendless.Cvar

  type 'field t =
    { mutable multi_ranges : 'field Cvar.t standard_limbs list
    ; mutable compact_multi_ranges : 'field Cvar.t compact_limbs list
    ; mutable bounds : 'field Cvar.t standard_limbs list
    }

  let create (type field)
      (module Circuit : Snark_intf.Run with type field = field) : field t =
    { multi_ranges = []; compact_multi_ranges = []; bounds = [] }

  (* Track a multi-range-check *)
  let add_multi_range_check (external_checks : 'field t)
      (x : 'field Cvar.t standard_limbs) =
    external_checks.multi_ranges <- x :: external_checks.multi_ranges

  (* Track a compact-multi-range-check *)
  let add_compact_multi_range_check (external_checks : 'field t)
      (x : 'field Cvar.t compact_limbs) =
    external_checks.compact_multi_ranges <-
      x :: external_checks.compact_multi_ranges

  (* Track a bound check *)
  let add_bound_check (external_checks : 'field t)
      (x : 'field Cvar.t standard_limbs) =
    external_checks.bounds <- x :: external_checks.bounds
end

let mul (type f) (module Circuit : Snark_intf.Run with type field = f)
    (left_input : f Foreign_field_element.t)
    (right_input : f Foreign_field_element.t)
    (foreign_field_modulus : f standard_limbs) :
    f Foreign_field_element.t * f External_checks.t =
  let open Circuit in
  (* Check foreign field modulus < max allowed *)
  (let foreign_field_modulus =
     field_standard_limbs_to_bignum_bigint
       (module Circuit)
       foreign_field_modulus
   in
   assert (
     Bignum_bigint.(
       foreign_field_modulus < max_foreign_field_modulus (module Circuit)) ) ) ;

  (* Compute gate coefficients
   *   This happens when circuit is created / not part of witness (e.g. exists, As_prover code)
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
      , remainder_bound0
      , remainder_bound1
      , remainder_bound2
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
    |> tuple24_of_array
  in

  (* Prepare external checks *)
  let external_checks = External_checks.create (module Circuit) in
  External_checks.add_multi_range_check external_checks
    (carry1_lo, product1_lo, product1_hi_0) ;
  External_checks.add_compact_multi_range_check external_checks
    (quotient_bound01, quotient_bound2) ;
  External_checks.add_multi_range_check external_checks
    (remainder_bound0, remainder_bound1, remainder_bound2) ;
  External_checks.add_bound_check external_checks
    (remainder0, remainder1, remainder2) ;

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
  ( Foreign_field_element.of_limbs (remainder0, remainder1, remainder2)
  , external_checks )

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

  let assert_eq ((a, b, c) : 'field standard_limbs)
      ((x, y, z) : 'field standard_limbs) =
    let open Runner.Impl.Field in
    Assert.equal (constant a) (constant x) ;
    Assert.equal (constant b) (constant y) ;
    Assert.equal (constant c) (constant z)
  in

  (* Helper to test foreign_field_mul gadget
   *   Inputs:
   *     - left_input
   *     - right_input
   *     - foreign_field_modulus
   *     - expected product
   *)
  let test_mul (left_input : Bignum_bigint.t) (right_input : Bignum_bigint.t)
      (foreign_field_modulus : Bignum_bigint.t) : unit =
    let _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          (* Prepare test inputs *)
          let expected =
            Bignum_bigint.(left_input * right_input % foreign_field_modulus)
          in
          let foreign_field_modulus =
            bignum_bigint_to_field_standard_limbs
              (module Runner.Impl)
              foreign_field_modulus
          in
          let left_input =
            Foreign_field_element.of_bignum_bigint
              (module Runner.Impl)
              left_input
          in
          let right_input =
            Foreign_field_element.of_bignum_bigint
              (module Runner.Impl)
              right_input
          in
          (* Create the gadget *)
          let product, _external_checks =
            mul
              (module Runner.Impl)
              left_input right_input foreign_field_modulus
          in
          (* Check product matches expected result *)
          as_prover (fun () ->
              let expected =
                bignum_bigint_to_field_standard_limbs
                  (module Runner.Impl)
                  expected
              in
              let product =
                Foreign_field_element.to_field_limbs
                  (module Runner.Impl)
                  product
              in
              assert_eq product expected ) ;
          () )
    in
    ()
  in

  (* Helper to test foreign_field_mul gadget with external checks
   *   Inputs:
   *     - left_input
   *     - right_input
   *     - foreign_field_modulus
   *     - expected product
   *)
  let test_mul_full (left_input : Bignum_bigint.t)
      (right_input : Bignum_bigint.t) (foreign_field_modulus : Bignum_bigint.t)
      : unit =
    let _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          (* Prepare test inputs *)
          let expected =
            Bignum_bigint.(left_input * right_input % foreign_field_modulus)
          in
          let foreign_field_modulus =
            bignum_bigint_to_field_standard_limbs
              (module Runner.Impl)
              foreign_field_modulus
          in
          let left_input =
            Foreign_field_element.of_bignum_bigint
              (module Runner.Impl)
              left_input
          in
          let right_input =
            Foreign_field_element.of_bignum_bigint
              (module Runner.Impl)
              right_input
          in

          (* External checks for this test (example, circuit designer has complete flexibility about organization)
           *   1) ForeignFieldMul
           *   2) ForeignFieldAdd (result bound addition)
           *   3) multi-range-check (left multiplicand)
           *   4) multi-range-check (right multiplicand)
           *   5) multi-range-check (product1_lo, product1_hi_0, carry1_lo)
           *   6) multi-range-check (remainder bound / product / result range check)
           *   7) compact-multi-range-check (quotient range check) *)

          (* 1) Create the foreign field mul gadget *)
          let product, external_checks =
            mul
              (module Runner.Impl)
              left_input right_input foreign_field_modulus
          in

          (* Sanity check product matches expected result *)
          as_prover (fun () ->
              let expected =
                bignum_bigint_to_field_standard_limbs
                  (module Runner.Impl)
                  expected
              in
              let product =
                Foreign_field_element.to_field_limbs
                  (module Runner.Impl)
                  product
              in
              assert_eq product expected ) ;

          (* TODO: 2) Add result bound addition gate *)
          assert (Mina_stdlib.List.Length.equal external_checks.bounds 1) ;

          (* 3) Add multi-range-check left input *)
          let left_input0, left_input1, left_input2 =
            Foreign_field_element.to_limbs left_input
          in
          Range_check.multi_range_check
            (module Runner.Impl)
            left_input0 left_input1 left_input2 ;

          (* 4) Add multi-range-check right input *)
          let right_input0, right_input1, right_input2 =
            Foreign_field_element.to_limbs right_input
          in
          Range_check.multi_range_check
            (module Runner.Impl)
            right_input0 right_input1 right_input2 ;

          (* 5-6) Add gates for external multi-range-checks
           *   In this case:
           *     carry1_lo, product1_lo, product1_hi_0
           *     remainder_bound0, remainder_bound1, remainder_bound2
           *)
          Core_kernel.List.iter external_checks.multi_ranges
            ~f:(fun multi_range ->
              let v0, v1, v2 = multi_range in
              Range_check.multi_range_check (module Runner.Impl) v0 v1 v2 ;
              () ) ;
          assert (Mina_stdlib.List.Length.equal external_checks.multi_ranges 2) ;

          (* 7) Add gates for external compact-multi-range-checks
           *   In this case:
           *     quotient_bound01, quotient_bound2
           *)
          Core_kernel.List.iter external_checks.compact_multi_ranges
            ~f:(fun compact_multi_range ->
              let v01, v2 = compact_multi_range in
              Range_check.compact_multi_range_check (module Runner.Impl) v01 v2 ;
              () ) ;
          assert (
            Mina_stdlib.List.Length.equal external_checks.compact_multi_ranges 1 ) ;

          () )
    in
    ()
  in

  (* Test constants *)
  let secp256k1_modulus =
    Common.bignum_bigint_of_hex
      "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f"
  in
  let secp256k1_max = Bignum_bigint.(secp256k1_modulus - Bignum_bigint.one) in
  let secp256k1_sqrt = Common.bignum_biguint_sqrt secp256k1_max in
  let pallas_modulus =
    Common.bignum_bigint_of_hex
      "40000000000000000000000000000000224698fc094cf91b992d30ed00000001"
  in
  let pallas_max = Bignum_bigint.(pallas_modulus - Bignum_bigint.one) in
  let pallas_sqrt = Common.bignum_biguint_sqrt pallas_max in
  let vesta_modulus =
    Common.bignum_bigint_of_hex
      "40000000000000000000000000000000224698fc0994a8dd8c46eb2100000001"
  in

  (* Positive tests *)
  (* zero_mul: 0 * 0 *)
  test_mul Bignum_bigint.zero Bignum_bigint.zero secp256k1_modulus ;
  (* one_mul: max * 1 *)
  test_mul secp256k1_max Bignum_bigint.one secp256k1_modulus ;
  (* max_native_square: pallas_sqrt * pallas_sqrt *)
  test_mul pallas_sqrt pallas_sqrt secp256k1_modulus ;
  (* max_foreign_square: secp256k1_sqrt * secp256k1_sqrt *)
  test_mul secp256k1_sqrt secp256k1_sqrt secp256k1_modulus ;
  (* max_native_multiplicands: pallas_max * pallas_max *)
  test_mul pallas_max pallas_max secp256k1_modulus ;
  (* max_foreign_multiplicands: secp256k1_max * secp256k1_max *)
  test_mul secp256k1_max secp256k1_max secp256k1_modulus ;
  (* nonzero carry0 bits *)
  test_mul
    (Common.bignum_bigint_of_hex
       "fbbbd91e03b48cebbac38855289060f8b29fa6ad3cffffffffffffffffffffff" )
    (Common.bignum_bigint_of_hex
       "d551c3d990f42b6d780275d9ca7e30e72941aa29dcffffffffffffffffffffff" )
    secp256k1_modulus ;
  (* test nonzero carry10 *)
  test_mul
    (Common.bignum_bigint_of_hex
       "4000000000000000000000000000000000000000000000000000000000000000" )
    (Common.bignum_bigint_of_hex
       "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0" )
    Bignum_bigint.(pow (of_int 2) (of_int 259)) ;
  (* test nonzero carry1_hi *)
  test_mul
    (Common.bignum_bigint_of_hex
       "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" )
    (Common.bignum_bigint_of_hex
       "8000000000000000000000000000000000000000000000000000000000000000d0" )
    Bignum_bigint.(pow (of_int 2) (of_int 259) - one) ;
  (* test nonzero_second_bit_carry1_hi *)
  test_mul
    (Common.bignum_bigint_of_hex
       "ffffffffffffffffffffffffffffffffffffffffffffffff8a9dec7cfd1acdeb" )
    (Common.bignum_bigint_of_hex
       "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2e" )
    secp256k1_modulus ;
  (* test random_multiplicands_carry1_lo *)
  test_mul
    (Common.bignum_bigint_of_hex
       "ffd913aa9e17a63c7a0ff2354218037aafcd6ecaa67f56af1de882594a434dd3" )
    (Common.bignum_bigint_of_hex
       "7d313d6b42719a39acea5f51de9d50cd6a4ec7147c003557e114289e9d57dffc" )
    secp256k1_modulus ;
  (* test random_multiplicands_valid *)
  test_mul
    (Common.bignum_bigint_of_hex
       "1f2d8f0d0cd52771bfb86ffdf651b7907e2e0fa87f7c9c2a41b0918e2a7820d" )
    (Common.bignum_bigint_of_hex
       "b58c271d1f2b1c632a61a548872580228430495e9635842591d9118236bacfa2" )
    secp256k1_modulus ;
  (* test smaller foreign field modulus *)
  test_mul
    (Common.bignum_bigint_of_hex
       "5945fa400436f458cb9e994dcd315ded43e9b60eb68e2ae7b5cf1d07b48ca1c" )
    (Common.bignum_bigint_of_hex
       "747109f882b8e26947dfcd887273c0b0720618cb7f6d407c9ba74dbe0eda22f" )
    (Common.bignum_bigint_of_hex
       "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ) ;
  (* vesta non-native on pallas native modulus *)
  test_mul
    (Common.bignum_bigint_of_hex
       "69cc93598e05239aa77b85d172a9785f6f0405af91d91094f693305da68bf15" )
    (Common.bignum_bigint_of_hex
       "1fffe27b14baa740db0c8bb6656de61d2871a64093908af6181f46351a1c1909" )
    vesta_modulus ;

  (* Full test including all external checks *)
  test_mul_full
    (Common.bignum_bigint_of_hex
       "1f2d8f0d0cd52771bfb86ffdf651b7907e2e0fa87f7c9c2a41b0918e2a7820d" )
    (Common.bignum_bigint_of_hex
       "b58c271d1f2b1c632a61a548872580228430495e9635842591d9118236bacfa2" )
    secp256k1_modulus ;
  ()
