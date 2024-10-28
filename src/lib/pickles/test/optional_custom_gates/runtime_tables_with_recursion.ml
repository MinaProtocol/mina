open Core_kernel
open Pickles_types
open Pickles.Impls.Step
open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

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
  
  (* Set this value for reproducibility *)
let seed = [| Random.int 1_000_000 |]

let state = Random.State.make seed

  let random_table_id = 1 + Random.State.int state 1_000
  
  let fresh_int i = exists Field.typ ~compute:(fun () -> Field.Constant.of_int i)

  
  let add_plonk_constraint c =
    add_constraint
      (Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T c)

  let main_runtime_tables () =
    let table_id = random_table_id in
    let table_size = 10 in
    let first_column = Array.init table_size Field.of_int in
    add_plonk_constraint
    (AddRuntimeTableCfg { id = Int32.of_int table_id; first_column }) ;
    add_constraint
          (Lookup
             { w0 = fresh_int table_id
             ; w1 = fresh_int 0
             ; w2 = fresh_int Random.State.int state 100
             ; w3 = fresh_int 1
             ; w4 = fresh_int Random.State.int state 100
             ; w5 = fresh_int 2
             ; w6 = fresh_int Random.State.int state 100
             } )
  
let test () =
  let tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N0)
      ~num_chunks:1 ~override_wrap_domain:N1 ~name:"runtime table lookup"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "runtime tables"
          ; prevs = []
          ; main =
              (fun _ ->
                main_runtime_tables () ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = Pickles_types.Plonk_types.Features.
        { none_bool with
          lookup = true
        ; runtime_tables = true
        }
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
  (* force vk creation  *)
  let _vk =
    Async.Thread_safe.block_on_async_exn (fun () ->
        Pickles.Side_loaded.Verification_key.of_compiled tag )
  in
  let tag2, _cache_handle, recursive_proof, Pickles.Provers.[ recursive_prove ]
      =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N1)
      ~name:"recursion over runtime tables"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "recurse over runtime tables"
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
          }
        ] )
      ()
  in
  (* force vk creation  *)
  let _vk =
    Async.Thread_safe.block_on_async_exn (fun () ->
        Pickles.Side_loaded.Verification_key.of_compiled tag2 )
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
  Alcotest.run "Runtime tables with recursion"
    [ ("runtime", [ ("prove and verify", `Quick, test) ]) ]
