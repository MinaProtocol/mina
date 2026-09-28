(* The pre-fork side of the archive hand-over: a daemon announces the fork over
   the archive RPC, and the archive records it and, if asked, stops.

   1. a 4.0.0 database has no hardfork_state: the announcement is refused, and
      the refusal names upgrade.sql
   2. after upgrade.sql:
      - the client refuses a missing file, text that is not JSON and a config
        with no fork stanza, before anything reaches the archive
      - the archive refuses the same over the RPC, records nothing and keeps
        running
      - ten concurrent announcements of one fork all succeed and leave one row
      - a repeat changes nothing, and a different fork block is refused
   3. --hardfork-handling exit: neither an unusable config nor a different fork
      block stops the archive; the recorded fork does
   4. --hardfork-handling migrate-exit runs upgrade.sql, then stops

   Run:
     MINA_TEST_POSTGRES_URI=postgres://postgres:xxxx@localhost:5432 \
     MINA_TEST_NETWORK_DATA=./src/test/archive/sample_db \
     ./_build/default/src/test/archive/archive_node_tests/archive_node_tests.exe \
     test hardfork_rpc
*)

open Async
open Core
open Mina_automation
open Mina_automation_fixture.Archive

type t = Mina_automation_fixture.Archive.before_bootstrap

let fork_config ~dir ~name ~state_hash ~height =
  let path = dir ^/ name ^ ".json" in
  let%map () =
    Writer.save path
      ~contents:
        (sprintf
           {json|{"proof":{"fork":{"state_hash":"%s","blockchain_length":%d,"global_slot_since_genesis":%d}}}|json}
           state_hash height height )
  in
  path

let sql ~connection query =
  Psql.run_command ~connection query >>| Or_error.ok_exn

(* Runs [f] against an archive started with [extra_args], its stdout drained
   into [log_file] so the pipe never fills. [f] gets the archive's exit status
   as a deferred, for the cases where the archive stops by itself. Whatever [f]
   does, the archive is stopped afterwards: a leftover archive would keep the
   port and answer the next case. *)
