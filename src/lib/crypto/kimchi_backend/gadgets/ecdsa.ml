open Core_kernel
module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

let group_tests_enabled = false

let group_scalar_mul_tests = false

let two_to_4limb = Bignum_bigint.(Common.two_to_3limb * Common.two_to_limb)

type bignum_point = Bignum_bigint.t * Bignum_bigint.t

(* Affine representation of an elliptic curve point over a foreign field *)
module Affine : sig
  type 'field t

  (* Create foreign field affine point from coordinate pair (x, y) *)
  val of_coordinates :
       'field Foreign_field.Element.Standard.t
       * 'field Foreign_field.Element.Standard.t
    -> 'field t

  (* Create foreign field affine point from coordinate pair of Bignum_bigint.t (x, y) *)
  val of_bignum_bigint_coordinates :
    (module Snark_intf.Run with type field = 'field) -> bignum_point -> 'field t

  (* Create foreign field affine point from hex *)
  val of_hex :
    (module Snark_intf.Run with type field = 'field) -> string -> 'field t

  (* Convert foreign field affine point to coordinate pair (x, y) *)
  val to_coordinates :
       'field t
    -> 'field Foreign_field.Element.Standard.t
       * 'field Foreign_field.Element.Standard.t

  (* Convert foreign field affine point to string of the form (x, y) *)
  val to_string_as_prover :
    (module Snark_intf.Run with type field = 'field) -> 'field t -> string

  (* Convert foreign field affine point to hex *)
  val to_hex_as_prover :
    (module Snark_intf.Run with type field = 'field) -> 'field t -> string

  (* Access x-coordinate of foreign field affine point *)
  val x : 'field t -> 'field Foreign_field.Element.Standard.t

  (* Access y-coordinate of foreign field affine point *)
  val y : 'field t -> 'field Foreign_field.Element.Standard.t

  (* Compare if two foreign field affine points are equal *)
  val equal_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field t
    -> bool

  (* Add copy constraints that two Affine points are equal *)
  val assert_equal :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field t
    -> unit

  (* Zero point *)
  val as_prover_zero :
    (module Snark_intf.Run with type field = 'field) -> 'field t

  (* Add conditional constraints to select Affine point *)
  val if_ :
       (module Snark_intf.Run with type field = 'field)
    -> 'field Snarky_backendless.Cvar.t Snark_intf.Boolean0.t
    -> 'field t
    -> 'field t
    -> 'field t
end = struct
  type 'field t =
    'field Foreign_field.Element.Standard.t
    * 'field Foreign_field.Element.Standard.t

  let of_coordinates a = a

  let of_bignum_bigint_coordinates (type field)
      (module Circuit : Snark_intf.Run with type field = field)
      (point : bignum_point) : field t =
    let x, y = point in
    of_coordinates
      ( Foreign_field.Element.Standard.of_bignum_bigint (module Circuit) x
      , Foreign_field.Element.Standard.of_bignum_bigint (module Circuit) y )

  let of_hex (type field)
      (module Circuit : Snark_intf.Run with type field = field) a : field t =
    let a = Common.bignum_bigint_of_hex a in
    let x, y = Common.(bignum_bigint_div_rem a two_to_4limb) in
    let x =
      Foreign_field.Element.Standard.of_bignum_bigint (module Circuit) x
    in
    let y =
      Foreign_field.Element.Standard.of_bignum_bigint (module Circuit) y
    in
    (x, y)

  let to_coordinates a = a

  let to_string_as_prover (type field)
      (module Circuit : Snark_intf.Run with type field = field) a : string =
    let x, y = to_coordinates a in
    sprintf "(%s, %s)"
      (Foreign_field.Element.Standard.to_string_as_prover (module Circuit) x)
      (Foreign_field.Element.Standard.to_string_as_prover (module Circuit) y)

  let to_hex_as_prover (type field)
      (module Circuit : Snark_intf.Run with type field = field) a : string =
    let x, y = to_coordinates a in
    let x =
      Foreign_field.Element.Standard.to_bignum_bigint_as_prover
        (module Circuit)
        x
    in
    let y =
      Foreign_field.Element.Standard.to_bignum_bigint_as_prover
        (module Circuit)
        y
    in
    let combined = Bignum_bigint.((x * two_to_4limb) + y) in
    Common.bignum_bigint_to_hex combined

  let x a =
    let x_element, _ = to_coordinates a in
    x_element

  let y a =
    let _, y_element = to_coordinates a in
    y_element

  let equal_as_prover (type field)
      (module Circuit : Snark_intf.Run with type field = field) (left : field t)
      (right : field t) : bool =
    let left_x, left_y = to_coordinates left in
    let right_x, right_y = to_coordinates right in
    Foreign_field.Element.Standard.(
      equal_as_prover (module Circuit) left_x right_x
      && equal_as_prover (module Circuit) left_y right_y)

  let assert_equal (type field)
      (module Circuit : Snark_intf.Run with type field = field) (left : field t)
      (right : field t) : unit =
    let left_x, left_y = to_coordinates left in
    let right_x, right_y = to_coordinates right in
    Foreign_field.Element.Standard.(
      assert_equal (module Circuit) left_x right_x ;
      assert_equal (module Circuit) left_y right_y)

  let as_prover_zero (type field)
      (module Circuit : Snark_intf.Run with type field = field) : field t =
    of_coordinates
      Foreign_field.Element.Standard.
        ( of_bignum_bigint (module Circuit) Bignum_bigint.zero
        , of_bignum_bigint (module Circuit) Bignum_bigint.zero )

  let if_ (type field) (module Circuit : Snark_intf.Run with type field = field)
      (b : Circuit.Boolean.var) (then_ : field t) (else_ : field t) : field t =
    let then_x, then_y = to_coordinates then_ in
    let else_x, else_y = to_coordinates else_ in
    of_coordinates
      Foreign_field.Element.Standard.
        ( if_ (module Circuit) b then_x else_x
        , if_ (module Circuit) b then_y else_y )
end

(* Array to tuple helpers *)
let tuple6_of_array array =
  match array with
  | [| a1; a2; a3; a4; a5; a6 |] ->
      (a1, a2, a3, a4, a5, a6)
  | _ ->
      assert false

let tuple9_of_array array =
  match array with
  | [| a1; a2; a3; a4; a5; a6; a7; a8; a9 |] ->
      (a1, a2, a3, a4, a5, a6, a7, a8, a9)
  | _ ->
      assert false

(* Helper to check if point is on elliptic curve curve: y^2 = x^3 + a * x + b *)
let is_on_curve (point : bignum_point)
    (a : Bignum_bigint.t) (* curve parameter a *)
    (b : Bignum_bigint.t) (* curve parameter b *)
    (foreign_field_modulus : Bignum_bigint.t) : bool =
  let x, y = point in
  Bignum_bigint.(
    pow y (of_int 2) % foreign_field_modulus
    = ( (pow x (of_int 3) % foreign_field_modulus)
      + (a * x % foreign_field_modulus)
      + b )
      % foreign_field_modulus)

let secp256k1_modulus =
  Bignum_bigint.of_string
    "115792089237316195423570985008687907853269984665640564039457584007908834671663"

let secp256k1_order =
  Bignum_bigint.of_string
    "115792089237316195423570985008687907852837564279074904382605163141518161494337"

let secp256k1_generator =
  ( Bignum_bigint.of_string
      "55066263022277343669578718895168534326250603453777594175500187360389116729240"
  , Bignum_bigint.of_string
      "32670510020758816978083085130507043184471273380659243275938904335757337482424"
  )

let secp256k1_a = Bignum_bigint.of_int 0

let secp256k1_b = Bignum_bigint.of_int 7

let secp256k1_ia =
  ( ( Bignum_bigint.of_string
        "73748207725492941843355928046090697797026070566443284126849221438943867210749"
    , Bignum_bigint.of_string
        "71805440039692371678177852429904809925653495989672587996663750265844216498843"
    )
  , ( Bignum_bigint.of_string
        "73748207725492941843355928046090697797026070566443284126849221438943867210749"
    , Bignum_bigint.of_string
        "43986649197623823745393132578783097927616488675967976042793833742064618172820"
    ) )

(* Helper to check if point is on secp256k1 curve: y^2 = x^3 + 7 *)
let secp256k1_is_on_curve (point : bignum_point) : bool =
  is_on_curve point secp256k1_a secp256k1_b secp256k1_modulus

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
 *   Supported group axioms:
 *     Closure
 *     Associativity
 *
 *   Note: We elide the Identity property because it is costly in circuit
 *         and we don't need it for our application.  By doing this we also
 *         lose Invertibility, which we also don't need for our goals.
 *)
let group_add (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t)
    (left_input : f Affine.t) (right_input : f Affine.t)
    (foreign_field_modulus : f Foreign_field.standard_limbs) : f Affine.t =
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
             (Affine.as_prover_zero (module Circuit)) ) ) ;
      assert (
        not
          (Affine.equal_as_prover
             (module Circuit)
             right_input
             (Affine.as_prover_zero (module Circuit)) ) ) ) ;

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
        let foreign_field_modulus =
          Foreign_field.field_standard_limbs_to_bignum_bigint
            (module Circuit)
            foreign_field_modulus
        in

        (* Compute slope and slope squared *)
        let slope =
          Bignum_bigint.(
            (* Computes s = (Ry - Ly)/(Rx - Lx) *)
            let delta_y = (right_y - left_y) % foreign_field_modulus in
            let delta_x = (right_x - left_x) % foreign_field_modulus in

            (* Compute delta_x inverse *)
            let delta_x_inv =
              Common.bignum_bigint_inverse delta_x foreign_field_modulus
            in

            delta_y * delta_x_inv % foreign_field_modulus)
        in

        let slope_squared =
          Bignum_bigint.((pow slope @@ of_int 2) % foreign_field_modulus)
        in

        (* Compute result's x-coodinate: x = s^2 - Lx - Rx *)
        let result_x =
          Bignum_bigint.(
            let slope_squared_x =
              (slope_squared - left_x) % foreign_field_modulus
            in
            (slope_squared_x - right_x) % foreign_field_modulus)
        in

        (* Compute result's y-coodinate: y = s * (Rx - x) - Ry *)
        let result_y =
          Bignum_bigint.(
            let x_diff = (right_x - result_x) % foreign_field_modulus in
            let x_diff_s = slope * x_diff % foreign_field_modulus in
            (x_diff_s - right_y) % foreign_field_modulus)
        in

        (* Convert from Bignums to field elements *)
        let slope0, slope1, slope2 =
          Foreign_field.bignum_bigint_to_field_standard_limbs
            (module Circuit)
            slope
        in
        let result_x0, result_x1, result_x2 =
          Foreign_field.bignum_bigint_to_field_standard_limbs
            (module Circuit)
            result_x
        in
        let result_y0, result_y1, result_y2 =
          Foreign_field.bignum_bigint_to_field_standard_limbs
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
    Foreign_field.mul
      (module Circuit)
      external_checks slope slope foreign_field_modulus
  in
  (* Bounds 1: Multiplication left input (slope) and right input (slope)
   *           bound checks with single bound check.
   *           Result bound check already tracked by external_checks.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
    (slope0, slope1, slope2) ;

  (* C2: Constrain result x-coordinate computation: x = s^2 - Lx - Rx with length 2 chain
   *     with s^2 - x - Lx = Rx
   *)
  let slope_squared_minus_x =
    (* s^2 - x = sΔx *)
    Foreign_field.sub
      (module Circuit)
      ~full:false slope_squared result_x foreign_field_modulus
  in
  (* Bounds 2: Left input bound check covered by (Bounds 1).
   *           Right input bound check value is gadget output so checked externally.
   *           Result chained, so no bound check required.
   *)
  let expected_right_x =
    (* sΔx - Lx = Rx *)
    Foreign_field.sub
      (module Circuit)
      ~full:false slope_squared_minus_x left_x foreign_field_modulus
  in
  (* Bounds 3: Left input bound check is chained.
   *           Right input bound check value is gadget input so checked externally.
   *)
  (* Copy expected_right_x to right_x *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    expected_right_x right_x ;
  (* C3: Continue the chain to length 4 by computing (Rx - x) * s (used later) *)
  let right_delta =
    (* Rx - x = RxΔ *)
    Foreign_field.sub
      (module Circuit)
      ~full:false expected_right_x result_x foreign_field_modulus
  in
  (* Bounds 4: Addition chain result (right_delta) bound check added below.
   *           Left input bound check is chained.
   *           Right input bound check value is gadget output so checked externally.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs right_delta ;
  let right_delta_s =
    (* RxΔ * s = RxΔs *)
    Foreign_field.mul
      (module Circuit)
      external_checks right_delta slope foreign_field_modulus
  in

  (* Bounds 5: Multiplication result bound checks for left input (right_delta)
   *           and right input (slope) already covered by (Bounds 4) and (Bounds 1).
   *           Result bound check already tracked by external_checks.
   *)

  (* C4: Constrain slope computation: s = (Ry - Ly)/(Rx - Lx) over two length 2 chains
   *     with (Rx - Lx) * s + Ly = Ry
   *)
  let delta_x =
    (* Rx - Lx = Δx *)
    Foreign_field.sub
      (module Circuit)
      ~full:false right_x left_x foreign_field_modulus
  in
  (* Bounds 6: Addition chain result (delta_x) bound check below.
   *           Addition inputs are gadget inputs and tracked externally.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs delta_x ;
  let delta_x_s =
    (* Δx * s = Δxs *)
    Foreign_field.mul
      (module Circuit)
      external_checks delta_x slope foreign_field_modulus
  in
  (* Bounds 7: Multiplication bound checks for left input (delta_x) and
   *           right input (slope) are already covered by (Bounds 6) and (Bounds 1).
   *           Result bound check tracked by external_checks.
   *)
  (* Finish constraining slope in new chain (above mul ended chain) *)
  let expected_right_y =
    (* Δxs + Ly = Ry *)
    Foreign_field.add
      (module Circuit)
      ~full:false delta_x_s left_y foreign_field_modulus
  in
  (* Bounds 8: Left input bound check is tracked by (Bounds 7).
   *           Right input bound check value is gadget input so checked externally.
   *)
  (* Copy expected_right_y to right_y *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    expected_right_y right_y ;
  (* C5: Constrain result y-coordinate computation: y = (Rx - x) * s - Ry
   *     with Ry + y = (Rx - x) * s
   *)
  let expected_right_delta_s =
    (* Ry + y = RxΔs *)
    Foreign_field.add ~full:false
      (module Circuit)
      expected_right_y result_y foreign_field_modulus
  in
  (* Bounds 9: Addition chain result (expected_right_delta_s) bound check already
   *           covered by (Bounds 5).
   *           Left input bound check is chained.
   *           Right input bound check value is gadget output so checked externally.
   *)
  let expected_right_delta_s0, expected_right_delta_s1, expected_right_delta_s2
      =
    Foreign_field.Element.Standard.to_limbs expected_right_delta_s
  in

  (* Final Zero gate with result *)
  with_label "group_add_final_zero_gate" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Raw
                 { kind = Zero
                 ; values =
                     [| expected_right_delta_s0
                      ; expected_right_delta_s1
                      ; expected_right_delta_s2
                     |]
                 ; coeffs = [||]
                 } )
        } ) ;
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
 *   Note: See group addition notes (above) about group properties supported by this implementation
 *)
let group_double (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t) (point : f Affine.t)
    ?(a =
      ( Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero ))
    (foreign_field_modulus : f Foreign_field.standard_limbs) : f Affine.t =
  let open Circuit in
  (* TODO: Remove sanity checks if this API is not public facing *)
  as_prover (fun () ->
      (* Sanity check that point is not infinity *)
      assert (
        not
          (Affine.equal_as_prover
             (module Circuit)
             point
             (Affine.as_prover_zero (module Circuit)) ) ) ) ;

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
        let point_x =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            point_x
        in
        let point_y =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            point_y
        in
        let a =
          Foreign_field.field_standard_limbs_to_bignum_bigint (module Circuit) a
        in
        let foreign_field_modulus =
          Foreign_field.field_standard_limbs_to_bignum_bigint
            (module Circuit)
            foreign_field_modulus
        in

        (* Compute slope using 1st derivative of sqrt(x^3 + a * x + b)
         * Note that when a = 0 (e.g. as in the case of secp256k1) we have
         * one fewer constraint (below).
         *)
        let slope =
          Bignum_bigint.(
            (* Computes s' = (3 * Px^2  + a )/ 2 * Py *)
            let numerator =
              let point_x_squared =
                pow point_x (of_int 2) % foreign_field_modulus
              in
              let point_x3_squared =
                of_int 3 * point_x_squared % foreign_field_modulus
              in

              (point_x3_squared + a) % foreign_field_modulus
            in
            let denominator = of_int 2 * point_y % foreign_field_modulus in

            (* Compute inverse of denominator *)
            let denominator_inv =
              Common.bignum_bigint_inverse denominator foreign_field_modulus
            in
            numerator * denominator_inv % foreign_field_modulus)
        in

        let slope_squared =
          Bignum_bigint.((pow slope @@ of_int 2) % foreign_field_modulus)
        in

        (* Compute result's x-coodinate: x = s^2 - 2 * Px *)
        let result_x =
          Bignum_bigint.(
            let point_x2 = of_int 2 * point_x % foreign_field_modulus in
            (slope_squared - point_x2) % foreign_field_modulus)
        in

        (* Compute result's y-coodinate: y = s * (Px - x) - Py *)
        let result_y =
          Bignum_bigint.(
            let x_diff = (point_x - result_x) % foreign_field_modulus in
            let x_diff_s = slope * x_diff % foreign_field_modulus in
            (x_diff_s - point_y) % foreign_field_modulus)
        in

        (* Convert from Bignums to field elements *)
        let slope0, slope1, slope2 =
          Foreign_field.bignum_bigint_to_field_standard_limbs
            (module Circuit)
            slope
        in
        let result_x0, result_x1, result_x2 =
          Foreign_field.bignum_bigint_to_field_standard_limbs
            (module Circuit)
            result_x
        in
        let result_y0, result_y1, result_y2 =
          Foreign_field.bignum_bigint_to_field_standard_limbs
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
    Foreign_field.mul
      (module Circuit)
      external_checks slope slope foreign_field_modulus
  in
  (* Bounds 1: Multiplication left input (slope) and right input (slope)
   *           bound checks with single bound check.
   *           Result bound check already tracked by external_checks.
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
      ~full:false slope_squared result_x foreign_field_modulus
  in
  (* Bounds 2: Left input bound check covered by (Bounds 1).
   *           Right input bound check value is gadget output so checked externally.
   *           Result chained, so no bound check required.
   *)
  let expected_point_x =
    (* 2Px - Px = Px *)
    Foreign_field.sub
      (module Circuit)
      ~full:false point_x2 point_x foreign_field_modulus
  in
  (* Bounds 3: Left input bound check is chained.
   *           Right input bound check value is gadget input so checked externally.
   *           Result chained, so no bound check required.
   *)
  (* Copy expected_point_x to point_x *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    expected_point_x point_x ;
  (* C3: Continue the chain to length 4 by computing (Px - x) * s (used later) *)
  let delta_x =
    (* Px - x = Δx *)
    Foreign_field.sub
      (module Circuit)
      ~full:false expected_point_x result_x foreign_field_modulus
  in
  (* Bounds 4: Left input bound check is chained.
   *           Right input bound check value is gadget output so checked externally.
   *           Addition chain result (delta_x) bound check added below.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs delta_x ;
  let delta_xs =
    (* Δx * s = Δxs *)
    Foreign_field.mul
      (module Circuit)
      external_checks delta_x slope foreign_field_modulus
  in

  (* Bounds 5: Multiplication result bound checks for left input (delta_x)
   *           and right input (slope) already covered by (Bounds 4) and (Bounds 1).
   *           Result bound check already tracked by external_checks.
   *)

  (* C4: Constrain rest of y = s' * (Px - x) - Py and part of slope computation
   *     s = (3 * Px^2 + a)/(2 * Py) in length 3 chain
   *)
  let expected_point_y =
    (* Δxs - y = Py *)
    Foreign_field.sub
      (module Circuit)
      ~full:false delta_xs result_y foreign_field_modulus
  in
  (* Bounds 6: Left input checked by (Bound 5).
   *           Right input is gadget output so checked externally.
   *           Addition result chained.
   *)
  (* Copy expected_point_y to point_y *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    expected_point_y point_y ;
  let point_y2 =
    (* Py + Py = 2Py *)
    Foreign_field.add
      (module Circuit)
      ~full:false point_y point_y foreign_field_modulus
  in
  (* Bounds 7: Left input is gadget output so checked externally.
   *           Right input is gadget output so checked externally.
   *           Addition result chained.
   *)
  let point_y2s =
    (* 2Py * s = 2Pys *)
    Foreign_field.mul
      (module Circuit)
      external_checks point_y2 slope foreign_field_modulus
  in
  (* Bounds 8: Left input (point_y2) bound check added below.
   *           Right input (slope) already checked by (Bound 1).
   *           Result bound check already tracked by external_checks.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs point_y2 ;

  (* C5: Constrain rest slope computation s = (3 * Px^2 + a)/(2 * Py) *)
  let point_x3 =
    (* 2Px + Px = 3Px *)
    Foreign_field.add
      (module Circuit)
      ~full:false point_x2 point_x foreign_field_modulus
  in
  (* Bounds 9: Left input (point_x2) bound check added below. (TODO: double check this is necessary)
   *           Right input is gadget input so checked externally.
   *           Result chained.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs point_x2 ;
  let point_x3_squared =
    (* 3Px * Px = 3Px^2 *)
    Foreign_field.mul
      (module Circuit)
      external_checks point_x3 point_x foreign_field_modulus
  in

  (* Bounds 10: Left input (point_x3) bound check added below.
   *            Right input is gadget input so checked externally.
   *            Result bound check already tracked by mul's
   *            external_checks.
   *)

  (* Check if the elliptic curve a parameter requires more constraints
   * to be added in order to add final a (e.g. 3Px^2 + a where a != 0).
   *)
  if Foreign_field.field_standard_limbs_is_zero (module Circuit) a then (
    (* Optimisation (saves 6 rows): Drop point_x3_squared bound check since
     * it's equal to point_y2s and covered by (Bounds 8) *)
    Foreign_field.External_checks.drop_bound_check external_checks ;

    (* Add point_x3 bound check (Bounds 10) *)
    Foreign_field.External_checks.append_bound_check external_checks
    @@ Foreign_field.Element.Standard.to_limbs point_x3 ;

    (* Copy point_x3_squared to point_y2s *)
    Foreign_field.Element.Standard.assert_equal
      (module Circuit)
      point_x3_squared point_y2s )
  else (
    (* Add point_x3 bound check (Bounds 10) *)
    Foreign_field.External_checks.append_bound_check external_checks
    @@ Foreign_field.Element.Standard.to_limbs point_x3 ;

    (* Add curve constant a *)
    let a =
      let a0, a1, a2 =
        exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
            let a0, a1, a2 = a in
            [| a0; a1; a2 |] )
        |> Common.tuple3_of_array
      in
      Foreign_field.Element.Standard.of_limbs (a0, a1, a2)
    in
    (* C6: Constrain rest slope computation s = (3 * Px^2 + a)/(2 * Py) *)
    let point_x3_squared_plus_a =
      (* 3Px^2 + a = 3Px^2a *)
      Foreign_field.add
        (module Circuit)
        ~full:false point_x3_squared a foreign_field_modulus
      (* Bounds 11: Left input (point_x3_squared) already tracked by (Bounds 10).
       *            Right input is public constant.
       *            Result bound check already covered by (Bound 8) since
       *            point_x3_squared_plus_a = point_y2s.
       *)
    in

    (* Final Zero gate with result *)
    let ( point_x3_squared_plus_a0
        , point_x3_squared_plus_a1
        , point_x3_squared_plus_a2 ) =
      Foreign_field.Element.Standard.to_limbs point_x3_squared_plus_a
    in
    with_label "group_add_final_zero_gate" (fun () ->
        assert_
          { annotation = Some __LOC__
          ; basic =
              Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                (Raw
                   { kind = Zero
                   ; values =
                       [| point_x3_squared_plus_a0
                        ; point_x3_squared_plus_a1
                        ; point_x3_squared_plus_a2
                       |]
                   ; coeffs = [||]
                   } )
          } ) ;

    (* Copy point_x3_squared_plus_a to point_y2s *)
    Foreign_field.Element.Standard.assert_equal
      (module Circuit)
      point_x3_squared_plus_a point_y2s ) ;

  (* Return result point *)
  Affine.of_coordinates (result_x, result_y)

(* Gadget for elliptic curve group negation *)
let group_negate (type f) (module Circuit : Snark_intf.Run with type field = f)
    (point : f Affine.t) (foreign_field_modulus : f Foreign_field.standard_limbs)
    : f Affine.t =
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
    Foreign_field.sub (module Circuit) ~full:false zero y foreign_field_modulus
  in

  (* Bounds 1: Left input is public constant
   *           Right input parameter (checked externally)
   *           Result bound is part of output checked externally
   *)
  Affine.of_coordinates (x, neg_y)

(* Select initial EC scalar mul accumulator value ia using trustworthy nothing-up-my-sleeve deterministic algorithm
 *
 *   Simple hash-to-curve algorithm
 *
 *   Trustlessly select an elliptic curve point for which noone knows the discrete logarithm!
 *)
let group_get_ia_point (a : Bignum_bigint.t) (* curve parameter a *)
    (b : Bignum_bigint.t) (* curve parameter b *)
    (gen : bignum_point) (* Elliptic curve generator point *)
    (foreign_field_modulus : Bignum_bigint.t) : bignum_point * bignum_point =
  (* Hash generator point to get candidate x-coordinate *)
  let open Digestif.SHA256 in
  let ctx = init () in

  assert (is_on_curve gen a b foreign_field_modulus) ;

  (* Hash to (possible) elliptic curve point function *)
  let hash_to_curve_point ctx (point : bignum_point ref) =
    (* Hash curve point *)
    let x, y = !point in
    let ctx = feed_string ctx @@ Common.bignum_bigint_unpack_bytes x in
    let ctx = feed_string ctx @@ Common.bignum_bigint_unpack_bytes y in
    let bytes = get ctx |> to_raw_string in

    (* Initialize x-coordinate from hash output *)
    let x =
      Bignum_bigint.(Common.bignum_bigint_of_bin bytes % foreign_field_modulus)
    in

    (* Compute y-coordinate: y = sqrt(x^3 + a * x + b) *)
    let x3 = Bignum_bigint.(pow x (of_int 3) % foreign_field_modulus) in
    let ax = Bignum_bigint.(a * x % foreign_field_modulus) in
    let x3ax = Bignum_bigint.((x3 + ax) % foreign_field_modulus) in
    let y2 = Bignum_bigint.((x3ax + b) % foreign_field_modulus) in
    let y = Common.bignum_bigint_sqrt_mod y2 foreign_field_modulus in

    (* Return possibly valid curve point *)
    (x, y)
  in

  (* Deterministically search for valid curve point *)
  let candidate_point = ref (hash_to_curve_point ctx (ref gen)) in
  while not (is_on_curve !candidate_point a b foreign_field_modulus) do
    candidate_point := hash_to_curve_point ctx candidate_point
  done ;

  (* We have a valid curve point! *)
  let point = !candidate_point in

  (* Compute negated point (i.e. with other y-root) *)
  let neg_point =
    let x, y = point in
    let neg_y = Bignum_bigint.(neg y % foreign_field_modulus) in
    (x, neg_y)
  in

  (point, neg_point)

(* Gadget to constrain a point in on the elliptic curve specified by
 *   y^2 = x^3 + ax + b
 * where a, b are the curve parameters and foreign_field_modulus is
 * the base field modulus
 *)
let group_is_on_curve (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t) (point : f Affine.t)
    ?(a =
      ( Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero ))
    ?(b =
      ( Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero ))
    (foreign_field_modulus : f Foreign_field.standard_limbs) =
  let open Circuit in
  let x, y = Affine.to_coordinates point in

  (* C1: x^2 = x * x *)
  let x_squared =
    Foreign_field.mul (module Circuit) external_checks x x foreign_field_modulus
  in

  (* Bounds 1: Left and right inputs are gadget input so checked externally
   *           Result bound check already tracked by external_checks
   *)

  (* C2: Optionally constrain addition of curve parameter a *)
  let x_squared_a =
    if not (Foreign_field.field_standard_limbs_is_zero (module Circuit) a) then (
      (* x^2 + a *)
      let a =
        let a0, a1, a2 =
          exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
              let a0, a1, a2 = a in
              [| a0; a1; a2 |] )
          |> Common.tuple3_of_array
        in
        Foreign_field.Element.Standard.of_limbs (a0, a1, a2)
      in
      let x_squared_a =
        Foreign_field.add
          (module Circuit)
          ~full:false x_squared a foreign_field_modulus
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
      external_checks x_squared_a x foreign_field_modulus
  in

  (* Bounds 3: Left input already checked by (Bounds 2) or (Bounds 1)
   *           Right input is gadget input so checked externally
   *           Result bound check already tracked by external_checks
   *)

  (* C4: Optionally constrain addition of curve parameter b *)
  let x_cubed_ax_b =
    if not (Foreign_field.field_standard_limbs_is_zero (module Circuit) b) then (
      (* (x^2 + a) * x + b *)
      let b =
        let b0, b1, b2 =
          exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
              let b0, b1, b2 = b in
              [| b0; b1; b2 |] )
          |> Common.tuple3_of_array
        in
        Foreign_field.Element.Standard.of_limbs (b0, b1, b2)
      in
      let x_cubed_ax_b =
        Foreign_field.add
          (module Circuit)
          ~full:false x_cubed_ax b foreign_field_modulus
      in

      (* Bounds 4: Left input already checked by (Bounds 3)
       *           Right input public parameter (no check necessary)
       *           Result bound check below
       *)

      (* Add x_cubed_ax_b bound check *)
      Foreign_field.External_checks.append_bound_check external_checks
      @@ Foreign_field.Element.Standard.to_limbs x_cubed_ax_b ;

      (* Zero gate with result x_cubed_ax_b *)
      let x_cubed_ax_b0, x_cubed_ax_b1, x_cubed_ax_b2 =
        Foreign_field.Element.Standard.to_limbs x_cubed_ax_b
      in
      with_label "group_is_on_curve_x_cubed_ax_b" (fun () ->
          assert_
            { annotation = Some __LOC__
            ; basic =
                Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                  (Raw
                     { kind = Zero
                     ; values =
                         [| x_cubed_ax_b0; x_cubed_ax_b1; x_cubed_ax_b2 |]
                     ; coeffs = [||]
                     } )
            } ) ;

      x_cubed_ax_b )
    else x_cubed_ax
  in

  (* C5: y^2 = y * y *)
  let y_squared =
    Foreign_field.mul (module Circuit) external_checks y y foreign_field_modulus
  in

  (* Bounds 5: Left and right inputs are gadget input so checked externally
   *           Result bound check already tracked by external_checks
   *)

  (* Copy y_squared to x_cubed_ax_b *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    y_squared x_cubed_ax_b ;
  ()

(* Gadget to constrain that initial accumulator point is on elliptic curve and the computation of its negation *)
let group_check_ia (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t)
    (ai : f Affine.t * f Affine.t)
    ?(a =
      ( Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero ))
    ?(b =
      ( Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero ))
    (foreign_field_modulus : f Foreign_field.standard_limbs) =
  let open Circuit in
  let init_acc, expected_neg_init_acc = ai in
  (* C1: Check that initial accumulator point is on curve *)
  group_is_on_curve
    (module Circuit)
    external_checks init_acc ~a ~b foreign_field_modulus ;

  (* C2: Constrain computation of the negated initial accumulator point *)
  let neg_init_acc =
    group_negate (module Circuit) init_acc foreign_field_modulus
  in

  (* Bounds 1: Input is public constant
   *           Result is part of input (checked externally)
   *)
  let _, neg_init_y = Affine.to_coordinates neg_init_acc in

  (* Zero gate with result neg_init_y *)
  let neg_init_y0, neg_init_y1, neg_init_y2 =
    Foreign_field.Element.Standard.to_limbs neg_init_y
  in
  with_label "group_check_ia_neg_init_y" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Raw
                 { kind = Zero
                 ; values = [| neg_init_y0; neg_init_y1; neg_init_y2 |]
                 ; coeffs = [||]
                 } )
        } ) ;

  (* C3: Copy computed_neg_init_acc to neg_init_acc *)
  Affine.assert_equal (module Circuit) neg_init_acc expected_neg_init_acc ;

  (* P is on curve <=> -P is on curve, thus we do not need to check
   * neg_init_acc is on curve *)
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
 *      scalar                := Boolean array of scalar bits
 *      point                 := Affine point to scale
 *      ia                    := Initial accumulator point (and its negation)
 *      a                     := Elliptic curve a parameter
 *      foreign_field_modulus := Elliptic curve base field modulus
 *
 *   Preconditions and limitations:
 *      P is not O (the point at infinity)
 *      P's coordinates are bounds checked
 *      P is on the curve
 *      s is not zero
 *      z > 0
 *      ia point is randomly selected and constrained to be on the curve
 *      ia negated point computation is constrained
 *      ia coordinates are bounds checked
 *)
let group_scalar_mul (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t)
    (scalar : Circuit.Boolean.var array) (point : f Affine.t)
    (ia : f Affine.t * f Affine.t) ?(doubles : f Affine.t array option)
    ?(a =
      ( Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero ))
    (foreign_field_modulus : f Foreign_field.standard_limbs) : f Affine.t =
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
  let init_acc, neg_init_acc = ia in
  let acc, _base =
    Array.foldi scalar ~init:(init_acc, point) (* (acc, base) *)
      ~f:(fun i (acc, base) bit ->
        (* Add: sum = acc + base *)
        let sum =
          group_add
            (module Circuit)
            external_checks acc base foreign_field_modulus
        in
        (* Bounds 1:
         *   Left input is previous result, so already checked.
         *   Right input is checked by previous doubling check.
         *   Initial acc and base are gadget inputs and checked externally.
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
                group_double
                  (module Circuit)
                  external_checks base ~a foreign_field_modulus
              in
              (* Bounds 2:
               *   Input is previous result, so already checked.
               *   Initial base is gadget inputs and checked externally.
               *   Result bounds check below.
               *)
              Foreign_field.External_checks.append_bound_check external_checks
              @@ Foreign_field.Element.Standard.to_limbs @@ Affine.x double_base ;
              Foreign_field.External_checks.append_bound_check external_checks
              @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y double_base ;
              double_base
          | Some doubles ->
              (* When the base point is public (e.g. the secp256k1 generator)
               * they could be a precomputed public parameter *)
              doubles.(i)
        in

        (* Group add conditionally *)
        let acc = Affine.if_ (module Circuit) bit sum acc in

        (acc, double_base) )
  in

  (* Subtract init_point from accumulator for final result *)
  group_add
    (module Circuit)
    external_checks acc neg_init_acc foreign_field_modulus

(* Gadget to check point is in the subgroup
 *   nP = O
 * where n is the elliptic curve group order and O is the point at infinity
 *)
let group_check_subgroup (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t) (point : f Affine.t)
    (ia : f Affine.t * f Affine.t) ?(doubles : f Affine.t array option)
    ?(a =
      ( Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero ))
    (curve_order : f Foreign_field.standard_limbs)
    (foreign_field_modulus : f Foreign_field.standard_limbs) =
  let open Circuit in
  (* Useful helpers (TODO: Move to curve_params) *)
  let curve_order_bigint =
    Foreign_field.field_standard_limbs_to_bignum_bigint
      (module Circuit)
      curve_order
  in
  let scalar_bit_length = Common.bignum_bigint_bit_length curve_order_bigint in

  (* Subgroup check: nP = O
   *   We don't support identity element, so instead we check
   *     ((n - 1) + 1)P = O
   *     (n - 1)P = -P
   *)
  let n_minus_one_bits =
    (* TODO: This should be public curve parameter constants and not constrained here *)
    exists (Typ.array ~length:scalar_bit_length Boolean.typ) ~compute:(fun () ->
        Common.bignum_bigint_unpack Bignum_bigint.(curve_order_bigint - one) )
  in

  (* C1: Compute (n - 1)P *)
  let n_minus_one_point =
    group_scalar_mul
      (module Circuit)
      external_checks n_minus_one_bits point ia ?doubles ~a
      foreign_field_modulus
  in
  (* Bounds 1: Left input is public constant (no bounds check required)
   *           Right input is gadget input (checked externally)
   *           Result bound check below
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.x n_minus_one_point ;
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y n_minus_one_point ;

  (* C2: Compute -P *)
  let minus_point = group_negate (module Circuit) point foreign_field_modulus in
  (* Result row *)
  Foreign_field.result_row (module Circuit) ~label:"minus_point_y"
  @@ Affine.y minus_point ;
  (* Bounds 2: Input is gadget input (checked externally)
   *           Result bound check below
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y minus_point ;

  (* C3: Assert (n - 1)P = -P *)
  Affine.assert_equal (module Circuit) n_minus_one_point minus_point

(* Gadget for constraining ECDSA signature verification
 *
 *   Inputs:
 *     external_checks       := Context to track required external checks
 *     pubkey                := Public key of signer
 *     signature             := ECDSA signature (r, s) s.t. r, s \in [1, n)
 *     hash                  := Message hash s.t. hash \in Fn
 *     ia                    := Initial accumulator point (and its negation)
 *     gen                   := Elliptic curve group generator point
 *     a                     := Elliptic curve a parameter
 *     b                     := Elliptic curve b parameter
 *     curve_order           := Elliptic curve group order (scalar field modulus)
 *     foreign_field_modulus := Elliptic curve base field modulus
 *
 *   Preconditions:
 *      pubkey is on the curve and not O   (use group_is_on_curve gadget)
 *      pubkey is in the subgroup (nP = O) (use group_check_subgroup gadget)
 *      pubkey is bounds checked           (use multi-range-check gadgets)
 *      r, s \in [1, n)
 *      hash \in Fn                        (use bytes_to_foreign_field_element gadget)
 *
 *   Public parameters
 *      gen is the correct elliptic curve group generator point
 *      a, b are correct elliptic curve parameters
 *      curve_order is the correct elliptic curve group order
 *      foreign_field_modulus is the correct elliptic curve base field modulus
 *      ia point is randomly selected and constrained to be on the curve
 *      ia negated point computation is constrained
 *      ia coordinates are bounds checked
 *)
let ecdsa_verify (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t) (pubkey : f Affine.t)
    (signature :
      f Foreign_field.Element.Standard.t * f Foreign_field.Element.Standard.t )
    (hash : f Foreign_field.Element.Standard.t) (ia : f Affine.t * f Affine.t)
    (gen : f Affine.t) ?(doubles : f Affine.t array option)
    ?(a =
      ( Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero ))
    ?(b =
      ( Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero
      , Circuit.Field.Constant.zero ))
    (curve_order : f Foreign_field.standard_limbs)
    (foreign_field_modulus : f Foreign_field.standard_limbs) =
  let open Circuit in
  (* Signaures r and s *)
  let r, s = signature in

  (* Useful helpers *)
  let curve_order_bigint =
    Foreign_field.field_standard_limbs_to_bignum_bigint
      (module Circuit)
      curve_order
  in
  let scalar_bit_length = Common.bignum_bigint_bit_length curve_order_bigint in

  (* Compute witness value s^-1 *)
  let s_inv0, s_inv1, s_inv2 =
    exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
        let curve_order =
          Foreign_field.field_standard_limbs_to_bignum_bigint
            (module Circuit)
            curve_order
        in

        let s =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            s
        in

        (* Compute s^-1 *)
        let s_inv = Common.bignum_bigint_inverse s curve_order in

        (* Convert from Bignums to field elements *)
        let s_inv0, s_inv1, s_inv2 =
          Foreign_field.bignum_bigint_to_field_standard_limbs
            (module Circuit)
            s_inv
        in

        (* Return and convert back to Cvars *)
        [| s_inv0; s_inv1; s_inv2 |] )
    |> Common.tuple3_of_array
  in
  let s_inv =
    Foreign_field.Element.Standard.of_limbs (s_inv0, s_inv1, s_inv2)
  in

  (* C1: Constrain s * s^-1 = 1 *)
  let s_times_s_inv =
    (* s * s  = s^2 *)
    Foreign_field.mul (module Circuit) external_checks s s_inv curve_order
  in
  let one =
    Foreign_field.Element.Standard.of_bignum_bigint (module Circuit)
    @@ Bignum_bigint.one
  in
  Foreign_field.Element.Standard.assert_equal (module Circuit) s_times_s_inv one ;

  (* Bounds 1: Left input is gadget input (checked externally)
   *           Right input is witness value (checked below)
   *           Result bound check already tracked by external_checks.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
    (s_inv0, s_inv1, s_inv2) ;

  (* || Check modular reduction of z/hash *)
  (*    Addition method should be sufficient (same number of bits so can't be double size) *)

  (* C2: Constrain u1 = zs^-1 *)
  let u1 =
    Foreign_field.mul (module Circuit) external_checks hash s_inv curve_order
  in

  (* Bounds 2: Left input (hash) is gadget input (checked externally)
   *           Right input already checked by (Bounds 1)
   *           Result bound check already tracked by external_checks.
   *)

  (* C3: Constrain u2 = rs^-1 *)
  let u2 =
    Foreign_field.mul (module Circuit) external_checks r s_inv curve_order
  in

  (* Bounds 3: Left input r is gadget input (checked externally)
   *           Right input already checked by (Bounds 1)
   *           Result bound check already tracked by external_checks.
   *)

  (*
   * Compute R = u1G + u2P
   *)

  (* C4: Decompose u1 into bits *)
  let u1_bits =
    exists (Typ.array ~length:scalar_bit_length Boolean.typ) ~compute:(fun () ->
        Common.bignum_bigint_unpack
        @@ Foreign_field.Element.Standard.to_bignum_bigint_as_prover
             (module Circuit)
             u1 )
  in

  (* C5: Decompose u2 into bits *)
  let u2_bits =
    exists (Typ.array ~length:scalar_bit_length Boolean.typ) ~compute:(fun () ->
        Common.bignum_bigint_unpack
        @@ Foreign_field.Element.Standard.to_bignum_bigint_as_prover
             (module Circuit)
             u2 )
  in

  (* C6: Constrain scalar multiplication u1G *)
  let u1_point =
    group_scalar_mul
      (module Circuit)
      external_checks u1_bits gen ia ?doubles ~a foreign_field_modulus
  in

  (* Bounds 6: Point gen is gadget input (checked externally)
   *           Initial accumulator is gadget input (checked externally)
   *           Result bound check for u1_point below.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.x u1_point ;
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y u1_point ;

  (* C7: Constrain scalar multiplication u2P *)
  let u2_point =
    group_scalar_mul
      (module Circuit)
      external_checks u2_bits pubkey ia ?doubles ~a foreign_field_modulus
  in
  (* Bounds 7: Point gen is gadget input (checked externally)
   *           Initial accumulator is gadget input (checked externally)
   *           Result bound check for u1_point below.
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.x u2_point ;
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y u2_point ;

  (* C8: R = u1G + u2P *)
  let result =
    group_add
      (module Circuit)
      external_checks u1_point u2_point foreign_field_modulus
  in

  (* Bounds 8: Left and right inputs checked by (Bounds 6) and (Bounds 7)
   *           Result bound is bound checked below
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.x result ;
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y result ;

  (* Constrain that r = Rx (mod n), where n is the scalar field modulus
   *
   *   Note: The scalar field modulus (curve_order) may be greater or smaller than
   *         the base field modulus (foreign_field_modulus)
   *
   *           curve_order > foreign_field_modulus => Rx = 0 * n + Rx
   *
   *           curve_order < foreign_field_modulus  => Rx = q * n + Rx'
   *
   *  Thus, to check for congruence we need to compute the modular reduction of Rx and
   *  assert that it equals r.
   *
   *  Since we may want to target applications where the scalar field is much smaller
   *  than the base field, so we cannot make any assumptions about the ratio between
   *  these moduli, so we will constrain Rx = q * n + Rx' using the foreign field
   *  multiplication gadget, rather than just constraining Rx + 0 with our foreign
   *  field addition gadget.
   *
   *  As we are reducing Rx modulo n, we are performing foreign field arithmetic modulo n.
   *  However, the multiplicand n above is not a valid foreign field element in [0, n - 1].
   *  To be safe we must constrain Rx = q * (n - 1) + q + Rx  modulo n.
   *)

  (* Compute witness value q and Rx' *)
  let quotient0, quotient1, quotient2, x_prime0, x_prime1, x_prime2 =
    exists (Typ.array ~length:6 Field.typ) ~compute:(fun () ->
        let curve_order =
          Foreign_field.field_standard_limbs_to_bignum_bigint
            (module Circuit)
            curve_order
        in

        let x =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            (Affine.x result)
        in

        (* Compute q and r of Rx = q * n + r *)
        let quotient, x_prime = Common.bignum_bigint_div_rem x curve_order in

        (* Convert from Bignums to field elements *)
        let quotient0, quotient1, quotient2 =
          Foreign_field.bignum_bigint_to_field_standard_limbs
            (module Circuit)
            quotient
        in
        let x_prime0, x_prime1, x_prime2 =
          Foreign_field.bignum_bigint_to_field_standard_limbs
            (module Circuit)
            x_prime
        in

        (* Return and convert back to Cvars *)
        [| quotient0; quotient1; quotient2; x_prime0; x_prime1; x_prime2 |] )
    |> tuple6_of_array
  in

  (* C9: Constrain q * (n - 1) *)
  let quotient =
    Foreign_field.Element.Standard.of_limbs (quotient0, quotient1, quotient2)
  in
  let n_minus_one =
    Foreign_field.Element.Standard.of_bignum_bigint (module Circuit)
    @@ Bignum_bigint.(curve_order_bigint - one)
  in
  let quotient_product =
    Foreign_field.mul
      (module Circuit)
      external_checks quotient n_minus_one curve_order
  in
  (* Bounds 9: Left input q is bound checked below
   *           Right input (n - 1) is a public parameter so not checked
   *           Result bound check is already covered by external_checks
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs quotient ;

  (* C10: Compute qn = q * (n - 1) + q *)
  let quotient_times_n =
    Foreign_field.add
      (module Circuit)
      ~full:false quotient_product quotient curve_order
  in

  (* Bounds 10: Left input q * (n - 1) is covered by (Bounds 9)
   *            Right input q is covered by (Bounds 9)
   *            Result is chained into subsequent addition (no check necessary)
   *)

  (* C11: Compute Rx = qn + Rx' *)
  let x_prime =
    Foreign_field.Element.Standard.of_limbs (x_prime0, x_prime1, x_prime2)
  in
  let computed_x =
    Foreign_field.add
      (module Circuit)
      ~full:false quotient_times_n x_prime curve_order
  in
  (* Addition chain final result row *)
  Foreign_field.result_row (module Circuit) ~label:"ecdsa_verify_computed_x" computed_x ;

  (* Bounds 11: Left input qn is chained input, so not checked
   *            Right input x_prime bounds checked below
   *            Result bound already checked by (Bounds 8)
   *)
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs x_prime ;

  (* C12: Check qn + r = Rx *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    computed_x (Affine.x result) ;

  (* C13: Check that r = x' *)
  Foreign_field.Element.Standard.assert_equal (module Circuit) r x_prime ;

  (* C14: Check result is on curve (also implies result is not infinity) *)
  group_is_on_curve
    (module Circuit)
    external_checks result ~a ~b foreign_field_modulus ;

  (* Bounds 14: Input already bound checked by (Bounds 8) *)
  ()

(***************)
(* Group tests *)
(***************)

let%test_unit "affine" =
  if group_tests_enabled then
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in
    (* Check Affine of_hex, to_hex_as_prover and equal_as_prover *)
    let _cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          let x =
            Foreign_field.Element.Standard.of_bignum_bigint (module Runner.Impl)
            @@ Common.bignum_bigint_of_hex
                 "5945fa400436f458cb9e994dcd315ded43e9b60eb68e2ae7b5cf1d07b48ca1c"
          in
          let y =
            Foreign_field.Element.Standard.of_bignum_bigint (module Runner.Impl)
            @@ Common.bignum_bigint_of_hex
                 "69cc93598e05239aa77b85d172a9785f6f0405af91d91094f693305da68bf15"
          in
          let affine_expected = Affine.of_coordinates (x, y) in
          as_prover (fun () ->
              let affine_hex =
                Affine.to_hex_as_prover (module Runner.Impl) affine_expected
              in
              (* 5945fa400436f458cb9e994dcd315ded43e9b60eb68e2ae7b5cf1d07b48ca1c000000000000000000000000069cc93598e05239aa77b85d172a9785f6f0405af91d91094f693305da68bf15 *)
              let affine = Affine.of_hex (module Runner.Impl) affine_hex in
              assert (
                Affine.equal_as_prover
                  (module Runner.Impl)
                  affine_expected affine ) ) ;

          (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
          let fake =
            exists Field.typ ~compute:(fun () -> Field.Constant.zero)
          in
          Boolean.Assert.is_true (Field.equal fake Field.zero) ;
          () )
    in
    ()

let%test_unit "group_add" =
  if group_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group add *)
    let test_group_add ?cs (left_input : bignum_point)
        (right_input : bignum_point) (expected_result : bignum_point)
        (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
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
              group_add
                (module Runner.Impl)
                unused_external_checks left_input right_input
                foreign_field_modulus
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
    let _cs =
      test_group_add
        (Bignum_bigint.of_int 4, Bignum_bigint.one) (* left_input *)
        (Bignum_bigint.of_int 0, Bignum_bigint.of_int 3) (* right_input *)
        (Bignum_bigint.of_int 0, Bignum_bigint.of_int 2) (* expected result *)
        (Bignum_bigint.of_int 5)
    in
    let _cs =
      test_group_add
        (Bignum_bigint.of_int 2, Bignum_bigint.of_int 3) (* left_input *)
        (Bignum_bigint.of_int 1, Bignum_bigint.of_int 0) (* right_input *)
        (Bignum_bigint.of_int 1, Bignum_bigint.of_int 0) (* expected result *)
        (Bignum_bigint.of_int 5)
    in

    (* Constraint system reuse tests *)
    let cs =
      test_group_add
        (Bignum_bigint.of_int 3, Bignum_bigint.of_int 8) (* left_input *)
        (Bignum_bigint.of_int 5, Bignum_bigint.of_int 11) (* right_input *)
        (Bignum_bigint.of_int 4, Bignum_bigint.of_int 10) (* expected result *)
        (Bignum_bigint.of_int 13)
    in
    let _cs =
      test_group_add ~cs
        (Bignum_bigint.of_int 10, Bignum_bigint.of_int 4) (* left_input *)
        (Bignum_bigint.of_int 12, Bignum_bigint.of_int 7) (* right_input *)
        (Bignum_bigint.of_int 3, Bignum_bigint.of_int 0) (* expected result *)
        (Bignum_bigint.of_int 13)
    in
    let _cs =
      test_group_add ~cs
        (Bignum_bigint.of_int 8, Bignum_bigint.of_int 6) (* left_input *)
        (Bignum_bigint.of_int 2, Bignum_bigint.of_int 1) (* right_input *)
        (Bignum_bigint.of_int 12, Bignum_bigint.of_int 8) (* expected result *)
        (Bignum_bigint.of_int 13)
    in

    (* Negative tests *)
    assert (
      Common.is_error (fun () ->
          (* Wrong constraint system (changed modulus) *)
          test_group_add ~cs
            (Bignum_bigint.of_int 8, Bignum_bigint.of_int 6) (* left_input *)
            (Bignum_bigint.of_int 2, Bignum_bigint.of_int 1) (* right_input *)
            (Bignum_bigint.of_int 12, Bignum_bigint.of_int 8)
            (* expected result *)
            (Bignum_bigint.of_int 9) ) ) ;
    assert (
      Common.is_error (fun () ->
          (* Wrong answer (right modulus) *)
          test_group_add ~cs
            (Bignum_bigint.of_int 8, Bignum_bigint.of_int 6) (* left_input *)
            (Bignum_bigint.of_int 2, Bignum_bigint.of_int 1) (* right_input *)
            (Bignum_bigint.of_int 12, Bignum_bigint.of_int 9)
            (* expected result *)
            (Bignum_bigint.of_int 13) ) ) ;

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

    assert (secp256k1_is_on_curve secp256k1_generator) ;
    assert (secp256k1_is_on_curve random_point1) ;
    assert (secp256k1_is_on_curve expected_result1) ;

    let _cs =
      test_group_add random_point1 (* left_input *)
        secp256k1_generator (* right_input *)
        expected_result1 (* expected result *)
        secp256k1_modulus
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

    assert (secp256k1_is_on_curve random_point2) ;
    assert (secp256k1_is_on_curve expected_result2) ;

    let _cs =
      test_group_add expected_result1 (* left_input *)
        random_point2 (* right_input *)
        expected_result2 (* expected result *)
        secp256k1_modulus
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

    assert (secp256k1_is_on_curve random_point3) ;
    assert (secp256k1_is_on_curve random_point4) ;
    assert (secp256k1_is_on_curve expected_result3) ;

    let _cs =
      test_group_add random_point3 (* left_input *)
        random_point4 (* right_input *)
        expected_result3 (* expected result *)
        secp256k1_modulus
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

    assert (secp256k1_is_on_curve pt1) ;
    assert (secp256k1_is_on_curve pt2) ;
    assert (secp256k1_is_on_curve expected_pt) ;

    let cs =
      test_group_add pt1 (* left_input *)
        pt2 (* right_input *)
        expected_pt (* expected result *)
        secp256k1_modulus
    in

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

    assert (secp256k1_is_on_curve pt1) ;
    assert (secp256k1_is_on_curve pt2) ;
    assert (secp256k1_is_on_curve expected_pt) ;

    let _cs =
      test_group_add ~cs pt1 (* left_input *)
        pt2 (* right_input *)
        expected_pt (* expected result *)
        secp256k1_modulus
    in

    let expected2 =
      ( Bignum_bigint.of_string
          "23989387498834566531803335539224216637656125335573670100510541031866883369583"
      , Bignum_bigint.of_string
          "8780199033752628541949962988447578555155504633890539264032735153636423550500"
      )
    in

    assert (secp256k1_is_on_curve expected2) ;

    let _cs =
      test_group_add ~cs expected_pt (* left_input *)
        pt1 (* right_input *)
        expected2 (* expected result *)
        secp256k1_modulus
    in

    (* Negative tests *)
    assert (
      Common.is_error (fun () ->
          (* Wrong constraint system (changed modulus) *)
          test_group_add ~cs expected_pt (* left_input *)
            pt1 (* right_input *)
            expected2
            (* expected result *)
            (Bignum_bigint.of_int 9) ) ) ;

    assert (
      Common.is_error (fun () ->
          (* Wrong result *)
          test_group_add ~cs expected_pt (* left_input *)
            pt1 (* right_input *)
            expected_pt (* expected result *)
            secp256k1_modulus ) ) ;

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

    assert (secp256k1_is_on_curve first_eth_tx_pubkey) ;
    assert (secp256k1_is_on_curve vitalik_eth_pubkey) ;
    assert (secp256k1_is_on_curve expected_result) ;

    let _cs =
      test_group_add ~cs first_eth_tx_pubkey (* left_input *)
        vitalik_eth_pubkey (* right_input *)
        expected_result (* expected result *)
        secp256k1_modulus
    in

    () )

let%test_unit "group_add_chained" =
  if group_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test chained group add *)
    let test_group_add_chained ?cs ?(chain_left = true)
        (left_input : bignum_point) (right_input : bignum_point)
        (input2 : bignum_point) (expected_result : bignum_point)
        (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
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
              group_add
                (module Runner.Impl)
                unused_external_checks left_input right_input
                foreign_field_modulus
            in

            let result2 =
              if chain_left then
                (* S + T = U *)
                (* Chain result to left input *)
                group_add
                  (module Runner.Impl)
                  unused_external_checks result1 input2 foreign_field_modulus
              else
                (* Chain result to right input *)
                (* T + S = U *)
                group_add
                  (module Runner.Impl)
                  unused_external_checks input2 result1 foreign_field_modulus
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

    assert (secp256k1_is_on_curve pt1) ;
    assert (secp256k1_is_on_curve pt2) ;
    assert (secp256k1_is_on_curve pt3) ;
    assert (secp256k1_is_on_curve expected) ;

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
    let _cs =
      test_group_add_chained pt1 (* left_input *)
        pt2 (* right_input *)
        pt3 (* input2 *)
        expected (* expected result *)
        secp256k1_modulus
    in

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
      test_group_add_chained ~chain_left:false pt1 (* left_input *)
        pt2 (* right_input *)
        pt3 (* input2 *)
        expected (* expected result *)
        secp256k1_modulus
    in
    () )

let%test_unit "group_add_full" =
  if group_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test full group add (with bounds cehcks) *)
    let test_group_add_full ?cs (left_input : bignum_point)
        (right_input : bignum_point) (expected_result : bignum_point)
        (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
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
              group_add
                (module Runner.Impl)
                external_checks left_input right_input foreign_field_modulus
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

            (* 1) Add gates for external bound additions.
             *    Note: internally this also adds multi-range-checks for the
             *    computed bound to the external_checks.multi-ranges, which
             *    are then constrainted in (2)
             *)
            assert (Mina_stdlib.List.Length.equal external_checks.bounds 12) ;
            List.iter external_checks.bounds ~f:(fun value ->
                let _bound =
                  Foreign_field.valid_element
                    (module Runner.Impl)
                    external_checks
                    (Foreign_field.Element.Standard.of_limbs value)
                    foreign_field_modulus
                in
                () ) ;

            (* 2) Add gates for external multi-range-checks *)
            assert (
              Mina_stdlib.List.Length.equal external_checks.multi_ranges 15 ) ;
            List.iter external_checks.multi_ranges ~f:(fun multi_range ->
                let v0, v1, v2 = multi_range in
                Range_check.multi (module Runner.Impl) v0 v1 v2 ;
                () ) ;

            (* 3) Add gates for external compact-multi-range-checks *)
            assert (
              Mina_stdlib.List.Length.equal external_checks.compact_multi_ranges
                3 ) ;
            List.iter external_checks.compact_multi_ranges
              ~f:(fun compact_multi_range ->
                let v01, v2 = compact_multi_range in
                Range_check.compact_multi (module Runner.Impl) v01 v2 ;
                () ) ;
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

    assert (secp256k1_is_on_curve pt1) ;
    assert (secp256k1_is_on_curve pt2) ;
    assert (secp256k1_is_on_curve expected) ;

    let _cs =
      test_group_add_full pt1 (* left_input *)
        pt2 (* right_input *)
        expected (* expected result *)
        secp256k1_modulus
    in
    () )

let%test_unit "group_double" =
  if group_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group double *)
    let test_group_double ?cs (point : bignum_point)
        (expected_result : bignum_point) ?(a = Bignum_bigint.zero)
        (* curve parameter a *)
          (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let a =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                a
            in
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
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
              group_double
                (module Runner.Impl)
                unused_external_checks point ~a foreign_field_modulus
            in

            (* Check for expected quantity of external checks *)
            if Foreign_field.field_standard_limbs_is_zero (module Runner.Impl) a
            then
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
      let a = Bignum_bigint.of_int 2 in
      let b = Bignum_bigint.of_int 5 in
      let modulus = Bignum_bigint.of_int 13 in
      let point = (Bignum_bigint.of_int 2, Bignum_bigint.of_int 2) in
      let expected_result = (Bignum_bigint.of_int 5, Bignum_bigint.of_int 7) in
      assert (is_on_curve point a b modulus) ;
      assert (is_on_curve expected_result a b modulus) ;
      test_group_double point (* point *)
        expected_result (* expected result *)
        ~a modulus
    in

    (* Test with elliptic curve y^2 = x^3 + 5 mod 13 *)
    let _cs =
      let a = Bignum_bigint.of_int 0 in
      let b = Bignum_bigint.of_int 5 in
      let modulus = Bignum_bigint.of_int 13 in
      let point = (Bignum_bigint.of_int 4, Bignum_bigint.of_int 2) in
      let expected_result = (Bignum_bigint.of_int 6, Bignum_bigint.of_int 0) in
      assert (is_on_curve point a b modulus) ;
      assert (is_on_curve expected_result a b modulus) ;
      test_group_double point (* point *)
        expected_result (* expected result *)
        modulus
    in

    (* Test with elliptic curve y^2 = x^3 + 7 mod 13 *)
    let cs0 =
      let a = Bignum_bigint.of_int 0 in
      let b = Bignum_bigint.of_int 7 in
      let modulus = Bignum_bigint.of_int 13 in
      let point = (Bignum_bigint.of_int 7, Bignum_bigint.of_int 8) in
      let expected_result = (Bignum_bigint.of_int 8, Bignum_bigint.of_int 8) in
      assert (is_on_curve point a b modulus) ;
      assert (is_on_curve expected_result a b modulus) ;
      let cs =
        test_group_double point (* point *)
          expected_result (* expected result *)
          modulus
      in
      let _cs =
        test_group_double point (* point *)
          expected_result (* expected result *)
          ~a modulus
      in
      cs
    in

    (* Test with elliptic curve y^2 = x^3 + 17 * x mod 7879 *)
    let cs17 =
      let a = Bignum_bigint.of_int 17 in
      let b = Bignum_bigint.of_int 0 in
      let modulus = Bignum_bigint.of_int 7879 in
      let point = (Bignum_bigint.of_int 7331, Bignum_bigint.of_int 888) in
      let expected_result =
        (Bignum_bigint.of_int 2754, Bignum_bigint.of_int 3623)
      in
      assert (is_on_curve point a b modulus) ;
      assert (is_on_curve expected_result a b modulus) ;
      test_group_double point (* point *)
        expected_result (* expected result *)
        ~a modulus
    in

    (* Constraint system reuse tests *)
    let _cs =
      let a = Bignum_bigint.of_int 0 in
      let b = Bignum_bigint.of_int 7 in
      let modulus = Bignum_bigint.of_int 13 in
      let point = (Bignum_bigint.of_int 8, Bignum_bigint.of_int 8) in
      let expected_result = (Bignum_bigint.of_int 11, Bignum_bigint.of_int 8) in
      assert (is_on_curve point a b modulus) ;
      assert (is_on_curve expected_result a b modulus) ;
      test_group_double ~cs:cs0 point (* point *)
        expected_result (* expected result *)
        ~a modulus
    in

    let _cs =
      let a = Bignum_bigint.of_int 17 in
      let b = Bignum_bigint.of_int 0 in
      let modulus = Bignum_bigint.of_int 7879 in
      let point = (Bignum_bigint.of_int 1729, Bignum_bigint.of_int 4830) in
      let expected_result =
        (Bignum_bigint.of_int 6020, Bignum_bigint.of_int 5832)
      in
      assert (is_on_curve point a b modulus) ;
      assert (is_on_curve expected_result a b modulus) ;
      let _cs =
        test_group_double ~cs:cs17 point (* point *)
          expected_result (* expected result *)
          ~a modulus
      in

      (* Negative test *)
      assert (
        Common.is_error (fun () ->
            (* Wrong constraint system *)
            test_group_double ~cs:cs0 point (* point *)
              expected_result (* expected result *)
              ~a modulus ) ) ;
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

    assert (secp256k1_is_on_curve point) ;
    assert (secp256k1_is_on_curve expected_result) ;

    let _cs = test_group_double point expected_result secp256k1_modulus in

    let expected_result =
      ( Bignum_bigint.of_string
          "89565891926547004231252920425935692360644145829622209833684329913297188986597"
      , Bignum_bigint.of_string
          "12158399299693830322967808612713398636155367887041628176798871954788371653930"
      )
    in

    assert (secp256k1_is_on_curve secp256k1_generator) ;
    assert (secp256k1_is_on_curve expected_result) ;

    let _cs =
      test_group_double secp256k1_generator expected_result secp256k1_modulus
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

    assert (secp256k1_is_on_curve point) ;
    assert (secp256k1_is_on_curve expected_result) ;

    let _cs = test_group_double point expected_result secp256k1_modulus in

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
    assert (secp256k1_is_on_curve point) ;
    assert (secp256k1_is_on_curve expected_result) ;

    let cs = test_group_double point expected_result secp256k1_modulus in

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
    assert (secp256k1_is_on_curve point) ;
    assert (secp256k1_is_on_curve expected_result) ;

    let _cs = test_group_double ~cs point expected_result secp256k1_modulus in

    (* Negative tests *)
    assert (
      Common.is_error (fun () ->
          (* Wrong constraint system *)
          test_group_double ~cs:cs0 point (* point *)
            expected_result (* expected result *)
            secp256k1_modulus ) ) ;

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
          test_group_double point (* point *)
            wrong_result (* expected result *)
            secp256k1_modulus ) ) ;

    () )

let%test_unit "group_double_chained" =
  if group_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group double chaining *)
    let test_group_double_chained ?cs (point : bignum_point)
        (expected_result : bignum_point) ?(a = Bignum_bigint.zero)
        (* curve parameter a *)
          (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let a =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                a
            in
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
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
              group_double
                (module Runner.Impl)
                unused_external_checks point ~a foreign_field_modulus
            in
            let result =
              group_double
                (module Runner.Impl)
                unused_external_checks result ~a foreign_field_modulus
            in

            (* Check for expected quantity of external checks *)
            if Foreign_field.field_standard_limbs_is_zero (module Runner.Impl) a
            then
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
      let a = Bignum_bigint.of_int 17 in
      let b = Bignum_bigint.of_int 0 in
      let modulus = Bignum_bigint.of_int 7879 in
      let point = (Bignum_bigint.of_int 1729, Bignum_bigint.of_int 4830) in
      let expected_result =
        (Bignum_bigint.of_int 355, Bignum_bigint.of_int 3132)
      in
      assert (is_on_curve point a b modulus) ;
      assert (is_on_curve expected_result a b modulus) ;
      test_group_double_chained point expected_result ~a modulus
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

    assert (secp256k1_is_on_curve point) ;
    assert (secp256k1_is_on_curve expected_result) ;

    let _cs =
      test_group_double_chained point expected_result secp256k1_modulus
    in
    () )

let%test_unit "group_double_full" =
  if group_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group double (full circuit with external checks) *)
    let test_group_double_full ?cs (point : bignum_point)
        (expected_result : bignum_point) ?(a = Bignum_bigint.zero)
        (* curve parameter a *)
          (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let a =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                a
            in
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
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
              group_double
                (module Runner.Impl)
                external_checks point ~a foreign_field_modulus
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

            (* 1) Add gates for external bound additions.
             *    Note: internally this also adds multi-range-checks for the
             *    computed bound to the external_checks.multi-ranges, which
             *    are then constrainted in (2)
             *)
            if Foreign_field.field_standard_limbs_is_zero (module Runner.Impl) a
            then assert (Mina_stdlib.List.Length.equal external_checks.bounds 12)
            else assert (Mina_stdlib.List.Length.equal external_checks.bounds 13) ;
            List.iter external_checks.bounds ~f:(fun value ->
                let _bound =
                  Foreign_field.valid_element
                    (module Runner.Impl)
                    external_checks
                    (Foreign_field.Element.Standard.of_limbs value)
                    foreign_field_modulus
                in
                () ) ;

            (* 2) Add gates for external multi-range-checks *)
            assert (
              Mina_stdlib.List.Length.equal external_checks.multi_ranges 16 ) ;
            List.iter external_checks.multi_ranges ~f:(fun multi_range ->
                let v0, v1, v2 = multi_range in
                Range_check.multi (module Runner.Impl) v0 v1 v2 ;
                () ) ;

            (* 3) Add gates for external compact-multi-range-checks *)
            assert (
              Mina_stdlib.List.Length.equal external_checks.compact_multi_ranges
                4 ) ;
            List.iter external_checks.compact_multi_ranges
              ~f:(fun compact_multi_range ->
                let v01, v2 = compact_multi_range in
                Range_check.compact_multi (module Runner.Impl) v01 v2 ;
                () ) ;

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

    assert (secp256k1_is_on_curve point) ;
    assert (secp256k1_is_on_curve expected_result) ;

    let _cs = test_group_double_full point expected_result secp256k1_modulus in

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

    assert (secp256k1_is_on_curve point) ;
    assert (secp256k1_is_on_curve expected_result) ;

    let _cs = test_group_double_full point expected_result secp256k1_modulus in

    () )

let%test_unit "group_ops_mixed" =
  if group_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test mix of group operations (e.g. things are wired correctly *)
    let test_group_ops_mixed ?cs (left_input : bignum_point)
        (right_input : bignum_point) (expected_result : bignum_point)
        ?(a = Bignum_bigint.zero)
        (* curve parameter a *)
          (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let a =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                a
            in
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
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
              group_add
                (module Runner.Impl)
                unused_external_checks left_input right_input
                foreign_field_modulus
            in

            (* S + S = D *)
            let double =
              group_double
                (module Runner.Impl)
                unused_external_checks sum ~a foreign_field_modulus
            in

            (* Check for expected quantity of external checks *)
            if Foreign_field.field_standard_limbs_is_zero (module Runner.Impl) a
            then
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
      let a = Bignum_bigint.of_int 17 in
      let b = Bignum_bigint.of_int 0 in
      let modulus = Bignum_bigint.of_int 7879 in
      let point1 = (Bignum_bigint.of_int 1729, Bignum_bigint.of_int 4830) in
      let point2 = (Bignum_bigint.of_int 993, Bignum_bigint.of_int 622) in
      let expected_result =
        (Bignum_bigint.of_int 6762, Bignum_bigint.of_int 4635)
      in
      assert (is_on_curve point1 a b modulus) ;
      assert (is_on_curve point2 a b modulus) ;
      assert (is_on_curve expected_result a b modulus) ;

      test_group_ops_mixed point1 point2 expected_result ~a modulus
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

    assert (secp256k1_is_on_curve point1) ;
    assert (secp256k1_is_on_curve point2) ;
    assert (secp256k1_is_on_curve expected_result) ;

    let _cs =
      test_group_ops_mixed point1 point2 expected_result secp256k1_modulus
    in
    () )

let%test_unit "group_properties" =
  if group_tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group properties *)
    let test_group_properties ?cs (point_a : bignum_point)
        (point_b : bignum_point) (point_c : bignum_point)
        (expected_commutative_result : bignum_point)
        (expected_associative_result : bignum_point)
        (expected_distributive_result : bignum_point) ?(a = Bignum_bigint.zero)
        (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let a =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                a
            in
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
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
              group_add
                (module Runner.Impl)
                unused_external_checks point_a point_b foreign_field_modulus
            in

            let b_plus_a =
              (* B + A *)
              group_add
                (module Runner.Impl)
                unused_external_checks point_b point_a foreign_field_modulus
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
              group_add
                (module Runner.Impl)
                unused_external_checks point_b point_c foreign_field_modulus
            in

            let a_plus_b_plus_c =
              (* (A + B) + C *)
              group_add
                (module Runner.Impl)
                unused_external_checks a_plus_b point_c foreign_field_modulus
            in

            let b_plus_c_plus_a =
              (* A + (B + C) *)
              group_add
                (module Runner.Impl)
                unused_external_checks point_a b_plus_c foreign_field_modulus
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
              group_double
                (module Runner.Impl)
                unused_external_checks a_plus_b ~a foreign_field_modulus
            in

            let double_a =
              (* 2 * A *)
              group_double
                (module Runner.Impl)
                unused_external_checks point_a ~a foreign_field_modulus
            in

            let double_b =
              (* 2 * B *)
              group_double
                (module Runner.Impl)
                unused_external_checks point_b ~a foreign_field_modulus
            in

            let sum_of_doubles =
              (* 2 * A + 2 * B *)
              group_add
                (module Runner.Impl)
                unused_external_checks double_a double_b foreign_field_modulus
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

    assert (secp256k1_is_on_curve point_a) ;
    assert (secp256k1_is_on_curve point_b) ;
    assert (secp256k1_is_on_curve point_c) ;
    assert (secp256k1_is_on_curve expected_commutative_result) ;
    assert (secp256k1_is_on_curve expected_associative_result) ;
    assert (secp256k1_is_on_curve expected_distributive_result) ;

    let _cs =
      test_group_properties point_a point_b point_c expected_commutative_result
        expected_associative_result expected_distributive_result
        secp256k1_modulus
    in

    (*
     * Test with NIST P-224 curve
     *     y^2 = x^3 -3 * x + 18958286285566608000408668544493926415504680968679321075787234672564
     *)
    let p224_modulus =
      Bignum_bigint.of_string
        "0xffffffffffffffffffffffffffffffff000000000000000000000001"
    in
    let a_param =
      (* - 3 *)
      Bignum_bigint.of_string
        "0xfffffffffffffffffffffffffffffffefffffffffffffffffffffffe"
      (* Note: p224 a_param < vesta_modulus *)
    in
    let b_param =
      (* 18958286285566608000408668544493926415504680968679321075787234672564 *)
      Bignum_bigint.of_string
        "0xb4050a850c04b3abf54132565044b0b7d7bfd8ba270b39432355ffb4"
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
    assert (is_on_curve point_a a_param b_param p224_modulus) ;
    assert (is_on_curve point_b a_param b_param p224_modulus) ;
    assert (is_on_curve point_c a_param b_param p224_modulus) ;
    assert (is_on_curve expected_commutative_result a_param b_param p224_modulus) ;
    assert (is_on_curve expected_associative_result a_param b_param p224_modulus) ;
    assert (
      is_on_curve expected_distributive_result a_param b_param p224_modulus ) ;

    let _cs =
      test_group_properties point_a point_b point_c expected_commutative_result
        expected_associative_result expected_distributive_result ~a:a_param
        p224_modulus
    in

    (*
     * Test with bn254 curve
     *     y^2 = x^3 + 0 * x + 2
     *)
    let bn254_modulus =
      Bignum_bigint.of_string
        "16798108731015832284940804142231733909889187121439069848933715426072753864723"
    in
    let a_param = Bignum_bigint.of_int 0 in
    let b_param = Bignum_bigint.of_int 2 in

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
    assert (is_on_curve point_a a_param b_param bn254_modulus) ;
    assert (is_on_curve point_b a_param b_param bn254_modulus) ;
    assert (is_on_curve point_c a_param b_param bn254_modulus) ;
    assert (
      is_on_curve expected_commutative_result a_param b_param bn254_modulus ) ;
    assert (
      is_on_curve expected_associative_result a_param b_param bn254_modulus ) ;
    assert (
      is_on_curve expected_distributive_result a_param b_param bn254_modulus ) ;

    let _cs =
      test_group_properties point_a point_b point_c expected_commutative_result
        expected_associative_result expected_distributive_result ~a:a_param
        bn254_modulus
    in

    (*
     * Test with (Pasta) Pallas curve (on Vesta native)
     *     y^2 = x^3 + 5
     *)
    let pallas_modulus =
      Bignum_bigint.of_string
        "28948022309329048855892746252171976963363056481941560715954676764349967630337"
    in
    let a_param = Bignum_bigint.of_int 0 in
    let b_param = Bignum_bigint.of_int 5 in

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
    assert (is_on_curve point_a a_param b_param pallas_modulus) ;
    assert (is_on_curve point_b a_param b_param pallas_modulus) ;
    assert (is_on_curve point_c a_param b_param pallas_modulus) ;
    assert (
      is_on_curve expected_commutative_result a_param b_param pallas_modulus ) ;
    assert (
      is_on_curve expected_associative_result a_param b_param pallas_modulus ) ;
    assert (
      is_on_curve expected_distributive_result a_param b_param pallas_modulus ) ;

    let _cs =
      test_group_properties point_a point_b point_c expected_commutative_result
        expected_associative_result expected_distributive_result ~a:a_param
        pallas_modulus
    in

    () )

(*******************************)
(* Scalar multiplication tests *)
(*******************************)

let%test_unit "group_is_on_curve" =
  if (* group_scalar_mul_tests *) false then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group_is_on_curve *)
    let test_group_is_on_curve ?cs (point : bignum_point)
        ?(a = Bignum_bigint.zero) ?(b = Bignum_bigint.zero)
        (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            (* Prepare test inputs *)
            let a =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                a
            in
            let b =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                b
            in
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
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
            group_is_on_curve
              (module Runner.Impl)
              unused_external_checks point ~a ~b foreign_field_modulus ;

            (* Check for expected quantity of external checks *)
            let bounds_checks_count = ref 3 in
            if
              not
                (Foreign_field.field_standard_limbs_is_zero
                   (module Runner.Impl)
                   a )
            then bounds_checks_count := !bounds_checks_count + 1 ;
            if
              not
                (Foreign_field.field_standard_limbs_is_zero
                   (module Runner.Impl)
                   b )
            then bounds_checks_count := !bounds_checks_count + 1 ;
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

    (* Positive tests *)
    let _cs =
      test_group_is_on_curve secp256k1_generator ~a:secp256k1_a ~b:secp256k1_b
        secp256k1_modulus
    in

    let good_pt =
      ( Bignum_bigint.of_string
          "18950551679048287927361677965259288422489066940346827203675447914841748996155"
      , Bignum_bigint.of_string
          "47337572658241658062145739798014345835092764795141449413289521900680935648400"
      )
    in
    let _cs =
      test_group_is_on_curve good_pt ~a:secp256k1_a ~b:secp256k1_b
        secp256k1_modulus
    in
    let neg_good_pt =
      let x, y = good_pt in
      (x, Bignum_bigint.((zero - y) % secp256k1_modulus))
    in
    let _cs =
      test_group_is_on_curve neg_good_pt ~a:secp256k1_a ~b:secp256k1_b
        secp256k1_modulus
    in

    (* Test with y^2 = x^3 -3 * x + 18958286285566608000408668544493926415504680968679321075787234672564 *)
    let c0_modulus =
      Bignum_bigint.of_string
        "0xffffffffffffffffffffffffffffffff000000000000000000000001"
    in
    let c0_a_param =
      (* -3 *)
      Bignum_bigint.of_string
        "0xfffffffffffffffffffffffffffffffefffffffffffffffffffffffe"
    in
    let c0_b_param =
      Bignum_bigint.of_string
        "18958286285566608000408668544493926415504680968679321075787234672564"
    in

    let point =
      ( Bignum_bigint.of_string
          "20564182195513988720077877094445678909500371329094056390559170498601"
      , Bignum_bigint.of_string
          "2677931089606376366731934050370502738338362171950142296573730478996"
      )
    in
    let _cs =
      test_group_is_on_curve point ~a:c0_a_param ~b:c0_b_param c0_modulus
    in

    (* Test with elliptic curve y^2 = x^3 + 17 * x mod 7879 *)
    let c1_a_param = Bignum_bigint.of_int 17 in
    let c1_b_param = Bignum_bigint.of_int 0 in
    let c1_modulus = Bignum_bigint.of_int 7879 in
    let _cs =
      let point = (Bignum_bigint.of_int 7331, Bignum_bigint.of_int 888) in
      test_group_is_on_curve point ~a:c1_a_param ~b:c1_b_param c1_modulus
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
          test_group_is_on_curve bad_pt ~a:secp256k1_a ~b:secp256k1_b
            secp256k1_modulus ) ) ;

    assert (
      Common.is_error (fun () ->
          let bad_pt = (Bignum_bigint.zero, Bignum_bigint.one) in
          test_group_is_on_curve bad_pt ~a:secp256k1_a ~b:secp256k1_b
            secp256k1_modulus ) ) ;
    assert (
      Common.is_error (fun () ->
          let bad_pt = (Bignum_bigint.one, Bignum_bigint.one) in
          test_group_is_on_curve bad_pt ~a:c0_a_param ~b:c0_b_param c0_modulus ) ) ;
    assert (
      Common.is_error (fun () ->
          let bad_pt = (Bignum_bigint.of_int 2, Bignum_bigint.of_int 77) in
          test_group_is_on_curve bad_pt ~a:c1_a_param ~b:c1_b_param c1_modulus ) ) ;

    () )

let%test_unit "group_check_ia" =
  if (* group_scalar_mul_tests *) false then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test group_check_ia *)
    let test_group_check_ia ?cs (ai : bignum_point * bignum_point)
        ?(a = Bignum_bigint.zero) ?(b = Bignum_bigint.zero)
        (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            (* Prepare test inputs *)
            let a =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                a
            in
            let b =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                b
            in
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
            in
            let ai =
              let init_acc, neg_init_acc = ai in
              ( Affine.of_bignum_bigint_coordinates (module Runner.Impl) init_acc
              , Affine.of_bignum_bigint_coordinates
                  (module Runner.Impl)
                  neg_init_acc )
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Check initial accumulator values *)
            group_check_ia
              (module Runner.Impl)
              unused_external_checks ai ~a ~b foreign_field_modulus ;

            (* Check for expected quantity of external checks *)
            let bounds_checks_count = ref 3 in
            if
              not
                (Foreign_field.field_standard_limbs_is_zero
                   (module Runner.Impl)
                   a )
            then bounds_checks_count := !bounds_checks_count + 1 ;
            if
              not
                (Foreign_field.field_standard_limbs_is_zero
                   (module Runner.Impl)
                   b )
            then bounds_checks_count := !bounds_checks_count + 1 ;
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

    (* Positive tests *)
    let secp_ia =
      group_get_ia_point secp256k1_a secp256k1_b secp256k1_generator
        secp256k1_modulus
    in
    let init_acc, neg_init_acc = secp_ia in
    (* Check secp256k1 initial accumulator(ia) point is correctly computed *)
    assert (
      Bignum_bigint.(
        equal (fst init_acc) (fst @@ fst secp256k1_ia)
        && equal (snd init_acc) (snd @@ fst secp256k1_ia)
        && equal (fst neg_init_acc) (fst @@ snd secp256k1_ia)
        && equal (snd neg_init_acc) (snd @@ snd secp256k1_ia)) ) ;
    (* Check constraining of ia *)
    let _cs =
      test_group_check_ia secp_ia ~a:secp256k1_a ~b:secp256k1_b
        secp256k1_modulus
    in
    let some_pt =
      ( Bignum_bigint.of_string
          "87932290535379810167112156366296444069940380144846532129360940996760542053602"
      , Bignum_bigint.of_string
          "33187319066909761709627516324935765453892876757028686788996843601006577450383"
      )
    in
    (* Check computation and constraining of another ia *)
    let another_ia =
      group_get_ia_point secp256k1_a secp256k1_b some_pt secp256k1_modulus
    in
    let cs =
      test_group_check_ia another_ia ~a:secp256k1_a ~b:secp256k1_b
        secp256k1_modulus
    in
    (* Constraint system reuse *)
    let some_pt2 =
      ( Bignum_bigint.of_string
          "33321203307284859285457570648264200146777100201560799373305582914511875834316"
      , Bignum_bigint.of_string
          "7129423920069223884043324693587298420542722670070397102650821528843979421489"
      )
    in
    let another_ia2 =
      group_get_ia_point secp256k1_a secp256k1_b some_pt2 secp256k1_modulus
    in
    let _cs =
      test_group_check_ia ~cs another_ia2 ~a:secp256k1_a ~b:secp256k1_b
        secp256k1_modulus
    in

    (* Negative tests *)
    assert (
      Common.is_error (fun () ->
          (* Bad negated ia *)
          let neg_init_acc = snd secp_ia in
          let bad_neg =
            (fst neg_init_acc, Bignum_bigint.(snd neg_init_acc + one))
          in
          let bad_ia = (fst secp_ia, bad_neg) in
          test_group_check_ia bad_ia ~a:secp256k1_a ~b:secp256k1_b
            secp256k1_modulus ) ) ;

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
          assert (
            not (is_on_curve bad_pt secp256k1_a secp256k1_b secp256k1_modulus) ) ;
          let neg_bad_pt =
            let x, y = bad_pt in
            (x, Bignum_bigint.((zero - y) % secp256k1_modulus))
          in
          let bad_ia = (bad_pt, neg_bad_pt) in
          test_group_check_ia bad_ia ~a:secp256k1_a ~b:secp256k1_b
            secp256k1_modulus ) ) ;

    () )

let%test_unit "group_scalar_mul" =
  if (* group_scalar_mul_tests *) false then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test elliptic curve scalar multiplication *)
    let test_group_scalar_mul ?cs (scalar : Bignum_bigint.t)
        (point : bignum_point) (expected_result : bignum_point)
        (ia : bignum_point * bignum_point) ?(a = Bignum_bigint.zero)
        (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let ia =
              let init_acc, neg_init_acc = ia in
              ( Affine.of_bignum_bigint_coordinates (module Runner.Impl) init_acc
              , Affine.of_bignum_bigint_coordinates
                  (module Runner.Impl)
                  neg_init_acc )
            in
            let a =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                a
            in
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
            in
            let scalar_bits =
              (* Removing trailing zeros helps make the test faster *)
              let scalar_bits =
                Common.bignum_bigint_unpack ~remove_trailing:true scalar
              in
              Array.map scalar_bits ~f:(fun bit ->
                  exists Boolean.typ ~compute:(fun () -> bit) )
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
              group_scalar_mul
                (module Runner.Impl)
                unused_external_checks scalar_bits point ia ~a
                foreign_field_modulus
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

    (* Test initial accumulator (ia) point generation algorithm *)
    let pointX =
      ( Bignum_bigint.of_string
          "67973637023329354644729732876692436096994797487488454090437075702698953132769"
      , Bignum_bigint.of_string
          "108096131279561713744990959402407452508030289249215221172372441421932322041359"
      )
    in
    let ia =
      group_get_ia_point secp256k1_a secp256k1_b pointX secp256k1_modulus
    in
    assert (
      Bignum_bigint.(
        equal
          (fst (fst ia))
          (Bignum_bigint.of_string
             "77808213848094917079255757522755861813805484598820680171349097575367307923684" )) ) ;
    assert (
      Bignum_bigint.(
        equal
          (snd (fst ia))
          (Bignum_bigint.of_string
             "53863434441850287308371409267019602514253829996603354269738630468061457326859" )) ) ;
    assert (
      Bignum_bigint.(
        equal
          (fst (snd ia))
          (Bignum_bigint.of_string
             "77808213848094917079255757522755861813805484598820680171349097575367307923684" )) ) ;
    assert (
      Bignum_bigint.(
        equal
          (snd (snd ia))
          (Bignum_bigint.of_string
             "61928654795465908115199575741668305339016154669037209769718953539847377344804" )) ) ;

    (* Get EC scalar mul initial accumulator point *)
    let ia =
      group_get_ia_point secp256k1_a secp256k1_b secp256k1_generator
        secp256k1_modulus
    in
    assert (
      Bignum_bigint.(
        equal
          (fst (fst ia))
          (Bignum_bigint.of_string
             "73748207725492941843355928046090697797026070566443284126849221438943867210749" )) ) ;
    assert (
      Bignum_bigint.(
        equal
          (snd (fst ia))
          (Bignum_bigint.of_string
             "71805440039692371678177852429904809925653495989672587996663750265844216498843" )) ) ;
    assert (
      Bignum_bigint.(
        equal
          (fst (snd ia))
          (Bignum_bigint.of_string
             "73748207725492941843355928046090697797026070566443284126849221438943867210749" )) ) ;
    assert (
      Bignum_bigint.(
        equal
          (snd (snd ia))
          (Bignum_bigint.of_string
             "43986649197623823745393132578783097927616488675967976042793833742064618172820" )) ) ;

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
    let _cs = test_group_scalar_mul scalar point point ia secp256k1_modulus in

    (* Multiply by 6 *)
    let scalar = Bignum_bigint.of_int 6 in
    let point =
      ( Bignum_bigint.of_string
          "67973637023329354644729732876692436096994797487488454090437075702698953132769"
      , Bignum_bigint.of_string
          "108096131279561713744990959402407452508030289249215221172372441421932322041359"
      )
    in
    let expected_result =
      ( Bignum_bigint.of_string
          "37941877700581055232085743160302884615963229784754572200220248617732513837044"
      , Bignum_bigint.of_string
          "103619381845871132282285745641400810486981078987965768860988615362483475376768"
      )
    in
    let _cs =
      test_group_scalar_mul scalar point expected_result ia secp256k1_modulus
    in

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
    let _cs =
      test_group_scalar_mul scalar point expected_result ia secp256k1_modulus
    in

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
    let _cs =
      test_group_scalar_mul scalar point expected_result ia secp256k1_modulus
    in

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
    let _cs =
      test_group_scalar_mul scalar point expected_result ia secp256k1_modulus
    in

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
    let _cs =
      test_group_scalar_mul scalar point expected_result ia secp256k1_modulus
    in

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
      test_group_scalar_mul scalar secp256k1_generator expected_pubkey ia
        secp256k1_modulus
    in
    (* Constraint system reuse *)
    let scalar =
      Bignum_bigint.of_string
        "93102346685989503200550820820601664115283772668359982393657391253613200462560"
    in
    let pt =
      ( Bignum_bigint.of_string
          "80241667548591023836188751980970358333134768792886000377475093272122544843235"
      , Bignum_bigint.of_string
          "102689901017063159731231921183137353356646798093847528339410885787356562759036"
      )
    in
    let expected_pt =
      ( Bignum_bigint.of_string
          "64386647670032720196082497276861206017517306207097800786232350268707480253408"
      , Bignum_bigint.of_string
          "61006610021997184131721512813438552408464895711704942585895904572625072596197"
      )
    in
    let _cs =
      test_group_scalar_mul ~cs scalar pt expected_pt ia secp256k1_modulus
    in
    () )

