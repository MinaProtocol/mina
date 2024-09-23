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

let update =
  let open Sponge.Default.F (Field) in
  Fn.compose (sponge ~add_assign) block_cipher

let update_batch_ocaml_sponge params ~rate =
  List.map ~f:(fun (`State state, input) ->
      let state = copy state in
      update params ~rate ~state input )

let update_rust_sponge _params input ~rate:_ ~state =
  let state_and_input_v = Kimchi_bindings.FieldVectors.Fp.create () in
  Array.iter state
    ~f:(Kimchi_bindings.FieldVectors.Fp.emplace_back state_and_input_v) ;
  Array.iter input
    ~f:(Kimchi_bindings.FieldVectors.Fp.emplace_back state_and_input_v) ;
  Kimchi_pasta_fp_poseidon.update params state_and_input_v ;
  Array.init (Array.length state)
    ~f:(Kimchi_bindings.FieldVectors.Fp.get state_and_input_v)

let chunks_pow =
  Sys.getenv_opt "CHUNKS_POW" |> Option.value_map ~default:4 ~f:Int.of_string

let chunks_thr =
  Sys.getenv_opt "CHUNKS_THR"
  |> Option.value_map ~default:(1 lsl (chunks_pow + 1)) ~f:Int.of_string

let update_batch params' ~rate inputs =
  let len = List.length inputs in
  if len < chunks_thr then update_batch_ocaml_sponge params' ~rate inputs
  else
    let state_and_input_vs = Kimchi_bindings.FieldVectors.Fp_batch.create () in
    List.iter inputs ~f:(fun (`State state, input) ->
        let state_and_input_v = Kimchi_bindings.FieldVectors.Fp.create () in
        Array.iter state
          ~f:(Kimchi_bindings.FieldVectors.Fp.emplace_back state_and_input_v) ;
        Array.iter input
          ~f:(Kimchi_bindings.FieldVectors.Fp.emplace_back state_and_input_v) ;
        Kimchi_bindings.FieldVectors.Fp_batch.emplace_back state_and_input_vs
          state_and_input_v ) ;
    let chunk_size = len lsr chunks_pow in
    Kimchi_pasta_fp_poseidon.update_batch params chunk_size state_and_input_vs ;
    let res =
      List.init len ~f:(fun i ->
          let v =
            Kimchi_bindings.FieldVectors.Fp_batch.get state_and_input_vs i
          in
          Array.init 3 (*state length*)
            ~f:(Kimchi_bindings.FieldVectors.Fp.get v) )
    in
    res

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
        (update_rust_sponge ~rate:2 params' ~state:(s ()) @@ value ()) )

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
    let%bind values_large = list @@ list_with_length 8 T.Field.gen in
    let%map values = list @@ list T.Field.gen in
    (init_state, values_large @ values)
  in
  Quickcheck.test gen ~f:(fun (s, value) ->
      let s = Array.of_list s in
      let value () = List.map ~f:(fun l -> (`State s, Array.of_list l)) value in
      [%test_eq: T.Field.t array list]
        (Ocaml_permutation.update_batch ~rate:2 params' @@ value ())
        (update_batch ~rate:2 params' @@ value ()) )

(* Parametrize chunk size via an argument and experiment more
   we need to determine minimum effective chunk, maybe *)
let%test_unit "check update_batch on a large number of small vectors (parallel)"
    =
  let params' : Field.t Sponge.Params.t =
    Kimchi_pasta_basic.poseidon_params_fp
  in
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  let gen =
    let open Quickcheck.Generator in
    let open Let_syntax in
    let%bind init_state = list_with_length 3 T.Field.gen in
    let%map values = list_with_length 1280 @@ list_with_length 2 T.Field.gen in
    (init_state, values)
  in
  Quickcheck.test ~trials:100 gen ~f:(fun (s, value) ->
      let s = Array.of_list s in
      let value () = List.map ~f:(fun l -> (`State s, Array.of_list l)) value in
      let _ = update_batch ~rate:2 params' @@ value () in
      () )
