(* Testing
   -------

   Component: Merkle ledger tests
   Subject: Run all Merkle ledger tests
   Invocation: dune exec src/lib/merkle_ledger_tests/main.exe
*)

let () =
  let tests = Test_database.tests @ Test.tests @ Test_mask.tests in
  Alcotest.run "Merkle ledger" tests
