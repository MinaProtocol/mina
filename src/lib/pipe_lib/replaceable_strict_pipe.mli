open Async_kernel

(** the type for a replaceable strict pipe *)
type ('data_in_pipe, 'pipe_kind, 'write_return) t

(** [create ?warn_on_drop ~name type] creates a replaceable strict pipe
    designated ~name. Warning on drop behavior depends on ?warn_on_drop, and it
    has underlying pipe of type `type`. *)
val create :
     ?warn_on_drop:bool
  -> name:string
  -> ('data_in_pipe, 'pipe_kind, 'write_return) Strict_pipe.type_
  -> ('data_in_pipe, 'pipe_kind, 'write_return) t

(** [write t data] writes to a replaceable strict pipe, it would return value
    designated by the strict pipe type. All ownership is managed inside this
    data structure so no direct access to long live writer is provided. *)
val write :
  ('data_in_pipe, 'pipe_kind, 'write_return) t -> 'data_in_pipe -> 'write_return

(** [request_reader ~reader_name t] requests replaceable to prepare a new pipe,
    replacing the old pipe, and returns the reader. All ownership is managed
    inside this data structure so no writer is provided. *)
val request_reader :
     reader_name:string
  -> ('data_in_pipe, 'pipe_kind, 'write_return) t
  -> 'data_in_pipe Strict_pipe.Reader.t Deferred.t

(** [kill t] kills a replaceable strict pipe, it will close all related writer in
    itself. *)
val kill : ('data_in_pipe, 'pipe_kind, 'write_return) t -> unit
