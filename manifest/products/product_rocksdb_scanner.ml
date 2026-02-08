(** Product: rocksdb_scanner — Scan and inspect RocksDB databases. *)

open Manifest
open Externals

let () =
  executable "mina_rocksdb_scanner" ~internal_name:"rocksdb_scanner"
    ~package:"rocksdb_scanner" ~path:"src/app/rocksdb-scanner"
    ~modes:[ "native" ]
    ~deps:[ async; core; Layer_logging.logger; Layer_storage.rocksdb ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])
