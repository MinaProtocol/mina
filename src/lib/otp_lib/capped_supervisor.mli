open Async_kernel

type _ t

val create :
     ?buffer_capacity:int
  -> job_capacity:int
  -> ('job -> unit Deferred.t)
  -> 'job t

val dispatch : 'job t -> 'job -> unit
