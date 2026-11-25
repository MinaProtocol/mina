open Core_kernel

let parse s = Runtime_config.of_yojson (Yojson.Safe.from_string s)

let parse_exn s = parse s |> Result.ok_or_failwith

let fork_a : Runtime_config.Fork_config.t =
  { state_hash = "3NKSvjaGSKiQuAt8BP1b1VCpLbJc9RcEFjYCaBYsJJFdrtd6tpaV"
  ; blockchain_length = 100
  ; global_slot_since_genesis = 200
  }

let fork_b : Runtime_config.Fork_config.t =
  { state_hash = "3NLRTfY4kZyJtvaP4dFenDcxfoMfT3uEpkWS913KkeXLtziyVd15"
  ; blockchain_length = 500
  ; global_slot_since_genesis = 1000
  }

let fork_json (fork : Runtime_config.Fork_config.t) =
  Runtime_config.Fork_config.to_yojson fork |> Yojson.Safe.to_string

let fork_config =
  Alcotest.testable
    (fun fmt fork -> Format.pp_print_string fmt (fork_json fork))
    Runtime_config.Fork_config.equal

let check_fork ~expected config =
  Alcotest.(check (option fork_config))
    "genesis.fork" expected
    (Runtime_config.fork config)

let check_error s =
  match parse s with
  | Ok _ ->
      Alcotest.fail "expected the configuration to be rejected"
  | Error _ ->
      ()

let legacy_layer =
  sprintf {json| { "proof": { "fork": %s } } |json} (fork_json fork_a)

let new_layer =
  sprintf {json| { "genesis": { "fork": %s } } |json} (fork_json fork_b)

let test_new_key () = parse_exn new_layer |> check_fork ~expected:(Some fork_b)

let test_legacy_key () =
  parse_exn legacy_layer |> check_fork ~expected:(Some fork_a)

let test_legacy_key_keeps_other_fields () =
  let config =
    parse_exn
      (sprintf
         {json| { "genesis": { "k": 10 }
                , "proof": { "work_delay": 1, "fork": %s } } |json}
         (fork_json fork_a) )
  in
  check_fork ~expected:(Some fork_a) config ;
  Alcotest.(check (option int))
    "genesis.k" (Some 10)
    (Option.bind config.genesis ~f:(fun genesis -> genesis.k)) ;
  Alcotest.(check (option int))
    "proof.work_delay" (Some 1)
    (Option.bind config.proof ~f:(fun proof -> proof.work_delay))

let test_neither_key () =
  parse_exn {json| { "genesis": { "k": 10 } } |json}
  |> check_fork ~expected:None

let test_both_keys () =
  check_error
    (sprintf
       {json| { "genesis": { "fork": %s }, "proof": { "fork": %s } } |json}
       (fork_json fork_b) (fork_json fork_a) )

let test_both_keys_equal () =
  check_error
    (sprintf
       {json| { "genesis": { "fork": %s }, "proof": { "fork": %s } } |json}
       (fork_json fork_a) (fork_json fork_a) )

let test_proof_keys_reject_legacy_key () =
  match
    Runtime_config.Proof_keys.of_yojson
      (Yojson.Safe.from_string
         (sprintf {json| { "fork": %s } |json} (fork_json fork_a)) )
  with
  | Ok _ ->
      Alcotest.fail "expected the proof section to be rejected"
  | Error _ ->
      ()

let test_detects_legacy_key () =
  let sets_legacy s =
    Runtime_config.sets_legacy_fork (Yojson.Safe.from_string s)
  in
  Alcotest.(check bool) "legacy key" true (sets_legacy legacy_layer) ;
  Alcotest.(check bool) "new key" false (sets_legacy new_layer)

let test_layering_legacy_then_new () =
  Runtime_config.combine (parse_exn legacy_layer) (parse_exn new_layer)
  |> check_fork ~expected:(Some fork_b)

let test_layering_new_then_legacy () =
  Runtime_config.combine (parse_exn new_layer) (parse_exn legacy_layer)
  |> check_fork ~expected:(Some fork_a)

let proof_section json =
  match json with
  | `Assoc fields ->
      List.Assoc.find fields ~equal:String.equal "proof"
  | _ ->
      None

let test_written_with_new_key () =
  let json = parse_exn legacy_layer |> Runtime_config.to_yojson in
  Alcotest.(check bool)
    "proof section has no fork" false
    (Option.value_map (proof_section json) ~default:false ~f:(function
      | `Assoc fields ->
          List.Assoc.mem fields ~equal:String.equal "fork"
      | _ ->
          false ) ) ;
  parse_exn (Yojson.Safe.to_string json) |> check_fork ~expected:(Some fork_a)

let test_genesis_constants_from_legacy_key () =
  let genesis_constants =
    Genesis_ledger_helper.make_genesis_constants ~logger:(Logger.null ())
      ~default:Genesis_constants.For_unit_tests.t (parse_exn legacy_layer)
    |> Or_error.ok_exn
  in
  Alcotest.(check (option int))
    "blockchain_length" (Some fork_a.blockchain_length)
    (Option.map genesis_constants.fork ~f:(fun fork ->
         Mina_numbers.Length.to_int fork.blockchain_length ) )

let () =
  Alcotest.run "fork"
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
        ; Alcotest.test_case "detects legacy key" `Quick test_detects_legacy_key
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
    ; ( "constants"
      , [ Alcotest.test_case "genesis constants from legacy key" `Quick
            test_genesis_constants_from_legacy_key
        ] )
    ]
