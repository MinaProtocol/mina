(** Thin wrapper around the [mina-archive-healthcheck] binary for
    integration tests.  Resolves the binary via the same auto-detect
    rules as the rest of [mina_automation] (look in [_build/default]
    first, fall back to PATH for deb-installed packages), then shells
    out and surfaces exit codes as [Or_error]: [Ok ()] on exit 0,
    [Error] otherwise.

    Only exposes the subcommands actually used by integration tests
    today; for the full surface see [src/app/mina_archive_healthcheck/]. *)

open Async
open Core

module Paths = struct
  let dune_name =
    "src/app/mina_archive_healthcheck/mina_archive_healthcheck.exe"

  let official_name = "mina-archive-healthcheck"
end

module PathFinder = Executor.Make_PathFinder (Paths)

let exit_status_to_string = function
  | Ok () ->
      "0"
  | Error (`Exit_non_zero n) ->
      Int.to_string n
  | Error (`Signal s) ->
      sprintf "signal %s" (Signal.to_string s)

let run args =
  let open Deferred.Let_syntax in
  let%bind prog = PathFinder.standalone_path_exn in
  let%bind proc = Process.create_exn ~prog ~args () in
  let%map output = Process.collect_output_and_wait proc in
  match output.exit_status with
  | Ok () ->
      Ok output.stdout
  | Error _ as status ->
      Or_error.errorf
        "mina-archive-healthcheck %s exited %s\nstdout=%s\nstderr=%s"
        (String.concat ~sep:" " args)
        (exit_status_to_string status)
        output.stdout output.stderr

(** [db_ready ~postgres_uri ()] runs [mina-archive-healthcheck db-ready]
    once.  Returns [Ok ()] if the [blocks] table responds to a
    [SELECT MAX(height)], otherwise [Error] (DB unreachable, schema
    not loaded, etc.). *)
let db_ready ~postgres_uri () =
  let%map result = run [ "db-ready"; "--postgres-uri"; postgres_uri ] in
  Result.ignore_m result

(** [wait_db_ready ~postgres_uri ()] blocks until [db-ready] passes or
    [timeout] seconds elapse.  This is the natural replacement for the
    log-tailing [Archive.wait_until_ready] — it talks to the DB
    directly, so it doesn't depend on the daemon emitting any
    particular log line, and it works against integration archives
    that haven't yet ingested any blocks (the full readiness check
    cannot, because it requires a non-None [latest_ts]). *)
let wait_db_ready ~postgres_uri ?(timeout = 30) ?(interval = 1) () =
  let%map result =
    run
      [ "wait"
      ; "--db-only"
      ; "--postgres-uri"
      ; postgres_uri
      ; "--timeout"
      ; Int.to_string timeout
      ; "--interval"
      ; Int.to_string interval
      ]
  in
  Result.ignore_m result
