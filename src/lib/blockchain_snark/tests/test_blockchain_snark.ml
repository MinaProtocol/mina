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

let () =
  let open Alcotest in
  run "Blockchain Snark Tests"
    [ ("Regtest", [ test_case "Digest" `Quick regtest_digest_blockchain_snark ])
    ]
