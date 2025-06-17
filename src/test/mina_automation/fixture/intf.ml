open Async

type test_result = Passed | Failed of string | Warning of string

module type TestCase = sig
  type t

  val test_case : t -> test_result Deferred.Or_error.t
end

module type Fixture = sig
  type t

  (** 
    This module defines a type [t] representing a fixture for integration tests and provides functions to set up, run, and tear down the fixture.
    
    {1 Functions}
    
    - [setup ()]: Sets up the fixture and returns an instance of [t].
    - [test_case t]: Runs the test case associated with the fixture and returns a result.
    - [teardown t]: Tears down the fixture and cleans up resources.
    - [on_test_fail t]: Handles actions to take when a test fails.
  **)
  val setup : unit -> t Deferred.Or_error.t

  val test_case : t -> test_result Deferred.Or_error.t

  val teardown : t -> unit Deferred.Or_error.t

  val on_test_fail : t -> unit Deferred.t
end
