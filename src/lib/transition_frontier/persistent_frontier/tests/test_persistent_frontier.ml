open Core
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
  let hook () =
    match (t ()).long_jobs_last_cycle with
    | (context, span) :: _ ->
        raise (LongJobDetected (context, span))
    | _ ->
        ()
  in
  Expert.run_every_cycle_end hook

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

let wrap_as_deferred f = Deferred.create (fun ivar -> Ivar.fill ivar (f ()))

let deserializae_root_value_from_db logger dump_path snapshot_name () =
  let working_directory = dump_path ^/ snapshot_name in
  [%log info]
    "Start `deserializae_root_value_from_db`, Current working directory: %s"
    working_directory ;
  [%log info] "Loading database" ;
  let db = Database.create ~logger ~directory:working_directory in
  [%log info] "Querying root from database and attempt to deserialize it" ;
  let root = Database.get_root db in
  ( match root with
  | Ok _ ->
      [%log info] "Successfully found the root"
  | Error _ ->
      [%log info] "No root found" ) ;
  [%log info] "Done `deserializae_root_value_from_db`" ;
  Database.close db

let testcase_deserialize logger dump_path snapshot_name () =
  wrap_as_deferred
    (deserializae_root_value_from_db logger dump_path snapshot_name)

let () =
  fail_on_long_async_jobs () ;
  let logger = Logger.create () in
  let dump_path = Sys.getenv_exn "TEST_DUMP_PERSISTENT_FRONTIER_SYNC" in
  let open Alcotest in
  run "Persistent Frontier"
    [ ( "Catch long async jobs"
      , [ test_case "short jobs won't be catched" `Quick
            (is_long_job short_job false)
        ; test_case "long jobs will be catched" `Quick
            (is_long_job long_job true)
        ] )
    ; ( "Reproduce persistent frontier bottleneck"
      , [ test_case "testcase 2025_02-13-07-54-53" `Quick
            (is_long_job
               (testcase_deserialize logger dump_path "2025_02-13-07-54-53")
               true )
        ] )
    ]
