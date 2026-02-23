open Core
open Async

module Hex_util = struct
  (* Converts Bigstring to hex string *)
  let to_hex bs =
    Bigstring.to_string bs
    |> String.concat_map ~f:(fun c -> sprintf "%02x" (Char.to_int c))

  (* Converts hex string to Bigstring *)
  let of_hex hex_str =
    let hex_str = String.strip hex_str in
    let len = String.length hex_str in
    if len % 2 <> 0 then failwithf "Invalid hex string length %d" len () ;
    let bs = Bigstring.create (len / 2) in
    for i = 0 to (len / 2) - 1 do
      let byte_str = String.sub hex_str ~pos:(i * 2) ~len:2 in
      let byte = Int.of_string ("0x" ^ byte_str) in
      Bigstring.set_int8_exn bs ~pos:i byte
    done ;
    bs
end

let dump_cmd =
  Command.async ~summary:"Scan RocksDB and dump KV pairs as hex"
    (let%map_open.Command db_path =
       flag "--db-path" (required string) ~doc:"PATH to source RocksDB"
     and output_file =
       flag "--output-file" (required string) ~doc:"PATH to output hex file"
     in
     fun () ->
       let db = Rocksdb.Database.create db_path in
       let kv_pairs = Rocksdb.Database.to_alist db in
       let%bind writer = Writer.open_file output_file in
       List.iter kv_pairs ~f:(fun (k, v) ->
           Writer.writef writer "%s : %s\n" (Hex_util.to_hex k)
             (Hex_util.to_hex v) ) ;
       let%bind () = Writer.close writer in
       Rocksdb.Database.close db ;
       printf "Dump complete: %s\n" output_file ;
       Writer.flushed (Lazy.force Writer.stdout) )

let restore_cmd =
  Command.async ~summary:"Restore RocksDB from a hex-encoded file"
    (let%map_open.Command input_file =
       flag "--input-file" (required string) ~doc:"PATH to hex dump"
     and db_path =
       flag "--db-path" (required string) ~doc:"PATH to target RocksDB"
     in
     fun () ->
       let db = Rocksdb.Database.create db_path in
       let%bind reader = Reader.open_file input_file in
       let kv_of_line line =
         Scanf.sscanf line "%s : %s" (fun k_hex v_hex ->
             let key = Hex_util.of_hex k_hex in
             let data = Hex_util.of_hex v_hex in
             (key, data) )
       in
       let chunk_size = 256 in
       let buffer = Queue.create ~capacity:chunk_size () in
       let process_batch () =
         Rocksdb.Database.set_batch db ?remove_keys:None
           ~key_data_pairs:(Queue.to_list buffer) ;
         Queue.clear buffer
       in
       Monitor.protect
         (fun () ->
           let%bind () =
             Reader.lines reader
             |> Pipe.iter_without_pushback ~f:(fun line ->
                    try
                      let kv = kv_of_line line in
                      Queue.enqueue buffer kv ;
                      if Queue.length buffer >= chunk_size then process_batch ()
                    with e ->
                      failwithf "Can't parse data line `%s` in dump file: %s"
                        line (Exn.to_string e) () )
           in
           if not (Queue.is_empty buffer) then process_batch () ;
           printf "Restore complete: %s\n" db_path ;
           Writer.flushed (Lazy.force Writer.stdout) )
         ~finally:(fun () ->
           let%map () = Reader.close reader in
           Rocksdb.Database.close db ) )

let main =
  Command.group ~summary:"RocksDB Hex Dump/Restore Tool"
    [ ("dump", dump_cmd); ("restore", restore_cmd) ]

let () = Command.run main
