(* Synthetic_archive writes exactly the rows a scenario describes, into the
   real archive schema. Needs the PostgreSQL server MINA_TEST_POSTGRES names
   (any database path is ignored). *)

open Core
open Async
module B = Synthetic_archive

let test_keys () =
  let s = B.create () in
  let a = B.account s "alice" in
  Alcotest.(check string)
    "same name, same account" (B.public_key a)
    (B.public_key (B.account s "alice")) ;
  Alcotest.(check string)
    "deterministic across scenarios" (B.public_key a)
    (B.public_key (B.account (B.create ()) "alice")) ;
  (* a real key, not just a unique string *)
  let (_ : Signature_lib.Public_key.Compressed.t) =
    Signature_lib.Public_key.Compressed.of_base58_check_exn (B.public_key a)
  in
  Alcotest.(check bool)
    "different names, different keys" false
    (String.equal (B.public_key a) (B.public_key (B.account s "bob")))

let db_tests server_uri =
  let run f () =
    Thread_safe.block_on_async_exn (f server_uri) |> Or_error.ok_exn
  in
  [ Alcotest.test_case "rows match the scenario" `Quick (run Scenario_rows.test)
  ; Alcotest.test_case "create over a leftover database" `Quick
      (run Db_lifecycle.test_recreate)
  ; Alcotest.test_case "refuses a non-test database name" `Quick
      (run Db_lifecycle.test_refuses_non_test_name)
  ; Alcotest.test_case "materialize writes once" `Quick
      (run Db_lifecycle.test_materialize_once)
  ; Alcotest.test_case "a raising callback still drops its database" `Quick
      (run Db_lifecycle.test_with_fresh_drops_on_raise)
  ; Alcotest.test_case "mixed-case names are exact" `Quick
      (run Db_lifecycle.test_mixed_case_name)
  ]

let () =
  Alcotest.run "synthetic_archive"
    [ ( "synthetic_archive"
      , Alcotest.test_case "account keys" `Quick test_keys
        :: Alcotest.test_case "psql gets the whole connection URI" `Quick
             Db_lifecycle.test_conn_str_args
        :: db_tests (B.Db.test_server_uri ()) )
    ]
