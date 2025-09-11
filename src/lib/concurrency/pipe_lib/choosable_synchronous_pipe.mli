(** Choosable synchronous pipe: a pipe with read operation that is idempotent
    (calling it multiple times will return the same result) and return the
    updated read handle on each call.

    Pipe is specifically designed to work with [Deferred.choose]:

    - [read] would return the same value for a ['data_in_pipe reader_t],
        no matter how many times it is called.
    - [write_choice] would perform write only if the choice is selected.

   When performing a write, the pipe is waiting for some other async process
   to attempt the [read] operation, and once that happens, write is going to
   happen non-blockingly.

   Pipe is synchronous in the sense that it doesn't perform any background
   processing or buffering, write will always happen only after a read was
   initiated.

   Pipe has a peculiar interface, taking a handle and returning a new handle
   on [read], [write] and [write_choice] operations. For writing, the new
   handle should be used for all of the future operations. For reading, the
   using old handle will result in the same value being returned.
   This is unlike other pipes, where the same pipe handle is used for all
   operations and there is no new handle is returned.
   
   Pipe is thread-safe for [iter] and [read] operations. Note that if new handle
   is not shared among parallel threads, both threads will see the same
   sequence of values read.
   
   Pipe is also thread-safe for [write] and [write_choice] operations.
   Once writing or closing is done on a handle, it will throw an exception if
   the same handle is used again by another thread. *)

open Async_kernel

type 'data_in_pipe writer_t

type 'data_in_pipe reader_t

(** Exception raised when writing or closing is attempted on a closed pipe. *)
exception Pipe_closed

(** Exception raised when writing or closing is attempted on a pipe that was
    already used by [write_choice] and the write was completed
    (or in a [write] operation). *)
exception Pipe_handle_used

(** Closes the pipe handle. If the same handle was already used by [write_choice]
    and the write was completed (or in a [write] operation), [close] operation
    will result in [Pipe_handle_used] exception. If the pipe is closed, it will
    result in [Pipe_closed] exception. *)
val close : 'a writer_t -> unit

(** Creates a new pipe. *)
val create : unit -> 'data reader_t * 'data writer_t

(** Creates a new pipe that is already closed. *)
val create_closed : unit -> 'data reader_t

(** Returns a choice that writes data to the pipe if a read
    operation arrived and was chosen for the [Deferred.choose]
    operation the choice is used for.

    Once the read operation started, the write will happen
    non-blockingly. There are no additional blocking operations
    performed by the pipe.

    Callback [on_chosen] is given a new pipe handle which can be used
    for future writes. If the choice is not selected, the write will
    not happen and the callback won't be executed. It is safe to call
    [write_choice] multiple times for the same pipe.
    
    A call to [write_choice] after the pipe is closed will result in
    [Pipe_closed] exception.
    
    Handle passed to [on_chosen] must be used for future writes.
    If the same handle is used multiple times, it will result in
    [Pipe_handle_used] exception. *)
val write_choice :
     on_chosen:('data writer_t -> 'b)
  -> 'data writer_t
  -> 'data
  -> 'b Deferred.Choice.t

(** Write data to the pipe.

    Returns a new pipe handle that can be used for future writes.
    
    If the pipe is closed, the write will result in [Pipe_closed] exception.
    
    If the handle was used before for a write operation that completed,
    it will result in [Pipe_handle_used] exception. *)
val write : 'data writer_t -> 'data -> 'data writer_t Deferred.t

(** Reads data from the pipe.

    Returns [`Eof] if the pipe is closed.
    
    If the read was successful, returns the data along with a new pipe
    handle that can be used for future reads.
    
    Calling [read] on the same handle multiple times will return the same
    result and will not make the pipe progress on future writes. *)
val read : 'data reader_t -> [ `Eof | `Ok of 'data * 'data reader_t ] Deferred.t

(** Iterates over the pipe. The returned deferred is determined when the pipe
    is closed and callback is executed on every value written to the pipe.
    
    Calling [iter] on the same handle multiple times will execute the callback
    on the same series of values. *)
val iter : 'data reader_t -> f:('data -> unit Deferred.t) -> unit Deferred.t
