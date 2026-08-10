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

(* The envelope is the contract, so each shape is stated as a type and
   checked by its derived [of_yojson]: an extra, missing or wrongly
   typed field fails the parse and names itself.  [error] is typed as
   raw JSON because it is the structured [Error_json] encoding, whose
   inner shape is not part of the contract. *)
module Envelope = struct
  type probe = { healthy : bool; error : Yojson.Safe.t } [@@deriving of_yojson]

  type readiness = { ready : bool; error : Yojson.Safe.t }
  [@@deriving of_yojson]

  type wait =
    { ready : bool; timed_out : bool; db_only : bool; error : Yojson.Safe.t }
  [@@deriving of_yojson]
end

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

let check_contains ~label s ~sub =
  if not (String.is_substring s ~substring:sub) then
    Alcotest.failf "%s: expected to contain %S, got:\n%s" label sub s

(* Parse stdout as exactly one JSON object.  A second object tacked on
   is the double-print regression every subcommand must avoid. *)
let parse_single_json_record ~label out err =
  let trimmed = String.strip out in
  if String.is_empty trimmed then
    Alcotest.failf "%s: stdout empty, stderr:\n%s" label err ;
  List.iter [ "}\n{"; "} {" ] ~f:(fun separator ->
      if String.is_substring trimmed ~substring:separator then
        Alcotest.failf "%s: stdout contains multiple JSON objects:\n%s" label
          out ) ;
  try Yojson.Safe.from_string trimmed
  with exn ->
    Alcotest.failf "%s: stdout did not parse as JSON: %s\nstdout=%s" label
      (Exn.to_string exn) out

let of_yojson_exn ~label of_yojson json =
  match of_yojson json with
  | Ok envelope ->
      envelope
  | Error where ->
      Alcotest.failf "%s: unexpected envelope (at %s): %s" label where
        (Yojson.Safe.to_string json)

let check_error_reported ~label error =
  match error with
  | `Null ->
      Alcotest.failf "%s: error field is null" label
  | _ ->
      ()

(* Run [sub] against a dead PG in JSON mode and return its one record. *)
let run_dead_pg_json ~sub ?(extra_args = []) () =
  let label = sprintf "%s --json (dead PG)" sub in
  let code, out, err =
    run_cli ([ sub; "--postgres-uri"; dead_pg; "--json" ] @ extra_args)
  in
  if code = 0 then Alcotest.failf "%s: expected non-zero exit" label ;
  assert_no_ocaml_exn_leak (label ^ " stdout") out ;
  assert_no_ocaml_exn_leak (label ^ " stderr") err ;
  (label, parse_single_json_record ~label out err)

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

(* Every subcommand reaches text output through the same [emit], so one
   text-mode case is enough; the rest is covered in JSON mode below. *)
let test_db_ready_dead_pg_text () =
  let code, out, err = run_cli [ "db-ready"; "--postgres-uri"; dead_pg ] in
  if code = 0 then Alcotest.failf "db-ready (dead PG): expected non-zero exit" ;
  assert_no_ocaml_exn_leak "db-ready text stdout" out ;
  assert_no_ocaml_exn_leak "db-ready text stderr" err

(* A connection that never opened measured nothing, so the envelope
   carries the verdict and the error and no metric field. *)
let test_dead_pg_healthy_false ~sub () =
  let label, json = run_dead_pg_json ~sub () in
  let envelope = of_yojson_exn ~label Envelope.probe_of_yojson json in
  Alcotest.(check bool) (label ^ ": healthy") false envelope.healthy ;
  check_error_reported ~label envelope.error

let test_ready_dead_pg_json () =
  let label, json = run_dead_pg_json ~sub:"ready" () in
  let envelope = of_yojson_exn ~label Envelope.readiness_of_yojson json in
  Alcotest.(check bool) (label ^ ": ready") false envelope.ready ;
  check_error_reported ~label envelope.error

(* [wait] enters a polling loop; bound it tightly (--timeout/--interval
   1) so the test exits quickly.  Its envelope always carries
   [timed_out] and [db_only], so a consumer can tell a db-only wait from
   a full readiness wait, and a timeout from an outright connection
   failure. *)
let test_wait_dead_pg_json ~db_only () =
  let label, json =
    run_dead_pg_json ~sub:"wait"
      ~extra_args:
        ( (if db_only then [ "--db-only" ] else [])
        @ [ "--timeout"; "1"; "--interval"; "1" ] )
      ()
  in
  let envelope = of_yojson_exn ~label Envelope.wait_of_yojson json in
  Alcotest.(check bool) (label ^ ": ready") false envelope.ready ;
  Alcotest.(check bool) (label ^ ": db_only") db_only envelope.db_only ;
  check_error_reported ~label envelope.error

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
          , test_dead_pg_healthy_false ~sub:"db-ready" )
        ] )
    ; ( "json single-record contract against dead PG"
      , [ ( "block-height"
          , `Quick
          , test_dead_pg_healthy_false ~sub:"block-height" )
        ; ( "block-recency"
          , `Quick
          , test_dead_pg_healthy_false ~sub:"block-recency" )
        ; ( "missing-blocks"
          , `Quick
          , test_dead_pg_healthy_false ~sub:"missing-blocks" )
        ; ( "unparented-blocks"
          , `Quick
          , test_dead_pg_healthy_false ~sub:"unparented-blocks" )
        ; ("ready", `Quick, test_ready_dead_pg_json)
        ; ("wait", `Quick, test_wait_dead_pg_json ~db_only:false)
        ; ("wait --db-only", `Quick, test_wait_dead_pg_json ~db_only:true)
        ] )
    ]
