(** Mina Core infrastructure libraries: logging, metrics, config, etc.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let register () =
  (* ============================================================ *)
  (* Tier 3: Core infrastructure libraries                         *)
  (* ============================================================ *)

  (* -- logger (virtual) ------------------------------------------- *)
  library "logger" ~path:"src/lib/logger"
    ~deps:[ core_kernel; sexplib0; local "interpolator_lib" ]
    ~ppx:Ppx.mina_rich ~virtual_modules:[ "logger" ]
    ~default_implementation:"logger.native" ;

  (* -- logger.context_logger -------------------------------------- *)
  library "logger.context_logger" ~internal_name:"context_logger"
    ~path:"src/lib/logger/context_logger"
    ~synopsis:
      "Context logger: useful for passing logger down the deep callstacks"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ base_internalhash_types
      ; core_kernel
      ; sexplib0
      ; async_kernel
      ; local "logger"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_mina"; "ppx_version"; "ppx_deriving_yojson" ] ) ;

  (* -- logger.fake ------------------------------------------------ *)
  library "logger.fake" ~internal_name:"logger_fake" ~path:"src/lib/logger/fake"
    ~synopsis:"Fake logging library"
    ~deps:
      [ result
      ; core_kernel
      ; sexplib0
      ; bin_prot_shape
      ; base_caml
      ; base_internalhash_types
      ; local "interpolator_lib"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:Ppx.mina_rich ~implements:"logger" ;

  (* -- logger.file_system ----------------------------------------- *)
  library "logger.file_system" ~internal_name:"logger_file_system"
    ~path:"src/lib/logger/file_system" ~synopsis:"Logging library"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:[ core; yojson; core_kernel; local "logger" ]
    ~ppx:Ppx.mina_rich ;

  (* -- logger.native ---------------------------------------------- *)
  library "logger.native" ~internal_name:"logger_native"
    ~path:"src/lib/logger/native" ~synopsis:"Logging library"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ result
      ; core
      ; core_kernel
      ; sexplib0
      ; bin_prot_shape
      ; base_caml
      ; base_internalhash_types
      ; local "itn_logger"
      ; local "interpolator_lib"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:Ppx.mina_rich ~implements:"logger" ;

  (* -- o1trace ---------------------------------------------------- *)
  library "o1trace" ~path:"src/lib/o1trace" ~synopsis:"Basic event tracing"
    ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_internalhash_types
      ; core
      ; core_kernel
      ; ocamlgraph
      ; ppx_inline_test_config
      ; sexplib0
      ; local "logger"
      ]
    ~ppx:Ppx.mina ;

  (* -- o1trace_webkit_event --------------------------------------- *)
  library "o1trace_webkit_event" ~path:"src/lib/o1trace/webkit_event"
    ~deps:
      [ base
      ; base_caml
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; core_time_stamp_counter
      ; core_kernel
      ; sexplib0
      ; local "webkit_trace_event.binary"
      ; local "webkit_trace_event"
      ; local "o1trace"
      ]
    ~ppx:Ppx.standard ;

  (* -- mina_stdlib_unix ------------------------------------------- *)
  library "mina_stdlib_unix" ~path:"src/lib/mina_stdlib_unix"
    ~synopsis:"Mina standard library Unix utilities"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; core
      ; core_kernel
      ; ptime
      ; local "logger"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_here"; "ppx_jane"; "ppx_let"; "ppx_mina"; "ppx_version" ] ) ;

  (* -- mina_numbers ----------------------------------------------- *)
  library "mina_numbers" ~path:"src/lib/mina_numbers"
    ~synopsis:"Snark-friendly numbers used in Coda consensus"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ result
      ; base_caml
      ; bin_prot_shape
      ; bignum_bigint
      ; core_kernel
      ; integers
      ; sexplib0
      ; base
      ; base_internalhash_types
      ; ppx_inline_test_config
      ; local "protocol_version"
      ; local "mina_wire_types"
      ; local "bignum_bigint"
      ; local "pickles"
      ; local "codable"
      ; local "snarky.backendless"
      ; local "fold_lib"
      ; local "tuple_lib"
      ; local "snark_bits"
      ; local "snark_params"
      ; local "unsigned_extended"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "bitstring_lib"
      ; local "test_util"
      ; local "kimchi_backend_common"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_mina"
         ; "ppx_bin_prot"
         ; "ppx_sexp_conv"
         ; "ppx_compare"
         ; "ppx_hash"
         ; "ppx_let"
         ; "ppx_inline_test"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "ppx_assert"
         ] ) ;

  (* -- cache_lib -------------------------------------------------- *)
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
         [ "ppx_base"
         ; "ppx_custom_printf"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  (* -- trust_system ----------------------------------------------- *)
  library "trust_system" ~path:"src/lib/trust_system"
    ~synopsis:"Track how much we trust peers" ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ sexplib0
      ; core
      ; ppx_inline_test_config
      ; base_caml
      ; async_kernel
      ; core_kernel
      ; bin_prot_shape
      ; base
      ; result
      ; async
      ; async_unix
      ; local "mina_metrics"
      ; local "rocksdb"
      ; local "pipe_lib"
      ; local "logger"
      ; local "key_value_database"
      ; local "network_peer"
      ; local "run_in_thread"
      ; local "test_util"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_assert"
         ; "ppx_base"
         ; "ppx_bin_prot"
         ; "ppx_mina"
         ; "ppx_custom_printf"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_fields_conv"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_register_event"
         ; "ppx_sexp_conv"
         ; "ppx_snarky"
         ; "ppx_version"
         ] ) ;

  (* -- parallel --------------------------------------------------- *)
  library "parallel" ~path:"src/lib/parallel"
    ~synopsis:"Template code to run programs that rely Rpc_parallel.Expert"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async_rpc_kernel; async; core; rpc_parallel; async_rpc; core_kernel ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane"; "ppx_compare" ]) ;

  (* -- mina_version.dummy ----------------------------------------- *)
  library "mina_version.dummy" ~internal_name:"mina_version_dummy"
    ~path:"src/lib/mina_version/dummy" ~deps:[ core_kernel; base ]
    ~ppx:Ppx.minimal ~implements:"mina_version" ;

  (* -- mina_version.runtime --------------------------------------- *)
  library "mina_version.runtime" ~internal_name:"mina_version_runtime"
    ~path:"src/lib/mina_version/runtime"
    ~deps:[ core_kernel; base; unix ]
    ~ppx:Ppx.minimal ~implements:"mina_version" ;

  (* -- mina_signature_kind (virtual) ------------------------------ *)
  library "mina_signature_kind" ~path:"src/lib/signature_kind"
    ~deps:[ local "mina_signature_kind.type" ]
    ~ppx:(Ppx.custom [ "ppx_bin_prot"; "ppx_version"; "ppx_deriving_yojson" ])
    ~virtual_modules:[ "mina_signature_kind" ]
    ~default_implementation:"mina_signature_kind_config" ;

  (* -- mina_signature_kind.type ----------------------------------- *)
  library "mina_signature_kind.type" ~internal_name:"mina_signature_kind_type"
    ~path:"src/lib/signature_kind/type" ~deps:[ core_kernel ]
    ~ppx:(Ppx.custom [ "ppx_deriving_yojson"; "ppx_jane"; "ppx_version" ]) ;

  (* -- mina_signature_kind.config --------------------------------- *)
  library "mina_signature_kind.config"
    ~internal_name:"mina_signature_kind_config"
    ~path:"src/lib/signature_kind/compile_config"
    ~deps:[ local "mina_node_config" ]
    ~ppx:Ppx.minimal ~implements:"mina_signature_kind" ;

  (* -- mina_signature_kind.testnet -------------------------------- *)
  library "mina_signature_kind.testnet"
    ~internal_name:"mina_signature_kind_testnet"
    ~path:"src/lib/signature_kind/testnet" ~ppx:Ppx.minimal
    ~implements:"mina_signature_kind" ;

  (* -- mina_signature_kind.mainnet -------------------------------- *)
  library "mina_signature_kind.mainnet"
    ~internal_name:"mina_signature_kind_mainnet"
    ~path:"src/lib/signature_kind/mainnet" ~ppx:Ppx.minimal
    ~implements:"mina_signature_kind" ;

  (* -- multi_key_file_storage ------------------------------------- *)
  library "multi_key_file_storage" ~path:"src/lib/multi-key-file-storage"
    ~deps:[ core_kernel; bin_prot; local "mina_stdlib" ]
    ~modules_without_implementation:[ "intf" ] ~ppx:Ppx.mina ;

  ()
