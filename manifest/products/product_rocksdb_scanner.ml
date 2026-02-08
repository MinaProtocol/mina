(** Product: rocksdb_scanner — Scan and inspect RocksDB databases. *)

open Manifest

let register () =
  executable "mina_rocksdb_scanner" ~internal_name:"rocksdb_scanner"
    ~package:"rocksdb_scanner" ~path:"src/app/rocksdb-scanner"
    ~modes:[ "native" ]
    ~deps:[ opam "async"; opam "core"; local "logger"; local "rocksdb" ]
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_mina"; "ppx_version" ]) ;

  ()
