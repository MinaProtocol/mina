open Core_kernel
module Inputs = Pickles.Tick_field_sponge.Inputs
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

