(* Rosetta --watch-schema-era: when does the pre-fork Rosetta stand down?

   Each database state is reached the way production reaches it: the schema
   scripts an operator runs, and the archive's own record of a fork.

   a. an older schema, without hardfork_state: serve
   b. schema upgraded before the fork, no fork recorded: serve
   c. fork recorded on the upgraded schema: exit 0

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

let fork_config_json =
  Fork_runtime_config.naming
    ~state_hash:"3NKeMoncuHab5ScarV5ViyF16cJPT4taWNSaTLS64Dp67wuXigPZ"
    ~height:10 ~slot:12 ()

(* The protocol version upgrade.sql moves the schema to. *)
let upgraded_version = "5.0.0"

let test_case (test_data : t) =
  let postgres_uri = test_data.config.postgres_uri in
  let log_file = test_data.temp_dir ^/ "rosetta.log" in

  (* a: an older schema; upgrade.sql then downgrade.sql drops hardfork_state. *)
  let%bind () = Archive_schema.upgrade ~postgres_uri in
  let%bind () = Archive_schema.downgrade ~postgres_uri in
  let%bind port = Utils.free_port () in
  let%bind rosetta =
    Rosetta.start
      (Rosetta.of_config
         (Rosetta.Config.create ~archive_uri:postgres_uri ~port
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
      let%bind () = still_serving "older schema, no hardfork_state" in

      (* b *)
      let%bind () = Archive_schema.upgrade ~postgres_uri in
      let%bind () = still_serving "schema upgraded, no fork recorded" in

      (* c *)
      let%bind () =
        Archive_schema.record_fork ~postgres_uri ~config_json:fork_config_json
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

(* What the watcher reads, without a Rosetta process: each state costs one
   query rather than a watcher interval. *)
module Verdicts = struct
  type t = Mina_automation_fixture.Archive.before_bootstrap

  let test_case (test_data : t) =
    let postgres_uri = test_data.config.postgres_uri in
    let open Archive_lib.Schema_era.Verdict in
    let module Status = Archive_lib.Processor.Migration_history.Status in
    let pool =
      Mina_caqti.connect_pool ~max_size:1 (Uri.of_string postgres_uri)
      |> Result.map_error ~f:Caqti_error.show
      |> Result.ok_or_failwith
    in
    let expect step expected =
      let%map got =
        Mina_caqti.Pool.use Archive_lib.Schema_era.check pool
        >>| Result.map_error ~f:Caqti_error.show
        >>| Result.ok_or_failwith
      in
      if not (equal got expected) then
        failwithf "%s: got '%s'" step (describe got) ()
    in
    let set_status status =
      Archive_schema.set_latest_migration_status ~postgres_uri status
    in
    let%bind () = expect "schema from create_schema.sql, no fork" Serve in
    let%bind () =
      Archive_schema.record_fork ~postgres_uri ~config_json:fork_config_json
    in
    let%bind () = expect "fork recorded, schema never migrated" Serve in
    let%bind () = Archive_schema.upgrade ~postgres_uri in
    let%bind () =
      expect "fork recorded, schema upgraded"
        (Differs
           { schema = upgraded_version
           ; mine = Archive_lib.Schema_era.my_protocol_version
           } )
    in
    let%bind () = set_status Status.Starting in
    let%bind () =
      expect "fork recorded, migration starting"
        (Migration_in_progress Status.Starting)
    in
    let%bind () = set_status Status.Failed in
    let%bind () =
      expect "fork recorded, migration failed"
        (Migration_in_progress Status.Failed)
    in
    let%bind () = Archive_schema.downgrade ~postgres_uri in
    let%bind () = expect "older schema, no hardfork_state" Serve in
    let%bind () = Archive_schema.upgrade ~postgres_uri in
    let%bind () = expect "schema upgraded, no fork recorded" Serve in
    let%map () = Caqti_async.Pool.drain pool.Mina_caqti.Pool.pool in
    Mina_automation_fixture.Intf.Passed
end
