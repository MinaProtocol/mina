val reader : int Pipe_lib.Broadcast_pipe.Reader.t

val writer : int Pipe_lib.Broadcast_pipe.Writer.t

val update : (int -> int) -> unit Async_kernel.Deferred.t

val incr : unit -> unit Async_kernel.Deferred.t

val decr : unit -> unit Async_kernel.Deferred.t
