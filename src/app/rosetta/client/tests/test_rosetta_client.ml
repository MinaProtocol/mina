(* Hermetic alcotest smoke tests for rosetta-client.

   These exercise only the subcommands that don't need a running
   Rosetta server: --help for each subgroup and the clean error paths of
   the HTTP and JSON-validation code.

   The regression guard we care most about is that user-visible error
   output never leaks raw OCaml exception syntax (e.g. Unix_error,
   Core.Unix.Unix_error, etc.).  See [assert_no_ocaml_exn_leak]. *)

open Core
open Rosetta_cli_test_helpers

let bin = exe_beside_test "rosetta_client_cli.exe"

let run_cli ?env args = run_cli ~bin ?env args

(* ---------- Tests ---------- *)

let test_help_root () =
  let code, out, err = run_cli [ "--help" ] in
  Alcotest.(check int) "--help exit" 0 code ;
  check_contains ~label:"--help root lists network" out ~sub:"network" ;
  check_contains ~label:"--help root lists construction" out ~sub:"construction" ;
  assert_no_ocaml_exn_leak "--help root stderr" err

let test_help_network () =
  let code, out, err = run_cli [ "network"; "--help" ] in
  Alcotest.(check int) "network --help exit" 0 code ;
  check_contains ~label:"network --help lists list" out ~sub:"list" ;
  check_contains ~label:"network --help lists status" out ~sub:"status" ;
  check_contains ~label:"network --help lists options" out ~sub:"options" ;
  assert_no_ocaml_exn_leak "network --help stderr" err

let test_help_construction () =
  let code, out, err = run_cli [ "construction"; "--help" ] in
  Alcotest.(check int) "construction --help exit" 0 code ;
  check_contains ~label:"construction --help lists derive" out ~sub:"derive" ;
  check_contains ~label:"construction --help lists submit" out ~sub:"submit" ;
  assert_no_ocaml_exn_leak "construction --help stderr" err

let test_connection_refused_clean_error () =
  (* Port 1 is privileged and reliably refuses on loopback. *)
  let code, out, err =
    run_cli [ "network"; "status"; "--rosetta-uri"; "http://127.0.0.1:1" ]
  in
  Alcotest.(check int) "network status (dead port) exit" 1 code ;
  assert_no_ocaml_exn_leak "network status stdout" out ;
  assert_no_ocaml_exn_leak "network status stderr" err ;
  let combined = out ^ "\n" ^ err in
  let has_signal =
    contains ~case_insensitive:true combined ~sub:"refused"
    || contains ~case_insensitive:true combined ~sub:"unreachable"
    || contains combined ~sub:"127.0.0.1:1"
  in
  if not has_signal then
    Alcotest.failf
      "network status (dead port): stderr should signal refusal / URI, got:\n\
       stdout=%s\n\
       stderr=%s"
      out err

let test_block_get_missing_args () =
  let code, out, err =
    run_cli [ "block"; "get"; "--rosetta-uri"; "http://127.0.0.1:1" ]
  in
  if code = 0 then
    Alcotest.failf "block get (no --index/--hash): expected non-zero exit" ;
  assert_no_ocaml_exn_leak "block get stdout" out ;
  assert_no_ocaml_exn_leak "block get stderr" err ;
  let combined = out ^ "\n" ^ err in
  if String.is_empty (String.strip combined) then
    Alcotest.failf "block get (no --index/--hash): expected a diagnostic"

let test_construction_derive_invalid_json () =
  let code, out, err =
    run_cli
      [ "construction"
      ; "derive"
      ; "--public-key-json"
      ; "{not valid"
      ; "--rosetta-uri"
      ; "http://127.0.0.1:1"
      ]
  in
  if code = 0 then
    Alcotest.failf "construction derive (bad JSON): expected non-zero exit" ;
  assert_no_ocaml_exn_leak "construction derive stdout" out ;
  assert_no_ocaml_exn_leak "construction derive stderr" err ;
  let combined = out ^ "\n" ^ err in
  if
    not
      ( contains ~case_insensitive:true combined ~sub:"json"
      || contains combined ~sub:"public-key-json" )
  then
    Alcotest.failf
      "construction derive (bad JSON): stderr should mention JSON, got:\n\
       stdout=%s\n\
       stderr=%s"
      out err

(* Valid JSON that is not a Rosetta PublicKey: the CLI decodes flag
   payloads into the endpoint's model, so this must be rejected locally
   with the flag name rather than sent to the server. *)
let test_construction_derive_schema_mismatch () =
  let code, out, err =
    run_cli
      [ "construction"
      ; "derive"
      ; "--public-key-json"
      ; {|{"hex_bytes":"aabb"}|}
      ; "--rosetta-uri"
      ; "http://127.0.0.1:1"
      ]
  in
  if code = 0 then
    Alcotest.failf "construction derive (bad schema): expected non-zero exit" ;
  assert_no_ocaml_exn_leak "construction derive stdout" out ;
  assert_no_ocaml_exn_leak "construction derive stderr" err ;
  let combined = out ^ "\n" ^ err in
  if
    not
      ( contains ~case_insensitive:true combined ~sub:"schema"
      || contains combined ~sub:"public-key-json" )
  then
    Alcotest.failf
      "construction derive (bad schema): stderr should name the flag or the \n\
       schema, got:\n\
       stdout=%s\n\
       stderr=%s"
      out err

(* ---------- Runner ---------- *)

let () =
  Alcotest.run "rosetta-client CLI smoke tests"
    [ ( "help"
      , [ ("root", `Quick, test_help_root)
        ; ("network", `Quick, test_help_network)
        ; ("construction", `Quick, test_help_construction)
        ] )
    ; ( "error paths"
      , [ ( "connection refused is clean"
          , `Quick
          , test_connection_refused_clean_error )
        ; ("block get missing args", `Quick, test_block_get_missing_args)
        ; ( "construction derive invalid JSON"
          , `Quick
          , test_construction_derive_invalid_json )
        ; ( "construction derive schema mismatch"
          , `Quick
          , test_construction_derive_schema_mismatch )
        ] )
    ]
