open Async_kernel

type ('data_in_pipe, 'pipe_kind, 'write_return) t

val create :
     ?warn_on_drop:bool
  -> name:string
  -> ('data_in_pipe, 'pipe_kind, 'write_return) Strict_pipe.type_
  -> ('data_in_pipe, 'pipe_kind, 'write_return) t

val write :
  ('data_in_pipe, 'pipe_kind, 'write_return) t -> 'data_in_pipe -> 'write_return

val request_reader :
     reader_name:string
  -> ('data_in_pipe, 'pipe_kind, 'write_return) t
  -> 'data_in_pipe Strict_pipe.Reader.t Deferred.t

val kill : ('data_in_pipe, 'pipe_kind, 'write_return) t -> unit
