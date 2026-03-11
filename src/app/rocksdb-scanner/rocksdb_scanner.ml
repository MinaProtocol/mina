open Core
open Async

module Hex_helpers = struct
  exception CantDeserializeHex of string

  let of_bigstring = Fn.compose Hex.Safe.to_hex Bigstring.to_string

  let to_bigstring input =
    match Hex.Safe.of_hex input with
    | Some str ->
        Bigstring.of_string str
    | None ->
        raise (CantDeserializeHex input)
end

module Rocksdb_helpers = struct
  exception DbNonExistent of string

  let safe_open path =
    match%map Sys.is_directory path with
    | `Yes ->
        Rocksdb.Database.create path
    | _ ->
        raise (DbNonExistent path)
end

let dump_cmd =
  Command.async ~summary:"Scan RocksDB and dump KV pairs as hex"
    (let%map_open.Command db_path =
       flag "--db-path" (required string) ~doc:"PATH to source RocksDB"
     and output_file =
       flag "--output-file" (required string) ~doc:"PATH to output hex file"
     in
     fun () ->
       let%bind db = Rocksdb_helpers.safe_open db_path in
       let kv_pairs = Rocksdb.Database.to_alist db in
       let%bind writer =
         match%map
           Monitor.try_with (fun () -> Writer.open_file output_file)
         with
         | Ok writer ->
             writer
         | Error exn ->
             Exn.reraise exn
             @@ sprintf "Can't write to hex dump needed to dump the DB at %s"
                  output_file
       in
       let%bind () =
         Monitor.protect
           (fun () ->
             List.iter kv_pairs ~f:(fun (k, v) ->
                 Writer.writef writer "%s : %s\n"
                   (Hex_helpers.of_bigstring k)
                   (Hex_helpers.of_bigstring v) ) ;
             Deferred.unit )
           ~finally:(fun () ->
             let%map () = Writer.close writer in
             Rocksdb.Database.close db )
       in
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
       let%bind reader =
         match%map Monitor.try_with (fun () -> Reader.open_file input_file) with
         | Ok reader ->
             reader
         | Error exn ->
             Exn.reraise exn
             @@ sprintf "Can't read hex dump needed to restore the DB at %s"
                  input_file
       in
       let kv_of_line line =
         Scanf.sscanf line "%s : %s" (fun k_hex v_hex ->
             let key = Hex_helpers.to_bigstring k_hex in
             let data = Hex_helpers.to_bigstring v_hex in
             (key, data) )
       in
       (* NOTE: This number here is choosen randomly, we can tune later *)
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
