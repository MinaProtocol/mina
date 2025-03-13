open Async

type test_result = Passed | Failed of string | Warning of string

module type TestCase = sig
  type t

  val test_case : t -> test_result Deferred.Or_error.t
end

module type Fixture = sig
  type t

  val setup : unit -> t Deferred.Or_error.t

  val test_case : t -> test_result Deferred.Or_error.t

  val teardown : t -> unit Deferred.Or_error.t

  val on_test_fail : t -> unit Deferred.t
end
