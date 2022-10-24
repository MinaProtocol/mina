open Core_kernel
module Inputs = Pickles.Step_field_sponge.Inputs
module Ocaml_permutation = Sponge.Poseidon (Inputs)
module Field = Kimchi_backend.Pasta.Basic.Fp

let add_assign = Ocaml_permutation.add_assign

let copy = Ocaml_permutation.copy

let params = Kimchi_pasta_fp_poseidon.create ()

let block_cipher _params (s : Field.t array) =
  let v = Kimchi_bindings.FieldVectors.Fp.create () in
  Array.iter s ~f:(Kimchi_bindings.FieldVectors.Fp.emplace_back v) ;
  Kimchi_pasta_fp_poseidon.block_cipher params v ;
  Array.init (Array.length s) ~f:(Kimchi_bindings.FieldVectors.Fp.get v)

let%test_unit "check rust implementation of block-cipher" =
  let params' : Field.t Sponge.Params.t =
    Sponge.Params.(map pasta_p_kimchi ~f:Field.of_string)
  in
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  Quickcheck.test (Quickcheck.Generator.list_with_length 3 T.Field.gen)
    ~f:(fun s ->
      let s () = Array.of_list s in
      [%test_eq: T.Field.t array]
        (Ocaml_permutation.block_cipher params' (s ()))
        (block_cipher params' (s ())) )
