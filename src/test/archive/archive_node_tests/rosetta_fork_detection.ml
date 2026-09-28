(* Rosetta --watch-schema-era: when does the pre-fork Rosetta stand down?

   a. a 4.0.0 database with neither table: serve
   b. upgrade.sql run early, no fork recorded: serve
   c. fork recorded, schema still 4.0.0: serve
   d. fork recorded, schema moved to 5.0.0: exit 0

   The tables are written by hand, as the archive and upgrade.sql would write
   them: the case is about what Rosetta reads, not who wrote it.

   Run:
     MINA_TEST_POSTGRES_URI=postgres://postgres:xxxx@localhost:5432 \
     MINA_TEST_NETWORK_DATA=./src/test/archive/sample_db \
     ./_build/default/src/test/archive/archive_node_tests/archive_node_tests.exe \
     test rosetta_fork_detection
*)

open Async
open Core
open Mina_automation
open Mina_automation_fixture.Archive

type t = Mina_automation_fixture.Archive.before_bootstrap

(* Longer than two passes of the watcher's 10s interval. *)
let settle = Time.Span.of_sec 25.

let test_case (test_data : t) =
  let archive_uri = test_data.config.postgres_uri in
  let connection = Psql.Conn_str archive_uri in
  let sql query = Psql.run_command ~connection query >>| Or_error.ok_exn in
  let log_file = test_data.temp_dir ^/ "rosetta.log" in

  (* A 4.0.0 database predates both tables. *)
  let%bind _ =
    sql
      "DROP TABLE IF EXISTS hardfork_state; DROP TYPE IF EXISTS \
       hardfork_source; DROP TABLE IF EXISTS migration_history"
  in
  let%bind port = Utils.free_port () in
  let%bind rosetta =
    Rosetta.start
      (Rosetta.of_config
         (Rosetta.Config.create ~archive_uri ~port
            ~extra_args:[ "--watch-schema-era" ] () ) )
  in
  let exited = Process.wait rosetta.process in
  Rosetta.Process.start_logging rosetta ~log_file ;
  let still_serving step =
    let%map () = after settle in
    if Deferred.is_determined exited then
      failwithf "%s: rosetta stopped, see %s" step log_file ()
  in
  Monitor.protect
    ~finally:(fun () ->
      if Deferred.is_determined exited then Deferred.unit
      else (
        ignore
          ( Signal.send Signal.kill (`Pid (Process.pid rosetta.process))
            : [ `Ok | `No_such_process ] ) ;
        exited >>| ignore ) )
    (fun () ->
      let%bind () =
        match%map
          Deferred.any
            [ Rosetta.wait_until_ready rosetta
            ; (exited >>| fun _ -> Or_error.error_string "rosetta exited")
            ]
        with
        | Ok () ->
            ()
        | Error e ->
            failwithf "rosetta did not start (%s), see %s"
              (Error.to_string_hum e) log_file ()
      in

      (* a *)
      let%bind () = still_serving "no tables" in

      (* b *)
      let%bind _ =
        sql
          "CREATE TABLE migration_history (commit_start_at timestamptz NOT \
           NULL DEFAULT now() PRIMARY KEY, protocol_version text NOT NULL, \
           migration_version text NOT NULL, description text NOT NULL, status \
           text NOT NULL); INSERT INTO migration_history (protocol_version, \
           migration_version, description, status) VALUES ('5.0.0', '0.0.2', \
           'test', 'applied')"
      in
      let%bind () = still_serving "schema 5.0.0, no fork recorded" in

      (* c *)
      let%bind _ =
        sql
          "DELETE FROM migration_history; INSERT INTO migration_history \
           (protocol_version, migration_version, description, status) VALUES \
           ('4.0.0', '0.0.6', 'test', 'applied'); CREATE TYPE hardfork_source \
           AS ENUM ('daemon_config', 'fork_genesis', 'operator'); CREATE TABLE \
           hardfork_state (id int PRIMARY KEY DEFAULT 1 CHECK (id = 1), \
           fork_state_hash text NOT NULL, fork_blockchain_length bigint NOT \
           NULL, fork_global_slot bigint NOT NULL, config_json text NOT NULL, \
           source hardfork_source NOT NULL, announced_at timestamptz NOT NULL \
           DEFAULT now(), finalized_at timestamptz); INSERT INTO \
           hardfork_state (fork_state_hash, fork_blockchain_length, \
           fork_global_slot, config_json, source) VALUES ('FORK', 10, 10, \
           '{}', 'daemon_config')"
      in
      let%bind () = still_serving "fork recorded, schema 4.0.0" in

      (* d *)
      let%bind _ =
        sql
          "INSERT INTO migration_history (protocol_version, migration_version, \
           description, status) VALUES ('5.0.0', '0.0.2', 'test', 'applied')"
      in
      let%bind () =
        match%map Clock.with_timeout settle exited with
        | `Result (Ok ()) ->
            ()
        | `Result (Error e) ->
            failwithf "rosetta did not exit cleanly: %s"
              (Unix.Exit_or_signal.to_string_hum (Error e))
              ()
        | `Timeout ->
            failwith "rosetta kept serving after the hand-over became due"
      in
      let%map log = Reader.file_contents log_file in
      if not (String.is_substring log ~substring:"Standing down") then
        failwith "rosetta exited without the stand-down line" ;
      Mina_automation_fixture.Intf.Passed )

(* What the watcher reads, against the tables upgrade.sql really creates:
   migration_history.status is an enum there, not text. No Rosetta process, so
   each state costs one query rather than a watcher interval. *)
module Verdicts = struct
  type t = Mina_automation_fixture.Archive.before_bootstrap

  let test_case (test_data : t) =
    let archive_uri = test_data.config.postgres_uri in
    let connection = Psql.Conn_str archive_uri in
    let sql query = Psql.run_command ~connection query >>| Or_error.ok_exn in
    let pool =
      Mina_caqti.connect_pool ~max_size:1 (Uri.of_string archive_uri)
      |> Result.map_error ~f:Caqti_error.show
      |> Result.ok_or_failwith
    in
    let verdict () =
      Mina_caqti.Pool.use Archive_lib.Schema_era.check pool
      >>| Result.map_error ~f:Caqti_error.show
      >>| Result.ok_or_failwith
    in
    let expect step expected =
      let%map v = verdict () in
      let got = Archive_lib.Schema_era.describe v in
      if not (String.equal got (Archive_lib.Schema_era.describe expected)) then
        failwithf "%s: got '%s'" step got ()
    in
    let mine = Archive_lib.Schema_era.my_protocol_version in
    let upgrade_script =
      Archive.Scripts.filepath `Upgrade
      |> Option.value_exn ~message:"Failed to find upgrade script"
    in
    let%bind _ =
      sql
        "DROP TABLE IF EXISTS hardfork_state; DROP TYPE IF EXISTS \
         hardfork_source; DROP TABLE IF EXISTS migration_history"
    in
    let%bind () = expect "no tables" Archive_lib.Schema_era.Serve in
    let%bind _ = Psql.run_script ~connection upgrade_script in
    let%bind () =
      expect "upgraded early, no fork recorded" Archive_lib.Schema_era.Serve
    in
    let%bind _ =
      sql
        "DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = \
         'hardfork_source') THEN CREATE TYPE hardfork_source AS ENUM \
         ('daemon_config', 'fork_genesis', 'operator'); END IF; END $$; CREATE \
         TABLE IF NOT EXISTS hardfork_state (id int PRIMARY KEY DEFAULT 1 \
         CHECK (id = 1), fork_state_hash text NOT NULL, fork_blockchain_length \
         bigint NOT NULL, fork_global_slot bigint NOT NULL, config_json text \
         NOT NULL, source hardfork_source NOT NULL, announced_at timestamptz \
         NOT NULL DEFAULT now(), finalized_at timestamptz); INSERT INTO \
         hardfork_state (fork_state_hash, fork_blockchain_length, \
         fork_global_slot, config_json, source) VALUES ('FORK', 10, 10, '{}', \
         'daemon_config')"
    in
    let%bind () =
      expect "fork recorded, upgraded schema"
        (Archive_lib.Schema_era.Differs { schema = "5.0.0"; mine })
    in
    let set_status status =
      sql
        (sprintf
           "UPDATE migration_history SET status = '%s' WHERE commit_start_at = \
            (SELECT max(commit_start_at) FROM migration_history)"
           status )
    in
    let%bind _ = set_status "starting" in
    let%bind () =
      expect "fork recorded, migration starting"
        (Archive_lib.Schema_era.Migration_in_progress "starting")
    in
    let%bind _ = set_status "failed" in
    let%bind () =
      expect "fork recorded, migration failed"
        (Archive_lib.Schema_era.Migration_in_progress "failed")
    in
    let%map () = Caqti_async.Pool.drain pool.Mina_caqti.Pool.pool in
    Mina_automation_fixture.Intf.Passed
end
