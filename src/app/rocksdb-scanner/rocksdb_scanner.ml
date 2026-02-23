open Core

let dump_cmd =
  Command.basic ~summary:"Scan RocksDB and dump KV pairs as hex"
    (let%map_open.Command db_path =
       flag "--db-path" (required string) ~doc:"PATH to source RocksDB"
     and output_file =
       flag "--output-file" (required string) ~doc:"PATH to output hex file"
     in
     Rocksdb.Scan.dump ~db_path ~text_file:output_file )

let restore_cmd =
  Command.basic ~summary:"Restore RocksDB from a hex-encoded file"
    (let%map_open.Command input_file =
       flag "--input-file" (required string) ~doc:"PATH to hex dump"
     and db_path =
       flag "--db-path" (required string) ~doc:"PATH to target RocksDB"
     in
     Rocksdb.Scan.restore ~db_path ~text_file:input_file )

let main =
  Command.group ~summary:"RocksDB Hex Dump/Restore Tool"
    [ ("dump", dump_cmd); ("restore", restore_cmd) ]

let () = Command.run main
