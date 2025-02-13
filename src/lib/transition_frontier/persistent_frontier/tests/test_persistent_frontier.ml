open Async_kernel
open Persistent_frontier

(* NOTE:
    Here's the implementation of "long_jobs_with_context" found in Async_kernel's
    source code:

   let long_jobs_with_context t =
     Stream.create (fun tail ->
       run_every_cycle_start t ~f:(fun () ->
           List.iter t.long_jobs_last_cycle ~f:(fun job -> Tail.extend tail job) ; t.long_jobs_last_cycle <- [] ))

   Issue with iterating on the jobs to check if there's a long jobs is that this is blocking.
   So instead a function that register a hook is designed as below.

   Here's the order of relevant events in `run_cycle` of sync_kernel's scheduler
   1. `run_every_cycle_start` events triggered
   2. a job is runned
   3. if the job takes too long, it's thrown into `long_jobs_last_cycle`
   4. `run_every_cycle_end` events triggered
*)

exception LongJobDetected of Execution_context.t * Time_ns.Span.t

let fail_on_long_async_jobs () =
  let open Async_kernel_scheduler in
  let raise_long_job (context, span) =
    raise (LongJobDetected (context, span))
  in
  Expert.run_every_cycle_end (fun _ ->
      let t = t () in
      List.iter t.long_jobs_last_cycle ~f:raise_long_job )

let sleep_async seconds = Deferred.create (fun _ -> Core.Unix.sleep seconds)

(* WARN:
   Async_Kernel has a hardcoded limit of 2000ms this is a expected invariant,
   as that number is private and hardcoded:

   if Float.(Time_ns.Span.to_ms this_job_time >= 2000.) then scheduler.long_jobs_last_cycle <- (execution_context, this_job_time) :: scheduler.long_jobs_last_cycle;
*)
let long_job_limit_seconds = 2

let is_long_job create_job expected () =
  let answer =
    try
      Async.Thread_safe.block_on_async_exn create_job ;
      false
    with LongJobDetected _ -> true
  in
  Alcotest.(check bool) "is long job" expected answer

let long_job () = sleep_async (long_job_limit_seconds + 1)

let short_job () = return ()

let worker_job (worker : Worker.t) input () = Worker.dispatch worker input

(* Define the test suite *)
let () =
  fail_on_long_async_jobs () ;
  let open Alcotest in
  run "Persistent Frontier"
    [ ( "Catch long async jobs"
      , [ test_case "short jobs won't be catched" `Quick
            (is_long_job short_job false)
        ; test_case "long jobs will be catched" `Quick
            (is_long_job long_job true)
          (*; test_case "worker job that's too slow will be catched" `Quick*)
          (*    (is_long_job (worker_job worker input) true)*)
        ] )
    ]
