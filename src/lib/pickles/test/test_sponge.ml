module Test
    (Impl : Snarky_backendless.Snark_intf.Run)
    (S_constant : Sponge.Intf.Sponge
                    with module Field := Impl.Field.Constant
                     and module State := Sponge.State
                     and type input := Impl.field
                     and type digest := Impl.field)
    (S_checked : Sponge.Intf.Sponge
                   with module Field := Impl.Field
                    and module State := Sponge.State
                    and type input := Impl.Field.t
                    and type digest := Impl.Field.t) =
struct
  open Impl

  let test params : unit =
    let n = 10 in
    let a = Array.init n ~f:(fun _ -> Field.Constant.random ()) in
    Impl.Internal_Basic.Test.test_equal ~sexp_of_t:Field.Constant.sexp_of_t
      ~equal:Field.Constant.equal
      (Typ.array ~length:n Field.typ)
      Field.typ
      (fun a ->
        make_checked (fun () ->
            let s =
              S_checked.create (Sponge.Params.map ~f:Field.constant params)
            in
            Array.iter a ~f:(S_checked.absorb s) ;
            S_checked.squeeze s ) )
      (fun a ->
        let s = S_constant.create params in
        Array.iter a ~f:(S_constant.absorb s) ;
        S_constant.squeeze s )
      a
end

module Step =
  Test (Impls.Step) (Pickles__Tick_field_sponge.Field)
    (Pickles__Step_main_inputs.Sponge.S)
module Wrap =
  Test (Impls.Wrap) (Pickles__Tock_field_sponge.Field)
    (Pickles__Wrap_main_inputs.Sponge.S)

let tests =
  let open Alcotest in
  [ ( "Sponge:Step"
    , [ test_case "sponge" `Quick (fun () ->
            Step.test Pickles__Tick_field_sponge.params )
      ] )
  ; ( "Sponge:Wrap"
    , [ test_case "sponge" `Quick (fun () ->
            Wrap.test Pickles__Tock_field_sponge.params )
      ] )
  ]
