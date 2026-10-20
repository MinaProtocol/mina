(* Testing
   -------

   Component: Pickles
   Subject: Test that adversarially-tweaked wrap statements are rejected
   Invocation: \
    dune exec src/lib/crypto/pickles/test/test_adversarial.exe
*)

open Pickles_types
open Hlist
module Compile = Pickles__Compile
module Import = Pickles__Import
module Proof = Pickles__Proof
module Inductive_rule = Pickles__Inductive_rule.Kimchi
module Branch_data = Import.Branch_data

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Backtrace.elide := false

let () = Snarky_backendless.Snark0.set_eval_constraints true

module Make_adversarial_test (M : sig
  val tweak_statement :
       ( Import.Challenge.Constant.t
       , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
       , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
       , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
         , bool )
         Import.Types.Opt.t
       , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         , bool )
         Import.Types.Opt.t
       , bool
       , 'max_proofs_verified
         Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
       , Import.Types.Digest.Constant.t
       , ( 'b
         , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.t
           , 'actual_proofs_verified )
           Pickles_types.Vector.t
         , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
               Import.Bulletproof_challenge.t
             , 'e )
             Pickles_types.Vector.t
           , 'actual_proofs_verified )
           Pickles_types.Vector.t )
         Proof.Base.Messages_for_next_proof_over_same_field.Step.t
       , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         Import.Types.Bulletproof_challenge.t
         Import.Types.Step_bp_vec.t
       , Import.Types.Branch_data.t )
       Import.Types.Wrap.Statement.In_circuit.t
    -> ( Import.Challenge.Constant.t
       , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
       , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
       , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
         , bool )
         Import.Types.Opt.t
       , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         , bool )
         Import.Types.Opt.t
       , bool
       , 'max_proofs_verified
         Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
       , Import.Types.Digest.Constant.t
       , ( 'b
         , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.t
           , 'actual_proofs_verified )
           Pickles_types.Vector.t
         , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
               Import.Bulletproof_challenge.t
             , 'e )
             Pickles_types.Vector.t
           , 'actual_proofs_verified )
           Pickles_types.Vector.t )
         Proof.Base.Messages_for_next_proof_over_same_field.Step.t
       , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         Import.Types.Bulletproof_challenge.t
         Import.Types.Step_bp_vec.t
       , Import.Types.Branch_data.t )
       Import.Types.Wrap.Statement.In_circuit.t

  val check_verifier_error : Error.t -> unit
