open Core_kernel

let regtest_digest_blockchain_snark () =
  let expected_digest = "36786c300e37c2a2f1341ad6374aa113" in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let proof_levels =
    [ Genesis_constants.Proof_level.Full
    ; Genesis_constants.Proof_level.Check
    ; Genesis_constants.Proof_level.No_check
    ]
  in
  List.iter proof_levels ~f:(fun proof_level ->
      let output =
        Blockchain_snark.Blockchain_snark_state.constraint_system_digests
          ~proof_level ~constraint_constants ()
      in
      assert (List.length output = 1) ;
      let _name, digest = List.hd_exn output in
      Alcotest.(check string)
        "Blockchain SNARK digest for regtest" expected_digest
        (Md5_lib.to_hex digest) )

(** Test to count the number of constraints in the blockchain SNARK.

    This test uses the new constraint_counts function to get the number
    of rows (constraints) in the blockchain SNARK step circuit.

    This is useful for:
    - Tracking constraint count changes over time
    - Comparing with a Rust reimplementation
    - Performance analysis
*)
let count_blockchain_snark_constraints () =
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let proof_level = Genesis_constants.Proof_level.Full in
  let counts =
    Blockchain_snark.Blockchain_snark_state.constraint_counts ~proof_level
      ~constraint_constants ()
  in
  List.iter counts ~f:(fun (name, num_constraints) ->
      Printf.printf "%s constraints: %d\n%!" name num_constraints ;
      Alcotest.(check bool)
        (Printf.sprintf "%s has constraints" name)
        true (num_constraints > 0) )

let () =
  let open Alcotest in
  run "Blockchain Snark Tests"
    [ ("Regtest", [ test_case "Digest" `Quick regtest_digest_blockchain_snark ])
    ; ( "Constraints"
      , [ test_case "Count" `Slow count_blockchain_snark_constraints ] )
    ]
