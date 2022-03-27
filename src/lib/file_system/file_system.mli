val dir_exists : string -> bool Async_kernel__Deferred.t

val remove_dir : string -> unit Async_kernel__Deferred.t

val rmrf : Core_kernel__.Import.string -> unit

val try_finally :
     f:(unit -> 'a Async.Deferred.t)
  -> finally:(unit -> unit Async.Deferred.t)
  -> 'a Async_kernel__Deferred.t

val with_temp_dir :
  f:(string -> 'a Async.Deferred.t) -> string -> 'a Async_kernel__Deferred.t

val dup_stdout : ?f:(string -> string) -> Async.Process.t -> unit

val dup_stderr : ?f:(string -> string) -> Async.Process.t -> unit

val clear_dir : Core.String.t -> unit Async_kernel__Deferred.t

val create_dir :
  ?clear_if_exists:bool -> Core.String.t -> unit Async_kernel__Deferred.t
