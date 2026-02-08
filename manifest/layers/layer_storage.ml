(** Mina storage layer: caching, disk cache, and database abstractions.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Dune_s_expr

let register () =
  (* -- disk_cache.intf -------------------------------------------- *)
  library "disk_cache.intf" ~internal_name:"disk_cache_intf"
    ~path:"src/lib/disk_cache/intf"
    ~deps:[ opam "core_kernel"; opam "async_kernel"; local "logger" ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_version" ]) ;

  (* -- cache_dir (virtual) ---------------------------------------- *)
  library "cache_dir" ~path:"src/lib/cache_dir"
    ~deps:[ opam "async_kernel"; local "key_cache"; local "logger" ]
    ~ppx:Ppx.minimal ~virtual_modules:[ "cache_dir" ]
    ~default_implementation:"cache_dir.native" ;

  (* -- cache_dir.native ------------------------------------------- *)
  library "cache_dir.native" ~internal_name:"cache_dir_native"
    ~path:"src/lib/cache_dir/native"
    ~deps:
      [ opam "base.caml"
      ; opam "async_unix"
      ; opam "base"
      ; opam "core"
      ; opam "async"
      ; opam "core_kernel"
      ; opam "stdio"
      ; opam "async_kernel"
      ; local "key_cache"
      ; local "logger"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_here"
         ; "ppx_let"
         ; "ppx_custom_printf"
         ] )
    ~implements:"cache_dir" ;

  (* -- cache_dir.fake --------------------------------------------- *)
  library "cache_dir.fake" ~internal_name:"cache_dir_fake"
    ~path:"src/lib/cache_dir/fake"
    ~deps:[ opam "async_kernel"; opam "core_kernel"; local "key_cache" ]
    ~ppx:Ppx.minimal ~implements:"cache_dir" ;

  (* -- rocksdb ---------------------------------------------------- *)
  library "rocksdb" ~path:"src/lib/rocksdb" ~inline_tests:false
    ~library_flags:[ "-linkall" ]
    ~flags:[ list [ atom ":standard"; atom "-warn-error"; atom "+a" ] ]
    ~deps:
      [ opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "core"
      ; opam "core.uuid"
      ; opam "core_kernel"
      ; opam "core_kernel.uuid"
      ; opam "ppx_inline_test.config"
      ; opam "rocks"
      ; opam "sexplib0"
      ; local "mina_stdlib_unix"
      ; local "key_value_database"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane" ])
    ~synopsis:"RocksDB Database module" ;

  (* -- key_cache --------------------------------------------------- *)
  library "key_cache" ~path:"src/lib/key_cache"
    ~deps:[ opam "core_kernel"; opam "async_kernel" ]
    ~ppx:Ppx.minimal ;

  (* -- key_cache.sync ---------------------------------------------- *)
  library "key_cache.sync" ~internal_name:"key_cache_sync"
    ~path:"src/lib/key_cache/sync"
    ~deps:
      [ opam "async"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "base"
      ; opam "stdio"
      ; local "key_cache"
      ; local "logger"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"; "ppx_version"; "ppx_base"; "ppx_here"; "ppx_let" ] ) ;

  (* -- key_cache.async --------------------------------------------- *)
  library "key_cache.async" ~internal_name:"key_cache_async"
    ~path:"src/lib/key_cache/async"
    ~deps:
      [ opam "async"
      ; opam "core"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core_kernel"
      ; opam "base"
      ; opam "base.caml"
      ; local "key_cache"
      ; local "logger"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"; "ppx_version"; "ppx_base"; "ppx_here"; "ppx_let" ] ) ;

  (* -- key_cache.native -------------------------------------------- *)
  library "key_cache.native" ~internal_name:"key_cache_native"
    ~path:"src/lib/key_cache/native"
    ~deps:[ local "key_cache"; local "key_cache.async"; local "key_cache.sync" ]
    ~ppx:Ppx.minimal ;

  (* -- lmdb_storage ------------------------------------------------ *)
  library "lmdb_storage" ~path:"src/lib/lmdb_storage"
    ~deps:[ opam "lmdb"; local "blake2"; local "mina_stdlib_unix" ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  (* -- disk_cache (virtual) ---------------------------------------- *)
  library "disk_cache" ~path:"src/lib/disk_cache"
    ~virtual_modules:[ "disk_cache" ]
    ~default_implementation:"disk_cache.identity"
    ~deps:[ local "disk_cache.intf" ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_version" ]) ;

  (* -- disk_cache.filesystem --------------------------------------- *)
  library "disk_cache.filesystem" ~internal_name:"disk_cache_filesystem"
    ~path:"src/lib/disk_cache/filesystem" ~inline_tests:true
    ~implements:"disk_cache"
    ~deps:
      [ opam "core"
      ; opam "async"
      ; local "logger"
      ; local "mina_stdlib_unix"
      ; local "disk_cache.utils"
      ; local "disk_cache.test_lib"
      ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_version"; "ppx_jane" ]) ;

  (* -- disk_cache.identity ----------------------------------------- *)
  library "disk_cache.identity" ~internal_name:"disk_cache_identity"
    ~path:"src/lib/disk_cache/identity" ~inline_tests:true
    ~implements:"disk_cache"
    ~deps:[ opam "async_kernel"; opam "core_kernel" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane" ]) ;

  (* -- disk_cache.lmdb --------------------------------------------- *)
  library "disk_cache.lmdb" ~internal_name:"disk_cache_lmdb"
    ~path:"src/lib/disk_cache/lmdb" ~inline_tests:true ~implements:"disk_cache"
    ~deps:
      [ opam "core_kernel"
      ; opam "core"
      ; local "lmdb_storage"
      ; local "disk_cache.utils"
      ; local "disk_cache.test_lib"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane"; "ppx_mina" ]) ;

  (* -- disk_cache.test_lib ----------------------------------------- *)
  library "disk_cache.test_lib" ~internal_name:"disk_cache_test_lib"
    ~path:"src/lib/disk_cache/test_lib"
    ~deps:
      [ opam "core"
      ; opam "async"
      ; opam "mina_stdlib"
      ; local "logger"
      ; local "mina_stdlib_unix"
      ; local "disk_cache.intf"
      ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_version"; "ppx_jane" ]) ;

  (* -- disk_cache/test --------------------------------------------- *)
  (* library: test_cache_deadlock_lib *)
  private_library ~path:"src/lib/disk_cache/test"
    ~modules:[ "test_cache_deadlock" ]
    ~deps:
      [ opam "async"
      ; opam "core"
      ; opam "core_kernel"
      ; local "disk_cache_intf"
      ; local "logger"
      ; local "mina_stdlib_unix"
      ]
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_version" ])
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a"; atom "-w"; atom "-22" ] ]
    "test_cache_deadlock_lib" ;

  (* test: test_lmdb_deadlock *)
  test "test_lmdb_deadlock" ~path:"src/lib/disk_cache/test"
    ~modules:[ "test_lmdb_deadlock" ]
    ~deps:
      [ opam "async"; local "disk_cache.lmdb"; local "test_cache_deadlock_lib" ]
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_version" ])
    ~flags:[ list [ atom ":standard"; atom "-w"; atom "+a" ] ] ;

  (* test: test_filesystem_deadlock *)
  test "test_filesystem_deadlock" ~path:"src/lib/disk_cache/test"
    ~modules:[ "test_filesystem_deadlock" ]
    ~deps:
      [ opam "async"
      ; local "disk_cache.filesystem"
      ; local "test_cache_deadlock_lib"
      ]
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_version" ])
    ~flags:[ list [ atom ":standard"; atom "-w"; atom "+a" ] ] ;

  (* -- disk_cache.utils -------------------------------------------- *)
  library "disk_cache.utils" ~internal_name:"disk_cache_utils"
    ~path:"src/lib/disk_cache/utils"
    ~deps:
      [ opam "core"; opam "async"; local "mina_stdlib_unix"; local "logger" ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_version"; "ppx_jane" ]) ;

  (* -- zkapp_vk_cache_tag ------------------------------------------- *)
  library "zkapp_vk_cache_tag" ~path:"src/lib/zkapp_vk_cache_tag"
    ~deps:
      [ opam "core_kernel"
      ; opam "async"
      ; local "logger"
      ; local "disk_cache"
      ; local "mina_base"
      ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_version" ]) ;

  ()
