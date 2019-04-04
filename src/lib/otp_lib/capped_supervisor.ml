open Core_kernel
open Async_kernel
open Pipe_lib
open Strict_pipe

type 'data t =
  { job_writer: ('data, crash buffered, unit) Writer.t
  ; f: 'data -> unit Deferred.t }

let create ?(buffer_capacity = 30) ~job_capacity f =
  let job_reader, job_writer =
    Strict_pipe.create (Buffered (`Capacity buffer_capacity, `Overflow Crash))
  in
  let active_jobs = ref 0 in
  let pending_jobs = ref [] in
  let job_finished_bvar = Bvar.create () in
  let run_job job =
    incr active_jobs ;
    don't_wait_for
      (let%map () = f job in
       decr active_jobs ;
       Bvar.broadcast job_finished_bvar ())
  in
  let rec start_jobs n =
    if n <= 0 then ()
    else
      match !pending_jobs with
      | [] -> ()
      | h :: t ->
          pending_jobs := t ;
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
         if !active_jobs < job_capacity then run_job job
         else pending_jobs := !pending_jobs @ [job] )) ;
  {job_writer; f}

let dispatch t data = Writer.write t.job_writer data
