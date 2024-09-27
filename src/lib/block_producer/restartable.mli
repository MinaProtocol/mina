type ('data, 'a) t

val create :
     task:
       (cancel:unit Async_kernel.Ivar.t -> 'data -> ('a, unit) Interruptible.t)
  -> ('data, 'a) t

val cancel : (_, _) t -> unit

val restart : ('data, 'a) t -> 'data -> ('a, unit) Interruptible.t
