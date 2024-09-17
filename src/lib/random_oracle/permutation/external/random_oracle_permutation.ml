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

let update _params input ~rate:_ ~state =
  let input_v = Kimchi_bindings.FieldVectors.Fp.create () in
  Array.iter input ~f:(Kimchi_bindings.FieldVectors.Fp.emplace_back input_v) ;
  let state_v = Kimchi_bindings.FieldVectors.Fp.create () in
  Array.iter state ~f:(Kimchi_bindings.FieldVectors.Fp.emplace_back state_v) ;
  Kimchi_pasta_fp_poseidon.update params state_v input_v ;
  Array.init (Array.length state)
    ~f:(Kimchi_bindings.FieldVectors.Fp.get state_v)

let update_batch _params ~rate:_ ~state inputs =
  let input_vs = Kimchi_bindings.FieldVectors.Fp_batch.create () in
  List.iter inputs ~f:(fun input ->
      let input_v = Kimchi_bindings.FieldVectors.Fp.create () in
      Array.iter input ~f:(Kimchi_bindings.FieldVectors.Fp.emplace_back input_v) ;
      Kimchi_bindings.FieldVectors.Fp_batch.emplace_back input_vs input_v ) ;
  let state_v = Kimchi_bindings.FieldVectors.Fp.create () in
  Array.iter state ~f:(Kimchi_bindings.FieldVectors.Fp.emplace_back state_v) ;
  Kimchi_pasta_fp_poseidon.update_batch params state_v input_vs ;
  let state_length = Array.length state in
  List.mapi inputs ~f:(fun i _ ->
      let v = Kimchi_bindings.FieldVectors.Fp_batch.get input_vs i in
      Array.init state_length ~f:(Kimchi_bindings.FieldVectors.Fp.get v) )

let%test_unit "check rust implementation of block-cipher" =
  let params' : Field.t Sponge.Params.t =
    Kimchi_pasta_basic.poseidon_params_fp
  in
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  Quickcheck.test (Quickcheck.Generator.list_with_length 3 T.Field.gen)
    ~f:(fun s ->
      let s () = Array.of_list s in
      [%test_eq: T.Field.t array]
        (Ocaml_permutation.block_cipher params' (s ()))
        (block_cipher params' (s ())) )

let%test_unit "check rust implementation of update" =
  let params' : Field.t Sponge.Params.t =
    Kimchi_pasta_basic.poseidon_params_fp
  in
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  let gen =
    let open Quickcheck.Generator in
    let open Let_syntax in
    let%bind init_state = list_with_length 3 T.Field.gen in
    let%map value = list T.Field.gen in
    (init_state, value)
  in
  Quickcheck.test gen ~f:(fun (s, value) ->
      let s () = Array.of_list s in
      let value () = Array.of_list value in
      [%test_eq: T.Field.t array]
        (Ocaml_permutation.update ~rate:2 params' ~state:(s ()) @@ value ())
        (update ~rate:2 params' ~state:(s ()) @@ value ()) )

let%test_unit "check rust implementation of update_batch" =
  let params' : Field.t Sponge.Params.t =
    Kimchi_pasta_basic.poseidon_params_fp
  in
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  let gen =
    let open Quickcheck.Generator in
    let open Let_syntax in
    let%bind init_state = list_with_length 3 T.Field.gen in
    let%bind values_large = list @@ list_with_length 20 T.Field.gen in
    let%map values = list @@ list T.Field.gen in
    (init_state, values_large @ values)
  in
  Quickcheck.test gen ~f:(fun (s, value) ->
      let s () = Array.of_list s in
      let value () = List.map ~f:Array.of_list value in
      [%test_eq: T.Field.t array list]
        ( Ocaml_permutation.update_batch ~rate:2 params' ~state:(s ())
        @@ value () )
        (update_batch ~rate:2 params' ~state:(s ()) @@ value ()) )
