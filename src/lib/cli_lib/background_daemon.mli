open Async
open Command

val init :
     ?rest:bool
  -> f:(int -> 'a -> unit Deferred.t)
  -> 'a Param.t
  -> (unit -> unit Deferred.t) Param.t
