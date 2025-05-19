open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let add_constraint c = assert_ c

let add_plonk_constraint c = add_constraint c

let fresh_int i = exists Field.typ ~compute:(fun () -> Field.Constant.of_int i)

let range_check0 () = add_plonk_constraint (Boolean (fresh_int 0))

let test_range_check_lookup () =
  let _tag, _cache_handle, (module Proof), Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Nat.N0)
      ~name:"lookup range-check"
      ~choices:(fun ~self:_ ->
        [ { identifier = "main"
          ; prevs = []
          ; main =
              (fun _ ->
                for _i = 0 to 65536 do
                  Printf.printf "dzerz" ; range_check0 ()
                done ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = Plonk_types.Features.none_bool
          }
        ] )
      ()
  in
  let public_input, (), proof =
    Async.Thread_safe.block_on_async_exn (fun () -> prove ())
  in
  Or_error.ok_exn
    (Async.Thread_safe.block_on_async_exn (fun () ->
         Proof.verify [ (public_input, proof) ] ) )

let () =
  let open Alcotest in
  run "Test range-check in lookup gate"
    [ ( "range check in lookup gate"
      , [ ( "prove range-check lookup in lookup gate"
          , `Quick
          , test_range_check_lookup )
        ] )
    ]
