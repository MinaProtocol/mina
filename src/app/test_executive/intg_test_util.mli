open Core
open Integration_test_lib
open Async
open Dsl
open Network
open Engine

val check_common_prefixes :
     tolerance:int
  -> logger:Logger.t
  -> string list list
  -> ( unit Malleable_error.Result_accumulator.t
     , Malleable_error.Hard_fail.t )
     result
     Async_kernel.Deferred.t

type network = Network.t

type node = Network.Node.t

val check_peers :
     logger:Logger.t
  -> node list
  -> ( unit Malleable_error.Result_accumulator.t
     , Malleable_error.Hard_fail.t )
     result
     Deferred.t
