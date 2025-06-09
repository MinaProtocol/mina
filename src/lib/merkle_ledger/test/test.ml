(* Testing
   -------

   Component: Merkle ledger tests
   Subject: Run all Merkle ledger tests
   Invocation: dune exec src/lib/merkle_ledger/test/test.exe
*)

let () =
  let tests =
    Test_database_in_mem.tests @ Test_database_integration.tests
    @ Test_mask.tests @ Test_converting.tests
  in
  Alcotest.run "Merkle ledger" tests
