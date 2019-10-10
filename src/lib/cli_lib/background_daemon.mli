open Async
open Command

val rpc_init :
     f:(int -> 'a -> unit Deferred.t)
  -> 'a Param.t
  -> (unit -> unit Deferred.t) Param.t

val graphql_init :
     f:(int -> 'a -> unit Deferred.t)
  -> 'a Param.t
  -> (unit -> unit Deferred.t) Param.t
