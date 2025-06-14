(** swappable strict pipe *)
type ('data_in_pipe, 'write_return) t

(** [create ?warn_on_drop ~name type] creates a swappable strict pipe.
    This name would be used to generate prometheus metrics, so please obey the
    naming convention, e.g. use underscore & alphas only. *)
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

(** [swap_reader t] requests the swappable pipe [t] to create a new iterator
    and attach it to the pipe as reader.

    Any value that wasn't read by the previous iterator is passed to the new
    iterator. It's guaranteed that no value is lost or passed to more than one
    iterator.

    If two calls to [swap_reader] are made in parallel, the first
    call "wins", and the second call returns an immediately closed iterator.

    If [t] is terminated, [swap_reader] returns an immediately closed iterator.
    *)
val swap_reader :
     ('data_in_pipe, 'write_return) t
  -> 'data_in_pipe Choosable_synchronous_pipe.reader_t Async_kernel.Deferred.t

(** [kill t] signals the swappable pipe [t] to terminate. If [t] is already
    terminated, this is a no-op. *)
val kill : ('data_in_pipe, 'write_return) t -> unit
