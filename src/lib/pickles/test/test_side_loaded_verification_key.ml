(* Testing
   -------

   Component: Pickles
   Subject: Test side-loaded verification key
   Invocation: \
    dune exec src/lib/pickles/test/main.exe -- test "Side-loaded verification key"
*)

module SLV_key = Pickles__Side_loaded_verification_key
open Pickles_types

let input_size w =
  (* This should be an affine function in [a]. *)
  let size proofs_verified =
    let (T (Typ typ, _conv, _conv_inv)) =
      Impls.Step.input ~proofs_verified ~wrap_rounds:Backend.Tock.Rounds.n
    in
    typ.size_in_field_elements
  in
  let f0 = size Nat.N0.n in
  let slope = size Nat.N1.n - f0 in
  f0 + (slope * w)

let test_input_size () =
  List.iter
    (List.range 0
       (Nat.to_int SLV_key.Width.Max.n)
       ~stop:`inclusive ~start:`inclusive )
    ~f:(fun n ->
      Alcotest.(check int)
        "input size" (input_size n)
        (let (T a) = Pickles_types.Nat.of_int n in
         let (T (Typ typ, _conv, _conv_inv)) =
           Impls.Step.input ~proofs_verified:a
             ~wrap_rounds:Backend.Tock.Rounds.n
         in
         typ.size_in_field_elements ) )

let tests =
  let open Alcotest in
  [ ( "Side-loaded verification key"
    , [ test_case "test_input_size" `Quick test_input_size ] )
  ]
