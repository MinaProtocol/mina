(** Operations concerning the state directory. *)

open Core

val check_and_set_lockfile :
     logger:Logger__Impl.Stable.V1.t
  -> state_dir:string
  -> unit Async_kernel__Types.Deferred.t

val export_logs_to_tar :
     ?basename:string
  -> state_dir:string
  -> (string, Error.t) result Async.Deferred.t
