open Core
open Async

module type TestCase = sig
  type t

  val setup : t Deferred.t

  val test_case : t -> unit Deferred.Or_error.t

  val on_test_fail : t -> unit Deferred.t

  val teardown : t -> unit Deferred.Or_error.t
end

module type DefaultTestCase = sig
  type t

  val test_case : t -> unit Deferred.Or_error.t
end

let run (module Test : TestCase) =
  let test_failed = ref false in
  let open Deferred.Let_syntax in
  let%bind app = Test.setup in
  Monitor.protect
    ~finally:(fun () ->
      if !test_failed then Test.on_test_fail app else Deferred.unit )
    (fun () ->
      match%bind Test.test_case app with
      | Ok () ->
          let%bind _ = Test.teardown app in
          Deferred.unit
      | Error err ->
          let%bind _ = Test.teardown app in
          test_failed := false ;
          Error.raise err )

let run_blocking test_case () =
  Async.Thread_safe.block_on_async_exn (fun () -> run test_case)
