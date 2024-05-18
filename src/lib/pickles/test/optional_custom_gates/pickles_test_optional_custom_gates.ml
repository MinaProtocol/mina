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
let random_table_id = 1 + Random.State.int state 1_000

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
let max_fixed_lt_n = 1 + Random.State.int state 10

(* number of fixed lookups *)
let fixed_lt_queries_n = 1 + Random.State.int state 100

(* fixed lookup tables data *)
let fixed_lt_data =
  (* generate some random unique table ids *)
  let fixed_table_ids =
    Int.Set.to_array
      (Int.Set.of_list
         (List.init max_fixed_lt_n ~f:(fun _ ->
              1 + Random.State.int state (max_fixed_lt_n * 4) ) ) )
  in
  Array.map fixed_table_ids ~f:(fun table_id ->
      let max_table_size = 1 + Random.State.int state 100 in
      let indexes =
        Int.Set.to_array
          (Int.Set.of_list
             (List.init max_table_size ~f:(fun _ ->
                  1 + Random.State.int state (max_table_size * 4) ) ) )
      in
      let table_size = Array.length indexes in
      let values =
        Array.init table_size ~f:(fun _ -> Random.State.int state 100_000_000)
      in
      (table_id, indexes, values) )

(* lookup queries; selected random rows from f_lt_data *)
let lookups =
  Array.init fixed_lt_queries_n ~f:(fun _ ->
      let table_id, indexes, values =
        fixed_lt_data.(Random.State.int state (Array.length fixed_lt_data))
      in
      let table_size = Array.length indexes in
      let idx1 = Random.State.int state table_size in
      let idx2 = Random.State.int state table_size in
      let idx3 = Random.State.int state table_size in
      ( table_id
      , (indexes.(idx1), values.(idx1))
      , (indexes.(idx2), values.(idx2))
      , (indexes.(idx3), values.(idx3)) ) )

let main_fixed_lookup_tables_multiple_tables_multiple_lookups () =
  Array.iter fixed_lt_data ~f:(fun (table_id, indexes, values) ->
      add_plonk_constraint
        (AddFixedLookupTable
           { id = Int32.of_int_exn table_id
           ; data =
               [| Array.map ~f:Field.Constant.of_int indexes
                ; Array.map ~f:Field.Constant.of_int values
               |]
           } ) ) ;
  Array.iter lookups ~f:(fun (table_id, (idx1, v1), (idx2, v2), (idx3, v3)) ->
      add_plonk_constraint
        (Lookup
           { w0 = fresh_int table_id
           ; w1 = fresh_int idx1
           ; w2 = fresh_int v1
           ; w3 = fresh_int idx2
           ; w4 = fresh_int v2
           ; w5 = fresh_int idx3
           ; w6 = fresh_int v3
           } ) )

(* maximum number of runtime lookup tables *)
let max_runtime_lt_n = 1 + Random.State.int state 10

(* number of runtime lookups *)
let runtime_lt_queries_n = 1 + Random.State.int state 100

