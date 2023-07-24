module Impl = Pickles__Impls.Step
module Inner_curve = Pickles__Step_main_inputs.Inner_curve
module Ops = Pickles__Step_main_inputs.Ops

let test_scale_fast_2 () =
  let open Impl in
  let module T = Internal_Basic in
  let module G = Inner_curve in
  let n = Field.size_in_bits in
  let module F = struct
    type t = Field.t

    let typ = Field.typ

    module Constant = struct
      include Field.Constant

      let to_bigint = Impl.Bigint.of_field
    end
  end in
  Quickcheck.test ~trials:5 Field.Constant.gen ~f:(fun s ->
      T.Test.test_equal ~equal:G.Constant.equal ~sexp_of_t:G.Constant.sexp_of_t
        (Typ.tuple2 G.typ Field.typ)
        G.typ
        (fun (g, s) ->
          make_checked (fun () -> Ops.scale_fast2' ~num_bits:n (module F) g s)
          )
        (fun (g, _) ->
          let x =
            let chunks_needed = Ops.chunks_needed ~num_bits:(n - 1) in
            let actual_bits_used = chunks_needed * Ops.bits_per_chunk in
            Pickles_types.Pcs_batch.pow ~one:G.Constant.Scalar.one
              ~mul:G.Constant.Scalar.( * )
              G.Constant.Scalar.(of_int 2)
              actual_bits_used
            |> G.Constant.Scalar.( + )
                 (G.Constant.Scalar.project (Field.Constant.unpack s))
          in
          G.Constant.scale g x )
        (G.Constant.random (), s) )

let test_scale_fast_2_small () =
  let open Impl in
  let module T = Internal_Basic in
  let module G = Inner_curve in
  let n = 8 in
  let module F = struct
    type t = Field.t

    let typ = Field.typ

    module Constant = struct
      include Field.Constant

      let to_bigint = Impl.Bigint.of_field
    end
  end in
  Quickcheck.test ~trials:5 Field.Constant.gen ~f:(fun s ->
      let s =
        Field.Constant.unpack s |> Fn.flip List.take n |> Field.Constant.project
      in
      T.Test.test_equal ~equal:G.Constant.equal ~sexp_of_t:G.Constant.sexp_of_t
        (Typ.tuple2 G.typ Field.typ)
        G.typ
        (fun (g, s) ->
          make_checked (fun () -> Ops.scale_fast2' ~num_bits:n (module F) g s)
          )
        (fun (g, _) ->
          let x =
            let chunks_needed = Ops.chunks_needed ~num_bits:(n - 1) in
            let actual_bits_used = chunks_needed * Ops.bits_per_chunk in
            Pickles_types.Pcs_batch.pow ~one:G.Constant.Scalar.one
              ~mul:G.Constant.Scalar.( * )
              G.Constant.Scalar.(of_int 2)
              actual_bits_used
            |> G.Constant.Scalar.( + )
                 (G.Constant.Scalar.project (Field.Constant.unpack s))
          in
          G.Constant.scale g x )
        (G.Constant.random (), s) )

let tests =
  let open Alcotest in
  [ ( "Step curve operations"
    , [ test_case "scale fast prime" `Quick test_scale_fast_2
      ; test_case "scale fast small" `Quick test_scale_fast_2_small
      ] )
  ]
