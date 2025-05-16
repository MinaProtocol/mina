open Async_kernel

type t = Mutex.t

let rec lock_async (t : t) : unit Deferred.t =
  if Mutex.try_lock t then Deferred.unit
  else
    let%bind.Deferred () = Async_kernel_scheduler.yield () in
    lock_async t

let lock_sync = Mutex.lock

let repr (t : t) = Printf.sprintf "Async_mutex.%x" (Obj.magic (Obj.repr t))

[%%define_locally Mutex.(create, unlock, try_lock)]
