open Mina_automation
open Intf

type after_bootstrap =
  { archive : Archive.Process.t; network_data : Network_data.t }

type before_bootstrap =
  { config : Archive.Config.t; network_data : Network_data.t }

module type TestCaseWithBootstrap = TestCase with type t = after_bootstrap

module type TestCaseWithoutBootstrap = TestCase with type t = before_bootstrap

module Make_FixtureWithBootstrap (M : TestCaseWithBootstrap) :
  Fixture with type t = after_bootstrap

module Make_FixtureWithoutBootstrap (M : TestCaseWithoutBootstrap) :
  Fixture with type t = before_bootstrap