let%test_unit "group_scalar_mul_properties" =
  if (* group_scalar_mul_tests *) false then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Test elliptic curve scalar multiplication properties *)
    let test_group_scalar_mul_properties ?cs (a_scalar : Bignum_bigint.t)
        (b_scalar : Bignum_bigint.t) (point : bignum_point)
        (a_expected_result : bignum_point) (b_expected_result : bignum_point)
        (a_plus_b_expected : bignum_point) (a_times_b_expected : bignum_point)
        (negation_expected : bignum_point) (ia : bignum_point * bignum_point)
        (scalar_modulus : Bignum_bigint.t) ?(a = Bignum_bigint.zero)
        (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let ia =
              let init_acc, neg_init_acc = ia in
              ( Affine.of_bignum_bigint_coordinates (module Runner.Impl) init_acc
              , Affine.of_bignum_bigint_coordinates
                  (module Runner.Impl)
                  neg_init_acc )
            in
            let a =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                a
            in
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
            in
            let a_scalar_bits =
              (* Removing trailing zeros helps make the test faster *)
              let a_scalar_bits =
                Common.bignum_bigint_unpack ~remove_trailing:true a_scalar
              in
              Array.map a_scalar_bits ~f:(fun bit ->
                  exists Boolean.typ ~compute:(fun () -> bit) )
            in
            let b_scalar_bits =
              (* Removing trailing zeros helps make the test faster *)
              let b_scalar_bits =
                Common.bignum_bigint_unpack ~remove_trailing:true b_scalar
              in
              Array.map b_scalar_bits ~f:(fun bit ->
                  exists Boolean.typ ~compute:(fun () -> bit) )
            in
            let c_scalar_bits =
              (* Removing trailing zeros helps make the test faster *)
              let c_scalar =
                Bignum_bigint.((a_scalar + b_scalar) % scalar_modulus)
              in
              let c_scalar_bits =
                Common.bignum_bigint_unpack ~remove_trailing:true c_scalar
              in
              Array.map c_scalar_bits ~f:(fun bit ->
                  exists Boolean.typ ~compute:(fun () -> bit) )
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
              group_scalar_mul
                (module Runner.Impl)
                unused_external_checks a_scalar_bits point ia ~a
                foreign_field_modulus
            in

            (* B = bP *)
            let b_result =
              group_scalar_mul
                (module Runner.Impl)
                unused_external_checks b_scalar_bits point ia ~a
                foreign_field_modulus
            in

            (* C = (a + b)P *)
            let a_plus_b_result =
              group_scalar_mul
                (module Runner.Impl)
                unused_external_checks c_scalar_bits point ia ~a
                foreign_field_modulus
            in

            (* A + B *)
            let a_result_plus_b_result =
              group_add
                (module Runner.Impl)
                unused_external_checks a_result b_result foreign_field_modulus
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
              group_scalar_mul
                (module Runner.Impl)
                unused_external_checks a_scalar_bits b_result ia ~a
                foreign_field_modulus
            in

            (* [b]aP *)
            let b_a_result =
              group_scalar_mul
                (module Runner.Impl)
                unused_external_checks b_scalar_bits a_result ia ~a
                foreign_field_modulus
            in

            (* Compute a*b as foreign field multiplication in scalar field *)
            let ab_scalar_bits =
              let ab_scalar =
                Bignum_bigint.(a_scalar * b_scalar % scalar_modulus)
              in
              let ab_scalar_bits =
                Common.bignum_bigint_unpack ~remove_trailing:true ab_scalar
              in
              Array.map ab_scalar_bits ~f:(fun bit ->
                  exists Boolean.typ ~compute:(fun () -> bit) )
            in

            (* (a * b)P *)
            let ab_result =
              group_scalar_mul
                (module Runner.Impl)
                unused_external_checks ab_scalar_bits point ia ~a
                foreign_field_modulus
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
             * Check scaling computes with negation: [-s]P = -(sP)
             *)

            (* Compute -a_scalar witness *)
            let minus_a_scalar_bits =
              let minus_a_scalar = Bignum_bigint.(-a_scalar % scalar_modulus) in
              let minus_a_scalar_bits =
                Common.bignum_bigint_unpack ~remove_trailing:true minus_a_scalar
              in
              Array.map minus_a_scalar_bits ~f:(fun bit ->
                  exists Boolean.typ ~compute:(fun () -> bit) )
            in

            (* [-s]P *)
            let minus_a_result =
              group_scalar_mul
                (module Runner.Impl)
                unused_external_checks minus_a_scalar_bits point ia ~a
                foreign_field_modulus
            in

            (* -(sP) *)
            let negated_a_result =
              group_negate (module Runner.Impl) a_result foreign_field_modulus
            in

            (* Need to write negated y-coordinate to row in order to assert_equal on it *)
            let neg_init_y0, neg_init_y1, neg_init_y2 =
              Foreign_field.Element.Standard.to_limbs
              @@ Affine.y negated_a_result
            in
            with_label "negation_property_check" (fun () ->
                assert_
                  { annotation = Some __LOC__
                  ; basic =
                      Kimchi_backend_common.Plonk_constraint_system
                      .Plonk_constraint
                      .T
                        (Raw
                           { kind = Zero
                           ; values =
                               [| neg_init_y0; neg_init_y1; neg_init_y2 |]
                           ; coeffs = [||]
                           } )
                  } ) ;

            (* Assert [-s]P = -(sP) *)
            Affine.assert_equal
              (module Runner.Impl)
              minus_a_result negated_a_result ;
            (* Assert -(sP) = expected *)
            Affine.assert_equal
              (module Runner.Impl)
              negated_a_result negation_expected ;

            () )
      in

      cs
    in

    (* Get EC scalar mul initial accumulator point *)
    let ia =
      group_get_ia_point secp256k1_a secp256k1_b secp256k1_generator
        secp256k1_modulus
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

    assert (secp256k1_is_on_curve a_expected) ;
    assert (secp256k1_is_on_curve b_expected) ;
    assert (secp256k1_is_on_curve a_plus_b_expected) ;
    assert (secp256k1_is_on_curve a_times_b_expected) ;
    assert (secp256k1_is_on_curve negation_expected) ;

    let _cs =
      test_group_scalar_mul_properties a_scalar b_scalar secp256k1_generator
        a_expected b_expected a_plus_b_expected a_times_b_expected
        negation_expected ia secp256k1_order secp256k1_modulus
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

    assert (secp256k1_is_on_curve point) ;
    assert (secp256k1_is_on_curve a_expected) ;
    assert (secp256k1_is_on_curve b_expected) ;
    assert (secp256k1_is_on_curve a_plus_b_expected) ;
    assert (secp256k1_is_on_curve a_times_b_expected) ;
    assert (secp256k1_is_on_curve negation_expected) ;

    let _cs =
      test_group_scalar_mul_properties a_scalar b_scalar point a_expected
        b_expected a_plus_b_expected a_times_b_expected negation_expected ia
        secp256k1_order secp256k1_modulus
    in
    () )

