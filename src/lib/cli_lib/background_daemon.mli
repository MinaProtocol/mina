open Core
open Async

val rpc_init :
     f:(Host_and_port.t -> 'a -> unit Deferred.t)
  -> 'a Command.Param.t
  -> (unit -> unit Deferred.t) Command.Param.t

val graphql_init :
     f:(Uri.t Flag.Types.with_name -> 'a -> unit Deferred.t)
  -> 'a Command.Param.t
  -> (unit -> unit Deferred.t) Command.Param.t
