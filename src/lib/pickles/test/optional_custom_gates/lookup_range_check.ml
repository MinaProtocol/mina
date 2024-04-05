open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let add_constraint c = assert_ { basic = c; annotation = None }

let add_plonk_constraint c =
  add_constraint
    (Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T c)

let fresh_int i = exists Field.typ ~compute:(fun () -> Field.Constant.of_int i)

let range_check0 () =
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
       } )

let range_check_in_lookup_gate () =
  add_plonk_constraint
    (Lookup
       { w0 = (* Range check table *) fresh_int 1
       ; w1 = fresh_int 1
       ; w2 = fresh_int 0
       ; w3 = fresh_int 2
       ; w4 = fresh_int 0
       ; w5 = fresh_int ((1 lsl 12) - 1)
       ; w6 = fresh_int 0
       } )

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

let test_range_check_lookup () =
  let _tag, _cache_handle, (module Proof), Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N0)
      ~name:"lookup range-check"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "main"
          ; prevs = []
          ; main =
              (fun _ ->
                range_check0 () ;
                range_check_in_lookup_gate () ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags =
              Plonk_types.Features.
                { none_bool with range_check0 = true; lookup = true }
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
