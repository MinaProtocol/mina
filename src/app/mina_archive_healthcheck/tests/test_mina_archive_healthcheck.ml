(* Hermetic alcotest smoke tests for mina-archive-healthcheck.

   These exercise only the subcommands that don't require a running
   archive PostgreSQL: --help at the top level and per-subcommand, plus
   the single-JSON-record contract for each subcommand against a
   non-routable [postgres://...:1/...] URI.

   The dead-PG URI deliberately points at a port that no local service
   listens on (127.0.0.1:1), so the connect attempt fails fast with
   ECONNREFUSED, the [with_pool] error path runs, and we get one
   well-formed JSON record on stdout in [--json] mode.  This is the
   same contract regression the original defect — [Caqti_error]
   propagating unwrapped — could violate. *)

open Core

let bin =
  let here = Filename.dirname (Array.get (Sys.get_argv ()) 0) in
  Filename.concat here "../mina_archive_healthcheck.exe"

(* Non-routable URI: caqti will try to TCP-connect to 127.0.0.1:1,
   get ECONNREFUSED, surface a Caqti_error which the CLI must format
   into a single JSON record (or single text line) without leaking. *)
let dead_pg = "postgres://test:test@127.0.0.1:1/test"

let read_all_fd fd =
  let ic = Core_unix.in_channel_of_descr fd in
  let s = In_channel.input_all ic in
  In_channel.close ic ; s

(* Spawn the CLI with [args], capture stdout/stderr, return
   [(exit_code, stdout, stderr)]. *)
let run_cli args =
  let pi = Core_unix.create_process ~prog:bin ~args in
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
   exception syntax.  The original defect was [Caqti_error] /
   [Unix_error] propagating unwrapped through stderr on
   ECONNREFUSED. *)
