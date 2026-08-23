(** Testing
    -------

    Component: Random_oracle
    Subject: Test Rust block-cipher implementation against OCaml reference
    Invocation: \
     dune exec \
      src/lib/crypto/random_oracle/test/test_permutation.exe
*)

open Core_kernel
module Ocaml_permutation = Sponge.Poseidon (Pickles.Tick_field_sponge.Inputs)

let field_testable =
  let open Pickles.Impls.Step.Internal_Basic in
  Alcotest.testable
    (fun fmt f -> Format.pp_print_string fmt (Field.to_string f))
    Field.equal

let state_testable = Alcotest.array field_testable

let test_rust_block_cipher () =
  let params' : Kimchi_backend.Pasta.Basic.Fp.t Sponge.Params.t =
    Kimchi_pasta_basic.poseidon_params_fp
  in
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  Quickcheck.test (Quickcheck.Generator.list_with_length 3 T.Field.gen)
    ~f:(fun s ->
      let s () = Array.of_list s in
      Alcotest.check state_testable "block cipher equality"
        (Ocaml_permutation.block_cipher params' (s ()))
        (Random_oracle_permutation.block_cipher params' (s ())) )

let () =
  let open Alcotest in
  run "Random_oracle_permutation"
    [ ( "block_cipher"
      , [ test_case "rust matches ocaml" `Quick test_rust_block_cipher ] )
    ]
