open Mina_automation
open Intf
open Async

type after_bootstrap = { daemon : Daemon.Process.t; temp_dir : string }

type before_bootstrap = { config : Daemon.Config.t; temp_dir : string }

val generate_random_accounts :
  Daemon.t -> string -> Runtime_config.Accounts.t Deferred.t

val generate_random_config : Daemon.t -> string -> unit Deferred.t

module type TestCaseWithBootstrap = TestCase with type t = after_bootstrap

module type TestCaseWithoutBootstrap = TestCase with type t = before_bootstrap

module type TestCaseWithoutBootstrapAndWithSetup =
  TestCaseWithSetup with type t = Integration_test_lib.Test_config.t

module Make_FixtureWithBootstrap (M : TestCaseWithBootstrap) :
  Fixture with type t = after_bootstrap

module Make_FixtureWithoutBootstrap (M : TestCaseWithoutBootstrap) :
  Fixture with type t = before_bootstrap

module Make_FixtureWithBootstrapAndFromTestConfig
    (M : TestCaseWithoutBootstrapAndWithSetup) :
  Fixture with type t = Integration_test_lib.Test_config.t
