(** Test for memory caching mechanism.
    Relies on precompted block file.
    TODO Consider moving elsewhere.
*)

open Core_kernel
open Async

module Ledger_proof_list = struct
  type t = Ledger_proof.Stable.V2.t list [@@deriving bin_io_unversioned]
end

let read_proofs proofs_file =
  let f reader =
    Reader.read_bin_prot reader Ledger_proof_list.bin_reader_t
    >>| function `Ok t -> t | `Eof -> failwith "eof"
  in
  Reader.with_file proofs_file ~f

let heap_used () = (Gc.stat ()).heap_words

let gc_compact = Gc.compact

(** Read the process RSS (Resident Set Size) in KB from /proc/self/status.
    Returns the current memory usage including memory-mapped files (like LMDB). *)
let process_memory_kb () =
  try
    let status_file = "/proc/self/status" in
    let lines = In_channel.read_lines status_file in
    let vmrss_line =
      List.find_exn lines ~f:(String.is_prefix ~prefix:"VmRSS:")
    in
    (* Line format: "VmRSS:    12345 kB" *)
    let parts = String.split vmrss_line ~on:' ' |> List.filter ~f:(fun s -> not (String.is_empty s)) in
    let kb_str = List.nth_exn parts 1 in
    Int.of_string kb_str
  with
  | _ ->
      (* If /proc/self/status doesn't exist (non-Linux), return 0 *)
      0

let test_mem ~f ~n proofs_file =
  (* gc_compact () ; *)
  let init_heap = heap_used () in
  let init_rss_kb = process_memory_kb () in
  let%bind proofs =
    Deferred.List.init n ~f:(fun _ -> read_proofs proofs_file >>| List.map ~f)
    >>| List.concat
  in
  (* gc_compact () ; *)
  let heap_growth = heap_used () - init_heap in
  let rss_growth_kb = process_memory_kb () - init_rss_kb in
  let%map () = after (Time.Span.of_sec 0.1) in
  ignore proofs ; (heap_growth, rss_growth_kb)

let test_do ledger_proofs tmp_dir =
  let%bind proof_cache_db =
    Proof_cache_tag.create_db ~logger:(Logger.null ()) tmp_dir
    >>| function
    | Ok a -> a | Error _ -> failwith "failed to create proof cache db"
  in
  let%bind proofs_file, fd = Unix.mkstemp "_proofs.binio" in
  let%bind () = Fd.close fd in
  let%bind () =
    Writer.save_bin_prot proofs_file Ledger_proof_list.bin_writer_t
      ledger_proofs
  in
  let n = 1000 in
  gc_compact () ;
  let%bind heap_growth1, rss_growth1 = test_mem ~n ~f:Ledger_proof.underlying_proof proofs_file in
  gc_compact () ;
  let f p = (Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db p).proof in
  let%map heap_growth2, rss_growth2 = test_mem ~n ~f proofs_file in
  printf "Growth without cache: heap=%d words, RSS=%d KB\n" heap_growth1 rss_growth1 ;
  printf "Growth with cache: heap=%d words, RSS=%d KB\n" heap_growth2 rss_growth2 ;
  printf "Heap ratio: %.2fx, RSS ratio: %.2fx\n"
    (Float.of_int heap_growth1 /. Float.of_int (max 1 heap_growth2))
    (Float.of_int rss_growth1 /. Float.of_int (max 1 rss_growth2)) ;
  (* Assert that cached version uses significantly less OCaml heap *)
  assert (heap_growth2 * 50 < heap_growth1) ;
  (* Check if RSS also shows improvement or at least doesn't grow excessively *)
  if rss_growth2 > rss_growth1 * 2 then
    printf "WARNING: RSS with cache (%d KB) is more than 2x RSS without cache (%d KB)\n"
      rss_growth2 rss_growth1

(** Test reads precomputed json file, extracts ledger proofs and writes them to disk.
  Then it repeatedly reads the file 10x times and measures memory growth with both using memory caching and not.
  Measures both:
  - OCaml heap words (via Gc.stat)
  - Process RSS (Resident Set Size) via /proc/self/status to capture LMDB memory-mapped allocations
  Test asserts that OCaml heap used for storing proofs is 50x smaller when using memory caching.
*)
let test large_precomputed_json_file : unit =
  let json =
    Yojson.Safe.from_string (In_channel.read_all large_precomputed_json_file)
  in
  let precomputed =
    match Mina_block.Precomputed.of_yojson json with
    | Ok json ->
        json
    | Error err ->
        failwith err
  in
  let ledger_proofs =
    Staged_ledger_diff.Stable.Latest.completed_works
      precomputed.staged_ledger_diff
    |> List.concat_map
         ~f:
           (Fn.compose One_or_two.to_list
              Transaction_snark_work.Stable.Latest.proofs )
  in
  printf "Read %d ledger proofs\n" (List.length ledger_proofs) ;
  Thread_safe.block_on_async_exn (fun () ->
      Mina_stdlib_unix.File_system.with_temp_dir "test_mem"
        ~f:(test_do ledger_proofs) )
