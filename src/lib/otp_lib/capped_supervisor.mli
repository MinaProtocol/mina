(**
 * A [Capped_supervisor] is a process supervisor which which will limit the
 * number of active processes to some specified capacity. Specifically, it
 * allows the definition of a job runner which jobs can be dispatched to,
 * where dispatched jobs are added to a queue and a pool a processes work
 * off the queue, with at max [job_capacity] jobs.
 *)

open Async_kernel

type _ t

val create :
     ?buffer_capacity:int
  -> job_capacity:int
  -> ('job -> unit Deferred.t)
  -> 'job t

val dispatch : 'job t -> 'job -> unit

(** Stop starting jobs. Each job not yet started, including any dispatched
    later, is given to [release] instead of being run. Jobs already running
    carry on. Stopping a stopped supervisor does nothing. *)
val stop : 'job t -> release:('job -> unit) -> unit
