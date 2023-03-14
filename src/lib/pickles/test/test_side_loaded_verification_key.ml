module SLV_key = Pickles__Side_loaded_verification_key
open Pickles_types

let input_size ~of_int ~add ~mul w =
  (* This should be an affine function in [a]. *)
  let size proofs_verified =
    let (T (Typ typ, _conv, _conv_inv)) =
      Impls.Step.input ~proofs_verified ~wrap_rounds:Backend.Tock.Rounds.n
        ~feature_flags:Plonk_types.Features.none
    in
    typ.size_in_field_elements
  in
  let f0 = size Nat.N0.n in
  let slope = size Nat.N1.n - f0 in
  add (of_int f0) (mul (of_int slope) w)

let test_input_size () =
  List.iter
    (List.range 0
       (Nat.to_int SLV_key.Width.Max.n)
       ~stop:`inclusive ~start:`inclusive )
    ~f:(fun n ->
      Alcotest.(check int)
        "input size"
        (input_size ~of_int:Fn.id ~add:( + ) ~mul:( * ) n)
        (let (T a) = Pickles_types.Nat.of_int n in
         let (T (Typ typ, _conv, _conv_inv)) =
           Impls.Step.input ~proofs_verified:a
             ~wrap_rounds:Backend.Tock.Rounds.n
             ~feature_flags:Plonk_types.Features.none
         in
         typ.size_in_field_elements ) )

let tests =
  let open Alcotest in
  [ ( "Side_loaded_verification_key"
    , [ test_case "test_input_size" `Quick test_input_size ] )
  ]
