module type S = sig
  val trace_event : string -> unit

  val trace : string -> (unit -> 'a) -> 'a

  val trace_recurring : string -> (unit -> 'a) -> 'a

  val trace_task : string -> (unit -> unit Async_kernel.Deferred.t) -> unit

  val trace_recurring_task :
    string -> (unit -> unit Async_kernel.Deferred.t) -> unit

  val measure : string -> (unit -> 'a) -> 'a

  val forget_tid : (unit -> 'a) -> 'a
end
