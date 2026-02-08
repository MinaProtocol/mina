(** Mina storage layer: caching, disk cache, and database abstractions.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let cache_lib =
  library "cache_lib" ~path:"src/lib/cache_lib" ~inline_tests:true
    ~deps:
      [ async_kernel
      ; base
      ; base_internalhash_types
      ; core
      ; core_kernel
      ; ppx_inline_test_config
      ; local "logger"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_base
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let multi_key_file_storage =
  library "multi_key_file_storage" ~path:"src/lib/multi-key-file-storage"
    ~deps:[ core_kernel; bin_prot; Layer_base.mina_stdlib ]
    ~modules_without_implementation:[ "intf" ] ~ppx:Ppx.mina

let disk_cache_intf =
  library "disk_cache.intf" ~internal_name:"disk_cache_intf"
    ~path:"src/lib/disk_cache/intf"
    ~deps:[ core_kernel; async_kernel; Layer_logging.logger ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])

let cache_dir =
  library "cache_dir" ~path:"src/lib/cache_dir"
    ~deps:[ async_kernel; local "key_cache"; Layer_logging.logger ]
    ~ppx:Ppx.minimal ~virtual_modules:[ "cache_dir" ]
    ~default_implementation:"cache_dir.native"

let cache_dir_native =
  library "cache_dir.native" ~internal_name:"cache_dir_native"
    ~path:"src/lib/cache_dir/native"
    ~deps:
      [ base_caml
      ; async_unix
      ; base
      ; core
      ; async
      ; core_kernel
      ; stdio
      ; async_kernel
      ; local "key_cache"
      ; Layer_logging.logger
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_custom_printf
         ] )
    ~implements:"cache_dir"

let cache_dir_fake =
  library "cache_dir.fake" ~internal_name:"cache_dir_fake"
    ~path:"src/lib/cache_dir/fake"
    ~deps:[ async_kernel; core_kernel; local "key_cache" ]
    ~ppx:Ppx.minimal ~implements:"cache_dir"

let rocksdb =
  library "rocksdb" ~path:"src/lib/rocksdb" ~inline_tests:false
    ~library_flags:[ "-linkall" ]
    ~flags:[ list [ atom ":standard"; atom "-warn-error"; atom "+a" ] ]
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_internalhash_types
      ; base_caml
      ; core
      ; core_uuid
      ; core_kernel
      ; core_kernel_uuid
      ; ppx_inline_test_config
      ; rocks
      ; sexplib0
      ; Layer_base.mina_stdlib_unix
      ; Layer_base.key_value_database
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])
    ~synopsis:"RocksDB Database module"

let key_cache =
  library "key_cache" ~path:"src/lib/key_cache"
    ~deps:[ core_kernel; async_kernel ]
    ~ppx:Ppx.minimal

let key_cache_sync =
  library "key_cache.sync" ~internal_name:"key_cache_sync"
    ~path:"src/lib/key_cache/sync"
    ~deps:
      [ async; core; core_kernel; base; stdio; key_cache; Layer_logging.logger ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_let
         ] )

let key_cache_async =
  library "key_cache.async" ~internal_name:"key_cache_async"
    ~path:"src/lib/key_cache/async"
    ~deps:
      [ async
      ; core
      ; async_kernel
      ; async_unix
      ; core_kernel
      ; base
      ; base_caml
      ; key_cache
      ; Layer_logging.logger
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_let
         ] )

let key_cache_native =
  library "key_cache.native" ~internal_name:"key_cache_native"
    ~path:"src/lib/key_cache/native"
    ~deps:[ key_cache; key_cache_async; key_cache_sync ]
    ~ppx:Ppx.minimal

let lmdb_storage =
  library "lmdb_storage" ~path:"src/lib/lmdb_storage"
    ~deps:[ lmdb; Layer_crypto.blake2; Layer_base.mina_stdlib_unix ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let disk_cache =
  library "disk_cache" ~path:"src/lib/disk_cache"
    ~virtual_modules:[ "disk_cache" ]
    ~default_implementation:"disk_cache.identity" ~deps:[ disk_cache_intf ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])

let disk_cache_filesystem =
  library "disk_cache.filesystem" ~internal_name:"disk_cache_filesystem"
    ~path:"src/lib/disk_cache/filesystem" ~inline_tests:true
    ~implements:"disk_cache"
    ~deps:
      [ core
      ; async
      ; Layer_logging.logger
      ; Layer_base.mina_stdlib_unix
      ; local "disk_cache_utils"
      ; local "disk_cache_test_lib"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let disk_cache_identity =
  library "disk_cache.identity" ~internal_name:"disk_cache_identity"
    ~path:"src/lib/disk_cache/identity" ~inline_tests:true
    ~implements:"disk_cache"
    ~deps:[ async_kernel; core_kernel ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let disk_cache_lmdb =
  library "disk_cache.lmdb" ~internal_name:"disk_cache_lmdb"
    ~path:"src/lib/disk_cache/lmdb" ~inline_tests:true ~implements:"disk_cache"
    ~deps:
      [ core_kernel
      ; core
      ; lmdb_storage
      ; local "disk_cache_utils"
      ; local "disk_cache_test_lib"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_mina ])

let disk_cache_test_lib =
  library "disk_cache.test_lib" ~internal_name:"disk_cache_test_lib"
    ~path:"src/lib/disk_cache/test_lib"
    ~deps:
      [ core
      ; async
      ; mina_stdlib
      ; Layer_logging.logger
      ; Layer_base.mina_stdlib_unix
      ; disk_cache_intf
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

(* library: test_cache_deadlock_lib *)
let test_cache_deadlock_lib =
  private_library ~path:"src/lib/disk_cache/test"
    ~modules:[ "test_cache_deadlock" ]
    ~deps:
      [ async
      ; core
      ; core_kernel
      ; disk_cache_intf
      ; Layer_logging.logger
      ; Layer_base.mina_stdlib_unix
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a"; atom "-w"; atom "-22" ] ]
    "test_cache_deadlock_lib"

(* test: test_lmdb_deadlock *)
let () =
  test "test_lmdb_deadlock" ~path:"src/lib/disk_cache/test"
    ~modules:[ "test_lmdb_deadlock" ]
    ~deps:[ async; disk_cache_lmdb; local "test_cache_deadlock_lib" ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])
    ~flags:[ list [ atom ":standard"; atom "-w"; atom "+a" ] ]

(* test: test_filesystem_deadlock *)
let () =
  test "test_filesystem_deadlock" ~path:"src/lib/disk_cache/test"
    ~modules:[ "test_filesystem_deadlock" ]
    ~deps:[ async; disk_cache_filesystem; local "test_cache_deadlock_lib" ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])
    ~flags:[ list [ atom ":standard"; atom "-w"; atom "+a" ] ]

let disk_cache_utils =
  library "disk_cache.utils" ~internal_name:"disk_cache_utils"
    ~path:"src/lib/disk_cache/utils"
    ~deps:[ core; async; Layer_base.mina_stdlib_unix; Layer_logging.logger ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let zkapp_vk_cache_tag =
  library "zkapp_vk_cache_tag" ~path:"src/lib/zkapp_vk_cache_tag"
    ~deps:
      [ core_kernel
      ; async
      ; Layer_logging.logger
      ; disk_cache
      ; Layer_base.mina_base
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])
