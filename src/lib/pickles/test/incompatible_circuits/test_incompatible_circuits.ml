open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let add_tests, get_tests =
  let tests = ref [] in
  ( (fun name testcases -> tests := (name, testcases) :: !tests)
  , fun () -> List.rev !tests )

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

let circuit1 () =
  Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
    ~auxiliary_typ:Typ.unit
    ~branches:(module Nat.N1)
    ~max_proofs_verified:(module Nat.N0)
    ~name:"circuit1" ~constraint_constants
    ~choices:(fun ~self:_ ->
      [ { identifier = "main"
        ; prevs = []
        ; main =
            (fun _ ->
              let x =
                exists Field.typ ~compute:(fun () -> Field.Constant.of_int 1)
              in
              let y =
                exists Field.typ ~compute:(fun () -> Field.Constant.of_int 2)
              in
              let z =
                exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3)
              in
              Field.Assert.equal (Field.add x y) z ;
              { previous_proof_statements = []
              ; public_output = ()
              ; auxiliary_output = ()
              } )
        ; feature_flags = Plonk_types.Features.none_bool
        }
      ] )
    ()

let circuit2 () =
  Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
    ~auxiliary_typ:Typ.unit
    ~branches:(module Nat.N1)
    ~max_proofs_verified:(module Nat.N0)
    ~name:"circuit2" ~constraint_constants
    ~choices:(fun ~self:_ ->
      [ { identifier = "main"
        ; prevs = []
        ; main =
            (fun _ ->
              let x =
                exists Field.typ ~compute:(fun () -> Field.Constant.of_int 1)
              in
              let y =
                exists Field.typ ~compute:(fun () -> Field.Constant.of_int 2)
              in
              let z =
                exists Field.typ ~compute:(fun () -> Field.Constant.of_int 2)
              in
              Field.Assert.equal (Field.mul x y) z ;
              { previous_proof_statements = []
              ; public_output = ()
              ; auxiliary_output = ()
              } )
        ; feature_flags = Plonk_types.Features.none_bool
        }
      ] )
    ()

type _ Snarky_backendless.Request.t +=
  | Proof1 : (Nat.N0.n, Nat.N0.n) Pickles.Proof.t Snarky_backendless.Request.t

let handler3 (proof : _ Pickles.Proof.t)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Proof1 ->
      respond (Provide proof)
  | _ ->
      respond Unhandled

let circuit3 ~prev_tag () =
  Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
    ~auxiliary_typ:Typ.unit
    ~branches:(module Nat.N1)
    ~max_proofs_verified:(module Nat.N1)
    ~name:"circuit3" ~constraint_constants
    ~choices:(fun ~self:_ ->
      [ { identifier = "main"
        ; prevs = [ prev_tag ]
        ; main =
            (fun _ ->
              let proof =
                exists (Typ.Internal.ref ()) ~request:(fun () -> Proof1)
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
        ; feature_flags = Plonk_types.Features.none_bool
        }
      ] )
    ()

let () =
  let open Alcotest in
  let open Async.Deferred.Let_syntax in
  let tag1, _cache_handle1, (module Proof1), Pickles.Provers.[ prove1 ] =
    circuit1 ()
  in
  let _tag2, _cache_handle2, (module Proof2), Pickles.Provers.[ prove2 ] =
    circuit2 ()
  in
  let _tag3, _cache_handle3, (module Proof3), Pickles.Provers.[ prove3 ] =
    circuit3 ~prev_tag:tag1 ()
  in
  let proof1 = lazy (prove1 ()) in
  let proof2 = lazy (prove2 ()) in
  let proof3 =
    lazy
      (let%bind (), (), proof1 = Lazy.force proof1 in
       prove3 ~handler:(handler3 proof1) () )
  in
  let proof1_verifies () =
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           let%bind (), (), proof1 = Lazy.force proof1 in
           Proof1.verify [ ((), proof1) ] ) )
  in
  let proof2_verifies () =
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           let%bind (), (), proof2 = Lazy.force proof2 in
           Proof2.verify [ ((), proof2) ] ) )
  in
  let proof3_verifies () =
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           let%bind (), (), proof3 = Lazy.force proof3 in
           Proof3.verify [ ((), proof3) ] ) )
  in
  add_tests "Proofs verify"
    [ test_case "proof1 verifies" `Quick proof1_verifies
    ; test_case "proof2 verifies" `Quick proof2_verifies
    ; test_case "proof3 verifies" `Quick proof3_verifies
    ] ;
  let proof1_2_cross_verify () =
    assert (
      Or_error.is_error
        (Async.Thread_safe.block_on_async_exn (fun () ->
             let%bind (), (), proof1 = Lazy.force proof1 in
             Proof2.verify [ ((), proof1) ] ) ) )
  in
  let proof2_1_cross_verify () =
    assert (
      Or_error.is_error
        (Async.Thread_safe.block_on_async_exn (fun () ->
             let%bind (), (), proof2 = Lazy.force proof2 in
             Proof1.verify [ ((), proof2) ] ) ) )
  in
  add_tests "Proofs do not cross-verify"
    [ test_case "proof1 does not cross-verify with proof2's verifier" `Quick
        proof1_2_cross_verify
    ; test_case "proof2 does not cross-verify with proof1's verifier" `Quick
        proof2_1_cross_verify
    ] ;
  let proof3_cannot_prove_with_proof2 () =
    assert (
      Or_error.is_error
      @@ Or_error.try_with (fun () ->
             Async.Thread_safe.block_on_async_exn (fun () ->
                 let%bind (), (), proof2 = Lazy.force proof2 in
                 prove3 ~handler:(handler3 proof2) () ) ) )
  in
  add_tests "Circuit does not cross-verify"
    [ test_case "proof2 does not cross-verify with proof2's verifier circuit"
        `Quick proof3_cannot_prove_with_proof2
    ]

let () = Alcotest.run "Incompatible circuits" (get_tests ())
