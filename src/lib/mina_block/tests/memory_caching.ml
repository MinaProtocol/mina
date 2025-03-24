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

let test_mem ~f ~n proofs_file =
  gc_compact () ;
  let init_heap = heap_used () in
  let%bind proofs =
    Deferred.List.init n ~f:(fun _ -> read_proofs proofs_file >>| List.map ~f)
    >>| List.concat
  in
  gc_compact () ;
  let growth = heap_used () - init_heap in
  let%map () = after (Time.Span.of_sec 0.1) in
  ignore proofs ; growth

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
  let n = 10 in
  let%bind growth = test_mem ~n ~f:Ledger_proof.underlying_proof proofs_file in
  let f p = (Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db p).proof in
  let%map growth_cached = test_mem ~n ~f proofs_file in
  printf "Growth without cache: %d\n" growth ;
  printf "Growth with cache: %d\n" growth_cached ;
  assert (growth_cached * 50 < growth)

(** Test reads precomputed json file, extracts ledger proofs and writes them to disk.
  Then it repeatedly reads the file 10x times and measures memory growth with both using memory caching and not.
  Test asserts that memory used for storing proofs is 50x smaller than when not using memory caching.
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
    Staged_ledger_diff.completed_works precomputed.staged_ledger_diff
    |> List.concat_map
         ~f:(Fn.compose One_or_two.to_list Transaction_snark_work.proofs)
  in
  printf "Read %d ledger proofs\n" (List.length ledger_proofs) ;
  Thread_safe.block_on_async_exn (fun () ->
      File_system.with_temp_dir "test_mem" ~f:(test_do ledger_proofs) )
