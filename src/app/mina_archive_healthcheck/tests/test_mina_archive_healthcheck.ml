(* Alcotest smoke tests for mina-archive-healthcheck.

   These always exercise the subcommands that don't require a running
   archive PostgreSQL: --help at the top level and per-subcommand, plus
   the single-JSON-record contract for each subcommand against a
   non-routable [postgres://...:1/...] URI.  When [MINA_TEST_POSTGRES]
   is set, they also create temporary DBs for success-path envelope and
   query-regression coverage.

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

  type db_ready_success = { healthy : bool } [@@deriving of_yojson]

  type block_height_success = { healthy : bool; block_height : int }
  [@@deriving of_yojson]

  type recency_success =
    { healthy : bool; delay_seconds : int64; max_delay : int }
  [@@deriving of_yojson]

  type missing_blocks_success =
    { healthy : bool; missing_blocks : int; max_missing : int; window : int }
  [@@deriving of_yojson]

  type missing_blocks_failure =
    { healthy : bool
    ; missing_blocks : int
    ; max_missing : int
    ; window : int
    ; error : Yojson.Safe.t
    }
  [@@deriving of_yojson]

  type unparented_blocks_success =
    { healthy : bool; unparented_blocks : int; max_unparented : int }
  [@@deriving of_yojson]

  type readiness_success =
    { ready : bool
    ; block_height : int
    ; delay_seconds : int64
    ; missing_blocks : int
    ; unparented_blocks : int
    }
  [@@deriving of_yojson]

  type readiness_no_delay_failure =
    { ready : bool
    ; block_height : int
    ; missing_blocks : int
    ; unparented_blocks : int
    ; problems : string list
    ; error : Yojson.Safe.t
    }
  [@@deriving of_yojson]
end

let read_all_fd fd =
  let ic = Core_unix.in_channel_of_descr fd in
  let s = In_channel.input_all ic in
  In_channel.close ic ; s

(* Spawn a process with [args], capture stdout/stderr, return
   [(exit_code, stdout, stderr)]. *)
let run_program ~prog args =
  let pi = Core_unix.create_process ~prog ~args in
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
        128 + Signal_unix.to_system_int s
  in
  (code, out, err)

let run_cli args = run_program ~prog:bin args

(* Regression guard: user-visible output must not leak raw OCaml
   exception syntax.  The original defect was [Caqti_error] /
   [Unix_error] propagating unwrapped through stderr on
   ECONNREFUSED. *)
let assert_no_ocaml_exn_leak label s =
  (* [Core_unix] as well as [Core.Unix]: core v0.16 split the unix parts of
     [Core] into a separate [Core_unix] library, so an unwrapped exception
     now renders with the new module path. *)
  let needles =
    [ "Unix_error"; "(Unix."; "Core.Unix"; "Core_unix"; "Caqti_error" ]
  in
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

let rec json_contains_string (json : Yojson.Safe.t) expected =
  match json with
  | `String s ->
      String.equal s expected
  | `List xs ->
      List.exists xs ~f:(fun json -> json_contains_string json expected)
  | `Tuple xs ->
      List.exists xs ~f:(fun json -> json_contains_string json expected)
  | `Assoc fields ->
      List.exists fields ~f:(fun (_key, json) ->
          json_contains_string json expected )
  | `Variant (tag, payload) ->
      String.equal tag expected
      || Option.exists payload ~f:(fun json ->
          json_contains_string json expected )
  | `Bool _ | `Float _ | `Int _ | `Intlit _ | `Null ->
      false

let check_error_constructor ~label error expected =
  check_error_reported ~label error ;
  if not (json_contains_string error expected) then
    Alcotest.failf "%s: expected error constructor %S in %s" label expected
      (Yojson.Safe.to_string error)

let check_absent_field ~label (json : Yojson.Safe.t) field =
  match json with
  | `Assoc fields ->
      if List.Assoc.mem fields field ~equal:String.equal then
        Alcotest.failf "%s: expected field %S to be absent in %s" label field
          (Yojson.Safe.to_string json)
  | _ ->
      Alcotest.failf "%s: expected JSON object, got %s" label
        (Yojson.Safe.to_string json)

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
  ; "server-ready"
  ; "block-height"
  ; "block-recency"
  ; "missing-blocks"
  ; "unparented-blocks"
  ; "ready"
  ; "wait"
  ]

let test_postgres_env = "MINA_TEST_POSTGRES"

let current_epoch_ms () =
  Time_float.now () |> Time_float.to_span_since_epoch |> Time_float.Span.to_ms
  |> Int64.of_float

let quote_ident s =
  "\"" ^ String.substr_replace_all s ~pattern:"\"" ~with_:"\"\"" ^ "\""

let admin_uri raw_uri =
  let uri = Uri.of_string raw_uri in
  match Uri.path uri with
  | "" | "/" ->
      Uri.with_path uri "/postgres" |> Uri.to_string
  | _ ->
      raw_uri

let database_uri raw_uri db_name =
  Uri.with_path (Uri.of_string raw_uri) ("/" ^ db_name) |> Uri.to_string

let random_db_name () =
  sprintf "mina_archive_healthcheck_%d_%06d"
    (Core_unix.getpid () |> Pid.to_int)
    (Random.int 1_000_000)

let run_psql_exn ~uri sql =
  let code, out, err =
    run_program ~prog:"psql"
      [ "-v"; "ON_ERROR_STOP=1"; "-qAt"; "-d"; uri; "-c"; sql ]
  in
  if code <> 0 then
    Alcotest.failf "psql failed with exit %d\nsql=%s\nstdout=%s\nstderr=%s" code
      sql out err ;
  out

let create_blocks_schema_sql =
  {sql|
    CREATE TABLE blocks (
      id serial PRIMARY KEY,
      height bigint NOT NULL,
      timestamp text NOT NULL,
      parent_id int
    );
  |sql}

let with_test_db f =
  match Sys.getenv test_postgres_env with
  | None ->
      printf "Skipping DB-backed healthcheck tests: $%s is not set\n%!"
        test_postgres_env
  | Some raw_uri ->
      let admin_uri = admin_uri raw_uri in
      let db_name = random_db_name () in
      let db_ident = quote_ident db_name in
      let test_uri = database_uri raw_uri db_name in
      let created = ref false in
      Exn.protect
        ~f:(fun () ->
          ignore
            (run_psql_exn ~uri:admin_uri
               (sprintf "CREATE DATABASE %s" db_ident) ) ;
          created := true ;
          f test_uri )
        ~finally:(fun () ->
          if !created then
            ignore
              (run_program ~prog:"psql"
                 [ "-v"
                 ; "ON_ERROR_STOP=1"
                 ; "-qAt"
                 ; "-d"
                 ; admin_uri
                 ; "-c"
                 ; sprintf "DROP DATABASE IF EXISTS %s" db_ident
                 ] ) )

let run_success_json ~postgres_uri ~sub ?(extra_args = []) () =
  let label = sprintf "%s --json (test DB)" sub in
  let code, out, err =
    run_cli ([ sub; "--postgres-uri"; postgres_uri; "--json" ] @ extra_args)
  in
  if code <> 0 then
    Alcotest.failf "%s: expected exit 0\nstdout=%s\nstderr=%s" label out err ;
  assert_no_ocaml_exn_leak (label ^ " stdout") out ;
  assert_no_ocaml_exn_leak (label ^ " stderr") err ;
  (label, parse_single_json_record ~label out err)

let run_failure_json ~postgres_uri ~sub ?(extra_args = []) () =
  let label = sprintf "%s --json (test DB)" sub in
  let code, out, err =
    run_cli ([ sub; "--postgres-uri"; postgres_uri; "--json" ] @ extra_args)
  in
  if code = 0 then
    Alcotest.failf "%s: expected non-zero exit\nstdout=%s\nstderr=%s" label out
      err ;
  assert_no_ocaml_exn_leak (label ^ " stdout") out ;
  assert_no_ocaml_exn_leak (label ^ " stderr") err ;
  (label, parse_single_json_record ~label out err)

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
  check_error_constructor ~label envelope.error "Db_unreachable"

(* [server-ready] probes the archive's TCP port, not PostgreSQL; port 1
   on localhost is never listening, so the connect fails fast and must
   surface as [Server_unreachable] without leaking exception syntax. *)
let test_server_ready_dead_port_json () =
  let label = "server-ready --json (dead port)" in
  let code, out, err =
    run_cli [ "server-ready"; "--server-port"; "1"; "--json" ]
  in
  if code = 0 then Alcotest.failf "%s: expected non-zero exit" label ;
  assert_no_ocaml_exn_leak (label ^ " stdout") out ;
  assert_no_ocaml_exn_leak (label ^ " stderr") err ;
  let json = parse_single_json_record ~label out err in
  let envelope = of_yojson_exn ~label Envelope.probe_of_yojson json in
  Alcotest.(check bool) (label ^ ": healthy") false envelope.healthy ;
  check_error_constructor ~label envelope.error "Server_unreachable"

(* [wait --server-port] must gate on the server socket even when the
   DB side would pass; a dead port is checked first, so the timeout's
   last failure is the server one. *)
let test_wait_dead_server_port_json () =
  let label, json =
    run_dead_pg_json ~sub:"wait"
      ~extra_args:
        [ "--db-only"
        ; "--server-port"
        ; "1"
        ; "--timeout"
        ; "1"
        ; "--interval"
        ; "1"
        ]
      ()
  in
  let envelope = of_yojson_exn ~label Envelope.wait_of_yojson json in
  Alcotest.(check bool) (label ^ ": ready") false envelope.ready ;
  check_error_constructor ~label envelope.error "Server_unreachable"

let test_ready_dead_pg_json () =
  let label, json = run_dead_pg_json ~sub:"ready" () in
  let envelope = of_yojson_exn ~label Envelope.readiness_of_yojson json in
  Alcotest.(check bool) (label ^ ": ready") false envelope.ready ;
  check_error_constructor ~label envelope.error "Db_unreachable"

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
  if envelope.timed_out then
    check_error_constructor ~label envelope.error "Timed_out" ;
  check_error_constructor ~label envelope.error "Db_unreachable"

let test_success_envelopes_against_db () =
  with_test_db (fun postgres_uri ->
      ignore (run_psql_exn ~uri:postgres_uri create_blocks_schema_sql) ;
      let timestamp = Int64.to_string (current_epoch_ms ()) in
      ignore
        (run_psql_exn ~uri:postgres_uri
           (sprintf
              {sql|
                INSERT INTO blocks (height, timestamp, parent_id) VALUES
                  (10, '%s', NULL),
                  (10, '%s', NULL),
                  (12, '%s', 1);
              |sql}
              timestamp timestamp timestamp ) ) ;
      let label, json = run_success_json ~postgres_uri ~sub:"db-ready" () in
      let envelope =
        of_yojson_exn ~label Envelope.db_ready_success_of_yojson json
      in
      Alcotest.(check bool) (label ^ ": healthy") true envelope.healthy ;
      let label, json = run_success_json ~postgres_uri ~sub:"block-height" () in
      let envelope =
        of_yojson_exn ~label Envelope.block_height_success_of_yojson json
      in
      Alcotest.(check bool) (label ^ ": healthy") true envelope.healthy ;
      Alcotest.(check int) (label ^ ": block_height") 12 envelope.block_height ;
      let label, json =
        run_success_json ~postgres_uri ~sub:"block-recency"
          ~extra_args:[ "--max-delay"; "3600" ] ()
      in
      let envelope =
        of_yojson_exn ~label Envelope.recency_success_of_yojson json
      in
      Alcotest.(check bool) (label ^ ": healthy") true envelope.healthy ;
      Alcotest.(check int) (label ^ ": max_delay") 3600 envelope.max_delay ;
      let label, json =
        run_success_json ~postgres_uri ~sub:"missing-blocks"
          ~extra_args:[ "--window"; "3"; "--max-missing"; "1" ]
          ()
      in
      let envelope =
        of_yojson_exn ~label Envelope.missing_blocks_success_of_yojson json
      in
      Alcotest.(check bool) (label ^ ": healthy") true envelope.healthy ;
      Alcotest.(check int)
        (label ^ ": missing_blocks")
        1 envelope.missing_blocks ;
      Alcotest.(check int) (label ^ ": max_missing") 1 envelope.max_missing ;
      Alcotest.(check int) (label ^ ": window") 3 envelope.window ;
      let label, json =
        run_success_json ~postgres_uri ~sub:"unparented-blocks" ()
      in
      let envelope =
        of_yojson_exn ~label Envelope.unparented_blocks_success_of_yojson json
      in
      Alcotest.(check bool) (label ^ ": healthy") true envelope.healthy ;
      Alcotest.(check int)
        (label ^ ": unparented_blocks")
        0 envelope.unparented_blocks ;
      let label, json =
        run_success_json ~postgres_uri ~sub:"ready"
          ~extra_args:
            [ "--window"
            ; "3"
            ; "--max-delay"
            ; "3600"
            ; "--max-missing"
            ; "1"
            ; "--max-unparented"
            ; "0"
            ]
          ()
      in
      let envelope =
        of_yojson_exn ~label Envelope.readiness_success_of_yojson json
      in
      Alcotest.(check bool) (label ^ ": ready") true envelope.ready ;
      Alcotest.(check int) (label ^ ": block_height") 12 envelope.block_height ;
      Alcotest.(check int)
        (label ^ ": missing_blocks")
        1 envelope.missing_blocks ;
      Alcotest.(check int)
        (label ^ ": unparented_blocks")
        0 envelope.unparented_blocks )

let test_missing_blocks_counts_distinct_heights () =
  with_test_db (fun postgres_uri ->
      ignore (run_psql_exn ~uri:postgres_uri create_blocks_schema_sql) ;
      let timestamp = Int64.to_string (current_epoch_ms ()) in
      ignore
        (run_psql_exn ~uri:postgres_uri
           (sprintf
              {sql|
                INSERT INTO blocks (height, timestamp, parent_id) VALUES
                  (10, '%s', NULL),
                  (10, '%s', NULL),
                  (12, '%s', 1);
              |sql}
              timestamp timestamp timestamp ) ) ;
      let label, json =
        run_failure_json ~postgres_uri ~sub:"missing-blocks"
          ~extra_args:[ "--window"; "3"; "--max-missing"; "0" ]
          ()
      in
      let envelope =
        of_yojson_exn ~label Envelope.missing_blocks_failure_of_yojson json
      in
      Alcotest.(check bool) (label ^ ": healthy") false envelope.healthy ;
      Alcotest.(check int)
        (label ^ ": missing_blocks")
        1 envelope.missing_blocks ;
      check_error_constructor ~label envelope.error "Thresholds_exceeded" )

let test_ready_empty_db_omits_delay () =
  with_test_db (fun postgres_uri ->
      ignore (run_psql_exn ~uri:postgres_uri create_blocks_schema_sql) ;
      let label, json =
        run_failure_json ~postgres_uri ~sub:"ready"
          ~extra_args:
            [ "--window"
            ; "3"
            ; "--max-delay"
            ; "3600"
            ; "--max-missing"
            ; "0"
            ; "--max-unparented"
            ; "0"
            ]
          ()
      in
      check_absent_field ~label json "delay_seconds" ;
      let envelope =
        of_yojson_exn ~label Envelope.readiness_no_delay_failure_of_yojson json
      in
      Alcotest.(check bool) (label ^ ": ready") false envelope.ready ;
      Alcotest.(check int) (label ^ ": block_height") 0 envelope.block_height ;
      Alcotest.(check int)
        (label ^ ": missing_blocks")
        0 envelope.missing_blocks ;
      Alcotest.(check int)
        (label ^ ": unparented_blocks")
        0 envelope.unparented_blocks ;
      if
        not
          (List.mem envelope.problems "no blocks in archive database"
             ~equal:String.equal )
      then
        Alcotest.failf "%s: expected no-blocks problem, got %s" label
          (String.concat envelope.problems ~sep:", ") ;
      check_error_constructor ~label envelope.error "Thresholds_exceeded" )

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
        ; ("server-ready", `Quick, test_server_ready_dead_port_json)
        ; ( "wait --server-port gates on the server socket"
          , `Quick
          , test_wait_dead_server_port_json )
        ] )
    ; ( "json envelope against test DB"
      , [ ("success paths", `Quick, test_success_envelopes_against_db)
        ; ( "missing-blocks counts distinct heights"
          , `Quick
          , test_missing_blocks_counts_distinct_heights )
        ; ( "ready omits unavailable delay"
          , `Quick
          , test_ready_empty_db_omits_delay )
        ] )
    ]
