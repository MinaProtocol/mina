open Core_kernel
open Async_kernel

let autogen_path = "/tmp/coda_cache_dir"

let gs_install_path  = "/tmp/gs_cache_dir"

let gs_ledger_bucket_prefix = "mina-genesis-ledgers"

let manual_install_path = "/var/lib/coda"

let brew_install_path = "/usr/local/var/coda"

let cache = []

let env_path = manual_install_path

let possible_paths base =
  List.map
    [ env_path
    ; brew_install_path
    ; gs_install_path
    ; autogen_path
    ; manual_install_path
    ] ~f:(fun d -> d ^ "/" ^ base)

let load_from_gs ~gs_bucket_prefix:_ ~gs_object_name:_ _gs_install_path ~logger:_ =
  Deferred.Or_error.fail (Error.createf "Cannot load files from Google Storage")
