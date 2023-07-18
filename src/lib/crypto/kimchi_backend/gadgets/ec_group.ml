open Core_kernel
module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

let basic_tests_enabled = true

let scalar_mul_tests_enabled = true

(* Array to tuple helper *)
let tuple9_of_array array =
  match array with
  | [| a1; a2; a3; a4; a5; a6; a7; a8; a9 |] ->
      (a1, a2, a3, a4, a5, a6, a7, a8, a9)
  | _ ->
      assert false

(* Helper to check if point is on elliptic curve curve: y^2 = x^3 + a * x + b *)
let is_on_curve_bignum_point (curve : Curve_params.t)
    (point : Affine.bignum_point) : bool =
  let x, y = point in
  Bignum_bigint.(
    zero
    = (pow y (of_int 2) - (pow x (of_int 3) + (curve.a * x) + curve.b))
      % curve.modulus)

(* Gadget for (partial) elliptic curve group addition over foreign field
 *
 *   Given input points L and R, constrains that
 *     s = (Ry - Ly)/(Rx - Lx) mod f
 *     x = s^2 - Lx - Rx mod f
 *     y = s * (Rx - x) - Ry mod f
 *
 *   where f is the foreign field modulus.
 *   See p. 348 of "Introduction to Modern Cryptography" by Katz and Lindell
 *
 *   Preconditions and limitations:
 *     L != R
 *     Lx != Rx (no invertibility)
 *     L and R are not O (the point at infinity)
 *
 *  TODO: UPDATE ROWS
 *
 *   External checks: (not counting inputs and output)
 *     Bound checks:          6
 *     Multi-range-checks:    3
 *     Compact-range-checks:  3
 *     Total range-checks:   12
 *
 *   Rows: (not counting inputs/outputs and constants)
 *     Group addition:     13
 *     Bound additions:    12
 *     Multi-range-checks: 48
 *     Total:              73
 *
 *   Supported group axioms:
 *     Closure
 *     Associativity
 *
 *   Note: We elide the Identity property because it is costly in circuit
 *         and we don't need it for our application.  By doing this we also
 *         lose Invertibility, which we also don't need for our goals.
 *)
