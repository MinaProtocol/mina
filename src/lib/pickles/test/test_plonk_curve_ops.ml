module Test_make
    (Impl : Snarky_backendless.Snark_intf.Run)
    (G : Pickles__Intf.Group(Impl).S with type t = Impl.Field.t * Impl.Field.t) =
struct
  open Impl
  module T = Internal_Basic
  include Pickles__Plonk_curve_ops.Make (Impl) (G)

  let random_point =
    let rec pt x =
      let y2 = G.Params.(T.Field.(b + (x * (a + (x * x))))) in
      if T.Field.is_square y2 then (x, T.Field.sqrt y2)
      else pt T.Field.(x + one)
    in
    G.Constant.of_affine (pt (T.Field.of_int 0))

  let n = Field.size_in_bits

  let test_scale_fast_2 () =
    Quickcheck.test ~trials:5 Field.Constant.gen ~f:(fun s ->
        let input =
          let s_odd = T.Bigint.test_bit (T.Bigint.of_field s) 0 in
          Field.Constant.((if s_odd then s - one else s) / of_int 2, s_odd)
        in
        T.Test.test_equal ~equal:G.Constant.equal
          ~sexp_of_t:G.Constant.sexp_of_t
          (Typ.tuple2 G.typ (Typ.tuple2 Field.typ Boolean.typ))
          G.typ
          (fun (g, s) ->
            make_checked (fun () ->
                scale_fast2 ~num_bits:n g (Shifted_value s) ) )
          (fun (g, _) ->
            let x =
              let chunks_needed = chunks_needed ~num_bits:(n - 1) in
              let actual_bits_used = chunks_needed * bits_per_chunk in
              Pickles_types.Pcs_batch.pow ~one:G.Constant.Scalar.one
                ~mul:G.Constant.Scalar.( * )
                G.Constant.Scalar.(of_int 2)
                actual_bits_used
              |> G.Constant.Scalar.( + )
                   (G.Constant.Scalar.project (Field.Constant.unpack s))
            in
            G.Constant.scale g x )
          (random_point, input) )

  let test_scale_fast () =
    let open Pickles_types in
    let shift = Shifted_value.Type1.Shift.create (module G.Constant.Scalar) in
    Quickcheck.test ~trials:10
      Quickcheck.Generator.(
        map (list_with_length n Bool.quickcheck_generator) ~f:(fun bs ->
            Field.Constant.project bs |> Field.Constant.unpack ))
      ~f:(fun xs ->
        try
          T.Test.test_equal ~equal:G.Constant.equal
            ~sexp_of_t:G.Constant.sexp_of_t
            (Typ.tuple2 G.typ (Typ.list ~length:n Boolean.typ))
            G.typ
            (fun (g, s) ->
              make_checked (fun () ->
                  scale_fast ~num_bits:n g (Shifted_value (Field.project s)) )
              )
            (fun (g, s) ->
              let open G.Constant.Scalar in
              let s = project s in
              let x =
                Shifted_value.Type1.to_field
                  (module G.Constant.Scalar)
                  ~shift (Shifted_value s)
              in
              G.Constant.scale g x )
            (random_point, xs)
        with e ->
          eprintf !"Input %{sexp: bool list}\n%!" xs ;
          raise e )

  let tests =
    let open Alcotest in
    [ test_case "scale fast" `Quick test_scale_fast
    ; test_case "scale fast 2" `Quick test_scale_fast_2
    ]
end

module Wrap =
  Test_make (Pickles__Impls.Wrap) (Pickles__Wrap_main_inputs.Inner_curve)
module Step =
  Test_make (Pickles__Impls.Step) (Pickles__Step_main_inputs.Inner_curve)

let tests =
  [ ("Plonk curve operations:Wrap", Wrap.tests)
  ; ("Plonk curve operations:Step", Step.tests)
  ]
