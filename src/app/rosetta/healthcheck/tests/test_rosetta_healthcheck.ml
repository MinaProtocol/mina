(* Hermetic alcotest smoke tests for rosetta-healthcheck.

   These exercise only the subcommands that don't require a running
   Rosetta server: --help at the top level and the single-JSON-record
   contract for [ready --json] / [tip-recency --json] /
   [connectivity --json] against a dead port. *)

open Core

let bin =
  let here = Filename.dirname (Array.get (Sys.get_argv ()) 0) in
  Filename.concat here "../rosetta_healthcheck.exe"

let read_all_fd fd =
  let ic = Core_unix.in_channel_of_descr fd in
  let s = In_channel.input_all ic in
  In_channel.close ic ; s

(* Spawn the CLI with [args] + optional env overrides, capture
   stdout/stderr, return [(exit_code, stdout, stderr)]. *)
let run_cli ?(env = []) args =
  let pi = Core_unix.create_process_env ~prog:bin ~args ~env:(`Extend env) () in
  Core_unix.close pi.stdin ;
  let out = read_all_fd pi.stdout in
  let err = read_all_fd pi.stderr in
  let status = Core_unix.waitpid pi.pid in
  let code =
    match status with
    | Ok () ->
        0
    | Error (`Exit_non_zero n) ->
        n
    | Error (`Signal s) ->
        128 + Signal.to_system_int s
  in
  (code, out, err)

(* Regression guard: user-visible output must not leak raw OCaml
   exception syntax.  The original defect was [Unix_error]
   propagating unwrapped through stderr on ECONNREFUSED. *)
let assert_no_ocaml_exn_leak label s =
  let needles = [ "Unix_error"; "(Unix."; "Core.Unix" ] in
  List.iter needles ~f:(fun needle ->
      if String.is_substring s ~substring:needle then
        Alcotest.failf "%s: output leaked OCaml exception syntax (%s):\n%s"
          label needle s )

let contains s ~sub = String.is_substring s ~substring:sub

let check_contains ~label s ~sub =
  if not (contains s ~sub) then
    Alcotest.failf "%s: expected to contain %S, got:\n%s" label sub s

(* ---------- Tests ---------- *)

let test_help_root () =
  let code, out, err = run_cli [ "--help" ] in
  Alcotest.(check int) "--help exit" 0 code ;
  List.iter [ "ready"; "wait"; "tip-recency"; "connectivity" ] ~f:(fun sub ->
      check_contains ~label:(sprintf "--help lists %s" sub) out ~sub ) ;
  assert_no_ocaml_exn_leak "--help stderr" err

let test_ready_dead_port_text () =
  let code, out, err =
    run_cli [ "ready"; "--online-uri"; "http://127.0.0.1:1" ]
  in
  if code = 0 then Alcotest.failf "ready (dead port): expected non-zero exit" ;
  let combined = out ^ "\n" ^ err in
  check_contains ~label:"ready text mentions NOT READY" combined
    ~sub:"NOT READY" ;
  assert_no_ocaml_exn_leak "ready stdout" out ;
  assert_no_ocaml_exn_leak "ready stderr" err

(* Shared helper for "exactly one JSON object on stdout" assertions.
   Parses [out] as a single Yojson object, returns the field list.
   Guards against a second JSON object being tacked on, which is the
   double-print regression the ready/wait/tip-recency/connectivity
   paths all need to avoid. *)
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
  if String.is_substring trimmed ~substring:"}\n{" then
    Alcotest.failf
      "%s: stdout contains multiple JSON objects separated by newlines:\n%s"
      label out ;
  if String.is_substring trimmed ~substring:"} {" then
    Alcotest.failf
      "%s: stdout contains multiple JSON objects separated by whitespace:\n%s"
      label out ;
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

(* The key "single JSON record per invocation" contract test: when
   [ready --json] fails, stdout must contain exactly one well-formed
   JSON object with [ready: false] and no OCaml exception leakage. *)
let test_ready_dead_port_json_single_record () =
  let code, out, err =
    run_cli [ "ready"; "--online-uri"; "http://127.0.0.1:1"; "--json" ]
  in
  Alcotest.(check int) "ready --json (dead port) exit" 1 code ;
  assert_no_ocaml_exn_leak "ready --json stdout" out ;
  assert_no_ocaml_exn_leak "ready --json stderr" err ;
  let fields =
    parse_single_json_record ~label:"ready --json (dead port)" out err
  in
  check_bool_field ~label:"ready --json" fields ~field:"ready" ~expected:false

let test_tip_recency_dead_port_json () =
  let code, out, err =
    run_cli [ "tip-recency"; "--online-uri"; "http://127.0.0.1:1"; "--json" ]
  in
  Alcotest.(check int) "tip-recency --json (dead port) exit" 1 code ;
  assert_no_ocaml_exn_leak "tip-recency --json stdout" out ;
  assert_no_ocaml_exn_leak "tip-recency --json stderr" err ;
  let fields =
    parse_single_json_record ~label:"tip-recency --json (dead port)" out err
  in
  check_bool_field ~label:"tip-recency --json" fields ~field:"healthy"
    ~expected:false

let test_connectivity_dead_port_json () =
  let code, out, err =
    run_cli [ "connectivity"; "--online-uri"; "http://127.0.0.1:1"; "--json" ]
  in
  Alcotest.(check int) "connectivity --json (dead port) exit" 1 code ;
  assert_no_ocaml_exn_leak "connectivity --json stdout" out ;
  assert_no_ocaml_exn_leak "connectivity --json stderr" err ;
  let fields =
    parse_single_json_record ~label:"connectivity --json (dead port)" out err
  in
  check_bool_field ~label:"connectivity --json" fields ~field:"healthy"
    ~expected:false

(* ---------- Runner ---------- *)

let () =
  Alcotest.run "rosetta-healthcheck CLI smoke tests"
    [ ("help", [ ("root", `Quick, test_help_root) ])
    ; ( "ready against dead port"
      , [ ("text format", `Quick, test_ready_dead_port_text)
        ; ( "json is single well-formed record"
          , `Quick
          , test_ready_dead_port_json_single_record )
        ] )
    ; ( "dead port"
      , [ ("tip-recency --json", `Quick, test_tip_recency_dead_port_json)
        ; ("connectivity --json", `Quick, test_connectivity_dead_port_json)
        ] )
    ]
