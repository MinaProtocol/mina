open Core_kernel
module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

let tests_enabled = true

let two_to_4limb = Bignum_bigint.(Common.two_to_3limb * Common.two_to_limb)

(* Affine representation of an elliptic curve point over a foreign field *)
module Affine : sig
  type 'field t

  (* Create foreign field affine point from coordinate pair (x, y) *)
  val of_coordinates :
       'field Foreign_field.Element.Standard.t
       * 'field Foreign_field.Element.Standard.t
    -> 'field t

  (* Create foreign field affine point from hex *)
  val of_hex :
    (module Snark_intf.Run with type field = 'field) -> string -> 'field t

  (* Convert foreign field affine point to coordinate pair (x, y) *)
  val to_coordinates :
       'field t
    -> 'field Foreign_field.Element.Standard.t
       * 'field Foreign_field.Element.Standard.t

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
end = struct
  type 'field t =
    'field Foreign_field.Element.Standard.t
    * 'field Foreign_field.Element.Standard.t

  let of_coordinates a = a

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
end

(* Array to tuple helper *)
let tuple9_of_array array =
  match array with
  | [| a1; a2; a3; a4; a5; a6; a7; a8; a9 |] ->
      (a1, a2, a3, a4, a5, a6, a7, a8, a9)
  | _ ->
      assert false

(* Elliptic curve group addition *)
let group_add (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t)
    (left_input : f Affine.t) (right_input : f Affine.t)
    (foreign_field_modulus : f Foreign_field.standard_limbs) : f Affine.t =
  let open Circuit in
  (* Sanity check that two points are not equal *)
  as_prover (fun () ->
      assert (
        not (Affine.equal_as_prover (module Circuit) left_input right_input) ) ) ;

  (* Unpack coordinates *)
  let left_x, left_y = Affine.to_coordinates left_input in
  let right_x, right_y = Affine.to_coordinates right_input in

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
            (right_y - left_y) / (right_x - left_x) % foreign_field_modulus)
        in
        let slope_squared =
          Bignum_bigint.((pow slope @@ of_int 2) % foreign_field_modulus)
        in
        printf "slope         = %s\n" (Bignum_bigint.to_string slope) ;
        printf "slope_squared = %s\n" (Bignum_bigint.to_string slope_squared) ;

        (* Compute result's x-coodinate: x = s^2 - Lx - Rx *)
        let result_x =
          Bignum_bigint.(
            (slope_squared - left_x - right_x) % foreign_field_modulus)
        in

        (* Compute result's y-coodinate: y = s * (Rx - x) - Ry *)
        let result_y =
          Bignum_bigint.(
            ((slope * (right_x - result_x)) - right_y) % foreign_field_modulus)
        in
        printf "result_x      = %s\n" (Bignum_bigint.to_string result_x) ;
        printf "result_y      = %s\n" (Bignum_bigint.to_string result_y) ;

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

  (* Convert slope into foreign field element *)
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
    Foreign_field.mul
      (module Circuit)
      external_checks slope slope foreign_field_modulus
  in

  (* C2: Constrain result x-coordinate computation: x = s^2 - Lx - Rx with length 2 chain
   *     with s^2 - x - Lx = Rx
   *)
  let slope_squared_minus_x =
    Foreign_field.sub
      (module Circuit)
      ~full:false slope_squared result_x foreign_field_modulus
  in
  let expected_right_x =
    Foreign_field.sub
      (module Circuit)
      ~full:false slope_squared_minus_x left_x foreign_field_modulus
  in
  (* Copy expected_right_x to right_x *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    expected_right_x right_x ;
  (* C3: Continue the chain to length 4 by computing (Rx - x) * s (used later) *)
  let right_delta =
    Foreign_field.sub
      (module Circuit)
      ~full:false expected_right_x result_x foreign_field_modulus
  in
  let right_delta_s =
    Foreign_field.mul
      (module Circuit)
      external_checks right_delta slope foreign_field_modulus
  in

  (* C4: Constrain slope computation: s = (Ry - Ly)/(Rx - Lx) over two length 2 chains
   *     with (Rx - Lx) * s + Ly = Ry
   *)
  let delta_x =
    Foreign_field.sub
      (module Circuit)
      ~full:false right_x left_x foreign_field_modulus
  in
  let delta_x_s =
    Foreign_field.mul
      (module Circuit)
      external_checks delta_x slope foreign_field_modulus
  in
  (* Finish constraining slope in new chain (above mul ended chain) *)
  let expected_right_y =
    Foreign_field.add
      (module Circuit)
      ~full:false delta_x_s left_y foreign_field_modulus
  in
  (* Copy expected_right_y to right_y *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    expected_right_y right_y ;
  (* C5: Constrain result y-coordinate computation: y = (Rx - x) * s - Ry
   *     with Ry + y = (Rx - x) * s
   *)
  let expected_right_delta_s =
    Foreign_field.add ~full:false
      (module Circuit)
      expected_right_y result_y foreign_field_modulus
  in
  let expected_right_delta_s0, expected_right_delta_s1, expected_right_delta_s2
      =
    Foreign_field.Element.Standard.to_limbs expected_right_delta_s
  in
  (* Final Zero gate*)
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

  (* Append appropriate required external checks *)
  Foreign_field.External_checks.append_bound_check external_checks
    (slope0, slope1, slope2) ;
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs right_delta_s ;
  Foreign_field.External_checks.append_bound_check external_checks
  @@ Foreign_field.Element.Standard.to_limbs delta_x_s ;

  Affine.of_coordinates (result_x, result_y)

(*********)
(* Tests *)
(*********)

let%test_unit "ecdsa affine helpers " =
  if (* tests_enabled *) false then
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
  if tests_enabled then printf "\ngroup_add tests\n" ;
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in

  (* Test group add *)
  let test_group_add ?cs (left_input : Bignum_bigint.t * Bignum_bigint.t)
      (right_input : Bignum_bigint.t * Bignum_bigint.t)
      (foreign_field_modulus : Bignum_bigint.t) =
    (* Generate and verify proof *)
    let cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof ?cs (fun () ->
          (* let open Runner.Impl in *)
          (* Prepare test inputs *)
          (* let expected =
               Bignum_bigint.(left_input * right_input % foreign_field_modulus)
             in *)
          let foreign_field_modulus =
            Foreign_field.bignum_bigint_to_field_standard_limbs
              (module Runner.Impl)
              foreign_field_modulus
          in
          let left_input =
            let x, y = left_input in
            let x, y =
              ( Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  x
              , Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  y )
            in
            Affine.of_coordinates (x, y)
          in
          let right_input =
            let x, y = right_input in
            let x, y =
              ( Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  x
              , Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  y )
            in
            Affine.of_coordinates (x, y)
          in

          (* Create external checks context for tracking extra constraints
             that are required for soundness (unused in this simple test) *)
          let unused_external_checks =
            Foreign_field.External_checks.create (module Runner.Impl)
          in

          (* Create the gadget *)
          let _result =
            group_add
              (module Runner.Impl)
              unused_external_checks left_input right_input
              foreign_field_modulus
          in
          (* Check product matches expected result *)
          (* as_prover (fun () ->
              let expected =
                Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  expected
              in
              assert (
                Foreign_field.Element.Standard.equal_as_prover
                  (module Runner.Impl)
                  expected product ) ) ; *)
          () )
    in

    cs
  in

  let secp256k1_modulus =
    Common.bignum_bigint_of_hex
      "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f"
  in
  let secp256k1_max = Bignum_bigint.(secp256k1_modulus - Bignum_bigint.one) in
  let secp256k1_sqrt = Common.bignum_biguint_sqrt secp256k1_max in
  let _cs =
    test_group_add
      (Bignum_bigint.zero, secp256k1_max)
      (Bignum_bigint.one, secp256k1_sqrt)
      secp256k1_modulus
  in
  ()