let assert_no_ocaml_exn_leak label s =
  let needles = [ "Unix_error"; "(Unix."; "Core.Unix"; "Caqti_error" ] in
  List.iter needles ~f:(fun needle ->
      if String.is_substring s ~substring:needle then
        Alcotest.failf "%s: output leaked OCaml exception syntax (%s):\n%s"
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

let check_bool_field ~label fields ~field ~expected =
  match List.Assoc.find fields ~equal:String.equal field with
  | Some (`Bool b) when Bool.equal b expected ->
      ()
  | Some v ->
      Alcotest.failf "%s: expected %s:%b, got %s" label field expected
        (Yojson.Safe.to_string v)
  | None ->
      Alcotest.failf "%s: missing %S field" label field

let check_string_field_present ~label fields ~field =
  match List.Assoc.find fields ~equal:String.equal field with
  | Some (`String _) ->
      ()
  | Some v ->
      Alcotest.failf "%s: expected %s to be a string, got %s" label field
        (Yojson.Safe.to_string v)
  | None ->
      Alcotest.failf "%s: missing %S field" label field

let all_subcommands =
  [ "db-ready"
  ; "block-height"
  ; "block-recency"
  ; "missing-blocks"
  ; "unparented-blocks"
  ; "ready"
  ; "wait"
  ]

(* ---------- Tests ---------- *)

let test_help_root () =
  let code, out, err = run_cli [ "--help" ] in
  Alcotest.(check int) "--help exit" 0 code ;
  List.iter all_subcommands ~f:(fun sub ->
      check_contains ~label:(sprintf "--help lists %s" sub) out ~sub ) ;
  assert_no_ocaml_exn_leak "--help stderr" err

(* Each subcommand must respond to its own --help with exit 0.  This
   catches typos / orphaned [Command.Param.flag] definitions that only
   blow up at CLI construction time. *)
let test_help_subs () =
  List.iter all_subcommands ~f:(fun sub ->
      let code, _out, err = run_cli [ sub; "--help" ] in
      Alcotest.(check int) (sprintf "%s --help exit" sub) 0 code ;
      assert_no_ocaml_exn_leak (sprintf "%s --help stderr" sub) err )

(* Single text-mode regression: db-ready against a dead PG must fail
   non-zero without leaking raw exception syntax.  The other
   subcommands all share the same [finish ~json ~json_error] error
   path, so JSON-mode coverage below is sufficient and we don't
   duplicate text-mode coverage here. *)
let test_db_ready_dead_pg_text () =
  let code, out, err = run_cli [ "db-ready"; "--postgres-uri"; dead_pg ] in
  if code = 0 then Alcotest.failf "db-ready (dead PG): expected non-zero exit" ;
  assert_no_ocaml_exn_leak "db-ready text stdout" out ;
  assert_no_ocaml_exn_leak "db-ready text stderr" err

(* Generic dead-PG JSON test: every subcommand whose top-level JSON
   error envelope keys the failure as ["healthy": false] uses this. *)
let test_dead_pg_healthy_false ~sub ?(extra_args = []) () =
  let args = [ sub; "--postgres-uri"; dead_pg; "--json" ] @ extra_args in
  let label = sprintf "%s --json (dead PG)" sub in
  let code, out, err = run_cli args in
  if code = 0 then Alcotest.failf "%s: expected non-zero exit" label ;
  assert_no_ocaml_exn_leak (label ^ " stdout") out ;
  assert_no_ocaml_exn_leak (label ^ " stderr") err ;
  let fields = parse_single_json_record ~label out err in
  check_bool_field ~label fields ~field:"healthy" ~expected:false ;
  check_string_field_present ~label fields ~field:"error"

let test_db_ready_dead_pg_json () =
  test_dead_pg_healthy_false ~sub:"db-ready" ()

let test_block_height_dead_pg_json () =
  test_dead_pg_healthy_false ~sub:"block-height" ()

let test_block_recency_dead_pg_json () =
  test_dead_pg_healthy_false ~sub:"block-recency" ()

let test_missing_blocks_dead_pg_json () =
  test_dead_pg_healthy_false ~sub:"missing-blocks" ()

let test_unparented_blocks_dead_pg_json () =
  test_dead_pg_healthy_false ~sub:"unparented-blocks" ()

(* The composite [ready] envelope keys the failure as ["ready": false]
   instead of [healthy], hence its own assertion. *)
let test_ready_dead_pg_json () =
  let label = "ready --json (dead PG)" in
  let code, out, err =
    run_cli [ "ready"; "--postgres-uri"; dead_pg; "--json" ]
  in
  if code = 0 then Alcotest.failf "%s: expected non-zero exit" label ;
  assert_no_ocaml_exn_leak (label ^ " stdout") out ;
  assert_no_ocaml_exn_leak (label ^ " stderr") err ;
  let fields = parse_single_json_record ~label out err in
  check_bool_field ~label fields ~field:"ready" ~expected:false ;
  check_string_field_present ~label fields ~field:"error"

(* [wait] enters a polling loop; bound it tightly (--timeout/--interval
   1) so the test exits quickly.  Against a dead PG the failure shape is
   the same envelope as [ready] plus a [timed_out] boolean.

   The plain and [--db-only] variants are identical apart from the flag
   and the extra [db_only: true] field assertion, so they share this
   body.  [--db-only] is the polling variant used by integration tests
   and init containers: it skips recency / missing / unparented and
   waits only for the [blocks] table to respond.  Its failure envelope
   must carry [db_only: true] so JSON consumers can distinguish a
   db-only timeout from a full readiness timeout. *)
let test_wait_dead_pg_json ~db_only () =
  let label =
    sprintf "wait%s --json (dead PG)" (if db_only then " --db-only" else "")
  in
  let args =
    [ "wait" ]
    @ (if db_only then [ "--db-only" ] else [])
    @ [ "--postgres-uri"
      ; dead_pg
      ; "--json"
      ; "--timeout"
      ; "1"
      ; "--interval"
      ; "1"
      ]
  in
  let code, out, err = run_cli args in
  if code = 0 then Alcotest.failf "%s: expected non-zero exit" label ;
  assert_no_ocaml_exn_leak (label ^ " stdout") out ;
  assert_no_ocaml_exn_leak (label ^ " stderr") err ;
  let fields = parse_single_json_record ~label out err in
  check_bool_field ~label fields ~field:"ready" ~expected:false ;
  if db_only then check_bool_field ~label fields ~field:"db_only" ~expected:true ;
  check_string_field_present ~label fields ~field:"error"

(* ---------- Runner ---------- *)

let () =
  Alcotest.run "mina-archive-healthcheck CLI smoke tests"
    [ ( "help"
      , [ ("root", `Quick, test_help_root)
        ; ("each subcommand", `Quick, test_help_subs)
        ] )
    ; ( "db-ready against dead PG"
      , [ ("text format", `Quick, test_db_ready_dead_pg_text)
        ; ( "json is single well-formed record"
          , `Quick
          , test_db_ready_dead_pg_json )
        ] )
    ; ( "json single-record contract against dead PG"
      , [ ("block-height", `Quick, test_block_height_dead_pg_json)
        ; ("block-recency", `Quick, test_block_recency_dead_pg_json)
        ; ("missing-blocks", `Quick, test_missing_blocks_dead_pg_json)
        ; ("unparented-blocks", `Quick, test_unparented_blocks_dead_pg_json)
        ; ("ready", `Quick, test_ready_dead_pg_json)
        ; ("wait", `Quick, test_wait_dead_pg_json ~db_only:false)
        ; ("wait --db-only", `Quick, test_wait_dead_pg_json ~db_only:true)
        ] )
    ]
