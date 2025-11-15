open Core
open Core_bench

(* Instantiate database implementations *)
module Rocksdb_db = Rocksdb_impl.Make ()

module Lmdb_db = Lmdb_impl.Make ()

module Single_file_db = Single_file_impl.Make ()

module Multi_file_db = Multi_file_impl.Make ()

let init_db (type db) (module Db : Common.Database with type t = db) name =
  (* Initialization: create DB and warmup *)
  let dir = Common.make_temp_dir (Printf.sprintf "db_bench_%s" name) in
  let db = Db.create dir in
  Common.Ops.warmup (module Db) db ;
  eprintf "Warmup complete for %s\n" name ;
  db

(* Write benchmark - warmup happens once, then test runs repeatedly *)
let make_write_bench (type db) (module Db : Common.Database with type t = db)
    (db : db) =
  let oldest_block_ref = ref 0 in
  fun () ->
    let oldest_block = !oldest_block_ref in
    let new_block = oldest_block + Common.warmup_blocks in
    Common.Ops.steady_state_op (module Db) db ~oldest_block ~new_block ;
    incr oldest_block_ref

(* Read benchmark - warmup happens once, then test runs repeatedly *)
let make_read_bench (type db) (module Db : Common.Database with type t = db)
    (db : db) =
  let min_key = 0 in
  let max_key = (Common.warmup_blocks * Common.keys_per_block) - 1 in
  fun () -> Common.Ops.random_read (module Db) db ~min_key ~max_key

let test ~name (type db) (module Db : Common.Database with type t = db)
    (f : (module Common.Database with type t = db) -> db -> unit -> unit) =
  Bench.Test.create_with_initialization ~name (fun `init ->
      init_db (module Db) name |> f (module Db) )

(* Create all benchmarks *)
let all_benchmarks () =
  [ test ~name:"rocksdb_write" (module Rocksdb_db) make_write_bench
  ; test ~name:"rocksdb_read" (module Rocksdb_db) make_read_bench
  ; test ~name:"lmdb_write" (module Lmdb_db) make_write_bench
  ; test ~name:"lmdb_read" (module Lmdb_db) make_read_bench
  ; test ~name:"single_file_write" (module Single_file_db) make_write_bench
  ; test ~name:"single_file_read" (module Single_file_db) make_read_bench
  ; test ~name:"multi_file_write" (module Multi_file_db) make_write_bench
  ; test ~name:"multi_file_read" (module Multi_file_db) make_read_bench
  ]

(* Main entry point *)
let () =
  (* Print configuration *)
  Printf.printf "Database Benchmark Configuration:\n" ;
  Printf.printf "  Keys per block: %d\n" Common.keys_per_block ;
  Printf.printf "  Value size: %d bytes (%.1f KB)\n" Common.value_size
    (Float.of_int Common.value_size /. 1024.) ;
  Printf.printf "  Warmup blocks: %d\n" Common.warmup_blocks ;
  Printf.printf "  Warmup keys: %d\n"
    (Common.warmup_blocks * Common.keys_per_block) ;
  Printf.printf "\n" ;

  (* Run benchmarks *)
  Command.run (Bench.make_command (all_benchmarks ()))
