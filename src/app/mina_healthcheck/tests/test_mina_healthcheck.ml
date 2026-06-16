(* Hermetic alcotest smoke tests for mina-healthcheck.

   These exercise only the subcommands that don't require a running
   Mina daemon: --help at the top level and per-subcommand, plus the
   single-JSON-record contract for each subcommand against a
   non-routable [http://127.0.0.1:1/graphql] URI, and a wall-clock
   regression guard for [wait --timeout].

   The dead-URI tests rely on the one-shot CLI subcommands using
   [num_tries:1] (set in [mina_healthcheck.ml]); without it, each
   subcommand would retry 10 times with a 30s sleep and the suite
   would take ~5 minutes per dead-URI case.  See PR #18746 review
   thread for the original 300s-vs-30s incident. *)

open Core

let bin =
  let here = Filename.dirname (Array.get (Sys.get_argv ()) 0) in
  Filename.concat here "../mina_healthcheck.exe"

(* Non-routable URI: cohttp will TCP-connect to 127.0.0.1:1, get
   ECONNREFUSED, and the CLI must format that into a single JSON
   record (or single text line) without crashing or wedging. *)
let dead_uri = "http://127.0.0.1:1/graphql"

let read_all_fd fd =
  let ic = Core_unix.in_channel_of_descr fd in
  let s = In_channel.input_all ic in
  In_channel.close ic ; s

(* Spawn the CLI with [args], capture stdout/stderr, return
   [(exit_code, stdout, stderr, elapsed_seconds)].  Wall-clock time is
   captured because the [wait --timeout] regression guard turns on a
   ceiling check. *)
let run_cli args =
  let start = Time.now () in
  let pi = Core_unix.create_process ~prog:bin ~args in
  Core_unix.close pi.stdin ;
  let out = read_all_fd pi.stdout in
  let err = read_all_fd pi.stderr in
  let status = Core_unix.waitpid pi.pid in
  let elapsed = Time.Span.to_sec (Time.diff (Time.now ()) start) in
  let code =
    match status with
    | Ok () ->
        0
    | Error (`Exit_non_zero n) ->
        n
    | Error (`Signal s) ->
        128 + Signal.to_system_int s
  in
  (code, out, err, elapsed)

(* Regression guard: stderr must not contain raw OCaml runtime fatal
   markers ("Uncaught exception", "Fatal error", a backtrace).  The
   captured-and-formatted Unix_error sexprs that cohttp surfaces inside
   the JSON [error] field are not flagged here — they're an intentional
   part of the user-visible error message — but a panicked binary that
   blew up before reaching the JSON envelope path would be. *)
let assert_no_runtime_panic label s =
  let needles = [ "Uncaught exception"; "Fatal error:"; "Raised at " ] in
  List.iter needles ~f:(fun needle ->
      if String.is_substring s ~substring:needle then
        Alcotest.failf "%s: stderr leaked an OCaml runtime panic (%s):\n%s"
          label needle s )

let contains s ~sub = String.is_substring s ~substring:sub

let check_contains ~label s ~sub =
  if not (contains s ~sub) then
    Alcotest.failf "%s: expected to contain %S, got:\n%s" label sub s

(* Shared "exactly one JSON object on stdout" assertion.  Parses [out]
   as a single Yojson object, returns the field list.  Guards against
   a second JSON object being tacked on, which is the double-print
   regression every subcommand needs to avoid. *)
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

let check_string_field_present ~label fields ~field =
  match List.Assoc.find fields ~equal:String.equal field with
  | Some (`String _) ->
      ()
  | Some v ->
      Alcotest.failf "%s: expected %s to be a string, got %s" label field
        (Yojson.Safe.to_string v)
  | None ->
      Alcotest.failf "%s: missing %S field" label field

let check_bool_field ~label fields ~field ~expected =
  match List.Assoc.find fields ~equal:String.equal field with
  | Some (`Bool b) when Bool.equal b expected ->
      ()
  | Some v ->
      Alcotest.failf "%s: expected %s=%b, got %s" label field expected
        (Yojson.Safe.to_string v)
  | None ->
      Alcotest.failf "%s: missing %S field" label field

let all_subcommands =
  [ "sync-status"
  ; "daemon-status"
  ; "peer-count"
  ; "chain-length"
  ; "ready"
  ; "wait"
  ]

(* ---------- Tests ---------- *)

let test_help_root () =
  let code, out, err, _ = run_cli [ "--help" ] in
  Alcotest.(check int) "--help exit" 0 code ;
  List.iter all_subcommands ~f:(fun sub ->
      check_contains ~label:(sprintf "--help lists %s" sub) out ~sub ) ;
  assert_no_runtime_panic "--help stderr" err

(* Each subcommand must respond to its own --help with exit 0.  This
   catches typos / orphaned [Command.Param.flag] definitions that only
   blow up at CLI construction time. *)
let test_help_subs () =
  List.iter all_subcommands ~f:(fun sub ->
      let code, _out, err, _ = run_cli [ sub; "--help" ] in
      Alcotest.(check int) (sprintf "%s --help exit" sub) 0 code ;
      assert_no_runtime_panic (sprintf "%s --help stderr" sub) err )

(* Generic dead-URI JSON test for one-shot subcommands.  Each one
   should emit exactly one JSON record on stdout in [--json] mode,
   exit non-zero, contain a [healthy: false] field, an [error] field,
   nothing on stderr, and not trigger an OCaml runtime panic. *)
let test_dead_uri_json_envelope ?(extra_args = []) ~sub () =
  let args = [ sub; "--graphql-uri"; dead_uri; "--json" ] @ extra_args in
  let label = sprintf "%s --json (dead URI)" sub in
  let code, out, err, _ = run_cli args in
  if code = 0 then Alcotest.failf "%s: expected non-zero exit" label ;
  assert_no_runtime_panic (label ^ " stderr") err ;
  if not (String.is_empty (String.strip err)) then
    Alcotest.failf "%s: stderr expected empty when --json is set, got:\n%s"
      label err ;
  let fields = parse_single_json_record ~label out err in
  check_bool_field ~label fields ~field:"healthy" ~expected:false ;
  check_string_field_present ~label fields ~field:"error"

let test_sync_status_dead_uri () =
  test_dead_uri_json_envelope ~sub:"sync-status" ()

let test_daemon_status_dead_uri () =
  test_dead_uri_json_envelope ~sub:"daemon-status" ()

let test_peer_count_dead_uri () =
  test_dead_uri_json_envelope ~sub:"peer-count" ()

let test_chain_length_dead_uri () =
  test_dead_uri_json_envelope ~sub:"chain-length" ()

let test_ready_dead_uri () = test_dead_uri_json_envelope ~sub:"ready" ()

(* [wait]'s deadline plumbing is the regression guard for the
   original "wait --timeout 30 takes 300s" bug — without the deadline
   threading through [exec_graphql_request], this test would hang for
   minutes, not seconds.  We assert wall-clock time as well as exit
   code so a regression that drops the deadline parameter on the
   floor will surface here, not silently. *)
let test_wait_timeout_bound () =
  let label = "wait --timeout 3 (dead URI)" in
  let code, out, err, elapsed =
    run_cli
      [ "wait"
      ; "--graphql-uri"
      ; dead_uri
      ; "--json"
      ; "--timeout"
      ; "3"
      ; "--interval"
      ; "1"
      ]
  in
  if code = 0 then Alcotest.failf "%s: expected non-zero exit" label ;
  assert_no_runtime_panic (label ^ " stderr") err ;
  if Float.( > ) elapsed 10.0 then
    Alcotest.failf
      "%s: --timeout 3 took %.2fs (ceiling 10s).  Likely cause: deadline \
       parameter is no longer plumbed through exec_graphql_request's retry \
       loop.  Without it, each retry would wait ~30s for up to 10 attempts."
      label elapsed ;
  let fields = parse_single_json_record ~label out err in
  check_string_field_present ~label fields ~field:"error"

(* ---------- Runner ---------- *)

let () =
  Alcotest.run "mina-healthcheck CLI smoke tests"
    [ ( "help"
      , [ ("root", `Quick, test_help_root)
        ; ("each subcommand", `Quick, test_help_subs)
        ] )
    ; ( "json single-record contract against dead URI"
      , [ ("sync-status", `Quick, test_sync_status_dead_uri)
        ; ("daemon-status", `Quick, test_daemon_status_dead_uri)
        ; ("peer-count", `Quick, test_peer_count_dead_uri)
        ; ("chain-length", `Quick, test_chain_length_dead_uri)
        ; ("ready", `Quick, test_ready_dead_uri)
        ] )
    ; ( "wait timeout regression guard"
      , [ ( "--timeout 3 returns within 10s wall-clock"
          , `Quick
          , test_wait_timeout_bound )
        ] )
    ]
