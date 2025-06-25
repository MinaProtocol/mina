open Core_kernel
open Random_oracle

let test_iterativeness () =
  let open Random_oracle in
  let x1 = Field.random () in
  let x2 = Field.random () in
  let x3 = Field.random () in
  let x4 = Field.random () in
  let s_full = update ~state:initial_state [| x1; x2; x3; x4 |] in
  let s_it =
    update ~state:(update ~state:initial_state [| x1; x2 |]) [| x3; x4 |]
  in
  Alcotest.(check (array (module Field))) "iterativeness" s_full s_it

let test_sponge_checked_unchecked () =
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  let x = T.Field.random () in
  let y = T.Field.random () in
  let checked_result =
    T.make_checked (fun () -> Random_oracle.Checked.hash [| x; y |])
  in
  let unchecked_result = Random_oracle.hash [| x; y |] in
  Alcotest.(check (module T.Field)) "sponge checked-unchecked" checked_result unchecked_result

let test_block_cipher_rust_implementation () =
  let module Field = Kimchi_backend.Pasta.Basic.Fp in
  let module Ocaml_permutation = Sponge.Poseidon (Pickles.Tick_field_sponge.Inputs) in
  let params' : Field.t Sponge.Params.t =
    Kimchi_pasta_basic.poseidon_params_fp
  in
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  let test_case s =
    let s_array = Array.of_list s in
    let ocaml_result = Ocaml_permutation.block_cipher params' s_array in
    let rust_result = Random_oracle_permutation.block_cipher params' s_array in
    Alcotest.(check (array (module T.Field))) "rust vs ocaml block cipher" ocaml_result rust_result
  in
  (* Test with a few different inputs *)
  let test_inputs = [
    [T.Field.zero; T.Field.one; T.Field.zero];
    [T.Field.one; T.Field.one; T.Field.one];
    List.init 3 ~f:(fun _ -> T.Field.random ())
  ] in
  List.iter test_inputs ~f:test_case

let () =
  let open Alcotest in
  run "Random_oracle tests"
    [ ( "random_oracle"
      , [ test_case "iterativeness" `Quick test_iterativeness
        ; test_case "sponge checked-unchecked" `Quick test_sponge_checked_unchecked
        ; test_case "block cipher rust implementation" `Quick test_block_cipher_rust_implementation
        ] )
    ]