open Core
open Async_kernel
module Unix_sync = Unix
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
   Async_kernel has a hardcoded limit of 2000ms this is a expected invariant,
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

(* NOTE: Using a mmaped version to read input:
   - Iterating with In_channel.input_char is painfully slow
   - In_channel.read_all seems to cause OOM
*)
let mmap_input_to_bin_prot_buf (name : string) =
  let open Unix_sync in
  let open Bigarray in
  let fd = openfile name ~mode:[ O_RDONLY ] in
  let file_size =
    (fstat fd).st_size |> Int.of_int64
    |> Option.value_exn ?message:(Some "file size won't fit in `int`")
  in
  let buf =
    map_file fd char c_layout ~shared:false [| file_size |]
    |> array1_of_genarray
  in
  (fd, buf)

let testcase_persistent_frontier_bottleneck logger dump_path snapshot_name () =
  let prepare_worker =
    wrap_as_deferred (fun () ->
        let working_directory = dump_path ^/ snapshot_name in
        [%log info] "Current working directory: %s" working_directory ;
        [%log info] "Deserializing diff list from input.bin" ;
        let bin_class =
          Bin_prot.Type_class.bin_list Diff.Lite.Stable.Latest.bin_t
        in
        [%log info] "> Creating mmap for diff list" ;
        let fd, buf =
          mmap_input_to_bin_prot_buf (working_directory ^/ "input.bin")
        in
        [%log info] "> Deserialize in memory diff list" ;
        let input_deserialized = bin_class.reader.read ~pos_ref:(ref 0) buf in
        [%log info] "> Convert list from Diff.Lite.{Stable.V1.t -> E.t}" ;
        let input =
          List.map ~f:Diff.Lite.write_all_proofs_to_disk input_deserialized
        in

        [%log info] "Loading database" ;
        let db = Database.create ~logger ~directory:working_directory in
        let worker =
          Worker.create { db; logger; dequeue_snarked_ledger = const () }
        in
        (worker, fd, db, input) )
  in
  prepare_worker
  >>= fun (worker, fd, db, input) ->
  [%log info] "Dispatching the worker" ;
  Worker.dispatch worker input
  >>| fun _ ->
  [%log info] "Worker task done" ;
  Unix_sync.close fd ;
  Database.close db

let testcase_deserialize_root_hash logger dump_path snapshot_name () =
  let deserialize_root_hash logger dump_path snapshot_name () =
    let working_directory = dump_path ^/ snapshot_name in
    [%log info]
      "Start `deserializae_root_value_from_db`, Current working directory: %s"
      working_directory ;
    [%log info] "Loading database" ;
    (* NOTE:
       We expect the DB to not have `root_hash` and `root_common` at this moment
    *)
    let db = Database.create ~logger ~directory:working_directory in
    [%log info] "Querying root hash from database and attempt to deserialize it" ;
    ( match Database.get_root_hash db with
    | Ok hash ->
        [%log info] "Got hash %s" (Pasta_bindings.Fp.to_string hash)
    | Error _ ->
        [%log info] "No root hash found" ) ;
    [%log info] "Done deserialize_root_hash" ;
    Database.close db
  in

  wrap_as_deferred (deserialize_root_hash logger dump_path snapshot_name)

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
      , [ test_case "1-1 reproduce of persistent frontier perform" `Quick
            (is_long_job
               (testcase_persistent_frontier_bottleneck logger dump_path
                  "2025_02-13-07-54-53" )
               true )
        ] )
    ; ( "Deserialization perf test"
      , [ test_case "derserialize root hash" `Quick
            (is_long_job
               (testcase_deserialize_root_hash logger dump_path
                  "2025_02-13-07-54-53" )
               false )
        ] )
    ]
