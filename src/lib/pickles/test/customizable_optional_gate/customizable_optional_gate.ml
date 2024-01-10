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

let register_test name feature_flags custom_gate_type =
  let _tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N0)
      ~name:"optional_custom_gates"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "main1"
          ; prevs = []
          ; main =
              (fun _ ->
                main_body ~feature_flags () ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags
          ; custom_gate_type
          }
        ] )
      ()
  in
  let module Proof = (val proof) in
  let test_prove () =
    let public_input1, (), proof1 =
      Async.Thread_safe.block_on_async_exn (fun () -> prove ())
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Proof.verify [ (public_input1, proof1) ] ) )
  in

  let open Alcotest in
  add_tests name [ test_case "prove" `Quick test_prove ]

let register_feature_test (name, specific_feature_flags, custom_gate_type) =
  (* Tests activating "on" logic *)
  register_test name specific_feature_flags custom_gate_type ;
  (* Tests activating "maybe on" logic *)
  register_test
    (Printf.sprintf "%s (maybe)" name)
    Plonk_types.Features.none_bool custom_gate_type

(* User-supplied conditional gate in RPN
 *     w(0) = w(1) * w(3) + (1 - w(3)) * w(2)
 *)
let conditional_gate =
  Some
    Kimchi_types.
      [| Cell { col = Index ForeignFieldAdd; row = Curr }
       ; Cell { col = Witness 3; row = Curr }
       ; Dup
       ; Mul
       ; Cell { col = Witness 3; row = Curr }
       ; Sub
       ; Alpha
       ; Pow 1l
       ; Cell { col = Witness 0; row = Curr }
       ; Cell { col = Witness 3; row = Curr }
       ; Cell { col = Witness 1; row = Curr }
       ; Mul
       ; Literal (Impl.Field.Constant.of_int 1)
       ; Cell { col = Witness 3; row = Curr }
       ; Sub
       ; Cell { col = Witness 2; row = Curr }
       ; Mul
       ; Add
       ; Sub
       ; Mul
       ; Add
       ; Mul
      |]

let () =
  let configurations =
    [ ( "customizable gate (ffadd)"
      , Plonk_types.Features.{ none_bool with foreign_field_add = true }
      , None )
    ; ( "customizable gate (conditional)"
      , Plonk_types.Features.{ none_bool with foreign_field_add = true }
      , conditional_gate )
    ]
  in
  List.iter ~f:register_feature_test configurations ;
  Alcotest.run "Custom gates" (get_tests ())
