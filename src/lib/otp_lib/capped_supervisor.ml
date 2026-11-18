open Core_kernel
open Async_kernel
open Pipe_lib
open Strict_pipe

type 'data t =
  { job_writer : ('data, crash buffered, unit) Writer.t
  ; f : 'data -> unit Deferred.t
  ; mutable pending_jobs : 'data list
  ; mutable release : ('data -> unit) option
        (* Set once stopped: what to do with each job that won't be run. *)
  }

let create ?(buffer_capacity = 30) ~job_capacity f =
  let job_reader, job_writer =
    Strict_pipe.create (Buffered (`Capacity buffer_capacity, `Overflow Crash))
  in
  let t = { job_writer; f; pending_jobs = []; release = None } in
  let active_jobs = ref 0 in
  let job_finished_bvar = Bvar.create () in
  let run_job job =
    incr active_jobs ;
    don't_wait_for
      (let%map () = f job in
       decr active_jobs ;
       Bvar.broadcast job_finished_bvar () )
  in
  let rec start_jobs n =
    if n <= 0 || Option.is_some t.release then ()
    else
      match t.pending_jobs with
      | [] ->
          ()
      | h :: rest ->
          t.pending_jobs <- rest ;
          run_job h ;
          start_jobs (n - 1)
  in
  let rec process_pending_jobs () =
    let%bind () = Bvar.wait job_finished_bvar in
    start_jobs (job_capacity - !active_jobs) ;
    process_pending_jobs ()
  in
  don't_wait_for (process_pending_jobs ()) ;
  don't_wait_for
    (Reader.iter_without_pushback job_reader ~f:(fun job ->
         match t.release with
         | Some release ->
             release job
         | None ->
             if !active_jobs < job_capacity then run_job job
             else t.pending_jobs <- t.pending_jobs @ [ job ] ) ) ;
  t

let dispatch t data = Writer.write t.job_writer data

let stop t ~release =
  if Option.is_none t.release then (
    t.release <- Some release ;
    let pending_jobs = t.pending_jobs in
    t.pending_jobs <- [] ;
    List.iter pending_jobs ~f:release )

let%test_module "Capped_supervisor" =
  ( module struct
    (* A supervisor running one job at a time, whose jobs record that they ran
       and then wait for [gate]; and the jobs it releases. *)
    let supervisor () =
      let ran = ref [] and released = ref [] and gate = Ivar.create () in
      let t =
        create ~job_capacity:1 (fun job ->
            ran := job :: !ran ;
            Ivar.read gate )
      in
      (t, ran, released, gate)

    let settle () = Async_kernel_scheduler.yield_until_no_jobs_remain ()

    let%test_unit "Stopping releases the jobs not yet started" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let t, ran, released, gate = supervisor () in
          List.iter [ 1; 2; 3 ] ~f:(dispatch t) ;
          let%bind () = settle () in
          stop t ~release:(fun job -> released := job :: !released) ;
          Ivar.fill gate () ;
          let%map () = settle () in
          [%test_eq: int list] (List.rev !ran) [ 1 ] ;
          [%test_eq: int list] (List.rev !released) [ 2; 3 ] )

    let%test_unit "Jobs still being dispatched when stopped are released" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let t, ran, released, gate = supervisor () in
          dispatch t 1 ;
          stop t ~release:(fun job -> released := job :: !released) ;
          Ivar.fill gate () ;
          let%map () = settle () in
          [%test_eq: int list] !ran [] ;
          [%test_eq: int list] !released [ 1 ] )

    let%test_unit "Stopping twice keeps the first release" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let t, ran, released, gate = supervisor () in
          stop t ~release:(fun job -> released := job :: !released) ;
          stop t ~release:(fun _ -> failwith "released by the second stop") ;
          dispatch t 1 ;
          Ivar.fill gate () ;
          let%map () = settle () in
          [%test_eq: int list] !ran [] ;
          [%test_eq: int list] !released [ 1 ] )
  end )
