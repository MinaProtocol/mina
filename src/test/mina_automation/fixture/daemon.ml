open Async
open Core
open Mina_automation
open Intf

let logger = Logger.create ()

type after_bootstrap = { daemon : Daemon.Process.t; temp_dir : string }

type before_bootstrap = { config : Daemon.Config.t; temp_dir : string }

let generate_random_accounts t output =
  let client = Daemon.client t in
  let%map ledger_content = Daemon.Client.test_ledger client ~n:10 in
  let accounts =
    Yojson.Safe.from_string ledger_content
    |> Runtime_config.Accounts.of_yojson |> Result.ok_or_failwith
  in
  Runtime_config.Accounts.to_yojson accounts |> Yojson.Safe.to_file output ;
  accounts

let generate_random_config t output =
  let client = Daemon.client t in
  let%map ledger_content = Daemon.Client.test_ledger client ~n:10 in
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
  Runtime_config.to_yojson runtime_config |> Yojson.Safe.to_file output

module type TestCaseWithBootstrap = TestCase with type t = after_bootstrap

module type TestCaseWithoutBootstrap = TestCase with type t = before_bootstrap

module type TestCaseWithoutBootstrapAndWithSetup =
  TestCaseWithSetup with type t = Integration_test_lib.Test_config.t

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
    let config = Daemon.Config.default () in
    let executor = Daemon.of_config config in
    let ledger_file = config.dirs.conf ^/ "daemon.json" in
    let%bind () = generate_random_config executor ledger_file in
    [%log info] "Starting daemon" ;
    let%bind daemon = Daemon.start executor in
    [%log info] "Daemon started successfully" ;
    Deferred.Or_error.return
      { daemon; temp_dir = Filename.temp_dir "daemon_test" "" }

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
    let%map contents = Process.stdout t.daemon.process |> Reader.contents in
    [%log debug] "Daemon process output: %s" contents ;
    ()
end

module Make_FixtureWithoutBootstrap (M : TestCaseWithoutBootstrap) :
  Fixture with type t = before_bootstrap = struct
  type t = before_bootstrap

  let test_case = M.test_case

  let setup () =
    Deferred.Or_error.return
      { config = Daemon.Config.default ()
      ; temp_dir = Filename.temp_dir "daemon_test" ""
      }

  let teardown _t = Deferred.Or_error.ok_unit

  let on_test_fail _t = Deferred.unit
end

module Make_FixtureWithBootstrapAndFromTestConfig
    (M : TestCaseWithoutBootstrapAndWithSetup) :
  Fixture with type t = Integration_test_lib.Test_config.t = struct
  type t = Integration_test_lib.Test_config.t

  let test_case = M.test_case

  let setup () = Deferred.Or_error.return (M.setup ())

  let teardown _t = Deferred.Or_error.ok_unit

  let on_test_fail _t = Deferred.unit
end
