(* Hermetic alcotest smoke tests for rosetta-client.

   These exercise only the subcommands that don't need a running
   Rosetta server: --help for each subgroup and the clean error paths of
   the HTTP code.

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
  check_contains ~label:"--help root lists search" out ~sub:"search" ;
  assert_no_ocaml_exn_leak "--help root stderr" err

let test_help_network () =
  let code, out, err = run_cli [ "network"; "--help" ] in
  Alcotest.(check int) "network --help exit" 0 code ;
  check_contains ~label:"network --help lists list" out ~sub:"list" ;
  check_contains ~label:"network --help lists status" out ~sub:"status" ;
  check_contains ~label:"network --help lists options" out ~sub:"options" ;
  assert_no_ocaml_exn_leak "network --help stderr" err

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

(* ---------- Runner ---------- *)

let () =
  Alcotest.run "rosetta-client CLI smoke tests"
    [ ( "help"
      , [ ("root", `Quick, test_help_root)
        ; ("network", `Quick, test_help_network)
        ] )
    ; ( "error paths"
      , [ ( "connection refused is clean"
          , `Quick
          , test_connection_refused_clean_error )
        ; ("block get missing args", `Quick, test_block_get_missing_args)
        ] )
    ]
