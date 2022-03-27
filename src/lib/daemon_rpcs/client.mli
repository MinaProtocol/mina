val print_rpc_error : Core.Error.t -> unit

val dispatch :
     ('a, 'b) Async.Rpc.Rpc.t
  -> 'a
  -> Core.Host_and_port.t
  -> 'b Async.Deferred.Or_error.t

val dispatch_join_errors :
     ('a, 'b Core.Or_error.t) Async.Rpc.Rpc.t
  -> 'a
  -> Core.Host_and_port.t
  -> 'b Core.Or_error.t Async.Deferred.t

val dispatch_with_message :
     ('c, 'a) Async.Rpc.Rpc.t
  -> 'c
  -> Core.Host_and_port.t
  -> success:('b -> string)
  -> error:(Core_kernel__.Error.t -> string)
  -> join_error:('a Core.Or_error.t -> 'b Core.Or_error.t)
  -> unit Async_kernel__Deferred.t

val dispatch_pretty_message :
     (module Cli_lib.Render.Printable_intf with type t = 't)
  -> ?json:bool
  -> join_error:('a Core.Or_error.t -> 't Core.Or_error.t)
  -> error_ctx:string
  -> ('b, 'a) Async.Rpc.Rpc.t
  -> 'b
  -> Core.Host_and_port.t
  -> Base.unit Async_kernel__Deferred.t
