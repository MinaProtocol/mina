open Async
open Command

val init :
     f:(int -> 'a -> unit Deferred.t)
  -> 'a Param.t
  -> (unit -> unit Deferred.t) Param.t
