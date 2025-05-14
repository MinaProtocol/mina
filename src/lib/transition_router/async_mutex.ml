open Async_kernel

type t = Mutex.t

let rec lock_async (t : t) : unit Deferred.t =
  if Mutex.try_lock t then Deferred.unit
  else
    let%bind.Deferred () = Async_kernel_scheduler.yield () in
    lock_async t

let lock_sync = Mutex.lock

[%%define_locally Mutex.(create, unlock, try_lock)]