let with_archive (config : Archive.Config.t) ~extra_args ~log_file ~f =
  let config = Archive.Config.with_extra_args config extra_args in
  let%bind archive = Archive.start (Archive.of_config config) in
  let exited = Process.wait archive.process in
  Archive.Process.start_logging archive ~log_file ;
  Monitor.protect
    ~finally:(fun () ->
      if Deferred.is_determined exited then Deferred.unit
      else (
        ignore
          ( Signal.send Signal.kill (`Pid (Process.pid archive.process))
            : [ `Ok | `No_such_process ] ) ;
        exited >>| ignore ) )
    (fun () ->
      let%bind () = Archive.wait_until_ready ~log_file >>| Or_error.ok_exn in
      f exited )

let exit_code_within ~seconds exited =
  match%map Clock.with_timeout (Time.Span.of_sec seconds) exited with
  | `Result (Ok ()) ->
      Ok 0
  | `Result (Error (`Exit_non_zero code)) ->
      Ok code
  | `Result (Error (`Signal signal)) ->
      Or_error.errorf "archive killed by %s" (Signal.to_string signal)
  | `Timeout ->
      Or_error.errorf "archive still running after %.0fs" seconds

let log_contains ~log_file needle =
  let%map contents = Reader.file_contents log_file in
  String.is_substring contents ~substring:needle

(* The RPC a daemon sends, without the client's own checks in front of it. *)
let dispatch ~port ~config_json =
  Mina_lib.Archive_client.dispatch_hardfork_config ~max_tries:1
    ~logger:(Logger.null ())
    { Cli_lib.Flag.Types.name = "--archive-address"
    ; value = Host_and_port.create ~host:"127.0.0.1" ~port
    }
    ~config_json

let expect_refused ~what ~needle = function
  | Ok () ->
      failwithf "%s was accepted" what ()
  | Error msg ->
      if not (String.is_substring msg ~substring:needle) then
        failwithf "%s was refused, but not with %S: %s" what needle msg ()

let still_running ~what exited =
  if Deferred.is_determined exited then
    failwithf "%s stopped the archive" what ()

let test_case (test_data : t) =
  let%bind port = Utils.free_port () in
  let config = { test_data.config with server_port = port } in
  let dir = test_data.temp_dir in
  let connection = Psql.Conn_str config.postgres_uri in
  let archive_address = sprintf "127.0.0.1:%d" config.server_port in
  let client = Daemon.Client.create () in
  let send config_file =
    let%map output =
      Daemon.Client.advanced_send_hardfork_config client ~config_file
        ~archive_address
    in
    match output.exit_status with
    | Ok () ->
        Ok ()
    | Error _ ->
        Error output.stderr
  in
  let recorded_hash () =
    sql ~connection "SELECT fork_state_hash FROM hardfork_state"
  in
  let upgrade_script =
    Archive.Scripts.filepath `Upgrade
    |> Option.value_exn ~message:"Failed to find upgrade script"
  in
  let%bind fork_a =
    fork_config ~dir ~name:"fork_a" ~state_hash:"FORK_A" ~height:10
  in
  let%bind fork_b =
    fork_config ~dir ~name:"fork_b" ~state_hash:"FORK_B" ~height:11
  in
  let dispatch config_json =
    dispatch ~port:config.server_port ~config_json
    >>| Result.map_error ~f:Error.to_string_hum
  in
  let unusable =
    [ ("text that is not JSON", "not json at all")
    ; ("a config with no fork stanza", {json|{"proof":{}}|json})
    ; ( "a fork stanza with missing fields"
      , {json|{"proof":{"fork":{"state_hash":"FORK_C"}}}|json} )
    ]
  in
  let%bind () = Writer.save (dir ^/ "not_json.json") ~contents:"{" in
  let%bind () =
    Writer.save (dir ^/ "no_fork.json") ~contents:{json|{"proof":{}}|json}
  in
  let rows () = sql ~connection "SELECT count(*) FROM hardfork_state" in

  (* 1. A 4.0.0 database was created before hardfork_state existed. *)
  let%bind _ =
    sql ~connection "DROP TABLE hardfork_state; DROP TYPE hardfork_source"
  in
  let%bind () =
    with_archive config ~extra_args:[]
      ~log_file:(dir ^/ "keep_running_4_0_0.log") ~f:(fun _ ->
        match%map send fork_a with
        | Ok () ->
            failwith
              "the archive accepted a fork without a hardfork_state table"
        | Error msg ->
            if not (String.is_substring msg ~substring:"run upgrade.sql") then
              failwithf "the refusal does not name upgrade.sql: %s" msg () )
  in

  (* 2. upgrade.sql, run before the fork. *)
  let%bind _ = Psql.run_script ~connection upgrade_script in
  let%bind migration =
    sql ~connection
      "SELECT protocol_version || ' ' || status::text FROM migration_history \
       ORDER BY commit_start_at DESC LIMIT 1"
  in
  [%test_eq: string] migration "5.0.0 applied" ;
  let log_file = dir ^/ "keep_running.log" in
  let%bind () =
    with_archive config ~extra_args:[] ~log_file ~f:(fun exited ->
        (* The client refuses before anything reaches the archive. *)
        let%bind () =
          send (dir ^/ "missing.json")
          >>| expect_refused ~what:"a missing file" ~needle:"Could not read"
        in
        let%bind () =
          send (dir ^/ "not_json.json")
          >>| expect_refused ~what:"a file that is not JSON"
                ~needle:"is not a runtime configuration"
        in
        let%bind () =
          send (dir ^/ "no_fork.json")
          >>| expect_refused ~what:"a config with no fork stanza"
                ~needle:"has no fork stanza"
        in
        (* The archive refuses the same, sent straight over the RPC. *)
        let%bind () =
          Deferred.List.iter unusable ~f:(fun (what, config_json) ->
              dispatch config_json
              >>| expect_refused ~what
                    ~needle:"unusable hard fork configuration" )
        in
        let%bind n = rows () in
        [%test_eq: string] n "0" ;
        still_running ~what:"an unusable config" exited ;
        (* Ten daemons announce the same fork at once. *)
        let%bind config_json = Reader.file_contents fork_a in
        let%bind results =
          Deferred.List.init ~how:`Parallel 10 ~f:(fun _ ->
              dispatch config_json )
        in
        List.iteri results ~f:(fun i result ->
            match result with
            | Ok () ->
                ()
            | Error msg ->
                failwithf "concurrent announcement %d was refused: %s" i msg () ) ;
        let%bind n = rows () in
        [%test_eq: string] n "1" ;
        let%bind hash = recorded_hash () in
        [%test_eq: string] hash "FORK_A" ;
        (* The heartbeat: a repeat changes nothing. *)
        let%bind () = send fork_a >>| Result.ok_or_failwith in
        let%bind n = rows () in
        [%test_eq: string] n "1" ;
        (* Two daemons disagree about the fork block. *)
        let%bind () =
          send fork_b
          >>| expect_refused ~what:"a different fork block"
                ~needle:"already records a fork"
        in
        let%map hash = recorded_hash () in
        [%test_eq: string] hash "FORK_A" )
  in

  (* 3. exit *)
  let%bind () =
    with_archive config ~extra_args:[ "--hardfork-handling"; "exit" ]
      ~log_file:(dir ^/ "exit.log") ~f:(fun exited ->
        (* Neither of these is a fork to hand over for. The hand-over waits
           five seconds after the record, so give it longer than that. *)
        let%bind (_ : (unit, string) Result.t) = dispatch "not json at all" in
        let%bind (_ : (unit, string) Result.t) = send fork_b in
        let%bind () = after (Time.Span.of_sec 8.) in
        still_running ~what:"a refused announcement" exited ;
        let%bind () = send fork_a >>| Result.ok_or_failwith in
        let%map code =
          exit_code_within ~seconds:30. exited >>| Or_error.ok_exn
        in
        [%test_eq: int] code 0 )
  in

  (* 4. migrate-exit *)
  let log_file = dir ^/ "migrate_exit.log" in
  let%map () =
    with_archive config
      ~extra_args:
        [ "--hardfork-handling"
        ; "migrate-exit"
        ; "--schema-upgrade-script"
        ; upgrade_script
        ] ~log_file ~f:(fun exited ->
        let%bind () = send fork_a >>| Result.ok_or_failwith in
        let%bind code =
          exit_code_within ~seconds:30. exited >>| Or_error.ok_exn
        in
        [%test_eq: int] code 0 ;
        let%map upgraded =
          log_contains ~log_file "Upgraded the archive schema"
        in
        if not upgraded then failwith "migrate-exit did not run upgrade.sql" )
  in
  Mina_automation_fixture.Intf.Passed
