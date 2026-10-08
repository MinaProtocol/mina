(* The pre-fork hand-over end to end, on one node.

   A single demo-mode seed produces blocks on a network that forks on its own
   (slot_tx_end and slot_chain_end set in the test config), with an archive and
   a Rosetta beside it:

     daemon   --hardfork-handling migrate-exit --archive-address
     archive  --hardfork-handling migrate-exit
     rosetta  --watch-schema-era

   upgrade.sql runs before anything starts, as an operator does before a fork.
   At slot_chain_end the daemon generates its fork config, sends it to the
   archive and exits. The archive records the fork, re-runs upgrade.sql and
   exits. Rosetta then sees a recorded fork on a schema of another era and
   stands down. All three must exit 0, and the archive must hold the config the
   daemon generated, byte for byte, and the fork block.

   Every process runs with MINA_PROFILE=lightnet (no proofs, so the node
   produces blocks in time) on ports the OS hands out.

   Run:
     MINA_TEST_POSTGRES_URI=postgres://postgres:xxxx@localhost:5432 \
     MINA_TEST_NETWORK_DATA=./src/test/archive/sample_db \
     ./_build/default/src/test/archive/archive_node_tests/archive_node_tests.exe \
     test prefork_handover
*)

open Async
open Core
open Mina_automation
open Mina_automation_fixture.Archive
open Integration_test_lib

type t = Mina_automation_fixture.Archive.before_bootstrap

let block_producer = "block-producer"

(* Genesis is when the config is written. The node is up within a minute, long
   before the fork slots. No proof level: the binaries use their profile's. *)
let test_config =
  let default = Test_config.default ~constants:Test_config.default_constants in
  { default with
    genesis_ledger =
      [ Test_config.Test_account.create ~account_name:block_producer
          ~balance:"10000000" ()
      ; Test_config.Test_account.create ~account_name:"other" ~balance:"1000" ()
      ]
  ; slot_tx_end = Some 12
  ; slot_chain_end = Some 18
  ; hard_fork_genesis_slot_delta = Some 1
  ; proof_config =
      { default.proof_config with
        level = None
      ; block_window_duration_ms = Some 10_000
      }
  }

let profile_env = Profile.env Lightnet

(* Eighteen slots of ten seconds and the config dump: well inside this. *)
let shutdown_timeout = Time.Span.of_min 15.

let ok_exit = Ok () |> Or_error.return

let test_case (test_data : t) =
  let archive_uri = test_data.config.postgres_uri in
  let dir = test_data.temp_dir in
  let%bind client_port = Utils.free_port () in
  let%bind rest_port = Utils.free_port () in
  let%bind external_port = Utils.free_port () in
  let%bind archive_port = Utils.free_port () in
  let%bind rosetta_port = Utils.free_port () in

  (* The node, from the test config: daemon.json is written here. *)
  let daemon_config =
    Daemon.Config.create ~client_port ~rest_port
      ~dirs:(Daemon.Config.ConfigDirs.create ())
      ~config:test_config ()
  in
  let daemon = Daemon.of_config daemon_config in
  let conf_dir = daemon_config.dirs.conf in
  let%bind () = Daemon.Config.generate_keys daemon_config in
  let%bind block_producer_key =
    Daemon.Config.write_block_producer_key daemon_config
      ~account_name:block_producer
  in

  (* The operator's step before the fork. *)
  let%bind () = Archive_schema.upgrade ~postgres_uri:archive_uri in
  let upgrade_script =
    Archive.Scripts.filepath `Upgrade
    |> Option.value_exn ~message:"Failed to find upgrade script"
  in

  let%bind archive =
    Archive.start ~env:(`Extend profile_env)
      (Archive.of_config
         (Archive.Config.with_extra_args
            (Archive.Config.create
               ~config_file:(conf_dir ^/ "daemon.json")
               ~postgres_uri:archive_uri ~server_port:archive_port )
            [ "--hardfork-handling"
            ; "migrate-exit"
            ; "--schema-upgrade-script"
            ; upgrade_script
            ] ) )
  in
  let archive_exited = Process.wait archive.process in
  Utils.log_output archive.process ~log_file:(dir ^/ "archive.log") ;

  let%bind rosetta =
    Rosetta.start ~env:profile_env
      (Rosetta.of_config
         (Rosetta.Config.create ~archive_uri
            ~graphql_uri:(sprintf "http://127.0.0.1:%d/graphql" rest_port)
            ~port:rosetta_port ~extra_args:[ "--watch-schema-era" ] () ) )
  in
  let rosetta_exited = Process.wait rosetta.process in
  Utils.log_output rosetta.process ~log_file:(dir ^/ "rosetta.log") ;

  (* The key passwords come from Daemon.Config.ConfigDirs.create. *)
  let%bind daemon_process =
    Daemon.start ~hardfork_handling:"migrate-exit" ~block_producer_key
      ~archive_address:(sprintf "127.0.0.1:%d" archive_port)
      ~external_port ~env:(`Extend profile_env) daemon
  in
  let daemon_exited = Process.wait daemon_process.process in

  Monitor.protect
    ~finally:(fun () ->
      Deferred.all_unit
        [ Utils.kill_if_running daemon_process.process daemon_exited
        ; Utils.kill_if_running archive.process archive_exited
        ; Utils.kill_if_running rosetta.process rosetta_exited
        ] )
    (fun () ->
      let%bind () =
        Archive_healthcheck.wait_db_and_server_ready ~postgres_uri:archive_uri
          ~server_port:archive_port ()
        >>| Or_error.ok_exn
      in
      let%bind () = Rosetta.wait_until_ready rosetta >>| Or_error.ok_exn in
      let%bind () =
        Daemon.wait_for_node_init daemon_process >>| Or_error.ok_exn
      in
      (* Before the fork: upgraded early, nothing recorded, Rosetta serving. *)
      if Deferred.is_determined rosetta_exited then
        failwith "rosetta stopped before the fork" ;

      (* The fork: all three exit 0, the daemon first. *)
      let%bind daemon_status =
        Utils.exit_status_within ~timeout:shutdown_timeout daemon_exited
      in
      let%bind archive_status =
        Utils.exit_status_within ~timeout:(Time.Span.of_min 2.) archive_exited
      in
      let%bind rosetta_status =
        Utils.exit_status_within ~timeout:(Time.Span.of_min 1.) rosetta_exited
      in
      [%test_eq: Unix.Exit_or_signal.t Or_error.t list]
        [ daemon_status; archive_status; rosetta_status ]
        [ ok_exit; ok_exit; ok_exit ] ;

      (* What the archive holds is what the daemon generated. *)
      let%bind generated, fork =
        Hardfork_handover.generated_config daemon_config >>| Or_error.ok_exn
      in
      let%map record =
        Hardfork_handover.Archive_record.load ~postgres_uri:archive_uri
          ~fork_state_hash:fork.state_hash
      in
      [%test_eq: Hardfork_handover.Archive_record.t] record
        { recorded = Some (fork.state_hash, generated)
        ; fork_block_archived = true
        ; migration =
            Some
              Archive_lib.Processor.Migration_history.
                { status = Status.Applied; protocol_version = "5.0.0" }
        } ;
      Mina_automation_fixture.Intf.Passed )
