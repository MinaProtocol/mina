(* TODO: see if keep this module aliases in place or use fully-qualified names
   instead. *)
module P = Pickles__Pickles_internal
module Tock = Backend.Tock
module Tick = Backend.Tick

module No_side_loaded = struct
  let () = Tock.Keypair.set_urs_info []

  let () = Tick.Keypair.set_urs_info []

  let () = Backtrace.elide := false

  open Impls.Step

  let () = Snarky_backendless.Snark0.set_eval_constraints true

  (* Currently, a circuit must have at least 1 of every type of constraint. *)
  let dummy_constraints () =
    Impl.(
      let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
      let g =
        exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
            Tick.Inner_curve.(to_affine_exn one) )
      in
      ignore
        ( Scalar_challenge.to_field_checked'
            (module Impl)
            ~num_bits:16
            (Kimchi_backend_common.Scalar_challenge.create x)
          : Field.t * Field.t * Field.t ) ;
      ignore
        ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
          : Step_main_inputs.Inner_curve.t ) ;
      ignore
        ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
          : Step_main_inputs.Inner_curve.t ) ;
      ignore
        ( Step_verifier.Scalar_challenge.endo g ~num_bits:4
            (Kimchi_backend_common.Scalar_challenge.create x)
          : Field.t * Field.t ))

  let compile ~main =
    compile_promise () ~public_input:(Input Field.typ) ~auxiliary_typ:Typ.unit
      ~branches:(module Pickles_types.Nat.N1)
      ~max_proofs_verified:(module Pickles_types.Nat.N0)
      ~name:"blockchain-snark"
      ~constraint_constants:
        (* Dummy values *)
        { sub_windows_per_window = 0
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
      ~choices:(fun ~self:_ ->
        [ { identifier = "main"
          ; prevs = []
          ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
          ; main
          }
        ] )

  module No_recursion = struct
    let[@warning "-45"] tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile ~main:(fun { public_input = self } ->
              dummy_constraints () ;
              Field.Assert.equal self Field.zero ;
              { previous_proof_statements = []
              ; public_output = ()
              ; auxiliary_output = ()
              } ) )

    module Proof = (val p)

    let example =
      lazy
        (let (), (), b0 =
           Common.time "b0" (fun () ->
               Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
         in
         Or_error.ok_exn
           (Promise.block_on_async_exn (fun () ->
                Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
         (Field.Constant.zero, b0) )
  end

  module No_recursion_return = struct
    let[@warning "-45"] tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise () ~public_input:(Output Field.typ)
            ~auxiliary_typ:Typ.unit
            ~branches:(module Pickles_types.Nat.N1)
            ~max_proofs_verified:(module Pickles_types.Nat.N0)
            ~name:"blockchain-snark"
            ~constraint_constants:
              (* Dummy values *)
              { sub_windows_per_window = 0
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
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; prevs = []
                ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
                ; main =
                    (fun _ ->
                      dummy_constraints () ;
                      { previous_proof_statements = []
                      ; public_output = Field.zero
                      ; auxiliary_output = ()
                      } )
                }
              ] ) )

    module Proof = (val p)

    let example =
      lazy
        (let res, (), b0 =
           Common.time "b0" (fun () ->
               Promise.block_on_async_exn (fun () -> step ()) )
         in
         assert (Field.Constant.(equal zero) res) ;
         Or_error.ok_exn
           (Promise.block_on_async_exn (fun () ->
                Proof.verify_promise [ (res, b0) ] ) ) ;
         (res, b0) )
  end
end

let test_lazy_eval : type a. a lazy_t -> unit -> unit =
 fun lazy_v () -> ignore (Lazy.force lazy_v : a)

let tests =
  let open Alcotest in
  [ ( "Pickles:No side loaded"
    , [ test_case "no recursion" `Quick
          (test_lazy_eval No_side_loaded.No_recursion.example)
      ; test_case "no recursion return" `Quick
          (test_lazy_eval No_side_loaded.No_recursion_return.example)
      ] )
  ]
