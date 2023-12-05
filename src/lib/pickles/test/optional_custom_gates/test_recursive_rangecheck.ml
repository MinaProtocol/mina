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

let add_constraint c = assert_ { basic = c; annotation = None }

let add_plonk_constraint c =
  add_constraint
    (Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T c)

let fresh_int i = exists Field.typ ~compute:(fun () -> Field.Constant.of_int i)

let main_range_check0 () =
  add_plonk_constraint
    (RangeCheck0
       { v0 = fresh_int 0
       ; v0p0 = fresh_int 0
       ; v0p1 = fresh_int 0
       ; v0p2 = fresh_int 0
       ; v0p3 = fresh_int 0
       ; v0p4 = fresh_int 0
       ; v0p5 = fresh_int 0
       ; v0c0 = fresh_int 0
       ; v0c1 = fresh_int 0
       ; v0c2 = fresh_int 0
       ; v0c3 = fresh_int 0
       ; v0c4 = fresh_int 0
       ; v0c5 = fresh_int 0
       ; v0c6 = fresh_int 0
       ; v0c7 = fresh_int 0
       ; (* Coefficients *)
         compact = Field.Constant.zero
       } ) ;
  add_plonk_constraint (Raw { kind = Zero; values = [||]; coeffs = [||] })

let test () =
  let tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N0)
      ~num_chunks:1 ~name:"recursive rangecheck"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "Recursive rangecheck"
          ; prevs = []
          ; main =
              (fun _ ->
                main_range_check0 () ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags =
              Pickles_types.Plonk_types.Features.
                { none_bool with range_check0 = true }
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
      ~name:"recursion over rangecheck"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "recurse rangecheck"
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
          ; feature_flags =
              Pickles_types.Plonk_types.Features.
                { none_bool with range_check0 = true }
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
  Alcotest.run "Recursive range check"
    [ ("2^16", [ ("prove and verify", `Quick, test) ]) ]
