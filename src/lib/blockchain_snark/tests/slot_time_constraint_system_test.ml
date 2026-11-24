open Core_kernel

let config_with_slot_time block_window_duration_ms =
  `Assoc
    [ ( "genesis"
      , `Assoc [ ("block_window_duration_ms", `Int block_window_duration_ms) ]
      )
    ]
  |> Runtime_config.of_yojson |> Result.ok_or_failwith

let blockchain_step_digests block_window_duration_ms =
  let config = config_with_slot_time block_window_duration_ms in
  let genesis_constants =
    Genesis_ledger_helper.make_genesis_constants ~logger:(Logger.null ())
      ~default:Genesis_constants.For_unit_tests.t config
    |> Or_error.ok_exn
  in
  let constraint_constants =
    Genesis_ledger_helper.make_constraint_constants
      ~default:Genesis_constants.For_unit_tests.Constraint_constants.t
      ~protocol_constants:genesis_constants.protocol config
  in
  Blockchain_snark.Blockchain_snark_state.constraint_system_digests
    ~proof_level:Full ~constraint_constants ()
  |> List.map ~f:(fun (name, digest) -> (name, Md5.to_hex digest))

let test_digests_independent_of_slot_time () =
  let expected = blockchain_step_digests 180_000 in
  List.iter [ 2_000; 20_000; 90_000 ] ~f:(fun block_window_duration_ms ->
      Alcotest.(check (list (pair string string)))
        (sprintf "digests at %d ms" block_window_duration_ms)
        expected
        (blockchain_step_digests block_window_duration_ms) )

let () =
  Alcotest.run "Blockchain snark slot time"
    [ ( "constraint system"
      , [ Alcotest.test_case "digests are independent of the slot time" `Quick
            test_digests_independent_of_slot_time
        ] )
    ]
