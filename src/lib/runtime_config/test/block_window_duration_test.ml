open Core_kernel

let parse s = Runtime_config.of_yojson (Yojson.Safe.from_string s)

let parse_exn s = parse s |> Result.ok_or_failwith

let genesis_block_window_duration_ms (config : Runtime_config.t) =
  Option.bind config.genesis ~f:(fun genesis ->
      genesis.block_window_duration_ms )

let check_slot_time ~expected config =
  Alcotest.(check (option int))
    "genesis.block_window_duration_ms" expected
    (genesis_block_window_duration_ms config)

let check_error s =
  match parse s with
  | Ok _ ->
      Alcotest.fail "expected the configuration to be rejected"
  | Error _ ->
      ()

let test_new_key () =
  parse_exn {json| { "genesis": { "block_window_duration_ms": 20000 } } |json}
  |> check_slot_time ~expected:(Some 20000)

let test_legacy_key () =
  parse_exn {json| { "proof": { "block_window_duration_ms": 20000 } } |json}
  |> check_slot_time ~expected:(Some 20000)

let test_legacy_key_keeps_other_fields () =
  let config =
    parse_exn
      {json| { "genesis": { "k": 10 }
             , "proof": { "work_delay": 1, "block_window_duration_ms": 20000 } } |json}
  in
  check_slot_time ~expected:(Some 20000) config ;
  Alcotest.(check (option int))
    "genesis.k" (Some 10)
    (Option.bind config.genesis ~f:(fun genesis -> genesis.k)) ;
  Alcotest.(check (option int))
    "proof.work_delay" (Some 1)
    (Option.bind config.proof ~f:(fun proof -> proof.work_delay))

let test_neither_key () =
  parse_exn {json| { "genesis": { "k": 10 } } |json}
  |> check_slot_time ~expected:None

let test_both_keys () =
  check_error
    {json| { "genesis": { "block_window_duration_ms": 20000 }
           , "proof": { "block_window_duration_ms": 30000 } } |json}

let test_both_keys_equal () =
  check_error
    {json| { "genesis": { "block_window_duration_ms": 20000 }
           , "proof": { "block_window_duration_ms": 20000 } } |json}

let legacy_layer =
  {json| { "proof": { "block_window_duration_ms": 20000 } } |json}

let new_layer =
  {json| { "genesis": { "block_window_duration_ms": 30000 } } |json}

let test_layering_legacy_then_new () =
  Runtime_config.combine (parse_exn legacy_layer) (parse_exn new_layer)
  |> check_slot_time ~expected:(Some 30000)

let test_layering_new_then_legacy () =
  Runtime_config.combine (parse_exn new_layer) (parse_exn legacy_layer)
  |> check_slot_time ~expected:(Some 20000)

let rec mentions_key key : Yojson.Safe.t -> bool = function
  | `Assoc fields ->
      List.exists fields ~f:(fun (field, value) ->
          String.equal field key || mentions_key key value )
  | `List values ->
      List.exists values ~f:(mentions_key key)
  | _ ->
      false

let proof_section json =
  match json with
  | `Assoc fields ->
      List.Assoc.find fields ~equal:String.equal "proof"
  | _ ->
      None

let test_written_with_new_key () =
  let json =
    parse_exn
      {json| { "proof": { "work_delay": 1, "block_window_duration_ms": 20000 } } |json}
    |> Runtime_config.to_yojson
  in
  Alcotest.(check bool)
    "proof section has no slot time" false
    (Option.value_map (proof_section json) ~default:false
       ~f:(mentions_key "block_window_duration_ms") ) ;
  parse_exn (Yojson.Safe.to_string json)
  |> check_slot_time ~expected:(Some 20000)

let test_proof_keys_reject_legacy_key () =
  match
    Runtime_config.Proof_keys.of_yojson
      (Yojson.Safe.from_string
         {json| { "block_window_duration_ms": 20000 } |json} )
  with
  | Ok _ ->
      Alcotest.fail "expected the proof section to be rejected"
  | Error _ ->
      ()

let default_constraint_constants =
  Genesis_constants.For_unit_tests.Constraint_constants.t

let test_constraint_constants_from_legacy_key () =
  let constraint_constants =
    Genesis_ledger_helper.make_constraint_constants
      ~default:default_constraint_constants (parse_exn legacy_layer)
  in
  Alcotest.(check int)
    "block_window_duration_ms" 20000
    constraint_constants.block_window_duration_ms

let test_transaction_capacity_from_legacy_key () =
  let legacy =
    parse_exn
      {json| { "proof":
                 { "block_window_duration_ms": 20000
                 , "transaction_capacity": { "txns_per_second_x10": 10 } } } |json}
  in
  let current =
    parse_exn
      {json| { "genesis": { "block_window_duration_ms": 20000 }
             , "proof": { "transaction_capacity": { "txns_per_second_x10": 10 } } } |json}
  in
  let make =
    Genesis_ledger_helper.make_constraint_constants
      ~default:default_constraint_constants
  in
  Alcotest.(check int)
    "transaction_capacity_log_2"
    (1 + Int.ceil_log2 (20 + 2))
    (make legacy).transaction_capacity_log_2 ;
  Alcotest.(check int)
    "same as the genesis key" (make current).transaction_capacity_log_2
    (make legacy).transaction_capacity_log_2

let () =
  Alcotest.run "block_window_duration_ms"
    [ ( "parsing"
      , [ Alcotest.test_case "new key" `Quick test_new_key
        ; Alcotest.test_case "legacy key" `Quick test_legacy_key
        ; Alcotest.test_case "legacy key keeps other fields" `Quick
            test_legacy_key_keeps_other_fields
        ; Alcotest.test_case "neither key" `Quick test_neither_key
        ; Alcotest.test_case "both keys" `Quick test_both_keys
        ; Alcotest.test_case "both keys, equal" `Quick test_both_keys_equal
        ; Alcotest.test_case "proof section rejects legacy key" `Quick
            test_proof_keys_reject_legacy_key
        ] )
    ; ( "layering"
      , [ Alcotest.test_case "legacy then new" `Quick
            test_layering_legacy_then_new
        ; Alcotest.test_case "new then legacy" `Quick
            test_layering_new_then_legacy
        ] )
    ; ( "writing"
      , [ Alcotest.test_case "written with the new key" `Quick
            test_written_with_new_key
        ] )
    ; ( "constraint constants"
      , [ Alcotest.test_case "slot time from legacy key" `Quick
            test_constraint_constants_from_legacy_key
        ; Alcotest.test_case "transaction capacity from legacy key" `Quick
            test_transaction_capacity_from_legacy_key
        ] )
    ]
