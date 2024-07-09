(* Testing
   -------

   Component: Pickles
   Subject: Test step and wrap scalar challenges
   Invocation: dune exec src/lib/pickles/test/main.exe -- test "scalar challenge"
*)

module SC = Pickles__Import.Scalar_challenge
module Scalar_challenge = Pickles__Scalar_challenge

module Test_make
    (Impl : Snarky_backendless.Snark_intf.Run)
    (G : Pickles__Intf.Group(Impl).S with type t = Impl.Field.t * Impl.Field.t)
    (Challenge : Pickles__Import.Challenge.S with module Impl := Impl)
    (Endo : sig
      val base : Impl.Field.Constant.t

      val scalar : G.Constant.Scalar.t
    end) =
struct
  open Impl
  include Pickles__Scalar_challenge.Make (Impl) (G) (Challenge) (Endo)
  module T = Internal_Basic

  let test_endo () =
    let random_point =
      let rec pt x =
        let y2 = G.Params.(T.Field.(b + (x * (a + (x * x))))) in
        if T.Field.is_square y2 then (x, T.Field.sqrt y2)
        else pt T.Field.(x + one)
      in
      G.Constant.of_affine (pt (T.Field.random ()))
    in
    let n = 128 in
    Quickcheck.test ~trials:10
      (Quickcheck.Generator.list_with_length n Bool.quickcheck_generator)
      ~f:(fun xs ->
        try
          T.Test.test_equal ~equal:G.Constant.equal
            ~sexp_of_t:G.Constant.sexp_of_t
            (Typ.tuple2 G.typ (Typ.list ~length:n Boolean.typ))
            G.typ
            (fun (g, s) ->
              make_checked (fun () -> endo g (SC.create (Field.pack s))) )
            (fun (g, s) ->
              let x =
                Constant.to_field (SC.create (Challenge.Constant.of_bits s))
              in
              G.Constant.scale g x )
            (random_point, xs)
        with e ->
          eprintf !"Input %{sexp: bool list}\n%!" xs ;
          raise e )

  let test_scalar ~endo () =
    let n = 128 in
    Quickcheck.test ~trials:10
      (Quickcheck.Generator.list_with_length n Bool.quickcheck_generator)
      ~f:(fun xs ->
        try
          T.Test.test_equal ~equal:Field.Constant.equal
            ~sexp_of_t:Field.Constant.sexp_of_t
            (Typ.list ~length:n Boolean.typ)
            Field.typ
            (fun s ->
              make_checked (fun () ->
                  Scalar_challenge.to_field_checked
                    (module Impl)
                    ~endo
                    (SC.create (Impl.Field.pack s)) ) )
            (fun s ->
              Scalar_challenge.to_field_constant
                (module Field.Constant)
                ~endo
                (SC.create (Challenge.Constant.of_bits s)) )
            xs
        with e ->
          eprintf !"Input %{sexp: bool list}\n%!" xs ;
          raise e )
end

module Endo = Pickles__Endo
module Wrap =
  Test_make (Impls.Wrap) (Pickles__Wrap_main_inputs.Inner_curve)
    (Impls.Wrap.Challenge)
    (Endo.Wrap_inner_curve)
module Step =
  Test_make (Impls.Step) (Pickles__Step_main_inputs.Inner_curve)
    (Impls.Step.Challenge)
    (Endo.Step_inner_curve)

let tests =
  let open Alcotest in
  [ ( "Wrap scalar challenge "
    , [ test_case "test endo" `Quick Wrap.test_endo
      ; test_case "test scalar" `Quick
          (Wrap.test_scalar ~endo:Endo.Step_inner_curve.scalar)
      ] )
  ; ( "Step scalar challenge"
    , [ test_case "test endo" `Quick Step.test_endo
      ; test_case "test scalar" `Quick
          (Step.test_scalar ~endo:Endo.Wrap_inner_curve.scalar)
      ] )
  ]
