open Core

let to_hex (b : Bigstring.t) = Hex.Safe.to_hex (Bigstring.to_string b)

let () =
  Command.(
    run
      (let open Let_syntax in
      basic
        ~summary:
          "Dump a RocksDB database into an ordered list of key-value hex \
           strings"
        (let%map dir =
           Param.flag "--rocksdb-dir"
             ~doc:"Directory storing the RocksDB (default: current directory)"
             Param.(required string)
         in
         fun () ->
           let db = Rocksdb.Database.create dir in
           let all_pairs = Rocksdb.Database.to_alist db in
           printf "[" ;
           List.iter all_pairs ~f:(fun (k, v) ->
               printf "[\"%s\", \"%s\"],\n" (to_hex k) (to_hex v) ) ;
           printf "]" )))
