(* The pre-fork side of the archive hand-over: a daemon announces the fork over
   the archive RPC, and the archive records it and, if asked, stops.

   1. an older schema has no hardfork_state (upgrade.sql then downgrade.sql):
      the announcement is refused, and the refusal names upgrade.sql
   2. after upgrade.sql:
      - the client refuses a missing file, text that is not JSON and a config
        with no fork stanza, before anything reaches the archive
      - the archive answers Invalid_config to an unusable config sent over the
        RPC, Era_mismatch to a fork announced from another era, and Era_start
        to the heartbeat of the fork that started its own era -- recording
        nothing and running on
      - ten concurrent announcements of one fork are all accepted, exactly one
        of them as Recorded, and leave one row
      - a repeat changes nothing, a different fork block is refused, and a
        post-fork daemon's heartbeat of the recorded fork is accepted
   3. --hardfork-handling exit: an unusable config, a different fork block and
      the heartbeat of the archive's own era do not stop the archive; the
      recorded fork does
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
open Archive_lib.Hardfork_announcement

type t = Mina_automation_fixture.Archive.before_bootstrap

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
      let%bind () =
        Archive_healthcheck.wait_db_and_server_ready
          ~postgres_uri:config.postgres_uri ~server_port:config.server_port ()
        >>| Or_error.ok_exn
      in
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

(* Valid state hashes: the announcement carries a real State_hash.t. *)
let fork_a = "3NKeMoncuHab5ScarV5ViyF16cJPT4taWNSaTLS64Dp67wuXigPZ"

let fork_b = "3NLYmfj4U9Fbbvruz3QJj2j8WJyjhGtq4LgYvo7oW1WZm16uEKib"

let fork_json ~state_hash ~height =
  Fork_runtime_config.naming ~state_hash ~height ()

let next_era =
  Protocol_version.(
    create ~transaction:(transaction current + 1) ~network:0 ~patch:0)

let previous_era =
  Protocol_version.(
    create ~transaction:(transaction current - 1) ~network:0 ~patch:0)

(* The announcement a daemon sends, without the client's checks in front of
   it; [config_json] defaults to a config naming the same fork. *)
let query ?(side = Side.Before_fork)
    ?(protocol_version = Protocol_version.current) ?config_json ~state_hash
    ~height () : Query.t =
  { fork_state_hash = Mina_base.State_hash.of_base58_check_exn state_hash
  ; fork_blockchain_length = Mina_numbers.Length.of_int height
  ; fork_global_slot = Mina_numbers.Global_slot_since_genesis.of_int height
  ; protocol_version
  ; side
  ; config_json =
      Option.value config_json ~default:(fork_json ~state_hash ~height)
  }

let announce ~port query =
  Mina_lib.Archive_client.announce_hardfork ~max_tries:1
    ~logger:(Logger.null ())
    { Cli_lib.Flag.Types.name = "--archive-address"
    ; value = Host_and_port.create ~host:"127.0.0.1" ~port
    }
    query
  >>| Or_error.ok_exn

let expect_refused ~what ~needle = function
  | Ok () ->
      failwithf "%s was accepted" what ()
  | Error msg ->
      if not (String.is_substring msg ~substring:needle) then
        failwithf "%s was refused, but not with %S: %s" what needle msg ()

let expect_reply ~what expected reply =
  if not (expected reply) then
    failwithf "%s: unexpected reply %s" what
      (Sexp.to_string (Reply.sexp_of_t reply))
      ()

let still_running ~what exited =
  if Deferred.is_determined exited then
    failwithf "%s stopped the archive" what ()

let test_case (test_data : t) =
  let%bind port = Utils.free_port () in
  let config = { test_data.config with server_port = port } in
  let dir = test_data.temp_dir in
  let postgres_uri = config.postgres_uri in
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
  let announce = announce ~port:config.server_port in
  (* hardfork_state holds one row at most: the recorded fork, if any. *)
  let recorded () =
    Archive_schema.recorded_fork ~postgres_uri
    >>| Option.map ~f:(fun (r : Archive_lib.Processor.Hardfork_state.t) ->
            r.fork_state_hash )
  in
  let upgrade_script =
    Archive.Scripts.filepath `Upgrade
    |> Option.value_exn ~message:"Failed to find upgrade script"
  in
  let%bind fork_a_file =
    Fork_runtime_config.save ~path:(dir ^/ "fork_a.json")
      (fork_json ~state_hash:fork_a ~height:10)
  in
  let%bind fork_b_file =
    Fork_runtime_config.save ~path:(dir ^/ "fork_b.json")
      (fork_json ~state_hash:fork_b ~height:11)
  in
  let%bind () = Writer.save (dir ^/ "not_json.json") ~contents:"{" in
  let%bind (_ : string) =
    Fork_runtime_config.save ~path:(dir ^/ "no_fork.json")
      (Fork_runtime_config.without_fork ())
  in

  (* 1. An older schema, created before hardfork_state existed. *)
  let%bind () = Archive_schema.upgrade ~postgres_uri in
  let%bind () = Archive_schema.downgrade ~postgres_uri in
  let%bind () =
    with_archive config ~extra_args:[]
      ~log_file:(dir ^/ "keep_running_older_schema.log") ~f:(fun _ ->
        match%map send fork_a_file with
        | Ok () ->
            failwith
              "the archive accepted a fork without a hardfork_state table"
        | Error msg ->
            if not (String.is_substring msg ~substring:"run upgrade.sql") then
              failwithf "the refusal does not name upgrade.sql: %s" msg () )
  in

  (* 2. upgrade.sql, run before the fork. *)
  let%bind () = Archive_schema.upgrade ~postgres_uri in
  let%bind migration = Archive_schema.latest_migration ~postgres_uri in
  [%test_eq: Archive_lib.Processor.Migration_history.t option] migration
    (Some
       Archive_lib.Processor.Migration_history.
         { status = Status.Applied; protocol_version = "5.0.0" } ) ;
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
        (* The archive refuses an unusable config itself. *)
        let%bind () =
          Deferred.List.iter
            [ ("text that is not JSON", "not json at all")
            ; ( "a config with no fork stanza"
              , Fork_runtime_config.without_fork () )
            ; ( "a config naming another fork"
              , fork_json ~state_hash:fork_b ~height:11 )
            ]
            ~f:(fun (what, config_json) ->
              announce (query ~config_json ~state_hash:fork_a ~height:10 ())
              >>| expect_reply ~what (function
                    | Reply.Refused (Invalid_config _) ->
                        true
                    | _ ->
                        false ) )
        in
        (* Other eras. *)
        let%bind () =
          announce
            (query ~protocol_version:previous_era ~state_hash:fork_a ~height:10
               () )
          >>| expect_reply ~what:"a fork announced from another era" (function
                | Reply.Refused (Era_mismatch _) ->
                    true
                | _ ->
                    false )
        in
        let%bind () =
          announce (query ~side:After_fork ~state_hash:fork_b ~height:11 ())
          >>| expect_reply ~what:"the heartbeat of this era's own fork"
                (Reply.equal (Accepted Era_start))
        in
        let%bind fork = recorded () in
        [%test_eq: string option] fork None ;
        still_running ~what:"a refused or ignored announcement" exited ;
        (* Ten daemons announce the same fork at once. *)
        let%bind replies =
          Deferred.List.init ~how:`Parallel 10 ~f:(fun _ ->
              announce (query ~state_hash:fork_a ~height:10 ()) )
        in
        [%test_eq: int]
          (List.count replies ~f:(Reply.equal (Accepted Recorded)))
          1 ;
        [%test_eq: int]
          (List.count replies ~f:(Reply.equal (Accepted Already_recorded)))
          9 ;
        let%bind fork = recorded () in
        [%test_eq: string option] fork (Some fork_a) ;
        (* A repeat changes nothing. *)
        let%bind () = send fork_a_file >>| Result.ok_or_failwith in
        let%bind fork = recorded () in
        [%test_eq: string option] fork (Some fork_a) ;
        (* Two daemons disagree about the fork block. *)
        let%bind () =
          send fork_b_file
          >>| expect_refused ~what:"a different fork block"
                ~needle:"already records a fork"
        in
        (* A post-fork daemon's heartbeat of the recorded fork. *)
        let%bind () =
          announce
            (query ~side:After_fork ~protocol_version:next_era
               ~state_hash:fork_a ~height:10 () )
          >>| expect_reply ~what:"a post-fork heartbeat of the recorded fork"
                (Reply.equal (Accepted Already_recorded))
        in
        let%map fork = recorded () in
        [%test_eq: string option] fork (Some fork_a) )
  in

  (* 3. exit *)
  let%bind () =
    with_archive config ~extra_args:[ "--hardfork-handling"; "exit" ]
      ~log_file:(dir ^/ "exit.log") ~f:(fun exited ->
        (* None of these is a fork to hand over for. The hand-over waits five
           seconds after the record, so give it longer than that. *)
        let%bind (_ : Reply.t) =
          announce
            (query ~config_json:"not json at all" ~state_hash:fork_a ~height:10
               () )
        in
        let%bind (_ : (unit, string) Result.t) = send fork_b_file in
        let%bind (_ : Reply.t) =
          announce (query ~side:After_fork ~state_hash:fork_b ~height:11 ())
        in
        let%bind () = after (Time.Span.of_sec 8.) in
        still_running ~what:"an announcement that records nothing" exited ;
        let%bind () = send fork_a_file >>| Result.ok_or_failwith in
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
        let%bind () = send fork_a_file >>| Result.ok_or_failwith in
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
