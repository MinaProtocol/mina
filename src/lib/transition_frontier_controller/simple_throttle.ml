open Async_kernel

type t =
  { max_jobs : int; queue : unit Ivar.t Queue.t; mutable active_jobs : int }

let allocate t =
  if t.active_jobs < t.max_jobs then (
    t.active_jobs <- t.active_jobs + 1 ;
    `Start_immediately )
  else
    let ivar = Ivar.create () in
    Queue.add ivar t.queue ; `Wait ivar

let rec deallocate t =
  assert (t.active_jobs > 0) ;
  match Queue.take_opt t.queue with
  | Some ivar when Async_kernel.Ivar.is_full ivar ->
      deallocate t
  | Some ivar ->
      Ivar.fill_if_empty ivar ()
  | None ->
      t.active_jobs <- t.active_jobs - 1

let create max_jobs = { max_jobs; queue = Queue.create (); active_jobs = 0 }