let add (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t)
    (curve : f Curve_params.InCircuit.t) (left_input : f Affine.t)
    (right_input : f Affine.t) : f Affine.t =
  let open Circuit in
  (* TODO: Remove sanity checks if this API is not public facing *)
  as_prover (fun () ->
      (* Sanity check that two points are not equal *)
      assert (
        not (Affine.equal_as_prover (module Circuit) left_input right_input) ) ;
      (* Sanity check that both points are not infinity *)
      assert (
        not
          (Affine.equal_as_prover
             (module Circuit)
             left_input
             (Affine.const_zero (module Circuit)) ) ) ;
      assert (
        not
          (Affine.equal_as_prover
             (module Circuit)
             right_input
             (Affine.const_zero (module Circuit)) ) ) ) ;

  (* Unpack coordinates *)
  let left_x, left_y = Affine.to_coordinates left_input in
  let right_x, right_y = Affine.to_coordinates right_input in

  (* TODO: Remove sanity checks if this API is not public facing *)
  (* Sanity check that x-coordinates are not equal (i.e. we don't support Invertibility) *)
  as_prover (fun () ->
      assert (
        not
          (Foreign_field.Element.Standard.equal_as_prover
             (module Circuit)
             left_x right_x ) ) ) ;

  (* Compute witness values *)
  let ( slope0
      , slope1
      , slope2
      , result_x0
      , result_x1
      , result_x2
      , result_y0
      , result_y1
      , result_y2 ) =
    exists (Typ.array ~length:9 Field.typ) ~compute:(fun () ->
        let left_x =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            left_x
        in
        let left_y =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            left_y
        in
        let right_x =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            right_x
        in
        let right_y =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            right_y
        in

        (* Compute slope and slope squared *)
        let slope =
          Curve_params.compute_slope_bignum curve.bignum (left_x, left_y)
            (right_x, right_y)
        in

        let slope_squared =
          Bignum_bigint.((pow slope @@ of_int 2) % curve.bignum.modulus)
        in

        (* Compute result's x-coodinate: x = s^2 - Lx - Rx *)
        let result_x =
          Bignum_bigint.(
            let slope_squared_x =
              (slope_squared - left_x) % curve.bignum.modulus
            in
            (slope_squared_x - right_x) % curve.bignum.modulus)
        in

        (* Compute result's y-coodinate: y = s * (Rx - x) - Ry *)
        let result_y =
          Bignum_bigint.(
            let x_diff = (right_x - result_x) % curve.bignum.modulus in
            let x_diff_s = slope * x_diff % curve.bignum.modulus in
            (x_diff_s - right_y) % curve.bignum.modulus)
        in

        (* Convert from Bignums to field elements *)
        let slope0, slope1, slope2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            slope
        in
        let result_x0, result_x1, result_x2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            result_x
        in
        let result_y0, result_y1, result_y2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            result_y
        in

        (* Return and convert back to Cvars *)
        [| slope0
         ; slope1
         ; slope2
         ; result_x0
         ; result_x1
         ; result_x2
         ; result_y0
         ; result_y1
         ; result_y2
        |] )
    |> tuple9_of_array
  in

  (* Convert slope and result into foreign field elements *)
  let slope =
    Foreign_field.Element.Standard.of_limbs (slope0, slope1, slope2)
  in
  let result_x =
    Foreign_field.Element.Standard.of_limbs (result_x0, result_x1, result_x2)
  in
  let result_y =
    Foreign_field.Element.Standard.of_limbs (result_y0, result_y1, result_y2)
  in

  (* C1: Constrain computation of slope squared *)
  let slope_squared =
    (* s * s = s^2 *)
    Foreign_field.mul (module Circuit) external_checks slope slope curve.modulus
  in
  (* Bounds 1: Left input (slope) bound check below.
   *           Right input (slope) equal to left input (already checked)
   *           Result (s^2) bound check already tracked by Foreign_field.mul.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
    (slope0, slope1, slope2) ;

  (*
   * Constrain result x-coordinate computation: x = s^2 - Lx - Rx with length 2 chain
   *)

  (* C2: Constrain s^2 - x = sΔx *)
  let slope_squared_minus_x =
    Foreign_field.sub
      (module Circuit)
      ~single:true slope_squared result_x curve.modulus
  in

  (* Bounds 2: Left input (s^2) bound check covered by (Bounds 1).
   *           Right input (x) bound check value is gadget output (checked by caller).
   *           Result is chained (no bound check required).
   *)

  (* C3: Constrain sΔx - Lx = Rx *)
  let expected_right_x =
    Foreign_field.sub
      (module Circuit)
      ~single:true slope_squared_minus_x left_x curve.modulus
  in

  (* Bounds 3: Left input (sΔx) is chained (no bound check required).
   *           Right input (Lx) is gadget input (checked by caller).
   *           Result is (Rx) gadget input (checked by caller)
   *)

  (* Copy expected_right_x to right_x *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    expected_right_x right_x ;

  (* Continue the chain to length 4 by computing (Rx - x) * s (used later) *)

  (* C4: Constrain Rx - x = RxΔ *)
  let right_delta =
    Foreign_field.sub
      (module Circuit)
      ~single:true expected_right_x result_x curve.modulus
  in
  (* Bounds 4: Left input (Rx) is chained (no bound check required).
   *           Right input (x) is gadget output (checked by caller).
   *           Addition chain result (right_delta) bound check added below.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs right_delta ;

  (* C5: RxΔ * s = RxΔs *)
  let right_delta_s =
    Foreign_field.mul
      (module Circuit)
      external_checks right_delta slope curve.modulus
  in

  (* Bounds 5: Left input (right_delta) already covered by (Bounds 4)
   *           Right input (slope) already covered by (Bounds 1).
   *           Result bound check already tracked by Foreign_field.mul.
   *)

  (*
   * Constrain slope computation: s = (Ry - Ly)/(Rx - Lx)
   *   with (Rx - Lx) * s + Ly = Ry
   *)

  (* C6:  Rx - Lx = Δx  *)
  let delta_x =
    Foreign_field.sub (module Circuit) ~single:true right_x left_x curve.modulus
  in
  (* Bounds 6: Inputs (Rx and Lx) are gadget inputs (checked by caller).
   *           Addition chain result (delta_x) bound check below.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs delta_x ;

  (* C7: Δx * s = Δxs *)
  let delta_x_s =
    Foreign_field.mul
      (module Circuit)
      external_checks delta_x slope curve.modulus
  in

  (* Bounds 7: Left input (delta_x) already covered by (Bounds 6)
   *           Right input (slope) already covered by (Bounds 1).
   *           Result bound check tracked by Foreign_field.mul.
   *)

  (*
   * Finish constraining slope in new chain (above mul ended chain)
   *)

  (* C8: Δxs + Ly = Ry *)
  let expected_right_y =
    Foreign_field.add
      (module Circuit)
      ~single:true delta_x_s left_y curve.modulus
  in

  (* Bounds 8: Left input (delta_x_s) check is tracked by (Bounds 7).
   *           Right input bound check value is gadget input (checked by caller).
   *           Result is chained (no check required)
   *)

  (* Copy expected_right_y to right_y *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    expected_right_y right_y ;

  (*
   * Constrain result y-coordinate computation: y = (Rx - x) * s - Ry
   *     with Ry + y = (Rx - x) * s
   *)

  (* C9: Ry + y = RxΔs *)
  let expected_right_delta_s =
    Foreign_field.add ~single:true
      (module Circuit)
      expected_right_y result_y curve.modulus
  in
  (* Result row *)
  Foreign_field.result_row
    (module Circuit)
    ~label:"Ec_group.add_expected_right_delta_s" expected_right_delta_s ;
  (* Bounds 9: Left input (Ry) check is chained (no check required).
   *           Right input (y) check value is gadget output (checked by caller).
   *           Addition chain result (expected_right_delta_s) check already covered by (Bounds 5).
   *)
  (* Copy expected_right_delta_s to right_delta_s *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    expected_right_delta_s right_delta_s ;

  (* Return result point *)
  Affine.of_coordinates (result_x, result_y)

(* Gadget for (partial) elliptic curve group doubling over foreign field
 *
 *   Given input point P, constrains that
 *     s' = 3 * Px^2 / (2 * Py) mod f
 *     x = s'^2 - 2 * Px mod f
 *     y = s' * (Px - x) - Py mod f
 *
 *   where f is the foreign field modulus.
 *   See p. 348 of "Introduction to Modern Cryptography" by Katz and Lindell
 *
 *   Preconditions and limitations:
 *      P is not O (the point at infinity)
 *
 *   External checks: (not counting inputs and output)
 *     Bound checks:          8 (+1 when a != 0)
 *     Multi-range-checks:    4
 *     Compact-range-checks:  4
 *     Total range-checks:   16
 *
 *   Rows: (not counting inputs/outputs and constants)
 *     Group double:       16 (+2 when a != 0)
 *     Bound additions:    16
 *     Multi-range-checks: 64
 *     Total:              96
 *
 *   Note: See group addition notes (above) about group properties supported by this implementation
 *)
let double (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t)
    (curve : f Curve_params.InCircuit.t) (point : f Affine.t) : f Affine.t =
  let open Circuit in
  (* TODO: Remove sanity checks if this API is not public facing *)
  as_prover (fun () ->
      (* Sanity check that point is not infinity *)
      assert (
        not
          (Affine.equal_as_prover
             (module Circuit)
             point
             (Affine.const_zero (module Circuit)) ) ) ) ;

  (* Unpack coordinates *)
  let point_x, point_y = Affine.to_coordinates point in

  (* Compute witness values *)
  let ( slope0
      , slope1
      , slope2
      , result_x0
      , result_x1
      , result_x2
      , result_y0
      , result_y1
      , result_y2 ) =
    exists (Typ.array ~length:9 Field.typ) ~compute:(fun () ->
        let point =
          ( Foreign_field.Element.Standard.to_bignum_bigint_as_prover
              (module Circuit)
              point_x
          , Foreign_field.Element.Standard.to_bignum_bigint_as_prover
              (module Circuit)
              point_y )
        in

        (* Compute slope *)
        let slope =
          Curve_params.compute_slope_bignum curve.bignum point point
        in

        (* Compute result point *)
        let result_x, result_y =
          Curve_params.double_bignum_point curve.bignum ~slope point
        in

        (* Convert from Bignums to field elements *)
        let slope0, slope1, slope2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            slope
        in
        let result_x0, result_x1, result_x2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            result_x
        in
        let result_y0, result_y1, result_y2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            result_y
        in

        (* Return and convert back to Cvars *)
        [| slope0
         ; slope1
         ; slope2
         ; result_x0
         ; result_x1
         ; result_x2
         ; result_y0
         ; result_y1
         ; result_y2
        |] )
    |> tuple9_of_array
  in

  (* Convert slope and result into foreign field elements *)
  let slope =
    Foreign_field.Element.Standard.of_limbs (slope0, slope1, slope2)
  in
  let result_x =
    Foreign_field.Element.Standard.of_limbs (result_x0, result_x1, result_x2)
  in
  let result_y =
    Foreign_field.Element.Standard.of_limbs (result_y0, result_y1, result_y2)
  in

  (* C1: Constrain computation of slope squared *)
  let slope_squared =
    (* s * s  = s^2 *)
    Foreign_field.mul (module Circuit) external_checks slope slope curve.modulus
  in
  (* Bounds 1: Left input (slope) checked below.
   *           Right input (slope) is equal to left input (no check required).
   *           Result (slope_squared) check already tracked by Foreign_field.mul.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
    (slope0, slope1, slope2) ;

  (* C2: Constrain result x-coordinate computation: x = s^2 - 2 * Px with length 2 chain
   *     with s^2 - x = 2 * Px
   *)
  let point_x2 =
    (* s^2 - x = 2Px *)
    Foreign_field.sub
      (module Circuit)
      ~single:true slope_squared result_x curve.modulus
  in

  (* Bounds 2: Left input (s^2) check covered by (Bounds 1).
   *           Right input (x) check value is gadget output (checked by caller).
   *           Result (2Px) chained (no check required).
   *)

  (* C3: 2Px - Px = Px *)
  let expected_point_x =
    Foreign_field.sub
      (module Circuit)
      ~single:true point_x2 point_x curve.modulus
  in
  (* Bounds 3: Left input (2Px) is chained (no check required).
   *           Right input (Px) is gadget input (checked by caller).
   *           Result (Px) chained (no check required).
   *)
  (* Copy expected_point_x to point_x *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    expected_point_x point_x ;

  (*
   * Continue the chain to length 4 by computing (Px - x) * s (used later)
   *)

  (* C4: Px - x = Δx *)
  let delta_x =
    Foreign_field.sub
      (module Circuit)
      ~single:true expected_point_x result_x curve.modulus
  in
  (* Bounds 4: Left input (Px) is chained (no check required).
   *           Right input (x) check value is gadget output (checked by caller).
   *           Addition chain result (delta_x) bound check added below.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs delta_x ;

  (* C5: Δx * s = Δxs *)
  let delta_xs =
    Foreign_field.mul
      (module Circuit)
      external_checks delta_x slope curve.modulus
  in

  (* Bounds 5: Left input (delta_x) check already covered by (Bounds 4).
   *           Right input (slope) already covered by (Bounds 1).
   *           Result (delta_xs) bound check already tracked by Foreign_field.mul.
   *)

  (*
   * Constrain rest of y = s' * (Px - x) - Py and part of slope computation
   *     s = (3 * Px^2 + a)/(2 * Py) in length 3 chain
   *)

  (* C6: Δxs - y = Py *)
  let expected_point_y =
    Foreign_field.sub
      (module Circuit)
      ~single:true delta_xs result_y curve.modulus
  in
  (* Bounds 6: Left input (delta_xs) checked by (Bound 5).
   *           Right input is gadget output (checked by caller).
   *           Addition result (Py) is chained (no check required).
   *)
  (* Copy expected_point_y to point_y *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    expected_point_y point_y ;

  (* C7: Py + Py = 2Py *)
  let point_y2 =
    Foreign_field.add
      (module Circuit)
      ~single:true point_y point_y curve.modulus
  in

  (* Bounds 7: Left input (Py) is gadget input (checked by caller).
   *           Right input (Py) is gadget input (checked by caller).
   *           Addition result (2Py) chained (no check required).
   *)

  (* C8: 2Py * s = 2Pys *)
  let point_y2s =
    Foreign_field.mul
      (module Circuit)
      external_checks point_y2 slope curve.modulus
  in
  (* Bounds 8: Left input (point_y2) bound check added below.
   *           Right input (slope) already checked by (Bound 1).
   *           Result (2Pys) bound check already tracked by Foreign_field.mul.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs point_y2 ;

  (*
   * Constrain rest slope computation s = (3 * Px^2 + a)/(2 * Py)
   *)

  (* C9: 2Px + Px = 3Px *)
  let point_x3 =
    Foreign_field.add
      (module Circuit)
      ~single:true point_x2 point_x curve.modulus
  in
  (* Bounds 9: Left input (point_x2) bound check added below.
   *           Right input (Px) is gadget input (checked by caller).
   *           Result (3Px) is chained (no check required).
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs point_x2 ;

  (* Check if the elliptic curve a parameter requires more constraints
   * to be added in order to add final a (e.g. 3Px^2 + a where a != 0).
   *)
  ( if Bignum_bigint.(curve.bignum.a = zero) then (
    (* C10a: 3Px * Px = 3Px^2 *)
    let point_x3_squared =
      Foreign_field.mul
        (module Circuit)
        external_checks ~bound_check_result:false point_x3 point_x curve.modulus
    in

    (* Bounds 10a: Left input (point_x3) bound check added below.
     *             Right input (Px) is gadget input (checked by caller).
     *             Result (3Px^2) bound check already covered by (Bounds 8) since
     *             point_x3_squared is equal to point_y2s.
     *)

    (* Add point_x3 bound check (Bounds 101) *)
    Foreign_field.External_checks.append_bound_check external_checks
    @@ Foreign_field.Element.Standard.to_limbs point_x3 ;

    (* Copy point_x3_squared to point_y2s *)
    Foreign_field.Element.Standard.assert_equal
      (module Circuit)
      point_x3_squared point_y2s )
  else
    (* C10b: 3Px * Px = 3Px^2 *)
    let point_x3_squared =
      Foreign_field.mul
        (module Circuit)
        external_checks point_x3 point_x curve.modulus
    in

    (* Bounds 10b: Left input (point_x3) bound check added below.
     *             Right input (Px) is gadget input (checked by caller).
     *             Result (3Px^2) bound check already covered by Foreign_field.mul.
     *)

    (* Add point_x3 bound check (Bounds 10b) *)
    Foreign_field.External_checks.append_bound_check external_checks
    @@ Foreign_field.Element.Standard.to_limbs point_x3 ;

    (* Add curve constant a and constrain rest slope computation
     *   with s = (3 * Px^2 + a)/(2 * Py)
     *)

    (* C11: 3Px^2 + a = 3Px^2a *)
    let point_x3_squared_plus_a =
      Foreign_field.add
        (module Circuit)
        ~single:true point_x3_squared curve.a curve.modulus
    in
    (* Bounds 11: Left input (point_x3_squared) already tracked by (Bounds 10b).
       *          Right input (curve.a) is public constant.
       *          Result (3Px^2a) bound check already covered by (Bound 8) since
       *          point_x3_squared_plus_a = point_y2s.
    *)
    (* Result row *)
    Foreign_field.result_row
      (module Circuit)
      ~label:"Ec_group.double_point_x3_squared_plus_a" point_x3_squared_plus_a ;

    (* Copy point_x3_squared_plus_a to point_y2s *)
    Foreign_field.Element.Standard.assert_equal
      (module Circuit)
      point_x3_squared_plus_a point_y2s ) ;

  (* Return result point *)
  Affine.of_coordinates (result_x, result_y)

(* Gadget for elliptic curve group negation
 *
 * Note: this gadget does not create a Zero row for the negated result.
 *       If not already present in witness the caller is responsible for placing
 *       the negated result somewhere (e.g. in a Zero row or elsewhere).
 *)
let negate (type f) (module Circuit : Snark_intf.Run with type field = f)
    (curve : f Curve_params.InCircuit.t) (point : f Affine.t) : f Affine.t =
  let x, y = Affine.to_coordinates point in
  (* Zero constant foreign field elemtn *)
  let zero =
    Foreign_field.Element.Standard.of_bignum_bigint
      (module Circuit)
      Bignum_bigint.zero
  in
  (* C1: Constrain computation of the negated point *)
  let neg_y =
    (* neg_y = 0 - y *)
    Foreign_field.sub (module Circuit) ~single:true zero y curve.modulus
  in

  (* Bounds 1: Left input is public constant
   *           Right input parameter (checked by caller)
   *           Result bound is part of output (checked by caller)
   *)
  Affine.of_coordinates (x, neg_y)

(* Select initial EC scalar mul accumulator value ia using trustless nothing-up-my-sleeve deterministic algorithm
 *
 *   Simple hash-to-curve algorithm
 *
 *   Trustlessly select an elliptic curve point for which noone knows the discrete logarithm!
 *)
let compute_ia_points ?(point : Affine.bignum_point option)
    (curve : Curve_params.t) : Affine.bignum_point Curve_params.ia_points =
  (* Hash generator point to get candidate x-coordinate *)
  let open Digestif.SHA256 in
  let ctx = init () in

  let start_point =
    match point with Some point -> point | None -> curve.gen
  in

  assert (is_on_curve_bignum_point curve start_point) ;

  (* Hash to (possible) elliptic curve point function *)
  let hash_to_curve_point ctx (point : Affine.bignum_point ref) =
    (* Hash curve point *)
    let x, y = !point in
    let ctx = feed_string ctx @@ Common.bignum_bigint_unpack_bytes x in
    let ctx = feed_string ctx @@ Common.bignum_bigint_unpack_bytes y in
    let bytes = get ctx |> to_raw_string in

    (* Initialize x-coordinate from hash output *)
    let x = Bignum_bigint.(Common.bignum_bigint_of_bin bytes % curve.modulus) in

    (* Compute y-coordinate: y = sqrt(x^3 + a * x + b) *)
    let x3 = Bignum_bigint.(pow x (of_int 3) % curve.modulus) in
    let ax = Bignum_bigint.(curve.a * x % curve.modulus) in
    let x3ax = Bignum_bigint.((x3 + ax) % curve.modulus) in
    let y2 = Bignum_bigint.((x3ax + curve.b) % curve.modulus) in
    let y = Common.bignum_bigint_sqrt_mod y2 curve.modulus in

    (* Sanity check *)
    ( if Bignum_bigint.(not (equal y zero)) then
      let y2_computed = Bignum_bigint.(y * y % curve.modulus) in
      assert (Bignum_bigint.(y2_computed = y2)) ) ;

    (* Return possibly valid curve point *)
    (x, y)
  in

  (* Deterministically search for valid curve point *)
  let candidate_point = ref (hash_to_curve_point ctx (ref start_point)) in

  while not (is_on_curve_bignum_point curve !candidate_point) do
    candidate_point := hash_to_curve_point ctx candidate_point
  done ;

  (* We have a valid curve point! *)
  let point = !candidate_point in

  (* Compute negated point (i.e. with other y-root) *)
  let neg_point =
    let x, y = point in
    let neg_y = Bignum_bigint.(neg y % curve.modulus) in
    (x, neg_y)
  in

  Curve_params.ia_of_points point neg_point

(* Gadget to constrain a point in on the elliptic curve specified by
 *   y^2 = x^3 + ax + b mod p
 * where a, b are the curve parameters and p is the base field modulus (curve.modulus)
 *
 *   External checks: (not counting inputs and output)
 *     Bound checks:         3 (+1 when a != 0 and +1 when b != 0)
 *     Multi-range-checks:   3
 *     Compact-range-checks: 3
 *     Total range-checks:   9
 *
 *   Rows: (not counting inputs/outputs and constants)
 *     Curve check:         8 (+1 when a != 0 and +2 when b != 0)
 *     Bound additions:     6
 *     Multi-range-checks: 36
 *     Total:              50
 *
 *   Constants:
 *     Curve constants:        10 (for 256-bit curve; one-time cost per circuit)
 *     Pre-computing doubles: 767 (for 256-bit curve; one-time cost per circuit)
 *)
let is_on_curve (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t)
    (curve : f Curve_params.InCircuit.t) (point : f Affine.t) =
  let x, y = Affine.to_coordinates point in

  (* C1: x^2 = x * x *)
  let x_squared =
    Foreign_field.mul (module Circuit) external_checks x x curve.modulus
  in

  (* Bounds 1: Left and right inputs are gadget input (checked by caller).
   *           Result bound check already tracked by Foreign_field.mul
   *)

  (* C2: Optionally constrain addition of curve parameter a *)
  let x_squared_a =
    if not Bignum_bigint.(curve.bignum.a = zero) then (
      (* x^2 + a *)
      let x_squared_a =
        Foreign_field.add
          (module Circuit)
          ~single:true x_squared curve.a curve.modulus
      in
      (* Bounds 2: Left input already checked by (Bounds 1)
       *           Right input public parameter (no check necessary)
       *           Result bound check below
       *)
      (* Add x_squared_a bound check *)
      Foreign_field.External_checks.append_bound_check external_checks
      @@ Foreign_field.Element.Standard.to_limbs x_squared_a ;
      x_squared_a )
    else x_squared
  in

  (* C3: x^3 + ax = (x^2 + a) * x *)
  let x_cubed_ax =
    Foreign_field.mul
      (module Circuit)
      external_checks x_squared_a x curve.modulus
  in

  (* Bounds 3: Left input already checked by (Bounds 2) or (Bounds 1)
   *           Right input is gadget input (checked by caller).
   *           Result bound check already tracked by Foreign_field.mul
   *)

  (* C4: Optionally constrain addition of curve parameter b *)
  let x_cubed_ax_b =
    if not Bignum_bigint.(curve.bignum.b = zero) then (
      (* (x^2 + a) * x + b *)
      let x_cubed_ax_b =
        Foreign_field.add
          (module Circuit)
          ~single:true x_cubed_ax curve.b curve.modulus
      in
      (* Result row *)
      Foreign_field.result_row
        (module Circuit)
        ~label:"Ec_group.is_on_curve_x_cubed_ax_b" x_cubed_ax_b ;

      (* Bounds 4: Left input already checked by (Bounds 3)
       *           Right input public parameter (no check necessary)
       *           Result bound check below
       *)

      (* Add x_cubed_ax_b bound check *)
      Foreign_field.External_checks.append_bound_check external_checks
      @@ Foreign_field.Element.Standard.to_limbs x_cubed_ax_b ;

      x_cubed_ax_b )
    else x_cubed_ax
  in

  (* C5: y^2 = y * y *)
  let y_squared =
    Foreign_field.mul (module Circuit) external_checks y y curve.modulus
  in

  (* Bounds 5: Left and right inputs are gadget input (checked by caller)
   *           Result bound check already tracked by Foreign_field.mul
   *)

  (* Copy y_squared to x_cubed_ax_b *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    y_squared x_cubed_ax_b ;
  ()

(* Gadget to constrain that initial accumulator (ia) point is on elliptic curve and the computation of its negation.
 *   Note: The value of the ia itself is a deterministically generated public constant (this computation is not checked),
 *         so using this gadget is only required in some situations.
 *)
let check_ia (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t)
    (curve : f Curve_params.InCircuit.t) (ia : f Affine.t Curve_params.ia_points)
    =
  (* C1: Check that initial accumulator point is on curve *)
  is_on_curve (module Circuit) external_checks curve ia.acc ;

  (* C2: Constrain computation of the negated initial accumulator point *)
  let neg_init_acc = negate (module Circuit) curve ia.acc in
  (* Result row *)
  Foreign_field.result_row
    (module Circuit)
    ~label:"Ec_group.check_ia_neg_init_y"
  @@ Affine.y neg_init_acc ;

  (* Bounds 1: Input is public constant
   *           Result is part of input (checked by caller)
   *)

  (* C3: Copy computed_neg_init_acc to  ia.neg_acc *)
  Affine.assert_equal (module Circuit) neg_init_acc ia.neg_acc ;

  (* P is on curve <=> -P is on curve, thus we do not need to check
   *  ai.neg_acc is on curve *)
  ()

(* Gadget for elliptic curve group scalar multiplication over foreign field
 *
 *   Given input point P and scalar field element s, computes and constrains that
 *     Q = s0 * P + ... + sz * 2^z * P
 *
 *   where s0, s1, ..., sz is the binary expansion of s, (+) is group addition
 *   and the terms P, 2 * P, ... 2^z * P are obtained with group doubling.
 *
 *   Inputs:
 *      external_checks       := Context to track required external checks
 *      curve                 := Elliptic curve parameters
 *      scalar                := Boolean array of scalar bits
 *      point                 := Affine point to scale
 *
 *   Preconditions and limitations:
 *      P is not O (the point at infinity)
 *      P's coordinates are bounds checked
 *      P is on the curve
 *      s is not zero
 *      ia point is randomly selected and constrained to be on the curve
 *      ia negated point computation is constrained
 *      ia coordinates are bounds checked
 *
 *   External checks: (per crumb, not counting inputs and output)
 *     Bound checks:         42 (+1 when a != 0)
 *     Multi-range-checks:   17
 *     Compact-range-checks: 17
 *     Total range-checks:   76
 *
 *   Rows: (per crumb, not counting inputs/outputs and constants)
 *     Scalar multiplication:  ~84 (+2 when a != 0)
 *     Bound additions:         84
 *     Multi-range-checks:     308
 *     Total:                  476
 *
 *   Constants:
 *     Curve constants:        10 (for 256-bit curve; one-time cost per circuit)
 *     Pre-computing doubles: 767 (for 256-bit curve; one-time cost per circuit)
 *)
let scalar_mul (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t)
    (curve : f Curve_params.InCircuit.t) ?(doubles : f Affine.t array option)
    (scalar : Circuit.Boolean.var list) (point : f Affine.t) : f Affine.t =
  (* Double-and-add algorithm
   *   Only used for signature verification, so simple algorithm suffices.
   *
   *     A = O; B = P
   *     for i in 0..z
   *         if si == 1
   *             A = group_add(A, B)
   *         B = group_double(B)
   *     return A
   *
   *   Optimization:
   *
   *     To avoid expensive in-circuit conditional checks for point at infinity,
   *     we employ a randomized strategy that avoids adding the identity element
   *     or the same point to itself.  The strategy works as follows.
   *
   *     Since the prover knows the the points that it will add and double during
   *     scaling, the prover could select an initial accumulator point I such that
   *     the double-and-add algorithm never adds the identity element, same point
   *     or negated point to itself whilst scaling.
   *
   *     The algorithm above is modified to initialize the accumulator to I and
   *     then (group) subtract I after scaling to compute the final result point.
   *
   *       A = I; B = P
   *       for i in 0..z
   *           if si == 1
   *               A = group_add(A, B)
   *           B = group_double(B)
   *       return A + -I
   *
   *     The prover MUST additionally constrain that
   *       1) point I is on the curve
   *       2) I' = -I
   *
   *   Simplification:
   *
   *     Uniformly and randomly select initial accumulator point I, instead of using
   *     the complicated deterministic process.
   *
   *     For a z-bit scalar, there are z unique B points.  Each point also has its
   *     negative, which we cannot add to itself.  Therefore, in total there are
   *     2z points that we do not want to select as our initial point nor compute
   *     as an intermediate A point during scaling.  The probability we select or
   *     compute one of these points is approx 2z^2/n, where n is the order of the
   *     elliptic curve group.
   *
   *     The probability of selecting a bad point is negligible for our applications
   *     where z is very small (e.g. 256) and n is very large (e.g. 2^256).  Thus,
   *     we can simply randomly select the initial accumulator I and the
   *     double-and-add algorithm will succeed with overwhelming probability.
   *)
  let acc, _base =
    List.foldi scalar ~init:(curve.ia.acc, point) (* (acc, base) *)
      ~f:(fun i (acc, base) bit ->
        (* Add: sum = acc + base *)
        let sum = add (module Circuit) external_checks curve acc base in
        (* Bounds 1:
         *   Left input is previous result, so already checked.
         *   Right input is checked by previous doubling check.
         *   Initial acc and base are gadget inputs (checked by caller).
         *   Result bounds check below.
         *)
        Foreign_field.External_checks.append_bound_check external_checks
        @@ Foreign_field.Element.Standard.to_limbs @@ Affine.x sum ;
        Foreign_field.External_checks.append_bound_check external_checks
        @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y sum ;

        (* Group double: double_base = base + base *)
        let double_base =
          match doubles with
          | None ->
              let double_base =
                double (module Circuit) external_checks curve base
              in
              (* Bounds 2:
               *   Input is previous result, so already checked.
               *   Initial base is gadget input (checked by caller).
               *   Result bounds check below.
               *)
              Foreign_field.External_checks.append_bound_check external_checks
              @@ Foreign_field.Element.Standard.to_limbs @@ Affine.x double_base ;
              Foreign_field.External_checks.append_bound_check external_checks
              @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y double_base ;
              double_base
          | Some doubles ->
              (* When the base point is public (e.g. the secp256k1 generator) we can
               * improve performance by having them as precomputed public parameters *)
              doubles.(i)
        in

        (* Group add conditionally *)
        let acc = Affine.if_ (module Circuit) bit ~then_:sum ~else_:acc in

        (acc, double_base) )
  in

  (* Subtract init_point from accumulator for final result *)
  add (module Circuit) external_checks curve acc curve.ia.neg_acc

(* Gadget to check point is in the subgroup
 *   nP = O
 * where n is the elliptic curve group order and O is the point at infinity
 *)
let check_subgroup (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t)
    (curve : f Curve_params.InCircuit.t) ?(doubles : f Affine.t array option)
    (point : f Affine.t) =
  (* Subgroup check: nP = O
   *   We don't support identity element, so instead we check
   *     ((n - 1) + 1)P = O
   *     (n - 1)P = -P
   *)

  (* C1: Compute (n - 1)P *)
  let n_minus_one_point =
    scalar_mul
      (module Circuit)
      external_checks curve ?doubles curve.order_minus_one_bits point
  in
  (* Bounds 1: Left input is public constant (no bounds check required)
   *           Right input is gadget input (checked by caller)
   *           Result bound check below
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.x n_minus_one_point ;
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y n_minus_one_point ;

  (* C2: Compute -P *)
  let minus_point = negate (module Circuit) curve point in
  (* Result row *)
  Foreign_field.result_row (module Circuit) ~label:"minus_point_y"
  @@ Affine.y minus_point ;
  (* Bounds 2: Input is gadget input (checked by caller)
   *           Result bound check below
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y minus_point ;

  (* C3: Assert (n - 1)P = -P *)
  Affine.assert_equal (module Circuit) n_minus_one_point minus_point

(***************)
(* Group tests *)
(***************)

let%test_unit "Ec_group.add" =
  if basic_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group add *)
    let test_add ?cs (curve : Curve_params.t) (left_input : Affine.bignum_point)
        (right_input : Affine.bignum_point)
        (expected_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants (module Runner.Impl) curve
            in
            let left_input =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                left_input
            in
            let right_input =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                right_input
            in
            let expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_result
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* L + R = S *)
            let result =
              add
                (module Runner.Impl)
                unused_external_checks curve left_input right_input
            in

            (* Check for expected quantity of external checks *)
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.bounds 6 ) ;
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.multi_ranges
                3 ) ;
            assert (
              Mina_stdlib.List.Length.equal
                unused_external_checks.compact_multi_ranges 3 ) ;

            (* Check output matches expected result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    result expected_result ) ) ;
            () )
      in

      cs
    in

    (* Tests for random points *)
    let fake_curve5 =
      Curve_params.{ default with modulus = Bignum_bigint.of_int 5 }
    in
    let _cs =
      test_add fake_curve5
        (Bignum_bigint.of_int 4, Bignum_bigint.one) (* left_input *)
        (Bignum_bigint.of_int 0, Bignum_bigint.of_int 3) (* right_input *)
        (Bignum_bigint.of_int 0, Bignum_bigint.of_int 2)
      (* expected result *)
    in
    let _cs =
      test_add fake_curve5
        (Bignum_bigint.of_int 2, Bignum_bigint.of_int 3) (* left_input *)
        (Bignum_bigint.of_int 1, Bignum_bigint.of_int 0) (* right_input *)
        (Bignum_bigint.of_int 1, Bignum_bigint.of_int 0)
      (* expected result *)
    in

    (* Constraint system reuse tests *)
    let fake_curve13 =
      Curve_params.{ default with modulus = Bignum_bigint.of_int 13 }
    in
    let cs =
      test_add fake_curve13
        (Bignum_bigint.of_int 3, Bignum_bigint.of_int 8) (* left_input *)
        (Bignum_bigint.of_int 5, Bignum_bigint.of_int 11) (* right_input *)
        (Bignum_bigint.of_int 4, Bignum_bigint.of_int 10)
      (* expected result *)
    in
    let _cs =
      test_add ~cs fake_curve13
        (Bignum_bigint.of_int 10, Bignum_bigint.of_int 4) (* left_input *)
        (Bignum_bigint.of_int 12, Bignum_bigint.of_int 7) (* right_input *)
        (Bignum_bigint.of_int 3, Bignum_bigint.of_int 0)
      (* expected result *)
    in
    let _cs =
      test_add ~cs fake_curve13
        (Bignum_bigint.of_int 8, Bignum_bigint.of_int 6) (* left_input *)
        (Bignum_bigint.of_int 2, Bignum_bigint.of_int 1) (* right_input *)
        (Bignum_bigint.of_int 12, Bignum_bigint.of_int 8)
      (* expected result *)
    in

    (* Negative tests *)
    let fake_curve9 =
      Curve_params.{ default with modulus = Bignum_bigint.of_int 9 }
    in
    assert (
      Common.is_error (fun () ->
          (* Wrong constraint system (changed modulus) *)
          test_add ~cs fake_curve9
            (Bignum_bigint.of_int 8, Bignum_bigint.of_int 6) (* left_input *)
            (Bignum_bigint.of_int 2, Bignum_bigint.of_int 1) (* right_input *)
            (Bignum_bigint.of_int 12, Bignum_bigint.of_int 8)
          (* expected result *) ) ) ;
    assert (
      Common.is_error (fun () ->
          (* Wrong answer (right modulus) *)
          test_add ~cs fake_curve13
            (Bignum_bigint.of_int 8, Bignum_bigint.of_int 6) (* left_input *)
            (Bignum_bigint.of_int 2, Bignum_bigint.of_int 1) (* right_input *)
            (Bignum_bigint.of_int 12, Bignum_bigint.of_int 9)
          (* expected result *) ) ) ;

    (* Tests with secp256k1 curve points *)
    let random_point1 =
      ( Bignum_bigint.of_string
          "11498799051185379176527662983290644419148625795866197242742376646044820710107"
      , Bignum_bigint.of_string
          "87365548140897354715632623292744880448736648603030553868546115582681395400362"
      )
    in
    let expected_result1 =
      ( Bignum_bigint.of_string
          "29271032301589161601163082898984274448470999636237808164579416118817375265766"
      , Bignum_bigint.of_string
          "70576057075545750224511488165986665682391544714639291167940534165970533739040"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params Secp256k1.params.gen) ;
    assert (is_on_curve_bignum_point Secp256k1.params random_point1) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result1) ;

    let _cs =
      test_add Secp256k1.params random_point1 Secp256k1.params.gen
        expected_result1
    in

    let random_point2 =
      ( Bignum_bigint.of_string
          "112776793647017636286801498409683698782792816810143189200772003475655331235512"
      , Bignum_bigint.of_string
          "37154006933110560524528936279434506593302537023736551486562363002969014272200"
      )
    in
    let expected_result2 =
      ( Bignum_bigint.of_string
          "80919512080552099332189419005806362073658070117780992417768444957631350640350"
      , Bignum_bigint.of_string
          "4839884697531819803579082430572588557482298603278351225895977263486959680227"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params random_point2) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result2) ;

    let _cs =
      test_add Secp256k1.params expected_result1 (* left_input *)
        random_point2 (* right_input *)
        expected_result2
      (* expected result *)
    in

    let random_point3 =
      ( Bignum_bigint.of_string
          "36425953153418322223243576029807183106978427220826420108023201968296177476778"
      , Bignum_bigint.of_string
          "24007339127999344540320969916238304309192480878642453507169699691156248304362"
      )
    in
    let random_point4 =
      ( Bignum_bigint.of_string
          "21639969699195480792170626687481368104641445608975892798617312168630290254356"
      , Bignum_bigint.of_string
          "30444719434143548339668041811488444063562085329168372025420048436035175999301"
      )
    in
    let expected_result3 =
      ( Bignum_bigint.of_string
          "113188224115387667795245114738521133409188389625511152470086031332181459812059"
      , Bignum_bigint.of_string
          "82989616646064102138003387261138741187755389122561858439662322580504431694519"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params random_point3) ;
    assert (is_on_curve_bignum_point Secp256k1.params random_point4) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result3) ;

    let _cs =
      test_add Secp256k1.params random_point3 (* left_input *)
        random_point4 (* right_input *)
        expected_result3
      (* expected result *)
    in

    (* Constraint system reuse tests *)
    let pt1 =
      ( Bignum_bigint.of_string
          "75669526378790147634671888414445173066514756807031971924620136884638031442759"
      , Bignum_bigint.of_string
          "21417425897684876536576718477824646351185804513111016365368704154638046645765"
      )
    in
    let pt2 =
      ( Bignum_bigint.of_string
          "14155322613096941824503892607495280579903778637099750589312382650686697414735"
      , Bignum_bigint.of_string
          "6513771125762614571725090849784101711151222857564970563886992272283710338112"
      )
    in
    let expected_pt =
      ( Bignum_bigint.of_string
          "11234404138675683238798732023399338183955476104311735089175934636931978267582"
      , Bignum_bigint.of_string
          "2483077095355421104741807026372550508534866555013063406887316930008225336894"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params pt1) ;
    assert (is_on_curve_bignum_point Secp256k1.params pt2) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_pt) ;

    let cs = test_add Secp256k1.params pt1 pt2 expected_pt in

    let pt1 =
      ( Bignum_bigint.of_string
          "97313026812541560473771297589757921196424145769025529099070592800256734650744"
      , Bignum_bigint.of_string
          "38700860102018844310665941222140210385381782344695476706452234109902874948789"
      )
    in
    let pt2 =
      ( Bignum_bigint.of_string
          "82416105962835331584090450180444085592428397648594295814088133554696721893017"
      , Bignum_bigint.of_string
          "72361514636959418409520767179749571220723219394228755075988292395103362307597"
      )
    in
    let expected_pt =
      ( Bignum_bigint.of_string
          "63066162743654726673830060769616154872212462240062945169518526070045923596428"
      , Bignum_bigint.of_string
          "54808797958010370431464079583774910620962703868682659560981623451275441505706"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params pt1) ;
    assert (is_on_curve_bignum_point Secp256k1.params pt2) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_pt) ;

    let _cs = test_add ~cs Secp256k1.params pt1 pt2 expected_pt in

    let expected2 =
      ( Bignum_bigint.of_string
          "23989387498834566531803335539224216637656125335573670100510541031866883369583"
      , Bignum_bigint.of_string
          "8780199033752628541949962988447578555155504633890539264032735153636423550500"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params expected2) ;

    let _cs = test_add ~cs Secp256k1.params expected_pt pt1 expected2 in

    (* Negative tests *)
    assert (
      Common.is_error (fun () ->
          (* Wrong constraint system (changed modulus) *)
          test_add ~cs fake_curve9 expected_pt pt1 expected2 ) ) ;

    assert (
      Common.is_error (fun () ->
          (* Wrong result *)
          test_add ~cs Secp256k1.params expected_pt pt1 expected_pt ) ) ;

    (* Test with some real Ethereum curve points *)

    (* Curve point from pubkey of sender of 1st Ethereum transcation
     * https://etherscan.io/tx/0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060
     *)
    let first_eth_tx_pubkey =
      ( Bignum_bigint.of_string
          "25074680562105920500390488848505179172301959433246133200656053822731415560379"
      , Bignum_bigint.of_string
          "40207352835024964935479287038185466710938760823387493786206830664631160762596"
      )
    in
    (* Vb pubkey curve point
     * https://etherscan.io/address/0xab5801a7d398351b8be11c439e05c5b3259aec9b
     *)
    let vitalik_eth_pubkey =
      ( Bignum_bigint.of_string
          "49781623198970027997721070672560275063607048368575198229673025608762959476014"
      , Bignum_bigint.of_string
          "44999051047832679156664607491606359183507784636787036192076848057884504239143"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "5673019186984644139884227978304592898127494693953507135947623290000290975721"
      , Bignum_bigint.of_string
          "63149760798259320533576297417560108418144118481056410815317549443093209180466"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params first_eth_tx_pubkey) ;
    assert (is_on_curve_bignum_point Secp256k1.params vitalik_eth_pubkey) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result) ;

    let _cs =
      test_add ~cs Secp256k1.params first_eth_tx_pubkey vitalik_eth_pubkey
        expected_result
    in

    () )

let%test_unit "Ec_group.add_chained" =
  if basic_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test chained group add *)
    let test_add_chained ?cs ?(chain_left = true) (curve : Curve_params.t)
        (left_input : Affine.bignum_point) (right_input : Affine.bignum_point)
        (input2 : Affine.bignum_point) (expected_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants (module Runner.Impl) curve
            in
            let left_input =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                left_input
            in
            let right_input =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                right_input
            in
            let input2 =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) input2
            in
            let expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_result
            in

            (* Create external checks context for tracking extra constraints
             * that are required for soundness (unused in this test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* L + R = S *)
            let result1 =
              add
                (module Runner.Impl)
                unused_external_checks curve left_input right_input
            in

            let result2 =
              if chain_left then
                (* S + T = U *)
                (* Chain result to left input *)
                add
                  (module Runner.Impl)
                  unused_external_checks curve result1 input2
              else
                (* Chain result to right input *)
                (* T + S = U *)
                add
                  (module Runner.Impl)
                  unused_external_checks curve input2 result1
            in

            (* Check for expected quantity of external checks *)
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.bounds 12 ) ;
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.multi_ranges
                6 ) ;
            assert (
              Mina_stdlib.List.Length.equal
                unused_external_checks.compact_multi_ranges 6 ) ;

            (* Check output matches expected result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    result2 expected_result ) ) ;
            () )
      in

      cs
    in

    (* Group add chaining test *)
    let pt1 =
      ( Bignum_bigint.of_string
          "22078445491128279362564324454450148838521766213873448035670368771866784776689"
      , Bignum_bigint.of_string
          "59164395213226911607629035235242369632135709209315776938135875644072412604417"
      )
    in
    let pt2 =
      ( Bignum_bigint.of_string
          "43363091675487122074415344565583111028231348930161176231597524718735106294021"
      , Bignum_bigint.of_string
          "111622036424234525038201689158418296167019583124308154759441266557529051647503"
      )
    in
    let pt3 =
      ( Bignum_bigint.of_string
          "27095120504150867682043281371962577090258298278269412698577541627879567814209"
      , Bignum_bigint.of_string
          "43319029043781297382854244012410471023426320563005937780035785457494374919933"
      )
    in
    let expected =
      ( Bignum_bigint.of_string
          "94445004776077869359279503733865512156009118507534561304362934747962270973982"
      , Bignum_bigint.of_string
          "5771544338553827547535594828872899427364500537732448576560233867747655654290"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params pt1) ;
    assert (is_on_curve_bignum_point Secp256k1.params pt2) ;
    assert (is_on_curve_bignum_point Secp256k1.params pt3) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected) ;

    (* Correct wiring for left chaining
     *   Result r1 = pt1 + pt2 and left operand of r2 = r1 + pt3
     *
     *     ,--------------------------------------------,
     * x0: `-> (2, 3) -> (4, 3) -> (20, 3) -> (16, 3) ->`
     *          r1x0      r1x0       Lx0        Lx0
     *
     *     ,--------------------------------------------,
     * x1: `-> (2, 4) -> (16, 4) -> (20, 4) -> (4, 4) ->`
     *          r1x1       Lx1        Lx1       r1x1
     *
     *     ,--------------------------------------------,
     * x2: `-> (2, 5) -> (20, 5) -> (4, 5) -> (16, 5) ->`
     *          r1x2       Lx2       r1x2       Lx2
     *
     *     ,------------------------,
     * y0: `-> (11, 3) -> (23, 3) ->`
     *          r1y0        Ly0
     *
     *     ,------------------------,
     * y1: `-> (11, 4) -> (23, 4) ->`
     *          r1y1        Ly1
     *
     *     ,------------------------,
     * y2: `-> (11, 5) -> (23, 5) ->`
     *          r1y2        Ly2
     *)
    let _cs = test_add_chained Secp256k1.params pt1 pt2 pt3 expected in

    (* Correct wiring for right chaining
     *   Result r1 = pt1 + pt2 and right operand of r2 = pt3 + r1
     *
     *     ,-------------------------------------------,
     * x0: `-> (2, 3) -> (17, 0) -> (4, 3) -> (20, 0) /
     *          r1x0       Rx0       r1x0       Rx0
     *
     *     ,-------------------------------------------,
     * x1: `-> (2, 4) -> (17, 1) -> (20, 1) -> (4, 4) /
     *          r1x1       Rx1        Rx1       r1x1
     *
     *     ,-------------------------------------------,
     * x2: `-> (2, 5) -> (4, 5) -> (17, 2) -> (20, 2) /
     *          r1x2      r1x2       Rx2        Rx2
     *
     *     ,------------------------,
     * y0: `-> (11, 3) -> (24, 0) ->`
     *          r1y0        Ry0
     *
     *     ,------------------------,
     * y1: `-> (11, 4) -> (24, 1) ->`
     *          r1y1        Ry1
     *
     *     ,------------------------,
     * y2: `-> (11, 5) -> (24, 2) ->`
     *          r1y2        Ry2
     *)
    let _cs =
      test_add_chained ~chain_left:false Secp256k1.params pt1 (* left_input *)
        pt2 (* right_input *)
        pt3 (* input2 *)
        expected
      (* expected result *)
    in
    () )

let%test_unit "Ec_group.add_full" =
  if basic_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test full group add (with bounds cehcks) *)
    let test_add_full ?cs (curve : Curve_params.t)
        (left_input : Affine.bignum_point) (right_input : Affine.bignum_point)
        (expected_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants (module Runner.Impl) curve
            in
            let left_input =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                left_input
            in
            let right_input =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                right_input
            in
            let expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_result
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness *)
            let external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* L + R = S *)
            let result =
              add
                (module Runner.Impl)
                external_checks curve left_input right_input
            in

            (* Add left_input to external checks *)
            Foreign_field.(
              External_checks.append_bound_check external_checks
              @@ Element.Standard.to_limbs @@ Affine.x left_input) ;
            Foreign_field.(
              External_checks.append_bound_check external_checks
              @@ Element.Standard.to_limbs @@ Affine.y left_input) ;

            (* Add right_input to external checks *)
            Foreign_field.(
              External_checks.append_bound_check external_checks
              @@ Element.Standard.to_limbs @@ Affine.x right_input) ;
            Foreign_field.(
              External_checks.append_bound_check external_checks
              @@ Element.Standard.to_limbs @@ Affine.y right_input) ;

            (* Add result to external checks *)
            Foreign_field.(
              External_checks.append_bound_check external_checks
              @@ Element.Standard.to_limbs @@ Affine.x result) ;
            Foreign_field.(
              External_checks.append_bound_check external_checks
              @@ Element.Standard.to_limbs @@ Affine.y result) ;

            (* Check output matches expected result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    result expected_result ) ) ;

            (*
             * Perform external checks
             *)
            assert (Mina_stdlib.List.Length.equal external_checks.bounds 12) ;
            assert (Mina_stdlib.List.Length.equal external_checks.multi_ranges 3) ;
            assert (
              Mina_stdlib.List.Length.equal external_checks.compact_multi_ranges
                3 ) ;
            (* Add gates for bound checks, multi-range-checks and compact-multi-range-checks *)
            Foreign_field.constrain_external_checks
              (module Runner.Impl)
              external_checks curve.modulus ;

            () )
      in
      cs
    in

    (* Full tests *)
    let pt1 =
      ( Bignum_bigint.of_string
          "108106717441068942935036481412556424456551432537879152449804306833272168535105"
      , Bignum_bigint.of_string
          "76460339884983741488305111710326981694475523676336423409829095132008854584808"
      )
    in
    let pt2 =
      ( Bignum_bigint.of_string
          "6918332104414828558125020939363051148342349799951368824506926403525772818971"
      , Bignum_bigint.of_string
          "112511987857588994657806651103271803396616867673371823390960630078201657435176"
      )
    in
    let expected =
      ( Bignum_bigint.of_string
          "87351883076573600335277375022118065102135008483181597654369109297980597321941"
      , Bignum_bigint.of_string
          "42323967499650833993389664859011147254281400152806022789809987122536303627261"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params pt1) ;
    assert (is_on_curve_bignum_point Secp256k1.params pt2) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected) ;

    let _cs =
      test_add_full Secp256k1.params pt1 (* left_input *)
        pt2 (* right_input *)
        expected
      (* expected result *)
    in

    () )

let%test_unit "Ec_group.double" =
  if basic_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group double *)
    let test_double ?cs (curve : Curve_params.t) (point : Affine.bignum_point)
        (expected_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants (module Runner.Impl) curve
            in
            let point =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point
            in
            let expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_result
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* P + P = D *)
            let result =
              double (module Runner.Impl) unused_external_checks curve point
            in

            (* Check for expected quantity of external checks *)
            if Bignum_bigint.(curve.bignum.a = zero) then
              assert (
                Mina_stdlib.List.Length.equal unused_external_checks.bounds 8 )
            else
              assert (
                Mina_stdlib.List.Length.equal unused_external_checks.bounds 9 ) ;
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.multi_ranges
                4 ) ;
            assert (
              Mina_stdlib.List.Length.equal
                unused_external_checks.compact_multi_ranges 4 ) ;

            (* Check output matches expected result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    result expected_result ) ) ;
            () )
      in

      cs
    in

    (* Test with elliptic curve y^2 = x^3 + 2 * x + 5 mod 13 *)
    let _cs =
      let fake_curve1 =
        Curve_params.
          { default with
            modulus = Bignum_bigint.of_int 13
          ; a = Bignum_bigint.of_int 2
          ; b = Bignum_bigint.of_int 5
          }
      in
      let point = (Bignum_bigint.of_int 2, Bignum_bigint.of_int 2) in
      let expected_result = (Bignum_bigint.of_int 5, Bignum_bigint.of_int 7) in
      assert (is_on_curve_bignum_point fake_curve1 point) ;
      assert (is_on_curve_bignum_point fake_curve1 expected_result) ;
      test_double fake_curve1 point expected_result
    in

    (* Test with elliptic curve y^2 = x^3 + 5 mod 13 *)
    let _cs =
      let fake_curve2 =
        Curve_params.
          { default with
            modulus = Bignum_bigint.of_int 13
          ; b = Bignum_bigint.of_int 5
          }
      in
      let point = (Bignum_bigint.of_int 4, Bignum_bigint.of_int 2) in
      let expected_result = (Bignum_bigint.of_int 6, Bignum_bigint.of_int 0) in
      assert (is_on_curve_bignum_point fake_curve2 point) ;
      assert (is_on_curve_bignum_point fake_curve2 expected_result) ;
      test_double fake_curve2 point expected_result
    in

    (* Test with elliptic curve y^2 = x^3 + 7 mod 13 *)
    let fake_curve0 =
      Curve_params.
        { default with
          modulus = Bignum_bigint.of_int 13
        ; b = Bignum_bigint.of_int 7
        }
    in
    let cs0 =
      let point = (Bignum_bigint.of_int 7, Bignum_bigint.of_int 8) in
      let expected_result = (Bignum_bigint.of_int 8, Bignum_bigint.of_int 8) in
      assert (is_on_curve_bignum_point fake_curve0 point) ;
      assert (is_on_curve_bignum_point fake_curve0 expected_result) ;
      let cs = test_double fake_curve0 point expected_result in
      let _cs = test_double fake_curve0 point expected_result in
      cs
    in

    (* Test with elliptic curve y^2 = x^3 + 17 * x mod 7879 *)
    let fake_curve17 =
      Curve_params.
        { default with
          modulus = Bignum_bigint.of_int 7879
        ; a = Bignum_bigint.of_int 17
        }
    in
    let cs17 =
      let point = (Bignum_bigint.of_int 7331, Bignum_bigint.of_int 888) in
      let expected_result =
        (Bignum_bigint.of_int 2754, Bignum_bigint.of_int 3623)
      in
      assert (is_on_curve_bignum_point fake_curve17 point) ;
      assert (is_on_curve_bignum_point fake_curve17 expected_result) ;
      test_double fake_curve17 point expected_result
    in

    (* Constraint system reuse tests *)
    let _cs =
      let point = (Bignum_bigint.of_int 8, Bignum_bigint.of_int 8) in
      let expected_result = (Bignum_bigint.of_int 11, Bignum_bigint.of_int 8) in
      assert (is_on_curve_bignum_point fake_curve0 point) ;
      assert (is_on_curve_bignum_point fake_curve0 expected_result) ;
      test_double ~cs:cs0 fake_curve0 point expected_result
    in

    let _cs =
      let point = (Bignum_bigint.of_int 1729, Bignum_bigint.of_int 4830) in
      let expected_result =
        (Bignum_bigint.of_int 6020, Bignum_bigint.of_int 5832)
      in
      assert (is_on_curve_bignum_point fake_curve17 point) ;
      assert (is_on_curve_bignum_point fake_curve17 expected_result) ;
      let _cs = test_double ~cs:cs17 fake_curve17 point expected_result in

      (* Negative test *)
      assert (
        Common.is_error (fun () ->
            (* Wrong constraint system *)
            test_double ~cs:cs0 fake_curve17 point expected_result ) ) ;
      _cs
    in

    (* Tests with secp256k1 curve points *)
    let point =
      ( Bignum_bigint.of_string
          "107002484780363838095534061209472738804517997328105554367794569298664989358181"
      , Bignum_bigint.of_string
          "92879551684948148252506282887871578114014191438980334462241462418477012406178"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "74712964529040634650603708923084871318006229334056222485473734005356559517441"
      , Bignum_bigint.of_string
          "115267803285637743262834568062293432343366237647730050692079006689357117890542"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params point) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result) ;

    let _cs = test_double Secp256k1.params point expected_result in

    let expected_result =
      ( Bignum_bigint.of_string
          "89565891926547004231252920425935692360644145829622209833684329913297188986597"
      , Bignum_bigint.of_string
          "12158399299693830322967808612713398636155367887041628176798871954788371653930"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params Secp256k1.params.gen) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result) ;

    let _cs =
      test_double Secp256k1.params Secp256k1.params.gen expected_result
    in

    let point =
      ( Bignum_bigint.of_string
          "72340565915695963948758748585975158634181237057659908187426872555266933736285"
      , Bignum_bigint.of_string
          "26612022505003328753510360357395054342310218908477055087761596777225815854353"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "108904232316543774780790055701972437888102004393747607639914151522482739421637"
      , Bignum_bigint.of_string
          "12361022197403188621809379658301822420116828257004558379520642349031207949605"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params point) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result) ;

    let _cs = test_double Secp256k1.params point expected_result in

    let point =
      ( Bignum_bigint.of_string
          "108904232316543774780790055701972437888102004393747607639914151522482739421637"
      , Bignum_bigint.of_string
          "12361022197403188621809379658301822420116828257004558379520642349031207949605"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "6412514063090203022225668498768852033918664033020116827066881895897922497918"
      , Bignum_bigint.of_string
          "46730676600197705465960490527225757352559615957463874893868944815778370642915"
      )
    in
    assert (is_on_curve_bignum_point Secp256k1.params point) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result) ;

    let cs = test_double Secp256k1.params point expected_result in

    (* CS reuse again*)
    let point =
      ( Bignum_bigint.of_string
          "3994127195658013268703905225007935609302368792888634855477505418126918261961"
      , Bignum_bigint.of_string
          "25535899907968670181603106060653290873698485840006655398881908734054954693109"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "85505889528097925687832670439248941652336655858213625210338216314923495678594"
      , Bignum_bigint.of_string
          "49191910521103183437466384378802260055879125327516949990516385020354020159575"
      )
    in
    assert (is_on_curve_bignum_point Secp256k1.params point) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result) ;

    let _cs = test_double ~cs Secp256k1.params point expected_result in

    (* Negative tests *)
    assert (
      Common.is_error (fun () ->
          (* Wrong constraint system *)
          test_double ~cs:cs0 Secp256k1.params point expected_result ) ) ;

    assert (
      Common.is_error (fun () ->
          (* Wrong answer *)
          let wrong_result =
            ( Bignum_bigint.of_string
                "6412514063090203022225668498768852033918664033020116827066881895897922497918"
            , Bignum_bigint.of_string
                "46730676600197705465960490527225757352559615957463874893868944815778370642914"
            )
          in
          test_double Secp256k1.params point wrong_result ) ) ;

    () )

let%test_unit "Ec_group.double_chained" =
  if basic_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group double chaining *)
    let test_double_chained ?cs (curve : Curve_params.t)
        (point : Affine.bignum_point) (expected_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants (module Runner.Impl) curve
            in
            let point =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point
            in
            let expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_result
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            let result =
              double (module Runner.Impl) unused_external_checks curve point
            in
            let result =
              double (module Runner.Impl) unused_external_checks curve result
            in

            (* Check for expected quantity of external checks *)
            if Bignum_bigint.(curve.bignum.a = zero) then
              assert (
                Mina_stdlib.List.Length.equal unused_external_checks.bounds 16 )
            else
              assert (
                Mina_stdlib.List.Length.equal unused_external_checks.bounds 18 ) ;
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.multi_ranges
                8 ) ;
            assert (
              Mina_stdlib.List.Length.equal
                unused_external_checks.compact_multi_ranges 8 ) ;

            (* Check output matches expected result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    result expected_result ) ) ;
            () )
      in

      cs
    in

    let _cs =
      let fake_curve0 =
        Curve_params.
          { default with
            modulus = Bignum_bigint.of_int 7879
          ; a = Bignum_bigint.of_int 17
          }
      in
      let point = (Bignum_bigint.of_int 1729, Bignum_bigint.of_int 4830) in
      let expected_result =
        (Bignum_bigint.of_int 355, Bignum_bigint.of_int 3132)
      in
      assert (is_on_curve_bignum_point fake_curve0 point) ;
      assert (is_on_curve_bignum_point fake_curve0 expected_result) ;
      test_double_chained fake_curve0 point expected_result
    in

    let point =
      ( Bignum_bigint.of_string
          "42044065574201065781794313442437176970676726666507255383911343977315911214824"
      , Bignum_bigint.of_string
          "31965905005059593108764147692698952070443290622957461138987132030153087962524"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "25296422933760701668354080561191268087967569090553018544803607419093394376171"
      , Bignum_bigint.of_string
          "8046470730121032635013615006105175410553103561598164661406103935504325838485"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params point) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result) ;

    let _cs = test_double_chained Secp256k1.params point expected_result in
    () )

let%test_unit "Ec_group.double_full" =
  if basic_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group double (full circuit with external checks) *)
    let test_double_full ?cs (curve : Curve_params.t)
        (point : Affine.bignum_point) (expected_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants (module Runner.Impl) curve
            in
            let point =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point
            in
            let expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_result
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness *)
            let external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* P + P = D *)
            let result =
              double (module Runner.Impl) external_checks curve point
            in

            (* Add input point to external checks *)
            Foreign_field.(
              External_checks.append_bound_check external_checks
              @@ Element.Standard.to_limbs @@ Affine.x point) ;
            Foreign_field.(
              External_checks.append_bound_check external_checks
              @@ Element.Standard.to_limbs @@ Affine.y point) ;

            (* Add result to external checks *)
            Foreign_field.(
              External_checks.append_bound_check external_checks
              @@ Element.Standard.to_limbs @@ Affine.x result) ;
            Foreign_field.(
              External_checks.append_bound_check external_checks
              @@ Element.Standard.to_limbs @@ Affine.y result) ;

            (* Check output matches expected result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    result expected_result ) ) ;

            (*
             * Perform external checks
             *)

            (* Sanity checks *)
            if Bignum_bigint.(curve.bignum.a = zero) then
              assert (Mina_stdlib.List.Length.equal external_checks.bounds 12)
            else assert (Mina_stdlib.List.Length.equal external_checks.bounds 13) ;
            assert (Mina_stdlib.List.Length.equal external_checks.multi_ranges 4) ;
            assert (
              Mina_stdlib.List.Length.equal external_checks.compact_multi_ranges
                4 ) ;

            (* Add gates for bound checks, multi-range-checks and compact-multi-range-checks *)
            Foreign_field.constrain_external_checks
              (module Runner.Impl)
              external_checks curve.modulus ;

            () )
      in

      cs
    in

    let point =
      ( Bignum_bigint.of_string
          "422320656143453469357911138554881092132771509739438645920469442837105323580"
      , Bignum_bigint.of_string
          "99573693339481125202377937570343422789783140695684047090890158240546390265715"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "111592986473580724183094323045895279290564238712238558254671818420787861656338"
      , Bignum_bigint.of_string
          "21999887286188040786039896471521925680577344653927821650184541049020329991940"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params point) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result) ;

    let _cs = test_double_full Secp256k1.params point expected_result in

    let point =
      ( Bignum_bigint.of_string
          "35572202113406269203741773940276421270986156279943921117631530910348880407195"
      , Bignum_bigint.of_string
          "77949858788528057664678921426007070786227653051729292366956150514299227362888"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "77054343462981168852324254689119448477035493875004605555517034503407691682302"
      , Bignum_bigint.of_string
          "71816304404296379298724767646016383731405297016881176644824032740912066853658"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params point) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result) ;

    let _cs = test_double_full Secp256k1.params point expected_result in

    () )

let%test_unit "Ec_group.ops_mixed" =
  if basic_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test mix of group operations (e.g. things are wired correctly *)
    let test_group_ops_mixed ?cs (curve : Curve_params.t)
        (left_input : Affine.bignum_point) (right_input : Affine.bignum_point)
        (expected_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants (module Runner.Impl) curve
            in
            let left_input =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                left_input
            in
            let right_input =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                right_input
            in
            let expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_result
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* R + L = S *)
            let sum =
              add
                (module Runner.Impl)
                unused_external_checks curve left_input right_input
            in

            (* S + S = D *)
            let double =
              double (module Runner.Impl) unused_external_checks curve sum
            in

            (* Check for expected quantity of external checks *)
            if Bignum_bigint.(curve.bignum.a = zero) then
              assert (
                Mina_stdlib.List.Length.equal unused_external_checks.bounds 14 )
            else
              assert (
                Mina_stdlib.List.Length.equal unused_external_checks.bounds 15 ) ;
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.multi_ranges
                7 ) ;
            assert (
              Mina_stdlib.List.Length.equal
                unused_external_checks.compact_multi_ranges 7 ) ;

            (* Check output matches expected result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    double expected_result ) ) ;
            () )
      in

      cs
    in

    let _cs =
      let fake_curve =
        Curve_params.
          { default with
            modulus = Bignum_bigint.of_int 7879
          ; a = Bignum_bigint.of_int 17
          }
      in
      let point1 = (Bignum_bigint.of_int 1729, Bignum_bigint.of_int 4830) in
      let point2 = (Bignum_bigint.of_int 993, Bignum_bigint.of_int 622) in
      let expected_result =
        (Bignum_bigint.of_int 6762, Bignum_bigint.of_int 4635)
      in
      assert (is_on_curve_bignum_point fake_curve point1) ;
      assert (is_on_curve_bignum_point fake_curve point2) ;
      assert (is_on_curve_bignum_point fake_curve expected_result) ;

      test_group_ops_mixed fake_curve point1 point2 expected_result
    in

    let point1 =
      ( Bignum_bigint.of_string
          "37404488720929062958906788322651728322575666040491554170565829193307192693651"
      , Bignum_bigint.of_string
          "9656313713772632982161856264262799630428732532087082991934556488549329780427"
      )
    in
    let point2 =
      ( Bignum_bigint.of_string
          "31293985021118266786561893156019691372812643656725598796588178883202613100468"
      , Bignum_bigint.of_string
          "62519749065576060946018142578164411421793328932510041279923944104940749401503"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "43046886127279816590953923378970473409794361644471707353489087385548452456295"
      , Bignum_bigint.of_string
          "67554760054687646408788973635096250584575090419180209042279187069048864087921"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params point1) ;
    assert (is_on_curve_bignum_point Secp256k1.params point2) ;
    assert (is_on_curve_bignum_point Secp256k1.params expected_result) ;

    let _cs =
      test_group_ops_mixed Secp256k1.params point1 point2 expected_result
    in
    () )

let%test_unit "Ec_group.properties" =
  if basic_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group properties *)
    let test_group_properties ?cs (curve : Curve_params.t)
        (point_a : Affine.bignum_point) (point_b : Affine.bignum_point)
        (point_c : Affine.bignum_point)
        (expected_commutative_result : Affine.bignum_point)
        (expected_associative_result : Affine.bignum_point)
        (expected_distributive_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants (module Runner.Impl) curve
            in
            let point_a =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point_a
            in
            let point_b =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point_b
            in
            let point_c =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point_c
            in
            let expected_commutative_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_commutative_result
            in
            let expected_associative_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_associative_result
            in
            let expected_distributive_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_distributive_result
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (*
             * Commutative property tests
             *
             *     A + B = B + A
             *)
            let a_plus_b =
              (* A + B *)
              add
                (module Runner.Impl)
                unused_external_checks curve point_a point_b
            in

            let b_plus_a =
              (* B + A *)
              add
                (module Runner.Impl)
                unused_external_checks curve point_b point_a
            in

            (* Todo add equality wiring *)
            (* Assert A + B = B + A *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover (module Runner.Impl) a_plus_b b_plus_a ) ) ;

            (* Assert A + B = expected_commutative_result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    a_plus_b expected_commutative_result ) ) ;

            (*
             * Associativity property tests
             *
             *     (A + B) + C = A + (B + C)
             *)
            let b_plus_c =
              (* B + C *)
              add
                (module Runner.Impl)
                unused_external_checks curve point_b point_c
            in

            let a_plus_b_plus_c =
              (* (A + B) + C *)
              add
                (module Runner.Impl)
                unused_external_checks curve a_plus_b point_c
            in

            let b_plus_c_plus_a =
              (* A + (B + C) *)
              add
                (module Runner.Impl)
                unused_external_checks curve point_a b_plus_c
            in

            (* Assert (A + B) + C = A + (B + C) *)
            Affine.assert_equal
              (module Runner.Impl)
              a_plus_b_plus_c b_plus_c_plus_a ;
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    a_plus_b_plus_c b_plus_c_plus_a ) ) ;

            (* Assert A + B = expected_commutative_result *)
            Affine.assert_equal
              (module Runner.Impl)
              a_plus_b_plus_c expected_associative_result ;
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    a_plus_b_plus_c expected_associative_result ) ) ;

            (*
             * Distributive property tests
             *
             *     2 * (A + B) = 2 * A + 2 * B
             *)
            let double_of_sum =
              (* 2 * (A + B) *)
              double (module Runner.Impl) unused_external_checks curve a_plus_b
            in

            let double_a =
              (* 2 * A *)
              double (module Runner.Impl) unused_external_checks curve point_a
            in

            let double_b =
              (* 2 * B *)
              double (module Runner.Impl) unused_external_checks curve point_b
            in

            let sum_of_doubles =
              (* 2 * A + 2 * B *)
              add
                (module Runner.Impl)
                unused_external_checks curve double_a double_b
            in

            (* Assert 2 * (A + B) = 2 * A + 2 * B *)
            Affine.assert_equal
              (module Runner.Impl)
              double_of_sum sum_of_doubles ;
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    double_of_sum sum_of_doubles ) ) ;

            (* Assert 2 * (A + B) = expected_distributive_result *)
            Affine.assert_equal
              (module Runner.Impl)
              double_of_sum expected_distributive_result ;
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    double_of_sum expected_distributive_result ) ) ;
            () )
      in

      cs
    in

    (* Test with secp256k1 curve *)
    let point_a =
      ( Bignum_bigint.of_string
          "104139740379639537914620141697889522643195068624996157573145175343741564772195"
      , Bignum_bigint.of_string
          "24686993868898088086788882517246409097753788695591891584026176923146938009248"
      )
    in
    let point_b =
      ( Bignum_bigint.of_string
          "36743784007303620043843440776745227903854397846775577839885696093428264537689"
      , Bignum_bigint.of_string
          "37572687997781202307536515813734773072395389211771147301250986255900442183367"
      )
    in
    let point_c =
      ( Bignum_bigint.of_string
          "49696436312078070273833592624394555921078337653960324106519507173094660966846"
      , Bignum_bigint.of_string
          "8233980127281521579593600770666525234073102501648621450313070670075221490597"
      )
    in
    let expected_commutative_result =
      (* A + B *)
      ( Bignum_bigint.of_string
          "82115184826944281192212047494549730220285137025844635077989275753462094545317"
      , Bignum_bigint.of_string
          "65806312870411158102677100909644698935674071740730856487954465264167266803940"
      )
    in
    let expected_associative_result =
      (* A + B + C *)
      ( Bignum_bigint.of_string
          "32754193298666340516904674847278729692077935996237244820399615298932008086168"
      , Bignum_bigint.of_string
          "98091569220567533408383096211571578494419313923145170353903484742714309353581"
      )
    in
    (* 2* (A + B) *)
    let expected_distributive_result =
      ( Bignum_bigint.of_string
          "92833221040863134022467437260311951512477869225271942781021131905899386232859"
      , Bignum_bigint.of_string
          "88875130971526456079808346479572776785614636860343295137331156710761285100759"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params point_a) ;
    assert (is_on_curve_bignum_point Secp256k1.params point_b) ;
    assert (is_on_curve_bignum_point Secp256k1.params point_c) ;
    assert (
      is_on_curve_bignum_point Secp256k1.params expected_commutative_result ) ;
    assert (
      is_on_curve_bignum_point Secp256k1.params expected_associative_result ) ;
    assert (
      is_on_curve_bignum_point Secp256k1.params expected_distributive_result ) ;

    let _cs =
      test_group_properties Secp256k1.params point_a point_b point_c
        expected_commutative_result expected_associative_result
        expected_distributive_result
    in

    (*
     * Test with NIST P-224 curve
     *     y^2 = x^3 -3 * x + 18958286285566608000408668544493926415504680968679321075787234672564
     *)
    let p224_curve =
      Curve_params.
        { default with
          modulus =
            Bignum_bigint.of_string
              "0xffffffffffffffffffffffffffffffff000000000000000000000001"
        ; a =
            (* - 3 *)
            Bignum_bigint.of_string
              "0xfffffffffffffffffffffffffffffffefffffffffffffffffffffffe"
            (* Note: p224 a_param < vesta_modulus *)
        ; b =
            (* 18958286285566608000408668544493926415504680968679321075787234672564 *)
            Bignum_bigint.of_string
              "0xb4050a850c04b3abf54132565044b0b7d7bfd8ba270b39432355ffb4"
        }
    in

    let point_a =
      ( Bignum_bigint.of_string
          "20564182195513988720077877094445678909500371329094056390559170498601"
      , Bignum_bigint.of_string
          "2677931089606376366731934050370502738338362171950142296573730478996"
      )
    in
    let point_b =
      ( Bignum_bigint.of_string
          "15331822097908430690332647239357533892026967275700588538504771910797"
      , Bignum_bigint.of_string
          "4049755097518382314285232898392449281690500011901831745754040069555"
      )
    in
    let point_c =
      ( Bignum_bigint.of_string
          "25082387259758106010480779115787834869202362152205819097823199674591"
      , Bignum_bigint.of_string
          "5836788343546154757468239805956174785568118741436223437725908467573"
      )
    in
    let expected_commutative_result =
      (* A + B *)
      ( Bignum_bigint.of_string
          "7995206472745921825893910722935139765985673196416788824369950333191"
      , Bignum_bigint.of_string
          "8265737252928447574971649463676620963677557474048291412774437728538"
      )
    in
    let expected_associative_result =
      (* A + B + C *)
      ( Bignum_bigint.of_string
          "3257699169520051230744895047894307554057883749899622226174209882724"
      , Bignum_bigint.of_string
          "7231957109409135332430424812410043083405298563323557216003172539215"
      )
    in
    (* 2 * (A + B) *)
    let expected_distributive_result =
      ( Bignum_bigint.of_string
          "12648120179660537445264809843313333879121180184951710403373354501995"
      , Bignum_bigint.of_string
          "130351274476047354152272911484022089680853927680837325730785745821"
      )
    in
    assert (is_on_curve_bignum_point p224_curve point_a) ;
    assert (is_on_curve_bignum_point p224_curve point_b) ;
    assert (is_on_curve_bignum_point p224_curve point_c) ;
    assert (is_on_curve_bignum_point p224_curve expected_commutative_result) ;
    assert (is_on_curve_bignum_point p224_curve expected_associative_result) ;
    assert (is_on_curve_bignum_point p224_curve expected_distributive_result) ;

    let _cs =
      test_group_properties p224_curve point_a point_b point_c
        expected_commutative_result expected_associative_result
        expected_distributive_result
    in

    (*
     * Test with bn254 curve
     *     y^2 = x^3 + 0 * x + 2
     *)
    let bn254_curve =
      Curve_params.
        { default with
          modulus =
            Bignum_bigint.of_string
              "16798108731015832284940804142231733909889187121439069848933715426072753864723"
        ; a = Bignum_bigint.of_int 0
        ; b = Bignum_bigint.of_int 2
        }
    in

    let point_a =
      ( Bignum_bigint.of_string
          "7489139758950854827551487063927077939563321761044181276420624792983052878185"
      , Bignum_bigint.of_string
          "2141496180075348025061594016907544139242551437114964865155737156269728330559"
      )
    in
    let point_b =
      ( Bignum_bigint.of_string
          "9956514278304933003335636627606783773825106169180128855351756770342193930117"
      , Bignum_bigint.of_string
          "1762095167736644705377345502398082775379271270251951679097189107067141702434"
      )
    in
    let point_c =
      ( Bignum_bigint.of_string
          "15979993511612396332695593711346186397534040520881664680241489873512193259980"
      , Bignum_bigint.of_string
          "10163302455117602785156120251106605625181898385895334763785764107729313787391"
      )
    in
    let expected_commutative_result =
      (* A + B *)
      ( Bignum_bigint.of_string
          "13759678784866515747881317697821131633872329198354290325517257690138811932261"
      , Bignum_bigint.of_string
          "4040037229868341675068324615541961445935091050207890024311587166409180676332"
      )
    in
    let expected_associative_result =
      (* A + B + C *)
      ( Bignum_bigint.of_string
          "16098676871974911854784905872738346730775870232298829667865365025475731380192"
      , Bignum_bigint.of_string
          "12574401007382321193248731381385712204251317924015127170657534965607164101869"
      )
    in
    (* 2 * (A + B) *)
    let expected_distributive_result =
      ( Bignum_bigint.of_string
          "9395314037281443688092936149000099903064729021023078772338895863158377429106"
      , Bignum_bigint.of_string
          "14218226539011623427628171089944499674924086623747284955166459983416867234215"
      )
    in
    assert (is_on_curve_bignum_point bn254_curve point_a) ;
    assert (is_on_curve_bignum_point bn254_curve point_b) ;
    assert (is_on_curve_bignum_point bn254_curve point_c) ;
    assert (is_on_curve_bignum_point bn254_curve expected_commutative_result) ;
    assert (is_on_curve_bignum_point bn254_curve expected_associative_result) ;
    assert (is_on_curve_bignum_point bn254_curve expected_distributive_result) ;

    let _cs =
      test_group_properties bn254_curve point_a point_b point_c
        expected_commutative_result expected_associative_result
        expected_distributive_result
    in

    (*
     * Test with (Pasta) Pallas curve (on Vesta native)
     *     y^2 = x^3 + 5
     *)
    let pallas_curve =
      Curve_params.
        { default with
          modulus =
            Bignum_bigint.of_string
              "28948022309329048855892746252171976963363056481941560715954676764349967630337"
        ; a = Bignum_bigint.of_int 0
        ; b = Bignum_bigint.of_int 5
        }
    in

    let point_a =
      ( Bignum_bigint.of_string
          "3687554385661875988153708668118568350801595287403286241588941623974773451174"
      , Bignum_bigint.of_string
          "4125300560830971348224390975663473429075828688503632065713036496032796088150"
      )
    in
    let point_b =
      ( Bignum_bigint.of_string
          "13150688393980970390008393861087383374732464068960495642594966124646063172404"
      , Bignum_bigint.of_string
          "2084472543720136255281934655991399553143524556330848293815942786297013884533"
      )
    in
    let point_c =
      ( Bignum_bigint.of_string
          "26740989696982304482414554371640280045791606641637898228291292575942109454805"
      , Bignum_bigint.of_string
          "14906024627800344780747375705291059367428823794643427263104879621768813059138"
      )
    in
    let expected_commutative_result =
      (* A + B *)
      ( Bignum_bigint.of_string
          "11878681988771676869370724830611253729756170947285460876552168044614948225457"
      , Bignum_bigint.of_string
          "14497133356854845193720136968564933709713968802446650329644811738138289288792"
      )
    in
    let expected_associative_result =
      (* A + B + C *)
      ( Bignum_bigint.of_string
          "8988194870545558903676114324437227470798902472195505563098874771184576333284"
      , Bignum_bigint.of_string
          "2715074574400479059415686517976976756653616385004805753779147804207672517454"
      )
    in
    (* 2 * (A + B) *)
    let expected_distributive_result =
      ( Bignum_bigint.of_string
          "5858337972845412034234591451268195730728808894992644330419904703508222498795"
      , Bignum_bigint.of_string
          "7758708768756582293117808728373210197717986974150537098853332332749930840785"
      )
    in
    assert (is_on_curve_bignum_point pallas_curve point_a) ;
    assert (is_on_curve_bignum_point pallas_curve point_b) ;
    assert (is_on_curve_bignum_point pallas_curve point_c) ;
    assert (is_on_curve_bignum_point pallas_curve expected_commutative_result) ;
    assert (is_on_curve_bignum_point pallas_curve expected_associative_result) ;
    assert (is_on_curve_bignum_point pallas_curve expected_distributive_result) ;

    let _cs =
      test_group_properties pallas_curve point_a point_b point_c
        expected_commutative_result expected_associative_result
        expected_distributive_result
    in

    () )

(*******************************)
(* Scalar multiplication tests *)
(*******************************)

let%test_unit "Ec_group.is_on_curve" =
  if scalar_mul_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test is_on_curve *)
    let test_is_on_curve ?cs (curve : Curve_params.t)
        (point : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants
                (module Runner.Impl)
                curve ~use_precomputed_gen_doubles:false
            in
            let point =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Check point is on elliptic curve *)
            is_on_curve (module Runner.Impl) unused_external_checks curve point ;

            (* Check for expected quantity of external checks *)
            let bound_checks_count = ref 3 in
            if not Bignum_bigint.(curve.bignum.a = zero) then
              bound_checks_count := !bound_checks_count + 1 ;
            if not Bignum_bigint.(curve.bignum.b = zero) then
              bound_checks_count := !bound_checks_count + 1 ;
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.bounds
                !bound_checks_count ) ;
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.multi_ranges
                3 ) ;
            assert (
              Mina_stdlib.List.Length.equal
                unused_external_checks.compact_multi_ranges 3 ) ;
            () )
      in

      cs
    in

    (* Positive tests *)
    let _cs = test_is_on_curve Secp256k1.params Secp256k1.params.gen in

    let good_pt =
      ( Bignum_bigint.of_string
          "18950551679048287927361677965259288422489066940346827203675447914841748996155"
      , Bignum_bigint.of_string
          "47337572658241658062145739798014345835092764795141449413289521900680935648400"
      )
    in
    let _cs = test_is_on_curve Secp256k1.params good_pt in
    let neg_good_pt =
      let x, y = good_pt in
      (x, Bignum_bigint.((zero - y) % Secp256k1.params.modulus))
    in
    let _cs = test_is_on_curve Secp256k1.params neg_good_pt in

    (* Test with y^2 = x^3 -3 * x + 18958286285566608000408668544493926415504680968679321075787234672564 *)
    let curve_p224 =
      Curve_params.
        { default with
          modulus =
            Bignum_bigint.of_string
              "0xffffffffffffffffffffffffffffffff000000000000000000000001"
            (* ; order = Bignum_bigint.one *)
        ; a =
            Bignum_bigint.of_string
              "0xfffffffffffffffffffffffffffffffefffffffffffffffffffffffe"
        ; b =
            Bignum_bigint.of_string
              "18958286285566608000408668544493926415504680968679321075787234672564"
        }
    in

    let point =
      ( Bignum_bigint.of_string
          "20564182195513988720077877094445678909500371329094056390559170498601"
      , Bignum_bigint.of_string
          "2677931089606376366731934050370502738338362171950142296573730478996"
      )
    in
    assert (is_on_curve_bignum_point curve_p224 point) ;
    let _cs = test_is_on_curve curve_p224 point in

    (* Test with elliptic curve y^2 = x^3 + 17 * x mod 7879 *)
    let curve_c1 =
      Curve_params.
        { default with
          modulus = Bignum_bigint.of_int 7879
        ; a = Bignum_bigint.of_int 17
        }
    in
    let _cs =
      let point = (Bignum_bigint.of_int 7331, Bignum_bigint.of_int 888) in
      assert (is_on_curve_bignum_point curve_c1 point) ;
      test_is_on_curve curve_c1 point
    in

    (* Negative tests *)
    assert (
      Common.is_error (fun () ->
          let bad_pt =
            ( Bignum_bigint.of_string
                "67973637023329354644729732876692436096994797487488454090437075702698953132769"
            , Bignum_bigint.of_string
                "208096131279561713744990959402407452508030289249215221172372441421932322041350"
            )
          in
          test_is_on_curve Secp256k1.params bad_pt ) ) ;

    assert (
      Common.is_error (fun () ->
          let bad_pt = (Bignum_bigint.zero, Bignum_bigint.one) in
          test_is_on_curve Secp256k1.params bad_pt ) ) ;
    assert (
      Common.is_error (fun () ->
          let bad_pt = (Bignum_bigint.one, Bignum_bigint.one) in
          test_is_on_curve curve_p224 bad_pt ) ) ;
    assert (
      Common.is_error (fun () ->
          let bad_pt = (Bignum_bigint.of_int 2, Bignum_bigint.of_int 77) in
          test_is_on_curve curve_c1 bad_pt ) ) ;
    () )

    
let%test_unit "Ec_group.check_ia" =
  if scalar_mul_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test check_ia *)
    let test_check_ia ?cs (curve : Curve_params.t)
        (ia : Affine.bignum_point Curve_params.ia_points) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants (module Runner.Impl) curve
            in
            let ia =
              Curve_params.ia_to_circuit_constants (module Runner.Impl) ia
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Check initial accumulator values *)
            check_ia (module Runner.Impl) unused_external_checks curve ia ;

            (* Check for expected quantity of external checks *)
            let bounds_checks_count = ref 3 in
            if not Bignum_bigint.(curve.bignum.a = zero) then
              bounds_checks_count := !bounds_checks_count + 1 ;
            if not Bignum_bigint.(curve.bignum.b = zero) then
              bounds_checks_count := !bounds_checks_count + 1 ;
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.bounds
                !bounds_checks_count ) ;
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.multi_ranges
                3 ) ;
            assert (
              Mina_stdlib.List.Length.equal
                unused_external_checks.compact_multi_ranges 3 ) ;
            () )
      in

      cs
    in

    (*
     * Positive tests
     *)

    (* Check secp256k1 initial accumulator (ia) points are correctly computed *)
    let ia = compute_ia_points Secp256k1.params in
    assert (Stdlib.(ia = Secp256k1.params.ia)) ;
    assert (
      Bignum_bigint.(
        equal (fst ia.acc) (fst Secp256k1.params.ia.acc)
        && equal (snd ia.acc) (snd Secp256k1.params.ia.acc)
        && equal (fst ia.neg_acc) (fst Secp256k1.params.ia.neg_acc)
        && equal (snd ia.neg_acc) (snd Secp256k1.params.ia.neg_acc)) ) ;

    (* Check secp256k1 ia *)
    let _cs = test_check_ia Secp256k1.params Secp256k1.params.ia in

    (* Check computation and constraining of another ia *)
    let some_pt =
      ( Bignum_bigint.of_string
          "67973637023329354644729732876692436096994797487488454090437075702698953132769"
      , Bignum_bigint.of_string
          "108096131279561713744990959402407452508030289249215221172372441421932322041359"
      )
    in
    let ia = compute_ia_points Secp256k1.params ~point:some_pt in
    assert (
      Bignum_bigint.(
        equal (fst ia.acc)
          (Bignum_bigint.of_string
             "77808213848094917079255757522755861813805484598820680171349097575367307923684" )) ) ;
    assert (
      Bignum_bigint.(
        equal (snd ia.acc)
          (Bignum_bigint.of_string
             "53863434441850287308371409267019602514253829996603354269738630468061457326859" )) ) ;
    assert (
      Bignum_bigint.(
        equal (fst ia.neg_acc)
          (Bignum_bigint.of_string
             "77808213848094917079255757522755861813805484598820680171349097575367307923684" )) ) ;
    assert (
      Bignum_bigint.(
        equal (snd ia.neg_acc)
          (Bignum_bigint.of_string
             "61928654795465908115199575741668305339016154669037209769718953539847377344804" )) ) ;
    let cs = test_check_ia Secp256k1.params ia in

    (* Constraint system reuse *)
    let some_pt2 =
      ( Bignum_bigint.of_string
          "33321203307284859285457570648264200146777100201560799373305582914511875834316"
      , Bignum_bigint.of_string
          "7129423920069223884043324693587298420542722670070397102650821528843979421489"
      )
    in
    let another_ia2 = compute_ia_points Secp256k1.params ~point:some_pt2 in
    let _cs = test_check_ia ~cs Secp256k1.params another_ia2 in

    (*
     * Negative tests
     *)
    assert (
      Common.is_error (fun () ->
          (* Bad negated ia *)
          let neg_init_acc = Secp256k1.params.ia.neg_acc in
          let bad_neg =
            (fst neg_init_acc, Bignum_bigint.(snd neg_init_acc + one))
          in
          let bad_ia =
            Curve_params.ia_of_points Secp256k1.params.ia.acc bad_neg
          in
          test_check_ia Secp256k1.params bad_ia ) ) ;

    assert (
      Common.is_error (fun () ->
          (* init_acc is not on curve, but negative is good *)
          let bad_pt =
            ( Bignum_bigint.of_string
                "73748207725492941843355928046090697797026070566443284126849221438943867210748"
            , Bignum_bigint.of_string
                "71805440039692371678177852429904809925653495989672587996663750265844216498843"
            )
          in
          assert (not (is_on_curve_bignum_point Secp256k1.params bad_pt)) ;
          let neg_bad_pt =
            let x, y = bad_pt in
            (x, Bignum_bigint.((zero - y) % Secp256k1.params.modulus))
          in
          let bad_ia = Curve_params.ia_of_points bad_pt neg_bad_pt in
          test_check_ia Secp256k1.params bad_ia ) ) ;
    () )

let%test_unit "Ec_group.scalar_mul" =
  if scalar_mul_tests_enabled then
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test elliptic curve scalar multiplication *)
    let test_scalar_mul ?cs (curve : Curve_params.t) (scalar : Bignum_bigint.t)
        (point : Affine.bignum_point) (expected_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants (module Runner.Impl) curve
            in
            let scalar_bits =
              Common.bignum_bigint_unpack_as_unchecked_vars
                (module Runner.Impl)
                ~remove_trailing:true scalar
            in
            let point =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point
            in
            let expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_result
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Q = sP *)
            let result =
              scalar_mul
                (module Runner.Impl)
                unused_external_checks curve scalar_bits point
            in

            (* Check for expected quantity of external checks *)

            (* Check output matches expected result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    result expected_result ) ) ;
            () )
      in

      cs
    in

    (*
     * EC scalar multiplication tests
     *)

    (* Multiply by 1 *)
    let scalar = Bignum_bigint.of_int 1 in
    let point =
      ( Bignum_bigint.of_string
          "67973637023329354644729732876692436096994797487488454090437075702698953132769"
      , Bignum_bigint.of_string
          "108096131279561713744990959402407452508030289249215221172372441421932322041359"
      )
    in
    let _cs = test_scalar_mul Secp256k1.params scalar point point in

    (* Multiply by 3 *)
    let scalar = Bignum_bigint.of_int 3 in
    let expected_result =
      ( Bignum_bigint.of_string
          "157187898623115017197196263696044455473966365375620096488909462468556488992"
      , Bignum_bigint.of_string
          "8815915990003770986701969284580631365087521759318521999314517238992555623924"
      )
    in
    let _cs = test_scalar_mul Secp256k1.params scalar point expected_result in

    let scalar = Bignum_bigint.of_int 5 in
    let expected_result =
      ( Bignum_bigint.of_string
          "51167536897757234729699532493775077246692685149885509345450034909880529264629"
      , Bignum_bigint.of_string
          "44029933166959533883508578962900776387952087967919619281016528212534310213626"
      )
    in
    let _cs = test_scalar_mul Secp256k1.params scalar point expected_result in

    let scalar = Bignum_bigint.of_int 6 in
    let expected_result =
      ( Bignum_bigint.of_string
          "37941877700581055232085743160302884615963229784754572200220248617732513837044"
      , Bignum_bigint.of_string
          "103619381845871132282285745641400810486981078987965768860988615362483475376768"
      )
    in
    let _cs = test_scalar_mul Secp256k1.params scalar point expected_result in

    let scalar = Bignum_bigint.of_int 7 in
    let expected_result =
      ( Bignum_bigint.of_string
          "98789585776319197684463328274590329296514884375780947918152956981890869725107"
      , Bignum_bigint.of_string
          "53439843286771287571705008292825119475125031375071120429905353259479677320421"
      )
    in
    let _cs = test_scalar_mul Secp256k1.params scalar point expected_result in

    (* Multiply by 391 (9-bits) *)
    let scalar = Bignum_bigint.of_int 391 in
    let point =
      ( Bignum_bigint.of_string
          "54895644447597143434988379138583445778456903839185254067441861567562618370751"
      , Bignum_bigint.of_string
          "104240867874630534073764110268869655023740253909668464291682942589488282068874"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "92358528850649079329920393962087666882076668287684124835881344341719861256355"
      , Bignum_bigint.of_string
          "27671880807027823848003850001152132266698242755975705342674616617508656063465"
      )
    in
    let _cs = test_scalar_mul Secp256k1.params scalar point expected_result in

    (* Multiply by 56081 (16-bits) = 0b1000 1000 1101 1011 *)
    let scalar = Bignum_bigint.of_int 56081 in
    let point =
      ( Bignum_bigint.of_string
          "49950185608981313523985721024498375953313579282523275566585584189656370223502"
      , Bignum_bigint.of_string
          "63146279987886420302806526994276928563454160280333237123111833753346399349172"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "108851670764886172021315090022738025632501895048831561535857748171372817371035"
      , Bignum_bigint.of_string
          "39836887958851910836029687008284321008437801650048469660046898576758470452396"
      )
    in
    let _cs = test_scalar_mul Secp256k1.params scalar point expected_result in

    (* Multiply by full-size secp256k1 scalar (256-bits) *)
    let scalar =
      Bignum_bigint.of_string
        "99539640504241691246180604816121958450675059637016987953058113537095650715171"
    in
    let point =
      ( Bignum_bigint.of_string
          "68328903637429126750778604407754814031272668830649072423942370967409226150426"
      , Bignum_bigint.of_string
          "115181214446139478209347980655067703553667234783111668132659797097404834370543"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "39225021357252528375135552880830100632566425214595783585248505195330577648905"
      , Bignum_bigint.of_string
          "29440534631649867975583896121458013539074827830686556074829823458426851891598"
      )
    in
    let _cs = test_scalar_mul Secp256k1.params scalar point expected_result in

    (* Multiply by another full-size secp256k1 scalar (256-bits) *)
    let scalar =
      Bignum_bigint.of_string
        "35756276706511369289499344520446188493221382068841792677286014237073874389678"
    in
    let point =
      ( Bignum_bigint.of_string
          "43525911664736252471195991194779124044474905699728523733063794335880455509831"
      , Bignum_bigint.of_string
          "55128733880722898542773180558916537797992134106308528712389282845794719232809"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "92989598011225532261029933411922200506770253480509168102582704300806548851952"
      , Bignum_bigint.of_string
          "91632035281581329897770791332253791028537996389304501325297573948973121537913"
      )
    in
    let _cs = test_scalar_mul Secp256k1.params scalar point expected_result in

    (* Compute secp256k1 pub key from secret key *)
    let scalar =
      Bignum_bigint.of_string
        "88112557240431687619949876834386306142823675858092281192015740375511510392207"
    in
    let expected_pubkey =
      ( Bignum_bigint.of_string
          "50567548908598322015490923046917426159132337313161362096244889522774999144344"
      , Bignum_bigint.of_string
          "35561449820918632865961375836489131575522128704654117756369029278244987778295"
      )
    in
    let cs =
      test_scalar_mul Secp256k1.params scalar Secp256k1.params.gen
        expected_pubkey
    in
    (* Constraint system reuse *)
    let scalar =
      Bignum_bigint.of_string
        "93102346685989503200550820820601664115283772668359982393657391253613200462560"
    in
    let expected_pt =
      ( Bignum_bigint.of_string
          "115384145918035657737810677734903949889161796282962842129612290299404313800919"
      , Bignum_bigint.of_string
          "86432196125585910060501672565270170370528330974696895998365685616223611168261"
      )
    in
    let _cs =
      test_scalar_mul ~cs Secp256k1.params scalar Secp256k1.params.gen
        expected_pt
    in
    ()

let%test_unit "Ec_group.scalar_mul_properties" =
  if scalar_mul_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test elliptic curve scalar multiplication properties *)
    let test_scalar_mul_properties ?cs (curve : Curve_params.t)
        (a_scalar : Bignum_bigint.t) (b_scalar : Bignum_bigint.t)
        (point : Affine.bignum_point) (a_expected_result : Affine.bignum_point)
        (b_expected_result : Affine.bignum_point)
        (a_plus_b_expected : Affine.bignum_point)
        (a_times_b_expected : Affine.bignum_point)
        (negation_expected : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants (module Runner.Impl) curve
            in
            let a_scalar_bits =
              Common.bignum_bigint_unpack_as_unchecked_vars
                (module Runner.Impl)
                ~remove_trailing:true a_scalar
            in
            let b_scalar_bits =
              Common.bignum_bigint_unpack_as_unchecked_vars
                (module Runner.Impl)
                ~remove_trailing:true b_scalar
            in
            let c_scalar_bits =
              let c_scalar =
                Bignum_bigint.((a_scalar + b_scalar) % curve.bignum.order)
              in
              Common.bignum_bigint_unpack_as_unchecked_vars
                (module Runner.Impl)
                ~remove_trailing:true c_scalar
            in
            let point =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point
            in
            let a_expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                a_expected_result
            in
            let b_expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                b_expected_result
            in
            let a_plus_b_expected =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                a_plus_b_expected
            in
            let a_times_b_expected =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                a_times_b_expected
            in
            let negation_expected =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                negation_expected
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (*
             * Check distributive property with adding scalars: aP + bP = (a + b)P
             *)

            (* A = aP *)
            let a_result =
              scalar_mul
                (module Runner.Impl)
                unused_external_checks curve a_scalar_bits point
            in

            (* B = bP *)
            let b_result =
              scalar_mul
                (module Runner.Impl)
                unused_external_checks curve b_scalar_bits point
            in

            (* C = (a + b)P *)
            let a_plus_b_result =
              scalar_mul
                (module Runner.Impl)
                unused_external_checks curve c_scalar_bits point
            in

            (* A + B *)
            let a_result_plus_b_result =
              add
                (module Runner.Impl)
                unused_external_checks curve a_result b_result
            in

            (* Assert aP = expected A *)
            Affine.assert_equal (module Runner.Impl) a_result a_expected_result ;
            (* Assert bP = expected B *)
            Affine.assert_equal (module Runner.Impl) b_result b_expected_result ;
            (* Assert (a + b)P = expected *)
            Affine.assert_equal
              (module Runner.Impl)
              a_plus_b_result a_plus_b_expected ;
            (* Assert A + B = (a + b)P = cP *)
            Affine.assert_equal
              (module Runner.Impl)
              a_result_plus_b_result a_plus_b_result ;

            (*
             * Check distributive property with multiplying scalars: [a]bP = [b]aP = [a*b]P
             *)

            (* [a]bP *)
            let a_b_result =
              scalar_mul
                (module Runner.Impl)
                unused_external_checks curve a_scalar_bits b_result
            in

            (* [b]aP *)
            let b_a_result =
              scalar_mul
                (module Runner.Impl)
                unused_external_checks curve b_scalar_bits a_result
            in

            (* Compute a*b as foreign field multiplication in scalar field *)
            let ab_scalar_bits =
              let ab_scalar =
                Bignum_bigint.(a_scalar * b_scalar % curve.bignum.order)
              in
              Common.bignum_bigint_unpack_as_unchecked_vars
                (module Runner.Impl)
                ~remove_trailing:true ab_scalar
            in

            (* (a * b)P *)
            let ab_result =
              scalar_mul
                (module Runner.Impl)
                unused_external_checks curve ab_scalar_bits point
            in

            (* Assert [a]bP = [b]aP *)
            Affine.assert_equal (module Runner.Impl) a_b_result b_a_result ;
            (* Assert [b]aP = (a * b)P *)
            Affine.assert_equal (module Runner.Impl) b_a_result ab_result ;
            (* Assert (a * b)P = expected *)
            Affine.assert_equal
              (module Runner.Impl)
              ab_result a_times_b_expected ;

            (*
             * Check scaling computes with negation: [-a]P = -(aP)
             *)

            (* Compute -a_scalar witness *)
            let minus_a_scalar_bits =
              let minus_a_scalar =
                Bignum_bigint.(-a_scalar % curve.bignum.order)
              in
              Common.bignum_bigint_unpack_as_unchecked_vars
                (module Runner.Impl)
                ~remove_trailing:true minus_a_scalar
            in

            (* [-a]P *)
            let minus_a_result =
              scalar_mul
                (module Runner.Impl)
                unused_external_checks curve minus_a_scalar_bits point
            in

            (* -(aP) *)
            let negated_a_result = negate (module Runner.Impl) curve a_result in
            (* Result row: need to write negated y-coordinate to row in order to assert_equal on it *)
            Foreign_field.result_row
              (module Runner.Impl)
              ~label:"negation_property_check"
            @@ Affine.y negated_a_result ;

            (* Assert [-a]P = -(aP) *)
            Affine.assert_equal
              (module Runner.Impl)
              minus_a_result negated_a_result ;
            (* Assert -(aP) = expected *)
            Affine.assert_equal
              (module Runner.Impl)
              negated_a_result negation_expected ;

            () )
      in

      cs
    in

    (*
     * EC scalar multiplication properties tests
     *)

    (* Tests with generator *)
    let a_scalar =
      Bignum_bigint.of_string
        "79401928295407367700174300280555320402843131478792245979539416476579739380993"
    in
    (* aG *)
    let a_expected =
      ( Bignum_bigint.of_string
          "17125835931983334217694156357722716412757965999176597307946554943053675538785"
      , Bignum_bigint.of_string
          "46388026915780724534166509048612278793220290073988306084942872130687658791661"
      )
    in
    let b_scalar =
      Bignum_bigint.of_string
        "89091288558408807474211262098870527285408764120538440460973310880924228023627"
    in
    (* bG *)
    let b_expected =
      ( Bignum_bigint.of_string
          "79327061200655101960260174492040176163202074463842535225851740487556039447898"
      , Bignum_bigint.of_string
          "17719907321698144940791372349744661269763063699265755816142522447977929876765"
      )
    in
    (* (a + b)G *)
    let a_plus_b_expected =
      ( Bignum_bigint.of_string
          "81040990384669475923010997008987195868838198748766130146528604954229008315134"
      , Bignum_bigint.of_string
          "34561268318835956667566052477444512933985042899902969559255322703897774718063"
      )
    in
    (* (a * b)G *)
    let a_times_b_expected =
      ( Bignum_bigint.of_string
          "81456477659851325370442471400511783773782655276230587738882014172211964156628"
      , Bignum_bigint.of_string
          "95026373302104994624825470484745116441888023752189438912144935562310761663097"
      )
    in
    (* [-a]G *)
    let negation_expected =
      ( Bignum_bigint.of_string
          "17125835931983334217694156357722716412757965999176597307946554943053675538785"
      , Bignum_bigint.of_string
          "69404062321535470889404475960075629060049694591652257954514711877221175880002"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params a_expected) ;
    assert (is_on_curve_bignum_point Secp256k1.params b_expected) ;
    assert (is_on_curve_bignum_point Secp256k1.params a_plus_b_expected) ;
    assert (is_on_curve_bignum_point Secp256k1.params a_times_b_expected) ;
    assert (is_on_curve_bignum_point Secp256k1.params negation_expected) ;

    let _cs =
      test_scalar_mul_properties Secp256k1.params a_scalar b_scalar
        Secp256k1.params.gen a_expected b_expected a_plus_b_expected
        a_times_b_expected negation_expected
    in

    (* Tests with another curve point *)
    let point =
      ( Bignum_bigint.of_string
          "33774054739397672981116348681092907963399779523481500939771509974082662984990"
      , Bignum_bigint.of_string
          "60414776605185041994402340927179985824709402511452021592188768672640080416757"
      )
    in
    let a_scalar =
      Bignum_bigint.of_string
        "101698197574283114939368343806106834988902354006673798485060078476846328099457"
    in
    (* aP *)
    let a_expected =
      ( Bignum_bigint.of_string
          "75195284589272297831705973079897644085806639251981864022525558637369799002975"
      , Bignum_bigint.of_string
          "21318219854954928210493202207122232794689530644716510309784081397689563830643"
      )
    in
    let b_scalar =
      Bignum_bigint.of_string
        "29906750163917842454712060592346612426879165698013462577595179415632189050569"
    in
    (* bP *)
    let b_expected =
      ( Bignum_bigint.of_string
          "31338730031552911193929716320599408654845663804319033450328019997834721773857"
      , Bignum_bigint.of_string
          "19509931248131549366806268091016515808560677012657535095393179462073374184004"
      )
    in
    (* (a + b)P *)
    let a_plus_b_expected =
      ( Bignum_bigint.of_string
          "3785015531479612950834562670482118046158085046729801327010146109899305257240"
      , Bignum_bigint.of_string
          "67252551234352942899384104854542424500400416990163373189382133933498016564076"
      )
    in
    (* (a * b)P *)
    let a_times_b_expected =
      ( Bignum_bigint.of_string
          "104796198157638974641325627725056289938393733264860209068332598339943619687138"
      , Bignum_bigint.of_string
          "62474612839119693016992187953610680368302121786246432257338185158014628586401"
      )
    in
    (* [-a]P *)
    let negation_expected =
      ( Bignum_bigint.of_string
          "75195284589272297831705973079897644085806639251981864022525558637369799002975"
      , Bignum_bigint.of_string
          "94473869382361267213077782801565675058580454020924053729673502610219270841020"
      )
    in

    assert (is_on_curve_bignum_point Secp256k1.params point) ;
    assert (is_on_curve_bignum_point Secp256k1.params a_expected) ;
    assert (is_on_curve_bignum_point Secp256k1.params b_expected) ;
    assert (is_on_curve_bignum_point Secp256k1.params a_plus_b_expected) ;
    assert (is_on_curve_bignum_point Secp256k1.params a_times_b_expected) ;
    assert (is_on_curve_bignum_point Secp256k1.params negation_expected) ;

    let _cs =
      test_scalar_mul_properties Secp256k1.params a_scalar b_scalar point
        a_expected b_expected a_plus_b_expected a_times_b_expected
        negation_expected
    in
    () )

let%test_unit "Ec_group.scalar_mul_tiny" =
  if scalar_mul_tests_enabled then
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test elliptic curve scalar multiplication with tiny scalar *)
    let test_scalar_mul_tiny ?cs (curve : Curve_params.t)
        (scalar : Bignum_bigint.t) (point : Affine.bignum_point)
        (expected_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants
                (module Runner.Impl)
                curve ~use_precomputed_gen_doubles:false
            in
            let scalar_bits =
              Common.bignum_bigint_unpack_as_unchecked_vars
                (module Runner.Impl)
                ~remove_trailing:true scalar
            in
            let point =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point
            in
            let expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_result
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Q = sP *)
            let result =
              scalar_mul
                (module Runner.Impl)
                unused_external_checks curve scalar_bits point
            in

            (* Check for expected quantity of external checks *)
            if Bignum_bigint.(curve.bignum.a = zero) then
              assert (
                Mina_stdlib.List.Length.equal unused_external_checks.bounds 42 )
            else
              assert (
                Mina_stdlib.List.Length.equal unused_external_checks.bounds 43 ) ;
            assert (
              Mina_stdlib.List.Length.equal unused_external_checks.multi_ranges
                17 ) ;
            assert (
              Mina_stdlib.List.Length.equal
                unused_external_checks.compact_multi_ranges 17 ) ;

            (* Check output matches expected result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    result expected_result ) ) ;
            () )
      in

      cs
    in

    (*
     * EC scalar multiplication tests
     *)

    (* Multiply by 2 *)
    let scalar = Bignum_bigint.of_int 2 in
    let expected_result =
      ( Bignum_bigint.of_string
          "89565891926547004231252920425935692360644145829622209833684329913297188986597"
      , Bignum_bigint.of_string
          "12158399299693830322967808612713398636155367887041628176798871954788371653930"
      )
    in
    let _cs =
      test_scalar_mul_tiny Secp256k1.params scalar Secp256k1.params.gen
        expected_result
    in

    ()

let%test_unit "Ec_group.scalar_mul_tiny_full" =
  if scalar_mul_tests_enabled then
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test elliptic curve scalar multiplication with tiny scalar (fully constrained) *)
    let test_scalar_mul_tiny_full ?cs (curve : Curve_params.t)
        (scalar : Bignum_bigint.t) (point : Affine.bignum_point)
        (expected_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants
                (module Runner.Impl)
                curve ~use_precomputed_gen_doubles:false
            in
            let scalar_bits =
              Common.bignum_bigint_unpack_as_unchecked_vars
                (module Runner.Impl)
                ~remove_trailing:true scalar
            in
            let point =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point
            in
            let expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_result
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Q = sP *)
            let result =
              scalar_mul
                (module Runner.Impl)
                external_checks curve scalar_bits point
            in

            (*
             * Perform external checks
             *)

            (* Sanity checks *)
            if Bignum_bigint.(curve.bignum.a = zero) then
              assert (Mina_stdlib.List.Length.equal external_checks.bounds 42)
            else assert (Mina_stdlib.List.Length.equal external_checks.bounds 43) ;
            assert (
              Mina_stdlib.List.Length.equal external_checks.multi_ranges 17 ) ;
            assert (
              Mina_stdlib.List.Length.equal external_checks.compact_multi_ranges
                17 ) ;

            (* Add gates for bound checks, multi-range-checks and compact-multi-range-checks *)
            Foreign_field.constrain_external_checks
              (module Runner.Impl)
              external_checks curve.modulus ;

            (* Check output matches expected result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    result expected_result ) ) ;
            () )
      in

      cs
    in

    (*
     * EC scalar multiplication full tiny test
     *)

    (* Multiply by 2 *)
    let scalar = Bignum_bigint.of_int 2 in
    let expected_result =
      ( Bignum_bigint.of_string
          "89565891926547004231252920425935692360644145829622209833684329913297188986597"
      , Bignum_bigint.of_string
          "12158399299693830322967808612713398636155367887041628176798871954788371653930"
      )
    in
    let _cs =
      test_scalar_mul_tiny_full Secp256k1.params scalar Secp256k1.params.gen
        expected_result
    in

    ()

let%test_unit "Ec_group.scalar_mul_full" =
  if scalar_mul_tests_enabled then
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test elliptic curve scalar multiplication with scalar (fully constrained, for 256 bit length scalars)
     *   Rows without external checks:  9239
     *   Rows with external checks:     >2^16 
     *)
    let test_scalar_mul_full ?cs (full : bool) (curve : Curve_params.t)
        (scalar : Bignum_bigint.t) (point : Affine.bignum_point)
        (expected_result : Affine.bignum_point) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test public inputs *)
            let curve =
              Curve_params.to_circuit_constants
                (module Runner.Impl)
                curve ~use_precomputed_gen_doubles:false
            in
            let scalar_bits =
              Common.bignum_bigint_unpack_as_unchecked_vars
                (module Runner.Impl)
                ~remove_trailing:true scalar
            in
            let point =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) point
            in
            let expected_result =
              Affine.of_bignum_bigint_coordinates
                (module Runner.Impl)
                expected_result
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Q = sP *)
            let result =
              scalar_mul
                (module Runner.Impl)
                external_checks curve scalar_bits point
            in

            (*
             * Perform external checks
             *)

            (* Sanity checks *)

            if full then
              (* Perform external checks *)
              Foreign_field.constrain_external_checks
                (module Runner.Impl)
                external_checks curve.modulus ;

            (* Check output matches expected result *)
            as_prover (fun () ->
                assert (
                  Affine.equal_as_prover
                    (module Runner.Impl)
                    result expected_result ) ) ;
            () )
      in

      cs
    in

    (*
     * EC scalar multiplication full test
     *)
    let scalar =
      Bignum_bigint.of_string
        "86328453031879654597075713189149610219798626760146420625950995482836591878435"
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "34471291466947522722859799187843146224770255220707476910295898769840639813138"
      , Bignum_bigint.of_string
          "93602351553749687946251059563423164683238306171680072584629082513591162129572"
      )
    in
    let _cs =
      test_scalar_mul_full false Secp256k1.params scalar Secp256k1.params.gen
        expected_result
    in

    (* New tests with smaller scalars now that there are more range checks.
    Otherwise, this test does not fit in the circuit. 
    This input has 240 bits, the largest that fits. *)
    let scalar =
      Bignum_bigint.of_string
        "883849402004873298920485930012984822284506669376738495737289485768964326"
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "113620340565295226155036286811009368115794672359843055969763147980683287881843"
      , Bignum_bigint.of_string
          "36869808244135275287753101919208985470540027125341749813053996658181590025295"
      )
    in
    let _cs =
      test_scalar_mul_full true Secp256k1.params scalar Secp256k1.params.gen
        expected_result
    in

    ()
