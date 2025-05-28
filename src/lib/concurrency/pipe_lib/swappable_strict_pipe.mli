(** swappable strict pipe *)
type ('data_in_pipe, 'write_return) t

(** [create ?warn_on_drop ~name type] creates a swappable strict pipe. *)
val create :
     ?warn_on_drop:bool
  -> name:string
  -> ('data_in_pipe, 'pipe_kind, 'write_return) Strict_pipe.type_
  -> ('data_in_pipe, 'write_return) t

(** [write t data] writes to a swappable strict pipe and returns value
    as specified by the strict pipe used for [create].
    [write t data] shouldn't be called after a call to [kill t].
    *)
val write : ('data_in_pipe, 'write_return) t -> 'data_in_pipe -> 'write_return

module Iterator : sig
  type 'data_in_pipe t

  val read :
    'data_in_pipe t -> [ `Eof | `Ok of 'data_in_pipe ] Async_kernel.Deferred.t

  val iter :
       'data_in_pipe t
    -> f:('data_in_pipe -> unit Async_kernel.Deferred.t)
    -> unit Async_kernel.Deferred.t
end

(** [swap_reader ~reader_name t] requests the swappable pipe [t] to prepare a
    new pipe, kill the previous pipe, and returns an iterator for the new pipe.
    
    If two calls to [swap_reader] are made in parallel, the first
    call "wins", and the second call returns an immediately closed reader.

    If [t] is terminated, [swap_reader] returns an immediately closed reader.
    *)
val swap_reader :
     reader_name:string
  -> ('data_in_pipe, 'write_return) t
  -> 'data_in_pipe Iterator.t Async_kernel.Deferred.t

(** [kill t] signals the swappable pipe [t] to terminate. If [t] is already
    terminated, this is a no-op. *)
val kill : ('data_in_pipe, 'write_return) t -> unit
