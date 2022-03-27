val register_handler :
  logger:Logger.t -> description:string -> (unit -> unit) -> unit

val register_async_shutdown_handler :
     logger:Logger.t
  -> description:string
  -> (unit -> unit Async_kernel.Deferred.t)
  -> unit
