(* Archive hardfork toolbox tests: a group of tests per command. Needs
   POSTGRES_URI. *)

let () =
  let server_uri = Uri.of_string (Test_env.postgres_uri ()) in
  Alcotest.run "Archive Hardfork Toolbox Tests"
    ( Convert_canonical_tests.tests
    @ Populate_genesis_accounts_tests.tests ~server_uri )
