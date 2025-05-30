(** Choosable synchronous pipe: a pipe with read and write operations
    that are idempotent (calling them multiple times will return the same
    result) and return the updated pipe on each call.

    Pipe is specifically designed to work with [Deferred.choose]:

    - [read] would return the same value for a ['data_in_pipe reader_t],
        no matter how many times it is called.
    - [write_choice] would perform write only if the choice is selected.

   When performing a write, the pipe is waiting for some other async process
   to attempt the [read] operation, and once that happens writing happens
   non-blockingly.

   Pipe is synchronous in the sense that it doesn't perform any background
   processing or buffering, write will always happen only after a read was
   initiated.

   Pipe has a peculiar interface, returning the "updated pipe" on [read] and
   [write_choice] operations which should be used for all of the future
   operations. This is unlike other pipes, where the same pipe value is used
   for all operations and there is no notion of "updated pipe".
   
   Pipe is thread-safe for [iter] and [read] operations. Note that if updated
   pipe is not shared among parallel threads, both threads will see the same
   sequence of values read.
   
   It is not recommended to use the same pipe for writing from parallel threads.
   While, behavior is well specified, it's unlikely to be a desired one. Same
   applies to parallelism of [close] operation or some combination of [close]
   and [write_choice]. *)

open Async_kernel

type 'data_in_pipe writer_t

type 'data_in_pipe reader_t

(** Closes the pipe. If the same pipe was already used by [write_choice]
    and the write was completed, [close] operation will have no effect, and
    the pipe won't be closed. Hence if the close is required, it's necessary
    to call it on the updated pipe passed to [write_choice] in the
    [on_chosen] callback. *)
val close : 'a writer_t -> unit

(** Creates a new pipe. *)
val create : unit -> 'data reader_t * 'data writer_t

(** Creates a new pipe that is already closed. *)
val create_closed : unit -> 'data reader_t

(** Returns a choice that writes data to the pipe if a read
    operation arrived and was chosen for the [Deferred.choose]
    operation the choice is used for.

    Once the read operation started, the write will happen
    non-blockingly.

    Callback [on_chosen] is given an updated pipe which can be used
    for future writes. If the choice is not selected, the write will
    not happen and the callback won't be executed. It is safe to call
    [write_choice] multiple times for the same pipe, but it is not
    safe to call [write_choice] after the pipe is closed.
    
    Updated pipe passed to [on_chosen] must be used for future writes.
    
    If the updated pipe passed to [on_chosen] on one of previous
    invocations of [write_choice] is ignored and not used, the call to
    [write_choice] on one and the same pipe will have no effect, and
    will simply be ignored. 

    Calling [write_choice] on a closed pipe will have no effect, and
    will simply be ignored. *)
val write_choice :
     on_chosen:('data writer_t -> 'b)
  -> 'data writer_t
  -> 'data
  -> 'b Deferred.Choice.t

(** Write data to the pipe.

    Returns a new pipe that can be used for future writes.
    
    If the pipe is closed, the write will have no effect and the
    same pipe will be returned. *)
val write : 'data writer_t -> 'data -> 'data writer_t Deferred.t

(** Reads data from the pipe.

    Returns [`Eof] if the pipe is closed.
    
    If the read was successful, returns the data along with a new pipe
    that can be used for future reads.
    
    Calling [read] on the same pipe multiple times will return the same
    result and will not make the pipe progress on future writes. *)
val read : 'data reader_t -> [ `Eof | `Ok of 'data * 'data reader_t ] Deferred.t

(** Iterates over the pipe. The returned deferred is determined when the pipe
    is closed.
    
    Calling [iter] on the same pipe multiple times will execute the callback
    on the same series of values. *)
val iter : 'data reader_t -> f:('data -> unit Deferred.t) -> unit Deferred.t
