(* Hermetic alcotest smoke tests for rosetta-healthcheck.

   These exercise only the subcommands that don't require a running
   Rosetta server: --help at the top level and the single-JSON-record
   contract for [ready --json] / [tip-recency --json] /
   [connectivity --json] against a dead port. *)

open Core
open Rosetta_cli_test_helpers

let bin = exe_beside_test "rosetta_healthcheck.exe"

let run_cli ?env args = run_cli ~bin ?env args

(* ---------- Tests ---------- *)

let test_help_root () =
  let code, out, err = run_cli [ "--help" ] in
  Alcotest.(check int) "--help exit" 0 code ;
  List.iter [ "ready"; "wait"; "tip-recency"; "connectivity" ] ~f:(fun sub ->
      check_contains ~label:(sprintf "--help lists %s" sub) out ~sub ) ;
  assert_no_ocaml_exn_leak "--help stderr" err

let test_ready_dead_port_text () =
  let code, out, err =
    run_cli [ "ready"; "--rosetta-uri"; "http://127.0.0.1:1" ]
  in
  if code = 0 then Alcotest.failf "ready (dead port): expected non-zero exit" ;
  let combined = out ^ "\n" ^ err in
  check_contains ~label:"ready text mentions NOT READY" combined
    ~sub:"NOT READY" ;
  assert_no_ocaml_exn_leak "ready stdout" out ;
  assert_no_ocaml_exn_leak "ready stderr" err

(* "Exactly one JSON object on stdout", the double-print regression the
   ready/wait/tip-recency/connectivity paths all need to avoid:
   [Yojson.Safe.from_string] rejects a second object as junk after the
   end of the value, so parsing is the whole check. *)
let parse_single_json_record ~label out err =
  let trimmed = String.strip out in
  if String.is_empty trimmed then
    Alcotest.failf "%s: stdout empty, stderr:\n%s" label err ;
  let json =
    try Yojson.Safe.from_string trimmed
    with exn ->
      Alcotest.failf "%s: stdout did not parse as JSON: %s\nstdout=%s" label
        (Exn.to_string exn) out
  in
  match json with
  | `Assoc fields ->
      fields
  | _ ->
      Alcotest.failf "%s: stdout was not a JSON object: %s" label out

let check_bool_field ~label fields ~field ~expected =
  match List.Assoc.find fields ~equal:String.equal field with
  | Some (`Bool b) when Bool.equal b expected ->
      ()
  | Some v ->
      Alcotest.failf "%s: expected %s:%b, got %s" label field expected
        (Yojson.Safe.to_string v)
  | None ->
      Alcotest.failf "%s: missing %S field" label field

(* Each probe against a dead port: exactly one well-formed record on
   stdout, its flag false, exit 1, and no OCaml exception leakage. *)
let test_dead_port_json () =
  List.iter
    [ ("ready", "ready")
    ; ("tip-recency", "healthy")
    ; ("connectivity", "healthy")
    ]
    ~f:(fun (subcommand, field) ->
      let code, out, err =
        run_cli [ subcommand; "--rosetta-uri"; "http://127.0.0.1:1"; "--json" ]
      in
      let label = sprintf "%s --json (dead port)" subcommand in
      Alcotest.(check int) (label ^ " exit") 1 code ;
      assert_no_ocaml_exn_leak (label ^ " stdout") out ;
      assert_no_ocaml_exn_leak (label ^ " stderr") err ;
      let fields = parse_single_json_record ~label out err in
      check_bool_field ~label fields ~field ~expected:false )

(* A flag value below its floor is refused before any request goes out,
   with a message the operator can act on and no OCaml exception syntax
   -- [Command] would render an escaping exception as [(Failure "...")].
   [--interval 0] is the one that matters: it asks for a poll loop with
   no pause, which hammers the server the probe is checking. *)
let test_out_of_range_flag_refused () =
  List.iter
    [ ([ "wait"; "--interval"; "0" ], "--interval must be at least 1 second")
    ; ([ "wait"; "--deadline"; "0" ], "--deadline must be at least 1 second")
    ; ([ "ready"; "--max-age"; "-1" ], "--max-age must be at least 0 seconds")
    ; ([ "ready"; "--timeout"; "0" ], "--timeout must be a positive number")
    ]
    ~f:(fun (args, expected) ->
      let label = String.concat ~sep:" " args in
      let code, out, err = run_cli args in
      (* 2, not 1: a mistyped flag is not the probe reporting that the
         server is unhealthy. *)
      Alcotest.(check int) (sprintf "%s: exit" label) 2 code ;
      check_contains ~label:(sprintf "%s: message" label) err ~sub:expected ;
      if String.is_substring err ~substring:"(Failure" then
        Alcotest.failf "%s: message wrapped in OCaml exception syntax:\n%s"
          label err ;
      assert_no_ocaml_exn_leak (sprintf "%s stderr" label) err ;
      if not (String.is_empty (String.strip out)) then
        Alcotest.failf "%s: expected nothing on stdout, got:\n%s" label out )

(* [wait] is the one subcommand that writes to stderr while it runs --
   one progress line per attempt -- so it is also the one that could not
   be tested until the suite drained both pipes concurrently.  Against a
   dead port it should report every attempt on stderr and still print
   exactly one record on stdout. *)
let test_wait_reports_progress_and_one_record () =
  let code, out, err =
    run_cli
      [ "wait"
      ; "--rosetta-uri"
      ; "http://127.0.0.1:1"
      ; "--deadline"
      ; "3"
      ; "--interval"
      ; "1"
      ; "--json"
      ]
  in
  Alcotest.(check int) "wait (dead port) exit" 1 code ;
  assert_no_ocaml_exn_leak "wait stdout" out ;
  assert_no_ocaml_exn_leak "wait stderr" err ;
  check_contains ~label:"wait reports progress on stderr" err ~sub:"not ready" ;
  (* With --json the diagnostics are machine-readable too: every stderr
     line is one Logger record, so a caller collecting the probe's
     output does not have to parse prose out of the same stream. *)
  List.iter
    (List.filter (String.split_lines err) ~f:(fun line ->
         not (String.is_empty (String.strip line)) ) )
    ~f:(fun line ->
      match Yojson.Safe.from_string line with
      | `Assoc fields ->
          if not (List.Assoc.mem fields ~equal:String.equal "level") then
            Alcotest.failf "wait --json: stderr record has no level:\n%s" line
      | _ | (exception _) ->
          Alcotest.failf "wait --json: stderr line is not one JSON record:\n%s"
            line ) ;
  let fields = parse_single_json_record ~label:"wait (dead port)" out err in
  check_bool_field ~label:"wait --json" fields ~field:"ready" ~expected:false ;
  check_bool_field ~label:"wait --json" fields ~field:"timed_out" ~expected:true

(* ---------- Runner ---------- *)

let () =
  Alcotest.run "rosetta-healthcheck CLI smoke tests"
    [ ("help", [ ("root", `Quick, test_help_root) ])
    ; ( "dead port"
      , [ ("ready text format", `Quick, test_ready_dead_port_text)
        ; ("json is one record per probe", `Quick, test_dead_port_json)
        ] )
    ; ( "wait"
      , [ ( "reports progress and one record"
          , `Quick
          , test_wait_reports_progress_and_one_record )
        ] )
    ; ( "flag bounds"
      , [ ( "out-of-range values are refused"
          , `Quick
          , test_out_of_range_flag_refused )
        ] )
    ]