(***************)
(* ECDSA tests *)
(***************)

let%test_unit "ecdsa_verify" =
  if (* ecdsa_tests *) true then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Let's test proving ECDSA signature verification in ZK! *)
    let test_ecdsa_verify ?cs (pubkey : bignum_point)
        (signature : Bignum_bigint.t * Bignum_bigint.t) (hash : Bignum_bigint.t)
        (ia : bignum_point * bignum_point) (gen : bignum_point)
        ?(a = Bignum_bigint.zero) ?(b = Bignum_bigint.zero)
        (curve_order : Bignum_bigint.t) (foreign_field_modulus : Bignum_bigint.t)
        =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            (* Prepare test inputs *)
            let ia =
              let init_acc, neg_init_acc = ia in
              ( Affine.of_bignum_bigint_coordinates (module Runner.Impl) init_acc
              , Affine.of_bignum_bigint_coordinates
                  (module Runner.Impl)
                  neg_init_acc )
            in
            let a =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                a
            in
            let b =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                b
            in
            let foreign_field_modulus =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
            in
            let curve_order =
              Foreign_field.bignum_bigint_to_field_standard_limbs
                (module Runner.Impl)
                curve_order
            in
            let pubkey =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) pubkey
            in
            let gen =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) gen
            in
            let signature =
              ( Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  (fst signature)
              , Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  (snd signature) )
            in
            let hash =
              Foreign_field.Element.Standard.of_bignum_bigint
                (module Runner.Impl)
                hash
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Subgroup check for pubkey *)
            group_check_subgroup
              (module Runner.Impl)
              unused_external_checks pubkey ia ~a curve_order
              foreign_field_modulus ;

            (* Verify ECDSA signature *)
            ecdsa_verify
              (module Runner.Impl)
              unused_external_checks pubkey signature hash ia gen ~a ~b
              curve_order foreign_field_modulus ;

            () )
      in

      cs
    in

    (* Test 1: ECDSA verify test with real Ethereum mainnet signature
     *   Tx: https://etherscan.io/tx/0x0d26b1539304a214a6517b529a027f987cd52e70afd8fdc4244569a93121f144
     *
     *   Raw tx: 0xf86580850df8475800830186a094353535353535353535353535353535353535353564801ba082de9950cc5aac0dca7210cb4b77320ac9e844717d39b1781e9d941d920a1206a01da497b3c134f50b2fce514d66e20c5e43f9615f097395a5527041d14860a52f
     *   Msg hash: 0x3e91cd8bd233b3df4e4762b329e2922381da770df1b31276ec77d0557be7fcef
     *   Raw pubkey: 0x046e0f66759bb520b026a9c7d61c82e8354025f2703696dcdac679b2f7945a352e637c8f71379941fa22f15a9fae9cb725ae337b16f216f5acdeefbd52a0882c27
     *   Raw signature: 0x82de9950cc5aac0dca7210cb4b77320ac9e844717d39b1781e9d941d920a12061da497b3c134f50b2fce514d66e20c5e43f9615f097395a5527041d14860a52f1b
     *     r := 0x82de9950cc5aac0dca7210cb4b77320ac9e844717d39b1781e9d941d920a1206
     *     s := 0x1da497b3c134f50b2fce514d66e20c5e43f9615f097395a5527041d14860a52f
     *     v := 27
     *)
    let eth_pubkey =
      ( Bignum_bigint.of_string
          "49781623198970027997721070672560275063607048368575198229673025608762959476014"
      , Bignum_bigint.of_string
          "44999051047832679156664607491606359183507784636787036192076848057884504239143"
      )
    in
    let eth_signature =
      ( (* r *)
        Bignum_bigint.of_string
          "59193968509713231970845573191808992654796038550727015999103892005508493218310"
      , (* s *)
        Bignum_bigint.of_string
          "13407882537414256709292360527926092843766608354464979273376653245977131525423"
      )
    in
    let tx_msg_hash =
      Bignum_bigint.of_string
        "0x3e91cd8bd233b3df4e4762b329e2922381da770df1b31276ec77d0557be7fcef"
    in

    assert (secp256k1_is_on_curve eth_pubkey) ;

    let _cs =
      test_ecdsa_verify eth_pubkey eth_signature tx_msg_hash secp256k1_ia
        secp256k1_generator ~a:secp256k1_a ~b:secp256k1_b secp256k1_order
        secp256k1_modulus
    in

    (* Negative test *)
    assert (
      Common.is_error (fun () ->
          (* Bad hash *)
          let bad_tx_msg_hash =
            Bignum_bigint.of_string
              "0x3e91cd8bd233b3df4e4762b329e2922381da770df1b31276ec77d0557be7fcee"
          in
          test_ecdsa_verify eth_pubkey eth_signature bad_tx_msg_hash
            secp256k1_ia secp256k1_generator ~a:secp256k1_a ~b:secp256k1_b
            secp256k1_order secp256k1_modulus ) ) ;

    (* Test 2: ECDSA verify test with another real Ethereum mainnet signature
     *   Tx: https://etherscan.io/tx/0x9cec14aadb06b59b2646333f47efe0ee7f21fed48d93806023b8eb205aa3b161
     *
     *   Raw tx: 0x02f9019c018201338405f5e100850cad3895d8830108949440a50cf069e992aa4536211b23f286ef88752187880b1a2bc2ec500000b90124322bba210000000000000000000000008a001303158670e284950565164933372807cd4800000000000000000000000012d220fbda92a9c8f281ea02871afa70dfde81e90000000000000000000000000000000000000000000000000afd4ea3d29472400000000000000000000000000000000000000000461c9bb5bb1c3429b25544e3f4b7bb67d63f9b432df61df28a9897e26284b370adcd7b558fa286babb0efdeb000000000000000000000000000000000000000000000000001cdd1f19bb8dc0000000000000000000000000000000000000000000000000000000006475ed380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a8f2573c080a0893bc3facf19becba979e31d37ed1b222faab09b8c554a17072f6fbfc1e5658fa01119ef751f0fc3c1ec4d1eeb9db64c9f416ce1aa3267d7b98d8426ab35f0c422
     *   Msg hash: 0xf7c5983cdb051f68aa84444c4b8ecfdbf60548fe3f5f3f2d19cc5d3c096f0b5b
     *   Raw pubkey: 0x04ad53a68c2120f9a81288b1377adbe7477b7cec1b9b5ff57d5e331ee7f9e6c2372f997b48cf3faa91023f77754ef63ec49dcd5a61b681b53cda894616c28422c0
     *   Raw signature: 0x893bc3facf19becba979e31d37ed1b222faab09b8c554a17072f6fbfc1e5658f1119ef751f0fc3c1ec4d1eeb9db64c9f416ce1aa3267d7b98d8426ab35f0c4221c
     *     r := 0x893bc3facf19becba979e31d37ed1b222faab09b8c554a17072f6fbfc1e5658f
     *     s := 0x1119ef751f0fc3c1ec4d1eeb9db64c9f416ce1aa3267d7b98d8426ab35f0c422
     *     v := 0
     *)
    let eth_pubkey =
      Ethereum.pubkey_hex_to_point
        "0x04ad53a68c2120f9a81288b1377adbe7477b7cec1b9b5ff57d5e331ee7f9e6c2372f997b48cf3faa91023f77754ef63ec49dcd5a61b681b53cda894616c28422c0"
    in

    let eth_signature =
      ( (* r *)
        Bignum_bigint.of_string
          "0x893bc3facf19becba979e31d37ed1b222faab09b8c554a17072f6fbfc1e5658f"
      , (* s *)
        Bignum_bigint.of_string
          "0x1119ef751f0fc3c1ec4d1eeb9db64c9f416ce1aa3267d7b98d8426ab35f0c422"
      )
    in
    let tx_msg_hash =
      Bignum_bigint.of_string
        "0xf7c5983cdb051f68aa84444c4b8ecfdbf60548fe3f5f3f2d19cc5d3c096f0b5b"
    in

    assert (secp256k1_is_on_curve eth_pubkey) ;

    let _cs =
      test_ecdsa_verify eth_pubkey eth_signature tx_msg_hash secp256k1_ia
        secp256k1_generator ~a:secp256k1_a ~b:secp256k1_b secp256k1_order
        secp256k1_modulus
    in

    (* Test 3: ECDSA verify test with yet another real Ethereum mainnet signature
     *   Tx: https://etherscan.io/tx/0x4eb2087dc31dda8fc1bd8680624cd2ae0c1ed0d880de1daefb6fddac208d08fb
     *
     *   Raw tx: 0x02f90114011c8405f5e100850d90b9d72982f4a8948a3749936e723325c6b645a0901470cd9e790b9480b8a8b88d4fde00000000000000000000000085210d346e2baa59a486dd19cf9d18f1325d9ffc00000000000000000000000039f083386e75120d2c6c152900219849dbdaa7e60000000000000000000000000000000000000000000000000000000000000b7100000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000360c6ebec080a0a8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe1a031532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d1
     *   Msg hash: 0xccdea6d5fce0363b9fbc2cf9a14087fc67c79fbdf55b25789ee2d51dcd82dbc1
     *   Raw pubkey: 0x042b7a248bf6fa2acc079d4f451c68c56a40ef81aeaf6a89c10ed6d692f7a6fdea0c05f95d601c3ab4f75d9253d356ab7af4d7d2ac250e0832581d08f1e224a976
     *   Raw signature: 0xa8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe131532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d11c
     *     r := 0xa8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe1
     *     s := 0x31532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d1
     *     v := 0
     *)
    let eth_pubkey =
      Ethereum.pubkey_hex_to_point
        "0x042b7a248bf6fa2acc079d4f451c68c56a40ef81aeaf6a89c10ed6d692f7a6fdea0c05f95d601c3ab4f75d9253d356ab7af4d7d2ac250e0832581d08f1e224a976"
    in

    let eth_signature =
      ( (* r *)
        Bignum_bigint.of_string
          "0xa8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe1"
      , (* s *)
        Bignum_bigint.of_string
          "0x31532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d1"
      )
    in
    let tx_msg_hash =
      Bignum_bigint.of_string
        "0xccdea6d5fce0363b9fbc2cf9a14087fc67c79fbdf55b25789ee2d51dcd82dbc1"
    in

    assert (secp256k1_is_on_curve eth_pubkey) ;

    let cs =
      test_ecdsa_verify eth_pubkey eth_signature tx_msg_hash secp256k1_ia
        secp256k1_generator ~a:secp256k1_a ~b:secp256k1_b secp256k1_order
        secp256k1_modulus
    in

    assert (
      Common.is_error (fun () ->
          (* Bad signature *)
          let bad_eth_signature =
            ( (* r *)
              Bignum_bigint.of_string
                "0xc8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe1"
            , (* s *)
              Bignum_bigint.of_string
                "0x31532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d1"
            )
          in
          test_ecdsa_verify eth_pubkey bad_eth_signature tx_msg_hash
            secp256k1_ia secp256k1_generator ~a:secp256k1_a ~b:secp256k1_b
            secp256k1_order secp256k1_modulus ) ) ;

    (* Test 4: Constraint system reuse
     *   Tx: https://etherscan.io/tx/0xfc7d65547eb5192c2f35b7e190b4792a9ebf79876f164ead32288e9fe2b7e4f3
     *
     *   Raw tx: 0x02f8730113843b9aca00851405ffdc00825b0494a9d1e08c7793af67e9d92fe308d5697fb81d3e4388299ce7c69d7b9c1780c001a06d5a635efe29deca27e52e96dd2d4056cff1a4b51f88d363f1c3802a26cd67a0a07c34d16c2831ee6265d6d2a55cee6e3273f41480424686d44fe709ce7cfd1567
     *   Msg hash: 0x62c771b337f1a0070dddb863b953017aa12918fc37f338419f7664fda443ce93
     *   Raw pubkey: 0x041d4911ee95f0858df65b942fe88cd54d6c06f73fc9e716db1e153d9994b16930e0284e96e308ef77f1d588aa446237111ab370eeab84059a08980e7e7ab0c467
     *   Raw signature: 0x6d5a635efe29deca27e52e96dd2d4056cff1a4b51f88d363f1c3802a26cd67a07c34d16c2831ee6265d6d2a55cee6e3273f41480424686d44fe709ce7cfd15671b
     *     r := 0xa8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe1
     *     s := 0x31532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d1
     *     v := 1
     *)
    let eth_pubkey =
      Ethereum.pubkey_hex_to_point
        "0x041d4911ee95f0858df65b942fe88cd54d6c06f73fc9e716db1e153d9994b16930e0284e96e308ef77f1d588aa446237111ab370eeab84059a08980e7e7ab0c467"
    in

    let eth_signature =
      ( (* r *)
        Bignum_bigint.of_string
          "0x6d5a635efe29deca27e52e96dd2d4056cff1a4b51f88d363f1c3802a26cd67a0"
      , (* s *)
        Bignum_bigint.of_string
          "0x7c34d16c2831ee6265d6d2a55cee6e3273f41480424686d44fe709ce7cfd1567"
      )
    in
    let tx_msg_hash =
      Bignum_bigint.of_string
        "0x62c771b337f1a0070dddb863b953017aa12918fc37f338419f7664fda443ce93"
    in

    assert (secp256k1_is_on_curve eth_pubkey) ;

    let _cs =
      test_ecdsa_verify ~cs eth_pubkey eth_signature tx_msg_hash secp256k1_ia
        secp256k1_generator ~a:secp256k1_a ~b:secp256k1_b secp256k1_order
        secp256k1_modulus
    in
    () )
