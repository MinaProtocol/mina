open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

(* JES: TODO: delete *)
let constraint_constants =
  { Snark_keys_header.Constraint_constants.sub_windows_per_window = 0
  ; ledger_depth = 0
  ; work_delay = 0
  ; block_window_duration_ms = 0
  ; transaction_capacity = Log_2 0
  ; pending_coinbase_depth = 0
  ; coinbase_amount = Unsigned.UInt64.of_int 0
  ; supercharged_coinbase_factor = 0
  ; account_creation_fee = Unsigned.UInt64.of_int 0
  ; fork = None
  }

let test () =
  let tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N0)
      ~name:"customizable gate"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "customizable gate"
          ; prevs = []
          ; main =
              (fun _ ->
                with_label "customizable gate (ffadd)" (fun () ->
                    assert_
                      { annotation = Some __LOC__
                      ; basic =
                          Kimchi_backend_common.Plonk_constraint_system
                          .Plonk_constraint
                          .T
                            (ForeignFieldAdd
                               { left_input_lo = Field.of_int 7
                               ; left_input_mi = Field.zero
                               ; left_input_hi = Field.zero
                               ; right_input_lo = Field.of_int 63
                               ; right_input_mi = Field.zero
                               ; right_input_hi = Field.zero
                               ; field_overflow = Field.zero
                               ; carry = Field.zero
                               ; foreign_field_modulus0 =
                                   Field.Constant.of_int 7919
                               ; foreign_field_modulus1 = Field.Constant.zero
                               ; foreign_field_modulus2 = Field.Constant.zero
                               ; sign = Field.Constant.one
                               } )
                      } ) ;

                with_label "customizable gate (result)" (fun () ->
                    assert_
                      { annotation = Some __LOC__
                      ; basic =
                          Kimchi_backend_common.Plonk_constraint_system
                          .Plonk_constraint
                          .T
                            (Raw
                               { kind = Zero
                               ; values =
                                   [| Field.of_int 70; Field.zero; Field.zero |]
                               ; coeffs = [||]
                               } )
                      } ) ;

                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags =
              Pickles_types.Plonk_types.Features.
                { none_bool with foreign_field_add = true }
          ; custom_gate_type =
              false (* JES: TODO: vary this for tests as well as witness *)
          }
        ] )
      ()
  in
  let module Requests = struct
    type _ Snarky_backendless.Request.t +=
      | Proof :
          (Nat.N0.n, Nat.N0.n) Pickles.Proof.t Snarky_backendless.Request.t

    let handler (proof : _ Pickles.Proof.t)
        (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | Proof ->
          respond (Provide proof)
      | _ ->
          respond Unhandled
  end in
  let _tag, _cache_handle, recursive_proof, Pickles.Provers.[ recursive_prove ]
      =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N1)
      ~name:"recursion over customizable gate"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "recurse over customizable gate"
          ; prevs =
              [ tag ]
              (* Prev feature flags tracked here.  Maybe propagate boolean here.  *)
          ; main =
              (fun _ ->
                let proof =
                  exists (Typ.Internal.ref ()) ~request:(fun () ->
                      Requests.Proof )
                in
                { previous_proof_statements =
                    [ { public_input = ()
                      ; proof
                      ; proof_must_verify =
                          Boolean.true_ (* Special-case for genesis *)
                      }
                    ]
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags =
              Pickles_types.Plonk_types.Features.none_bool
              (* JES: TODO: Do I need to pass feature flags here for deferred values and next step? *)
              (* Pickles_types.Plonk_types.Features.
                 { none_bool with foreign_field_add = true } *)
          ; custom_gate_type = false (* JES: TODO *)
          }
        ] )
      ()
  in
  let module Proof = (val proof) in
  let module Recursive_proof = (val recursive_proof) in
  let test_prove () =
    let public_input, (), proof =
      Async.Thread_safe.block_on_async_exn (fun () -> prove ())
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Proof.verify [ (public_input, proof) ] ) ) ;
    let public_input, (), recursive_proof' =
      Async.Thread_safe.block_on_async_exn (fun () ->
          recursive_prove ~handler:(Requests.handler proof) () )
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Recursive_proof.verify [ (public_input, recursive_proof') ] ) )
  in
  test_prove ()

let () =
  test () ;
  Alcotest.run "Customizable circuit"
    [ ("customizable gate", [ ("prove and verify", `Quick, test) ]) ]
