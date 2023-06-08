open Core_kernel
module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

(* Affine representation of an elliptic curve point over a foreign field *)

let tests_enabled = true

type bignum_point = Bignum_bigint.t * Bignum_bigint.t

let two_to_4limb = Bignum_bigint.(Common.two_to_3limb * Common.two_to_limb)

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

let const_of_bignum_bigint_coordinates (type field)
    (module Circuit : Snark_intf.Run with type field = field)
    (point : bignum_point) : field t =
  let x, y = point in
  of_coordinates
    ( Foreign_field.Element.Standard.const_of_bignum_bigint (module Circuit) x
    , Foreign_field.Element.Standard.const_of_bignum_bigint (module Circuit) y
    )

let to_coordinates a = a

let to_string_as_prover (type field)
    (module Circuit : Snark_intf.Run with type field = field) a : string =
  let x, y = to_coordinates a in
  sprintf "(%s, %s)"
    (Foreign_field.Element.Standard.to_string_as_prover (module Circuit) x)
    (Foreign_field.Element.Standard.to_string_as_prover (module Circuit) y)

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

let checked_const_of_bignum_bigint_coordinates (type field)
    (module Circuit : Snark_intf.Run with type field = field)
    (point : bignum_point) : field t =
  let const_point = const_of_bignum_bigint_coordinates (module Circuit) point in
  let var_point = of_bignum_bigint_coordinates (module Circuit) point in
  assert_equal (module Circuit) const_point var_point ;
  const_point

let const_zero (type field)
    (module Circuit : Snark_intf.Run with type field = field) : field t =
  of_coordinates
    Foreign_field.Element.Standard.
      ( const_of_bignum_bigint (module Circuit) Bignum_bigint.zero
      , const_of_bignum_bigint (module Circuit) Bignum_bigint.zero )

(* Uses 6 * 1.5 (Generics per Field) = 9 rows per Affine.if_ *)
let if_ (type field) (module Circuit : Snark_intf.Run with type field = field)
    (b : Circuit.Boolean.var) ~(then_ : field t) ~(else_ : field t) : field t =
  let then_x, then_y = to_coordinates then_ in
  let else_x, else_y = to_coordinates else_ in
  of_coordinates
    Foreign_field.Element.Standard.
      ( if_ (module Circuit) b ~then_:then_x ~else_:else_x
      , if_ (module Circuit) b ~then_:then_y ~else_:else_y )

(****************)
(* Affine tests *)
(****************)

let%test_unit "affine" =
  if tests_enabled then
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in
    (* Check Affine methods *)
    let _cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let pt_a =
            of_bignum_bigint_coordinates
              (module Runner.Impl)
              ( Bignum_bigint.of_string
                  "15038058761817109681921033191530858996191372456511467769172810422323500124150"
              , Bignum_bigint.of_string
                  "64223534476670136480328171927326822445460557333044467340973794755877726909525"
              )
          in
          Foreign_field.result_row (module Runner.Impl) @@ fst pt_a ;
          Foreign_field.result_row (module Runner.Impl) @@ snd pt_a ;
          let pt_b =
            of_bignum_bigint_coordinates
              (module Runner.Impl)
              ( Bignum_bigint.of_string
                  "99660522603236469231535770150980484469424456619444894985600600952621144670700"
              , Bignum_bigint.of_string
                  "8901505138963553768122761105087501646863888139548342861255965172357387323186"
              )
          in
          Foreign_field.result_row (module Runner.Impl) @@ fst pt_b ;
          Foreign_field.result_row (module Runner.Impl) @@ snd pt_b ;
          let bit =
            Runner.Impl.(exists Boolean.typ_unchecked ~compute:(fun () -> true))
          in

          let pt_c = if_ (module Runner.Impl) bit ~then_:pt_a ~else_:pt_b in
          Foreign_field.result_row (module Runner.Impl) (fst pt_c) ;
          Foreign_field.result_row (module Runner.Impl) (snd pt_c) ;

          assert_equal (module Runner.Impl) pt_c pt_a ;

          let bit2 =
            Runner.Impl.(
              exists Boolean.typ_unchecked ~compute:(fun () -> false))
          in

          let pt_d = if_ (module Runner.Impl) bit2 ~then_:pt_a ~else_:pt_b in
          Foreign_field.result_row (module Runner.Impl) (fst pt_d) ;
          Foreign_field.result_row (module Runner.Impl) (snd pt_d) ;

          assert_equal (module Runner.Impl) pt_d pt_b ;

          () )
    in
    ()
