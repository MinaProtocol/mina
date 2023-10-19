open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

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
      ~name:"custom"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "custom"
          ; prevs = []
          ; main =
              (fun _ ->
                let fresh_zero () =
                  exists Field.typ ~compute:(fun _ -> Field.Constant.zero)
                in
                let fresh_one () =
                  exists Field.typ ~compute:(fun _ -> Field.Constant.one)
                in
                Impl.assert_
                  { basic =
                      Kimchi_backend_common.Plonk_constraint_system
                      .Plonk_constraint
                      .T
                        (Raw
                           { kind = ForeignFieldAdd
                           ; values =
                               [| fresh_one ()
                                ; fresh_zero ()
                                ; fresh_zero ()
                                ; fresh_zero ()
                                ; fresh_zero ()
                                ; fresh_zero ()
                                ; fresh_zero ()
                               |]
                           ; coeffs = [||]
                           } )
                  ; annotation = Some __LOC__
                  } ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags =
              { Pickles_types.Plonk_types.Features.none_bool with
                foreign_field_add = true
              }
          ; override_ffadd = true
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
      ~name:"recursion over chunks"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "recurse over 2^17"
          ; prevs = [ tag ]
          ; main =
              (fun _ ->
                let proof =
                  exists (Typ.Internal.ref ()) ~request:(fun () ->
                      Requests.Proof )
                in
                { previous_proof_statements =
                    [ { public_input = ()
                      ; proof
                      ; proof_must_verify = Boolean.true_
                      }
                    ]
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
          ; override_ffadd = true
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
    let public_input, (), proof =
      Async.Thread_safe.block_on_async_exn (fun () ->
          recursive_prove ~handler:(Requests.handler proof) () )
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Recursive_proof.verify [ (public_input, proof) ] ) )
  in
  test_prove ()

let () =
  test () ;
  Alcotest.run "Chunked circuit"
    [ ("2^16", [ ("prove and verify", `Quick, test) ]) ]
