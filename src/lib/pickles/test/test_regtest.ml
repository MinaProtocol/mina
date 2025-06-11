let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Snarky_backendless.Snark0.set_eval_constraints true

let test_step_no_constraint_no_input () =
  let open Pickles.Impls.Step in
  let _tag, _, _p, Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Pickles.Impls.Step.Typ.unit
      ~max_proofs_verified:(module Pickles_types.Nat.N0)
      ~name:"step_no_constraint"
      ~choices:(fun ~self:_ ->
        [ { identifier = "step no constraint 2^16"
          ; prevs = []
          ; main =
              (fun _ ->
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
          }
        ] )
      ()
  in
  let (_ : unit) = ignore @@ prove () in
  ()

let () =
  let open Alcotest in
  run "Pickles Regtest"
    [ ( "Regtest"
      , [ test_case "step no constraint" `Quick test_step_no_constraint_no_input
          (* ; test_case "wrap no constraint" `Quick Impls.Wrap.Regtest.test *)
        ] )
    ]
