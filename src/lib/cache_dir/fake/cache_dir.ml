open Core_kernel
open Async_kernel

let autogen_path = "/tmp/coda_cache_dir"

let s3_install_path = "/tmp/s3_cache_dir"

let s3_keys_bucket_prefix =
  "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net"

let manual_install_path = "/var/lib/coda"

let brew_install_path = "/usr/local/var/coda"

let cache = []

let env_path = manual_install_path

let possible_paths base =
  List.map
    [ env_path
    ; brew_install_path
    ; s3_install_path
    ; autogen_path
    ; manual_install_path
    ] ~f:(fun d -> d ^ "/" ^ base)

let load_from_s3 _s3_bucket_prefix _s3_install_path ~logger:_ =
  Deferred.Or_error.fail (Error.createf "Cannot load files from S3")
