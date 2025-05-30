open Async_kernel

(** Choosable synchronous pipe: a pipe with read and write operations
    that are idempotent (calling them multiple times will return the same
    result) and return the updated pipe on each call.

    Pipe is specifically designed to work with [Deferred.choose]:

    - [read] would return the same value for a ['data_in_pipe t],
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
   for all operations and there is no notion of "updated pipe". *)
type 'data_in_pipe t

(** Closes the pipe. *)
val close : 'a t -> unit

(** Creates a new pipe. *)
val create : unit -> 'data t

(** Creates a new pipe that is already closed. *)
val create_closed : unit -> 'data t

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
  on_chosen:('data t -> 'b) -> 'data t -> 'data -> 'b Deferred.Choice.t

(** Reads data from the pipe.

    Returns [`Eof] if the pipe is closed.
    
    If the read was successful, returns the data along with a new pipe
    that can be used for future reads.
    
    Calling [read] on the same pipe multiple times will return the same
    result and will not make the pipe progress on future writes. *)
val read : 'data t -> [ `Eof | `Ok of 'data * 'data t ] Deferred.t

(** Iterates over the pipe. The returned deferred is determined when the pipe
    is closed.
    
    Calling [iter] on the same pipe multiple times will execute the callback
    on the same series of values. *)
val iter : 'data t -> f:('data -> unit Deferred.t) -> unit Deferred.t
