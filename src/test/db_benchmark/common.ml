open Core

(* Configuration constants - configurable via environment variables *)
let keys_per_block =
  Sys.getenv "KEYS_PER_BLOCK" |> Option.value_map ~default:125 ~f:int_of_string

let value_size =
  Sys.getenv "VALUE_SIZE"
  |> Option.value_map ~default:(128 * 1024) ~f:int_of_string
(* 128 KB *)

let warmup_blocks =
  Sys.getenv "WARMUP_BLOCKS" |> Option.value_map ~default:800 ~f:int_of_string

(* Fixed seed for reproducibility *)
let random_seed = 42

(* Get key ID from block number and offset within block *)
let key_of_block_offset block_num offset = (block_num * keys_per_block) + offset

(* Get all key IDs for a given block *)
let keys_of_block block_num =
  List.init keys_per_block ~f:(fun offset ->
      key_of_block_offset block_num offset )

(* Generate random data for a value *)
let generate_value () =
  let random_state = Random.State.make [| random_seed |] in
  String.init value_size ~f:(fun _ ->
      Char.of_int_exn (Random.State.int random_state 256) )

(* Cache a single value to avoid regenerating it every time *)
let cached_value = lazy (generate_value ())

(* Get the cached value *)
let get_value () = Lazy.force cached_value

(* Generate random key for read test *)
let random_key_in_range ~min_key ~max_key =
  let random_state = Random.State.make [| random_seed |] in
  min_key + Random.State.int random_state (max_key - min_key + 1)

(* Database interface that all implementations must satisfy *)
module type Database = sig
  type t

  (* Initialize the database at the given path *)
  val create : string -> t

  (* Close/cleanup the database *)
  val close : t -> unit

  (* Write a block of values (sequential keys starting at block_num * keys_per_block) *)
  val set_block : t -> block_num:int -> string list -> unit

  (* Read a single key *)
  val get : t -> key:int -> string option

  (* Delete a block *)
  val remove_block : t -> block_num:int -> unit

  (* Get implementation name for reporting *)
  val name : string
end

(* Operations for benchmarking *)
module Ops = struct
  (* Write a full block of keys *)
  let write_block (type db) (module Db : Database with type t = db) (db : db)
      block_num =
    let value = get_value () in
    (* Create list of identical values for all keys in the block *)
    let values = List.init keys_per_block ~f:(fun _ -> value) in
    Db.set_block db ~block_num values

  (* Delete a full block of keys *)
  let delete_block (type db) (module Db : Database with type t = db) (db : db)
      block_num =
    Db.remove_block db ~block_num

  (* Read a single key *)
  let read_key (type db) (module Db : Database with type t = db) (db : db) key =
    ignore (Db.get db ~key : string option)

  (* Warmup: write initial blocks *)
  let warmup (type db) (module Db : Database with type t = db) (db : db) =
    for block_num = 0 to warmup_blocks - 1 do
      write_block (module Db) db block_num
    done

  (* Steady state operation: remove oldest block and add new one *)
  let steady_state_op (type db) (module Db : Database with type t = db)
      (db : db) ~oldest_block ~new_block =
    delete_block (module Db) db oldest_block ;
    write_block (module Db) db new_block

  (* Random read operation *)
  let random_read (type db) (module Db : Database with type t = db) (db : db)
      ~min_key ~max_key =
    let key = random_key_in_range ~min_key ~max_key in
    read_key (module Db) db key
end

(* Temporary directory management *)
let make_temp_dir prefix =
  let pid = Unix.getpid () |> Pid.to_int in
  let dir_name = Printf.sprintf "%s_%d" prefix pid in
  Unix.mkdir_p dir_name ; dir_name

let cleanup_temp_dir dir =
  match Sys.file_exists dir with
  | `Yes ->
      ignore
        ( Core_unix.system (Printf.sprintf "rm -rf %s" (Filename.quote dir))
          : Core_unix.Exit_or_signal.t )
  | _ ->
      ()
