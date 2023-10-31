open Core_kernel
open Pickles_types
open Pickles.Impls.Step

(** Testing
    -------

    Component: Pickles
    Subject: Testing the integration of customizable gate
    Invocation: dune exec \
    src/lib/pickles/test/customizable_gate/customizable_gate_test.exe
*)

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let add_constraint c = assert_ { basic = c; annotation = None }

let add_plonk_constraint c =
  add_constraint
    (Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T c)

let fresh_int i = exists Field.typ ~compute:(fun () -> Field.Constant.of_int i)

let main_foreign_field_add () =
  add_plonk_constraint
    (ForeignFieldAdd
       { left_input_lo = fresh_int 0
       ; left_input_mi = fresh_int 0
       ; left_input_hi = fresh_int 0
       ; right_input_lo = fresh_int 0
       ; right_input_mi = fresh_int 0
       ; right_input_hi = fresh_int 0
       ; field_overflow = fresh_int 0
       ; carry = fresh_int 0
       ; foreign_field_modulus0 = Field.Constant.of_int 1
       ; foreign_field_modulus1 = Field.Constant.of_int 0
       ; foreign_field_modulus2 = Field.Constant.of_int 0
       ; sign = Field.Constant.of_int 0
       } ) ;
  add_plonk_constraint
    (Raw { kind = Zero; values = [| fresh_int 0 |]; coeffs = [||] })

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

let main_body ~(feature_flags : _ Plonk_types.Features.t) () =
  if feature_flags.foreign_field_add then main_foreign_field_add ()

let register_test name feature_flags1 feature_flags2 custom_gate_type1
    custom_gate_type2 =
  let _tag, _cache_handle, proof, Pickles.Provers.[ prove1; prove2 ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N2)
      ~max_proofs_verified:(module Nat.N0)
      ~name:"optional_custom_gates"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "main1"
          ; prevs = []
          ; main =
              (fun _ ->
                main_body ~feature_flags:feature_flags1 () ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = feature_flags1
          ; custom_gate_type = custom_gate_type1
          }
        ; { identifier = "main2"
          ; prevs = []
          ; main =
              (fun _ ->
                main_body ~feature_flags:feature_flags2 () ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = feature_flags2
          ; custom_gate_type = custom_gate_type2
          }
        ] )
      ()
  in
  let module Proof = (val proof) in
  let test_prove1 () =
    let public_input1, (), proof1 =
      Async.Thread_safe.block_on_async_exn (fun () -> prove1 ())
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Proof.verify [ (public_input1, proof1) ] ) )
  in
  let test_prove2 () =
    let public_input2, (), proof2 =
      Async.Thread_safe.block_on_async_exn (fun () -> prove2 ())
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Proof.verify [ (public_input2, proof2) ] ) )
  in

  let open Alcotest in
  add_tests name
    [ test_case "prove 1" `Quick test_prove1
    ; test_case "prove 2" `Quick test_prove2
    ]

let register_feature_test (name, specific_feature_flags, custom_gate_type) =
  (* Tests activating "on" logic *)
  register_test name specific_feature_flags specific_feature_flags
    custom_gate_type custom_gate_type ;
  (* Tests activating "maybe on" logic *)
  register_test
    (Printf.sprintf "%s (maybe)" name)
    specific_feature_flags Plonk_types.Features.none_bool custom_gate_type
    custom_gate_type

let () =
  let configurations =
    [ ( "foreign field addition (ffadd)"
      , Plonk_types.Features.{ none_bool with foreign_field_add = true }
      , false )
    ; ( "foreign field addition (conditional)"
      , Plonk_types.Features.{ none_bool with foreign_field_add = true }
      , true )
    ]
  in
  List.iter ~f:register_feature_test configurations ;
  Alcotest.run "Custom gates" (get_tests ())
