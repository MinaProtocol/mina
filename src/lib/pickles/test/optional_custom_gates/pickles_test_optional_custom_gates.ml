open Core_kernel
open Pickles_types
open Pickles.Impls.Step
open Pickles_optional_custom_gates_circuits

(** Testing
    -------

    Component: Pickles
    Subject: Testing the integration of custom gates
    Invocation: dune exec \
    src/lib/pickles/test/optional_custom_gates/pickles_test_optional_custom_gates.exe
*)

(* Set this value for reproducibility *)
let seed = [| Random.int 1_000_000 |]

let state = Random.State.make seed

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

(* Parameters *)
let random_table_id = Random.State.int state 1_000

let size = 1 + Random.State.int state 1_000

let values =
  Array.init size ~f:(fun _ ->
      let x = Random.State.int state 1_000_000 in
      Field.Constant.of_int x )

let idx1 = Random.State.int state size

let idx2 = Random.State.int state size

let idx3 = Random.State.int state size

let main_fixed_lookup_tables () =
  let table_id = random_table_id in
  let indexes = Array.init size ~f:Field.Constant.of_int in
  add_plonk_constraint
    (AddFixedLookupTable
       { id = Int32.of_int_exn table_id; data = [| indexes; values |] } ) ;
  let v1 = values.(idx1) in
  let v2 = values.(idx2) in
  let v3 = values.(idx3) in
  add_plonk_constraint
    (Lookup
       { (* table id *)
         w0 = fresh_int table_id
       ; (* idx1 *) w1 = fresh_int idx1
       ; (* v1 *) w2 = exists Field.typ ~compute:(fun () -> v1)
       ; (* idx2 *) w3 = fresh_int idx2
       ; (* v2 *) w4 = exists Field.typ ~compute:(fun () -> v2)
       ; (* idx3 *) w5 = fresh_int idx3
       ; (* v3 *) w6 = exists Field.typ ~compute:(fun () -> v3)
       } )

(* Parameters *)
(* nb of fixed lookup tables *)
let m = 1 + Random.State.int state 10

let f_lt_data =
  Array.init m ~f:(fun _ ->
      let size = 1 + Random.State.int state 100 in
      let indexes = Array.init size ~f:Field.Constant.of_int in
      let values =
        Array.init size ~f:(fun _ ->
            Field.Constant.of_int (Random.State.int state 100_000_000) )
      in
      (indexes, values) )

(* number of lookups *)
let n = 1 + Random.State.int state 10

let lookups =
  Array.init n ~f:(fun _ ->
      let table_id = Random.State.int state m in
      let indexes, values = f_lt_data.(table_id) in
      let table_size = Array.length indexes in
      let idx1 = Random.State.int state table_size in
      let idx2 = Random.State.int state table_size in
      let idx3 = Random.State.int state table_size in
      ( table_id
      , (idx1, values.(idx1))
      , (idx2, values.(idx2))
      , (idx3, values.(idx3)) ) )

let main_fixed_lookup_tables_multiple_tables_multiple_lookups () =
  Array.iteri f_lt_data ~f:(fun table_id (indexes, values) ->
      add_plonk_constraint
        (AddFixedLookupTable
           { id = Int32.of_int_exn table_id; data = [| indexes; values |] } ) ) ;
  Array.iter lookups ~f:(fun (table_id, (idx1, v1), (idx2, v2), (idx3, v3)) ->
      add_plonk_constraint
        (Lookup
           { w0 = fresh_int table_id
           ; w1 = fresh_int idx1
           ; w2 = exists Field.typ ~compute:(fun () -> v1)
           ; w3 = fresh_int idx2
           ; w4 = exists Field.typ ~compute:(fun () -> v2)
           ; w5 = fresh_int idx3
           ; w6 = exists Field.typ ~compute:(fun () -> v3)
           } ) )

let main_runtime_table_cfg () =
  let table_ids = Array.init 5 ~f:(fun i -> Int32.of_int_exn i) in
  let size = 10 in
  let first_column = Array.init size ~f:Field.Constant.of_int in
  Array.iter table_ids ~f:(fun table_id ->
      add_plonk_constraint (AddRuntimeTableCfg { id = table_id; first_column }) ) ;
  let num_lookup = 20 in
  let rec make_lookup i n =
    if i = n then ()
    else
      let table_id = 3 in
      add_plonk_constraint
        (Lookup
           { w0 = fresh_int table_id
           ; w1 = fresh_int 1
           ; w2 = fresh_int 1
           ; w3 = fresh_int 2
           ; w4 = fresh_int 2
           ; w5 = fresh_int 3
           ; w6 = fresh_int 3
           } ) ;
      make_lookup (i + 1) n
  in
  make_lookup 0 num_lookup

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
  Pickles_optional_custom_gates_circuits.main_body ~feature_flags () ;
  if feature_flags.runtime_tables then main_runtime_table_cfg () ;
  if feature_flags.lookup then (
    main_fixed_lookup_tables () ;
    main_fixed_lookup_tables_multiple_tables_multiple_lookups () )

let register_test name feature_flags1 feature_flags2 =
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

let register_feature_test (name, specific_feature_flags) =
  (* Tests activating "on" logic*)
  register_test name specific_feature_flags specific_feature_flags ;
  (* Tests activating "maybe on" logic *)
  register_test
    (Printf.sprintf "%s (maybe)" name)
    specific_feature_flags Plonk_types.Features.none_bool

let () =
  let configurations =
    [ ("xor", Plonk_types.Features.{ none_bool with xor = true })
    ; ( "range check 0"
      , Plonk_types.Features.{ none_bool with range_check0 = true } )
    ; ( "range check 1"
      , Plonk_types.Features.{ none_bool with range_check1 = true } )
    ; ("rot", Plonk_types.Features.{ none_bool with rot = true })
    ; ( "foreign field addition"
      , Plonk_types.Features.{ none_bool with foreign_field_add = true } )
    ; ( "foreign field multiplication"
      , Plonk_types.Features.{ none_bool with foreign_field_mul = true } )
    ; ( "Fixed lookup tables"
      , Plonk_types.Features.{ none_bool with lookup = true } )
    ; ( "Runtime lookup tables"
      , Plonk_types.Features.
          { none_bool with lookup = true; runtime_tables = true } )
    ]
  in
  List.iter ~f:register_feature_test configurations ;
  register_test "different sizes of lookup"
    Plonk_types.Features.{ none_bool with foreign_field_mul = true }
    Plonk_types.Features.{ none_bool with xor = true } ;
  Alcotest.run "Custom gates" (get_tests ())
