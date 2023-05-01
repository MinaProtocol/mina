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

(* Elliptic curve group addition *)
let add (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f Foreign_field.External_checks.t)
    (left_input : f Affine.t) (right_input : f Affine.t)
    (foreign_field_modulus : f Foreign_field.standard_limbs) : f Affine.t =
  let open Circuit in
  let left_x, left_y = Affine.to_coordinates left_input in
  let right_x, right_y = Affine.to_coordinates right_input in

  (* C1: Constrain slope numerator and denominator computaion *)
  let delta_y =
    Foreign_field.sub (module Circuit) right_y left_y foreign_field_modulus
  in
  let delta_x =
    Foreign_field.sub (module Circuit) right_x left_x foreign_field_modulus
  in

  (* Compute slope witness value *)
  let slope0, slope1, slope2 =
    exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
        let delta_y =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            delta_y
        in
        let delta_x =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            delta_x
        in
        let slope = Bignum_bigint.(delta_y / delta_x) in
        let slope0, slope1, slope2 =
          let slope =
            Foreign_field.Element.Standard.of_bignum_bigint
              (module Circuit)
              slope
          in
          Foreign_field.Element.Standard.to_field_limbs_as_prover
            (module Circuit)
            slope
        in

        [| slope0; slope1; slope2 |] )
    |> Common.tuple3_of_array
  in

  let slope =
    Foreign_field.Element.Standard.of_limbs (slope0, slope1, slope2)
  in

  (* C2: Constrain that
   *
   *     slope * (right_x - left_x) = right_y - left_y
   *)
  let slope_product =
    Foreign_field.mul
      (module Circuit)
      external_checks slope delta_x foreign_field_modulus
  in

  (* Sanity check *)
  as_prover (fun () ->
      assert (
        Foreign_field.Element.Standard.equal_as_prover
          (module Circuit)
          slope_product delta_x ) ) ;

  let product0, product1, product2 =
    Foreign_field.Element.Standard.to_limbs slope_product
  in
  let delta_y0, delta_y1, delta_y2 =
    Foreign_field.Element.Standard.to_limbs delta_y
  in
  Field.Assert.equal product0 delta_y0 ;
  Field.Assert.equal product1 delta_y1 ;
  Field.Assert.equal product2 delta_y2 ;

  (* C3: Constrain computation of slope squared *)
  let slope_squared =
    Foreign_field.mul
      (module Circuit)
      external_checks slope slope foreign_field_modulus
  in

  (* C4: Constrain result x-coordinate computation
   *
   *    x = slope^2 - right_x - left_x
   *)
  let x_sum =
    Foreign_field.add (module Circuit) right_x left_x foreign_field_modulus
  in
  let result_x =
    Foreign_field.sub (module Circuit) slope_squared x_sum foreign_field_modulus
  in

  (* C5: Constrain result y-coordinate computation
   *
   *    y = slope * (left_x - result_x) - left_y
   *)
  let x_sub =
    Foreign_field.sub (module Circuit) left_x result_x foreign_field_modulus
  in
  let left_mul =
    Foreign_field.mul
      (module Circuit)
      external_checks slope x_sub foreign_field_modulus
  in
  let result_y =
    Foreign_field.sub (module Circuit) left_mul left_y foreign_field_modulus
  in

  Affine.of_coordinates (result_x, result_y)

(*********)
(* Tests *)
(*********)

let%test_unit "ecdsa affine helpers " =
  if tests_enabled then
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

let%test_unit "group add" =
  if tests_enabled then printf "\ngroup add tests\n" ;
  ()
