open Mina_automation
open Intf

type after_bootstrap =
  { daemon : Daemon.Process.t
  ; temp_dir : string
  }

type before_bootstrap =
  { config : Daemon.Config.t
  ; temp_dir : string
  }

module type TestCaseWithBootstrap = TestCase with type t = after_bootstrap

module type TestCaseWithoutBootstrap = TestCase with type t = before_bootstrap

module Make_FixtureWithBootstrap (M : TestCaseWithBootstrap) :
  Fixture with type t = after_bootstrap

module Make_FixtureWithoutBootstrap (M : TestCaseWithoutBootstrap) :
  Fixture with type t = before_bootstrap
