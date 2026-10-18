type shutdown_tier =
  | FlushPersistentFrontier
  | DestroyConfigAndLedgers
  | ReleaseDaemonLockfile

val register_async_shutdown_handler :
     logger:Logger.t
  -> description:string
  -> tier:shutdown_tier
  -> (unit -> unit Async_kernel.Deferred.t)
  -> unit

module For_testing : sig
  val run_shutdown_handlers : unit -> unit Async_kernel.Deferred.t

  val reset : unit -> unit
end
