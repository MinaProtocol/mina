(** Mina storage layer: caching, disk cache, and database abstractions.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let key_value_database =
  library "key_value_database" ~path:"src/lib/key_value_database"
    ~synopsis:"Collection of key-value databases used in Coda"
    ~deps:[ core_kernel ] ~ppx:Ppx.standard ~library_flags:[ "-linkall" ]

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
    ~deps:[ bin_prot; core_kernel; Layer_base.mina_stdlib ]
    ~modules_without_implementation:[ "intf" ] ~ppx:Ppx.mina

let disk_cache_intf =
  library "disk_cache.intf" ~internal_name:"disk_cache_intf"
    ~path:"src/lib/disk_cache/intf"
    ~deps:[ async_kernel; core_kernel; Layer_logging.logger ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])

let cache_dir =
  library "cache_dir" ~path:"src/lib/cache_dir"
    ~deps:[ async_kernel; Layer_logging.logger; local "key_cache" ]
    ~ppx:Ppx.minimal ~virtual_modules:[ "cache_dir" ]
    ~default_implementation:"cache_dir.native"

let cache_dir_native =
  library "cache_dir.native" ~internal_name:"cache_dir_native"
    ~path:"src/lib/cache_dir/native"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; core
      ; core_kernel
      ; stdio
      ; Layer_logging.logger
      ; local "key_cache"
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
      ; base_caml
      ; base_internalhash_types
      ; core
      ; core_kernel
      ; core_kernel_uuid
      ; core_uuid
      ; key_value_database
      ; ppx_inline_test_config
      ; rocks
      ; sexplib0
      ; Layer_base.mina_stdlib_unix
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])
    ~synopsis:"RocksDB Database module"

let key_cache =
  library "key_cache" ~path:"src/lib/key_cache"
    ~deps:[ async_kernel; core_kernel ]
    ~ppx:Ppx.minimal

let key_cache_sync =
  library "key_cache.sync" ~internal_name:"key_cache_sync"
    ~path:"src/lib/key_cache/sync"
    ~deps:
      [ async
      ; base
      ; core
      ; core_kernel
      ; key_cache
      ; stdio
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

let key_cache_async =
  library "key_cache.async" ~internal_name:"key_cache_async"
    ~path:"src/lib/key_cache/async"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; core
      ; core_kernel
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
    ~deps:[ lmdb; Layer_base.mina_stdlib_unix; Layer_crypto.blake2 ]
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
      [ async
      ; core
      ; Layer_base.mina_stdlib_unix
      ; Layer_logging.logger
      ; local "disk_cache_test_lib"
      ; local "disk_cache_utils"
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
      [ core
      ; core_kernel
      ; lmdb_storage
      ; local "disk_cache_test_lib"
      ; local "disk_cache_utils"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_mina ])

let disk_cache_test_lib =
  library "disk_cache.test_lib" ~internal_name:"disk_cache_test_lib"
    ~path:"src/lib/disk_cache/test_lib"
    ~deps:
      [ async
      ; core
      ; disk_cache_intf
      ; mina_stdlib
      ; Layer_base.mina_stdlib_unix
      ; Layer_logging.logger
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
      ; Layer_base.mina_stdlib_unix
      ; Layer_logging.logger
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
    ~deps:[ async; core; Layer_base.mina_stdlib_unix; Layer_logging.logger ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let zkapp_vk_cache_tag =
  library "zkapp_vk_cache_tag" ~path:"src/lib/zkapp_vk_cache_tag"
    ~deps:
      [ async
      ; core_kernel
      ; disk_cache
      ; Layer_base.mina_base
      ; Layer_logging.logger
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])
