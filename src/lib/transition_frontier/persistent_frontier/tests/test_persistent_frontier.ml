open Core
open Async_kernel
open Persistent_frontier
open Frontier_base

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

(* NOTE: Using a mmaped version to read input:
   - Iterating with In_channel.input_char is painfully slow
   - In_channel.read_all seems to cause OOM
*)
let mmap_input_to_bin_prot_buf (name : string) =
  let open Unix in
  let open Bigarray in
  let fd = Unix.openfile name ~mode:[ O_RDONLY ] in
  let file_size =
    (fstat fd).st_size |> Int.of_int64
    |> Option.value_exn ?message:(Some "file size won't fit in `int`")
  in
  let buf =
    Unix.map_file fd char c_layout ~shared:false [| file_size |]
    |> Bigarray.array1_of_genarray
  in
  (fd, buf)

let persistent_frontier_worker_long_job logger dump_path snapshot_name =
  let working_directory = dump_path ^/ snapshot_name in
  [%log info] "Current working directory: %s" working_directory ;
  [%log info] "Deserializing diff list from input.bin" ;
  let bin_class = Bin_prot.Type_class.bin_list Diff.Lite.Stable.Latest.bin_t in
  let fd, buf =
    working_directory ^/ "input.bin" |> mmap_input_to_bin_prot_buf
  in
  let input =
    buf
    |> bin_class.reader.read ~pos_ref:(ref 0)
    |> List.map ~f:Diff.Lite.write_all_proofs_to_disk
  in
  [%log info] "Loading database" ;
  let db = Database.create ~logger ~directory:working_directory in
  let worker =
    Worker.create { db; logger; dequeue_snarked_ledger = const () }
  in
  [%log info] "Dispatching the worker" ;
  Worker.dispatch worker input
  >>| fun () ->
  Unix.close fd ;
  [%log info] "Worker task done"

(* TODO: fix data retrival so it works on CI *)
let dump_path () = Sys.getenv_exn "TEST_DUMP_PERSISTENT_FRONTIER_SYNC"

let test_case_2025_02_13 logger () =
  persistent_frontier_worker_long_job logger (dump_path ())
    "2025_02-13-07-54-53"

let () =
  fail_on_long_async_jobs () ;
  let logger = Logger.create () in
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
            (is_long_job (test_case_2025_02_13 logger) true)
        ] )
    ]