(* runtime lookup tables data *)
let runtime_lt_data =
  let runtime_table_ids =
    (* have at least one collision between runtime and fixed table ids *)
    let random_fixed_table_id =
      let table_id, _, _ =
        fixed_lt_data.(Random.State.int state (Array.length fixed_lt_data))
      in
      table_id
    in
    (* and generate some random table ids *)
    let other_ids =
      List.init (max_runtime_lt_n - 1) ~f:(fun _ ->
          1 + Random.State.int state 100 )
    in
    (* making sure they're all unique *)
    Int.Set.to_array
      (Int.Set.of_list (List.cons random_fixed_table_id other_ids))
  in

  Array.map runtime_table_ids ~f:(fun table_id ->
      let max_table_size = 1 + Random.State.int state 100 in
      let first_column =
        Int.Set.to_array
          (Int.Set.of_list
             (List.init max_table_size ~f:(fun _ ->
                  1 + Random.State.int state (max_table_size * 4) ) ) )
      in
      let table_size = Array.length first_column in
      (* We must make sure that if runtime table_id collides with some
         fixed table_id created earlier then elements in first_column
         and (fixed) indexes are either disjoint (k1 != k2), or they
         map to the same value (v1 = v2). In other words, in the case
         that this fixed table already contains (k,v) with k =
         first_column[i], we have to set second_column[i] to v. *)
      let second_column =
        match
          Array.find
            ~f:(fun (fixed_table_id, _, _) -> fixed_table_id = table_id)
            fixed_lt_data
        with
        | Some (_, indexes, values) ->
            (* This is O(n^2), can be O(nlogn) *)
            Array.map first_column ~f:(fun k ->
                match Array.findi ~f:(fun _ k2 -> k2 = k) indexes with
                | Some (ix, _) ->
                    values.(ix)
                | None ->
                    Random.State.int state 1_000_000 )
        | None ->
            Array.init table_size ~f:(fun _ -> Random.State.int state 1_000_000)
      in
      (table_id, first_column, second_column) )

(* runtime lookup queries *)
let runtime_lookups =
  Array.init runtime_lt_queries_n ~f:(fun _ ->
      let table_id, first_column, second_column =
        runtime_lt_data.(Random.State.int state (Array.length runtime_lt_data))
      in
      let table_size = Array.length first_column in
      let idx1 = Random.State.int state table_size in
      let idx2 = Random.State.int state table_size in
      let idx3 = Random.State.int state table_size in
      ( table_id
      , (first_column.(idx1), second_column.(idx1))
      , (first_column.(idx2), second_column.(idx2))
      , (first_column.(idx3), second_column.(idx3)) ) )

let main_runtime_table_cfg () =
  Array.iter runtime_lt_data ~f:(fun (table_id, first_column, _) ->
      add_plonk_constraint
        (AddRuntimeTableCfg
           { id = Int32.of_int_exn table_id
           ; first_column = Array.map ~f:Field.Constant.of_int first_column
           } ) ) ;
  Array.iter runtime_lookups ~f:(fun (table_id, (k1, v1), (k2, v2), (k3, v3)) ->
      add_plonk_constraint
        (Lookup
           { w0 = fresh_int table_id
           ; w1 = fresh_int k1
           ; w2 = fresh_int v1
           ; w3 = fresh_int k2
           ; w4 = fresh_int v2
           ; w5 = fresh_int k3
           ; w6 = fresh_int v3
           } ) )

let add_tests, get_tests =
  let tests = ref [] in
  ( (fun name testcases -> tests := (name, testcases) :: !tests)
  , fun () -> List.rev !tests )

let main_body ~(feature_flags : _ Plonk_types.Features.t) () =
  Pickles_optional_custom_gates_circuits.main_body ~feature_flags () ;
  if feature_flags.runtime_tables then main_runtime_table_cfg () ;
  if feature_flags.lookup then (
    main_fixed_lookup_tables () ;
    main_fixed_lookup_tables_multiple_tables_multiple_lookups () )

let register_test name feature_flags1 feature_flags2 =
  let tag, _cache_handle, proof, Pickles.Provers.[ prove1; prove2 ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N2)
      ~max_proofs_verified:(module Nat.N0)
      ~name:"optional_custom_gates"
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
  (* force vk creation before adding test *)
  let _vk =
    Async.Thread_safe.block_on_async_exn (fun () ->
        Pickles.Side_loaded.Verification_key.of_compiled tag )
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
    ; ( "fixed lookup tables"
      , Plonk_types.Features.{ none_bool with lookup = true } )
    ; ( "runtime+fixed lookup tables"
      , Plonk_types.Features.
          { none_bool with lookup = true; runtime_tables = true } )
    ]
  in
  List.iter ~f:register_feature_test configurations ;
  register_test "different sizes of lookup"
    Plonk_types.Features.{ none_bool with foreign_field_mul = true }
    Plonk_types.Features.{ none_bool with xor = true } ;
  Alcotest.run "Custom gates" (get_tests ())
