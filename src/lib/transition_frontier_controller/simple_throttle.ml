open Async_kernel

type t =
  { max_jobs : int
  ; low_queue : unit Ivar.t Queue.t
  ; med_queue : unit Ivar.t Queue.t
  ; high_queue : unit Ivar.t Queue.t
  ; mutable active_jobs : int
  }

let allocate ?(priority = `Medium) t =
  if t.active_jobs < t.max_jobs then (
    t.active_jobs <- t.active_jobs + 1 ;
    `Start_immediately )
  else
    let ivar = Ivar.create () in
    let q =
      match priority with
      | `High ->
          t.high_queue
      | `Medium ->
          t.med_queue
      | `Low ->
          t.low_queue
    in
    Queue.add ivar q ; `Wait ivar

let take_opt t =
  Core_kernel.List.find_map
    [ t.high_queue; t.med_queue; t.low_queue ]
    ~f:Queue.take_opt

let rec deallocate t =
  assert (t.active_jobs > 0) ;
  match take_opt t with
  | Some ivar when Async_kernel.Ivar.is_full ivar ->
      deallocate t
  | Some ivar ->
      Ivar.fill_if_empty ivar ()
  | None ->
      t.active_jobs <- t.active_jobs - 1

let create max_jobs =
  { max_jobs
  ; low_queue = Queue.create ()
  ; med_queue = Queue.create ()
  ; high_queue = Queue.create ()
  ; active_jobs = 0
  }
