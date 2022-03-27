val compute_conf_dir :
  Core_kernel__.Import.string option -> Core_kernel__.Import.string

val check_and_set_lockfile :
     logger:Logger.t
  -> Core_kernel__.Import.string
  -> unit Async_kernel__Deferred.t

val get_hw_info : unit -> string list option Async_kernel__Deferred.t

val export_logs_to_tar :
     ?basename:string
  -> conf_dir:Core_kernel__.Import.string
  -> (Core_kernel__.Import.string, Core_kernel__.Error.t) Core_kernel.Result.t
     Async.Deferred.t
