open Core
open Async

(* RocksDB scanning function that replaces ldb command *)
let scan_rocksdb_to_and_dump_hex_kvs db_path output_file =
  let db = Rocksdb.Database.create db_path in
  let kv_pairs = Rocksdb.Database.to_alist db in
  let%bind writer = Writer.open_file output_file in
  List.iter kv_pairs ~f:(fun (key, value) ->
      let key_hex =
        Bigstring.to_string key
        |> String.concat_map ~f:(fun c -> sprintf "%02x" (Char.to_int c))
      in
      let value_hex =
        Bigstring.to_string value
        |> String.concat_map ~f:(fun c -> sprintf "%02x" (Char.to_int c))
      in
      Writer.writef writer "%s : %s\n" key_hex value_hex ) ;
  let%map () = Writer.close writer in
  Rocksdb.Database.close db

let root_command =
  Command.async ~summary:"Scan RocksDB and dump key-value pairs as hex strings"
    (let%map_open.Command db_path =
       flag "--db-path" (required string)
         ~doc:"PATH address of Rocksdb database"
     and output_file =
       flag "--output-file" (required string)
         ~doc:"PATH of file to dump scanning result"
     in
     fun () ->
       let logger = Logger.create () in
       [%log info] "Scanning RocksDB at %s to output file %s" db_path
         output_file ;
       let%map () = scan_rocksdb_to_and_dump_hex_kvs db_path output_file in
       [%log info] "Successfully dumped data to %s" output_file )

let () = Command.run root_command
