open Async
open Core
open Mina_automation
open Intf

let logger = Logger.create ()

type after_bootstrap = { daemon : Daemon.Process.t; temp_dir : string }

type before_bootstrap = { config : Daemon.Config.t; temp_dir : string }

let generate_random_ledger t output =
  let open Deferred.Let_syntax in
  let client = Daemon.client t in
  let%bind ledger_content = Daemon.Client.test_ledger client ~n:10 in
  let accounts =
    Yojson.Safe.from_string ledger_content
    |> Runtime_config.Accounts.of_yojson |> Result.ok_or_failwith
  in
  let ledger : Runtime_config.Ledger.t =
    { base = Accounts accounts
    ; num_accounts = None
    ; balances = []
    ; hash = None
    ; s3_data_hash = None
    ; name = None
    ; add_genesis_winner = Some true
    }
  in
  let runtime_config = Runtime_config.make ~ledger () in
  Runtime_config.to_yojson runtime_config |> Yojson.Safe.to_file output ;
  return accounts

module type TestCaseWithBootstrap = TestCase with type t = after_bootstrap

module type TestCaseWithoutBootstrap = TestCase with type t = before_bootstrap

module Make_FixtureWithBootstrap (M : TestCaseWithBootstrap) :
  Fixture with type t = after_bootstrap = struct
  type t = after_bootstrap

  let test_case = M.test_case

  (**
      Sets up the daemon by performing the following steps:
      1. Retrieves the network data folder path from the environment variable "MINA_TEST_NETWORK_DATA".
         (This variable must be set before running the test.)
      2. Creates network data using the retrieved folder path.
      3. Sets up a connection using the created network data.

      @return A record containing the started daemon and the network data.
    *)
  let setup () =
    let open Deferred.Or_error.Let_syntax in
    let config = Daemon.Config.default () in
    let executor = Daemon.of_config config in
    let ledger_file = config.dirs.conf ^/ "daemon.json" in
    let%bind.Deferred _ = generate_random_ledger executor ledger_file in
    [%log info] "Starting daemon" ;
    let%bind.Deferred daemon = Daemon.start executor in
    [%log info] "Daemon started successfully" ;
    return { daemon; temp_dir = Filename.temp_dir "daemon_test" "" }

  let teardown t =
    let open Deferred.Or_error.Let_syntax in
    [%log info] "Tearing down daemon" ;
    let%bind _ = Daemon.Process.force_kill t.daemon in
    let%bind.Deferred () =
      Mina_stdlib_unix.File_system.remove_dir @@ t.temp_dir
    in
    [%log info] "Daemon teardown completed" ;
    Deferred.Or_error.ok_unit

  let on_test_fail (t : t) =
    let open Deferred.Let_syntax in
    let%map contents = Process.stdout t.daemon.process |> Reader.contents in
    [%log debug] "Daemon process output: %s" contents ;
    ()
end

module Make_FixtureWithoutBootstrap (M : TestCaseWithoutBootstrap) :
  Fixture with type t = before_bootstrap = struct
  type t = before_bootstrap

  let test_case = M.test_case

  let setup () =
    let open Deferred.Or_error.Let_syntax in
    return
      { config = Daemon.Config.default ()
      ; temp_dir = Filename.temp_dir "daemon_test" ""
      }

  let teardown _t = Deferred.Or_error.ok_unit

  let on_test_fail _t = Deferred.unit
end