end) =
struct
  open Impls.Step

  let rule self : _ Inductive_rule.Promise.t =
    { identifier = "main"
    ; prevs = [ self; self ]
    ; main =
        (fun { public_input = () } ->
          let dummy_proof =
            exists (Typ.prover_value ()) ~compute:(fun () ->
                Proof.dummy Nat.N2.n Nat.N2.n ~domain_log2:15 )
          in
          Promise.return
            { Inductive_rule.previous_proof_statements =
                [ { public_input = ()
                  ; proof = dummy_proof
                  ; proof_must_verify = Boolean.false_
                  }
                ; { public_input = ()
                  ; proof = dummy_proof
                  ; proof_must_verify = Boolean.false_
                  }
                ]
            ; public_output = ()
            ; auxiliary_output = ()
            } )
    ; feature_flags = Plonk_types.Features.none_bool
    }

  let override_wrap_main =
    { Compile.wrap_main = Compile.wrap_main_dummy_override
    ; tweak_statement = M.tweak_statement
    }

  let tag, _, p, ([ step ] : _ H3_2.T(Compile.Prover).t) =
    Compile.compile_with_wrap_main_override_promise () ~override_wrap_main
      ~public_input:(Input Typ.unit) ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Nat.N2)
      ~name:"blockchain-snark"
      ~choices:(fun ~self -> [ rule self ])

  module Proof = (val p)

  let proof_with_stmt =
    let (), (), p = Promise.block_on_async_exn (fun () -> step ()) in
    ((), p)

  let test_verify_invalid_proof () =
    Alcotest.(check bool)
      "should not be able to verify invalid proof" true
      ( match
          Promise.block_on_async_exn (fun () ->
              Proof.verify_promise [ proof_with_stmt ] )
        with
      | Ok () ->
          false
      | Error err ->
          M.check_verifier_error err ; true )

  module Recurse_on_bad_proof = struct
    open Impls.Step

    type _ Snarky_backendless.Request.t +=
      | Proof : Proof.t Snarky_backendless.Request.t

    let handler (proof : Proof.t)
        (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | Proof ->
          respond (Provide proof)
      | _ ->
          respond Unhandled

    let _tag, _, p, ([ step ] : _ H3_2.T(Compile.Prover).t) =
      Common.time "compile" (fun () ->
          Compile.compile_with_wrap_main_override_promise ()
            ~public_input:(Input Typ.unit) ~auxiliary_typ:Typ.unit
            ~max_proofs_verified:(module Nat.N2)
            ~name:"recurse-on-bad"
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; feature_flags = Plonk_types.Features.none_bool
                ; prevs = [ tag; tag ]
                ; main =
                    (fun { public_input = () } ->
                      let proof =
                        exists (Typ.prover_value ()) ~request:(fun () -> Proof)
                      in
                      Promise.return
                        { Inductive_rule.previous_proof_statements =
                            [ { public_input = ()
                              ; proof
                              ; proof_must_verify = Boolean.true_
                              }
                            ; { public_input = ()
                              ; proof
                              ; proof_must_verify = Boolean.true_
                              }
                            ]
                        ; public_output = ()
                        ; auxiliary_output = ()
                        } )
                }
              ] ) )

    module Proof = (val p)
  end

  let test_recurse_on_invalid_proof () =
    Alcotest.(check bool)
      "should not be able to create a recursive proof from an invalid proof"
      true
      ( try
          let (), (), proof =
            Promise.block_on_async_exn (fun () ->
                Recurse_on_bad_proof.step
                  ~handler:(Recurse_on_bad_proof.handler (snd proof_with_stmt))
                  () )
          in
          Or_error.is_error
          @@ Promise.block_on_async_exn (fun () ->
                 Recurse_on_bad_proof.Proof.verify_promise [ ((), proof) ] )
        with _ -> true )
end

module Domain_size_too_large = Make_adversarial_test (struct
  let tweak_statement (stmt : _ Import.Types.Wrap.Statement.In_circuit.t) =
    (* Modify the statement to use an invalid domain size. *)
    { stmt with
      proof_state =
        { stmt.proof_state with
          deferred_values =
            { stmt.proof_state.deferred_values with
              branch_data =
                { stmt.proof_state.deferred_values.branch_data with
                  Branch_data.domain_log2 =
                    Branch_data.Domain_log2.of_int_exn
                      (Nat.to_int Kimchi_pasta.Basic.Rounds.Step.n + 1)
                }
            }
        }
    }

  let check_verifier_error err =
    (* Convert to JSON to make it easy to parse. *)
    err |> Error_json.error_to_yojson
    |> Yojson.Safe.Util.member "multiple"
    |> Yojson.Safe.Util.to_list
    |> List.find_exn ~f:(fun json ->
           let error =
             json
             |> Yojson.Safe.Util.member "string"
             |> Yojson.Safe.Util.to_string
           in
           String.equal error "domain size is small enough" )
    |> fun _ -> ()
end)

let () =
  let open Alcotest in
  run "Pickles adversarial"
    [ ( "Domain size too large"
      , [ test_case "verify invalid proof" `Quick
            Domain_size_too_large.test_verify_invalid_proof
        ; test_case "recurse on invalid proof" `Quick
            Domain_size_too_large.test_recurse_on_invalid_proof
        ] )
    ]
