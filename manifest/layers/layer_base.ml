(** Mina Base libraries: trivial, moderate, virtual modules, and edge cases.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let register () =
  (* ============================================================ *)
  (* Tier 1: Trivial libraries                                    *)
  (* ============================================================ *)

  (* -- hex -------------------------------------------------------- *)
  library "hex" ~path:"src/lib/hex" ~deps:[ core_kernel ]
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_version"; "ppx_inline_test" ])
    ~inline_tests:true ;

  (* -- monad_lib -------------------------------------------------- *)
  library "monad_lib" ~path:"src/lib/monad_lib" ~deps:[ core_kernel ]
    ~ppx:Ppx.standard ;

  (* -- with_hash -------------------------------------------------- *)
  library "with_hash" ~path:"src/lib/with_hash"
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; core_kernel
      ; sexplib0
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_annot"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.std"
         ; "ppx_version"
         ; "ppx_fields_conv"
         ] ) ;

  (* -- pipe_lib --------------------------------------------------- *)
  library "pipe_lib" ~path:"src/lib/concurrency/pipe_lib"
    ~deps:
      [ async_kernel
      ; core
      ; core_kernel
      ; ppx_inline_test_config
      ; sexplib
      ; local "logger"
      ; local "o1trace"
      ; local "run_in_thread"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"; "ppx_version"; "ppx_jane"; "ppx_deriving.make" ] )
    ~inline_tests:true ;

  (* -- allocation_functor --------------------------------------- *)
  library "allocation_functor" ~path:"src/lib/allocation_functor"
    ~deps:
      [ core_kernel
      ; result
      ; ppx_inline_test_config
      ; sexplib0
      ; local "mina_metrics"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_compare"; "ppx_deriving_yojson"; "ppx_version" ] )
    ~inline_tests:true ;

  (* -- codable -------------------------------------------------- *)
  library "codable" ~path:"src/lib/codable"
    ~synopsis:"Extension of Yojson to make it easy for a type to derive yojson"
    ~deps:
      [ base64
      ; core_kernel
      ; ppx_deriving_yojson_runtime
      ; result
      ; yojson
      ; local "base58_check"
      ]
    ~ppx:(Ppx.custom [ "ppx_deriving_yojson"; "ppx_jane"; "ppx_version" ])
    ~inline_tests:true ~library_flags:[ "-linkall" ] ;

  (* -- comptime ------------------------------------------------- *)
  library "comptime" ~path:"src/lib/comptime" ~deps:[ core_kernel; base ]
    ~ppx:Ppx.minimal
    ~extra_stanzas:
      [ "rule"
        @: [ "target" @: [ atom "comptime.ml" ]
           ; "deps"
             @: [ list [ atom ":<"; atom "gen.sh" ]; list [ atom "universe" ] ]
           ; "action"
             @: [ "run" @: [ atom "bash"; atom "%{<}"; atom "%{target}" ] ]
           ]
      ] ;

  (* -- error_json ----------------------------------------------- *)
  library "error_json" ~path:"src/lib/error_json"
    ~deps:[ base; sexplib; sexplib0; yojson ]
    ~ppx:(Ppx.custom [ "ppx_deriving_yojson"; "ppx_version" ]) ;

  (* -- integers_stubs_js ---------------------------------------- *)
  library "integers_stubs_js" ~path:"src/lib/integers_stubs_js"
    ~deps:[ zarith_stubs_js ] ~ppx:Ppx.minimal
    ~js_of_ocaml:
      ("js_of_ocaml" @: [ "javascript_files" @: [ atom "./runtime.js" ] ]) ;

  (* -- key_value_database --------------------------------------- *)
  library "key_value_database" ~path:"src/lib/key_value_database"
    ~synopsis:"Collection of key-value databases used in Coda"
    ~deps:[ core_kernel ] ~ppx:Ppx.standard ~library_flags:[ "-linkall" ] ;

  (* -- linked_tree ---------------------------------------------- *)
  library "linked_tree" ~path:"src/lib/linked_tree"
    ~deps:[ core_kernel; local "mina_numbers" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane"; "ppx_compare" ]) ;

  (* -- logproc_lib ---------------------------------------------- *)
  library "logproc_lib" ~path:"src/lib/logproc_lib"
    ~modules:[ "logproc_lib"; "filter" ]
    ~deps:
      [ core_kernel
      ; yojson
      ; angstrom
      ; re2
      ; ppx_inline_test_config
      ; local "interpolator_lib"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane"; "ppx_deriving.std" ])
    ~inline_tests:true ;

  (* -- interpolator_lib ----------------------------------------- *)
  library "interpolator_lib" ~path:"src/lib/logproc_lib"
    ~modules:[ "interpolator" ]
    ~deps:[ core_kernel; yojson; angstrom ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane"; "ppx_deriving.std" ])
    ~inline_tests:true ;

  (* -- mina_wire_types ------------------------------------------ *)
  file_stanzas ~path:"src/lib/mina_wire_types"
    [ "include_subdirs" @: [ atom "unqualified" ] ] ;
  library "mina_wire_types" ~path:"src/lib/mina_wire_types"
    ~deps:
      [ integers
      ; pasta_bindings
      ; kimchi_types
      ; kimchi_bindings
      ; local "blake2"
      ]
    ~ppx:Ppx.minimal
    ~extra_stanzas:
      [ "documentation" @: [ "package" @: [ atom "mina_wire_types" ] ] ] ;

  (* -- one_or_two ----------------------------------------------- *)
  library "one_or_two" ~path:"src/lib/one_or_two"
    ~flags:[ atom ":standard"; atom "-short-paths" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ bin_prot_shape
      ; base
      ; async_kernel
      ; core_kernel
      ; ppx_hash_runtime_lib
      ; sexplib0
      ; base_caml
      ; ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_base"
         ; "ppx_bin_prot"
         ; "ppx_version"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_let"
         ] ) ;

  (* -- otp_lib -------------------------------------------------- *)
  library "otp_lib" ~path:"src/lib/otp_lib"
    ~deps:
      [ core_kernel; async_kernel; ppx_inline_test_config; local "pipe_lib" ]
    ~ppx:Ppx.standard ~inline_tests:true ;

  (* -- participating_state -------------------------------------- *)
  library "participating_state" ~path:"src/lib/participating_state"
    ~deps:[ async_kernel; core_kernel; base ]
    ~ppx:Ppx.minimal ;

  (* -- perf_histograms ------------------------------------------ *)
  library "perf_histograms" ~path:"src/lib/perf_histograms"
    ~synopsis:"Performance monitoring with histograms"
    ~modules:
      [ "perf_histograms0"; "perf_histograms"; "histogram"; "rpc"; "intf" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; bin_prot_shape
      ; async_rpc_kernel
      ; yojson
      ; async
      ; core
      ; core_kernel
      ; ppx_deriving_yojson_runtime
      ; async_rpc
      ; base_caml
      ; async_kernel
      ; local "mina_metrics"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_compare"; "ppx_deriving_yojson" ] )
    ~inline_tests:true ;

  (* -- proof_cache_tag ------------------------------------------ *)
  library "proof_cache_tag" ~path:"src/lib/proof_cache_tag"
    ~deps:
      [ core_kernel
      ; async_kernel
      ; local "logger"
      ; local "disk_cache"
      ; local "pickles"
      ]
    ~ppx:Ppx.mina ;

  (* -- rosetta_coding ------------------------------------------- *)
  library "rosetta_coding" ~path:"src/lib/rosetta_coding"
    ~synopsis:"Encoders and decoders for Rosetta" ~library_flags:[ "-linkall" ]
    ~deps:
      [ base
      ; core_kernel
      ; local "mina_stdlib"
      ; local "signature_lib"
      ; local "snark_params"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_assert"; "ppx_let" ]) ;

  (* -- rosetta_models ------------------------------------------- *)
  library "rosetta_models" ~path:"src/lib/rosetta_models"
    ~deps:[ ppx_deriving_yojson_runtime; yojson ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving_yojson"
         ; "ppx_deriving.eq"
         ; "ppx_deriving.show"
         ; "ppx_version"
         ] ) ;

  (* -- sgn_type ------------------------------------------------- *)
  library "sgn_type" ~path:"src/lib/sgn_type"
    ~deps:
      [ core_kernel
      ; ppx_deriving_yojson_runtime
      ; yojson
      ; sexplib0
      ; bin_prot_shape
      ; base_caml
      ; ppx_version_runtime
      ; local "mina_wire_types"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_version"; "ppx_compare"; "ppx_deriving_yojson" ] ) ;

  (* -- structured_log_events ------------------------------------ *)
  library "structured_log_events" ~path:"src/lib/structured_log_events"
    ~synopsis:"Events, logging and parsing" ~library_flags:[ "-linkall" ]
    ~deps:[ core_kernel; yojson; sexplib0; local "interpolator_lib" ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_inline_test"
         ] )
    ~inline_tests:true ;

  (* -- sync_status ---------------------------------------------- *)
  library "sync_status" ~path:"src/lib/sync_status"
    ~synopsis:"Different kinds of status for Coda "
    ~deps:
      [ base_internalhash_types
      ; base_caml
      ; bin_prot_shape
      ; core_kernel
      ; sexplib0
      ; ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_version"; "ppx_deriving_yojson"; "ppx_enumerate" ] ) ;

  (* -- unsigned_extended ---------------------------------------- *)
  library "unsigned_extended" ~path:"src/lib/unsigned_extended"
    ~synopsis:"Unsigned integer functions" ~library_flags:[ "-linkall" ]
    ~deps:
      [ base_caml
      ; result
      ; base
      ; core_kernel
      ; integers
      ; sexplib0
      ; bignum_bigint
      ; base_internalhash_types
      ; bin_prot_shape
      ; ppx_inline_test_config
      ; local "bignum_bigint"
      ; local "snark_params"
      ; local "test_util"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_bin_prot"
         ; "ppx_sexp_conv"
         ; "ppx_compare"
         ; "ppx_hash"
         ; "ppx_inline_test"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ] )
    ~inline_tests:true ;

  (* -- visualization -------------------------------------------- *)
  library "visualization" ~path:"src/lib/visualization"
    ~deps:[ core_kernel; async_kernel; ocamlgraph; yojson; sexplib0 ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_deriving_yojson"; "ppx_sexp_conv" ] ) ;

  (* -- webkit_trace_event --------------------------------------- *)
  library "webkit_trace_event" ~path:"src/lib/webkit_trace_event"
    ~synopsis:"Binary and JSON output of WebKit trace events"
    ~deps:[ core_kernel; base ] ~ppx:Ppx.minimal ;

  (* -- webkit_trace_event.binary -------------------------------- *)
  library "webkit_trace_event.binary"
    ~internal_name:"webkit_trace_event_binary_output"
    ~path:"src/lib/webkit_trace_event/binary_output"
    ~deps:
      [ core; async; base; core_kernel; async_unix; local "webkit_trace_event" ]
    ~ppx:Ppx.minimal ;

  (* -- graphql_basic_scalars ------------------------------------ *)
  library "graphql_basic_scalars" ~path:"src/lib/graphql_basic_scalars"
    ~deps:
      [ async
      ; async_unix
      ; async_kernel
      ; core_kernel
      ; integers
      ; core
      ; graphql
      ; graphql_async
      ; graphql_parser
      ; yojson
      ; sexplib0
      ; local "base_quickcheck"
      ; local "graphql_wrapper"
      ; local "quickcheck_lib"
      ; local "unix"
      ]
    ~ppx:Ppx.standard ~inline_tests:true ;

  (* -- graphql_wrapper ------------------------------------------ *)
  library "graphql_wrapper" ~path:"src/lib/graphql_wrapper"
    ~deps:[ graphql; graphql_async; graphql_parser ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving.show"; "ppx_deriving_yojson"; "ppx_version" ] ) ;

  (* -- mina_compile_config -------------------------------------- *)
  library "mina_compile_config" ~path:"src/lib/mina_compile_config"
    ~deps:
      [ local "mina_node_config"
      ; local "mina_node_config.for_unit_tests"
      ; core_kernel
      ; local "currency"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_base"; "ppx_deriving_yojson" ]) ;

  (* -- storage -------------------------------------------------- *)
  library "storage" ~path:"src/lib/storage"
    ~synopsis:"Storage module checksums data and stores it"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ core
      ; async
      ; core_kernel
      ; bin_prot_shape
      ; bin_prot
      ; base
      ; sexplib0
      ; async_kernel
      ; async_unix
      ; base_caml
      ; local "logger"
      ; local "ppx_version.runtime"
      ]
    ~ppx:Ppx.standard ~inline_tests:true ;

  (* -- mina_stdlib ------------------------------------------------ *)
  library "mina_stdlib" ~path:"src/lib/mina_stdlib"
    ~synopsis:"Mina standard library" ~inline_tests:true
    ~modules_without_implementation:[ "generic_set"; "sigs" ]
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "a"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ async_kernel
      ; base_caml
      ; bin_prot
      ; bin_prot_shape
      ; core_kernel
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; stdlib
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_inline_test"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  (* ============================================================ *)
  (* Tier 2: Moderate libraries                                   *)
  (* ============================================================ *)

  (* -- base58_check ----------------------------------------------- *)
  library "base58_check" ~path:"src/lib/base58_check"
    ~synopsis:"Base58Check implementation"
    ~deps:[ base; base58; core_kernel; digestif; ppx_inline_test_config ]
    ~ppx:
      (Ppx.custom
         [ "ppx_assert"
         ; "ppx_base"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] )
    ~inline_tests:true ~library_flags:[ "-linkall" ] ;

  (* -- currency --------------------------------------------------- *)
  library "currency" ~path:"src/lib/currency" ~synopsis:"Currency types"
    ~deps:
      [ base
      ; base_internalhash_types
      ; base_caml
      ; bin_prot_shape
      ; core_kernel
      ; integers
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; zarith
      ; local "bignum_bigint"
      ; local "bitstring_lib"
      ; local "codable"
      ; local "kimchi_backend_common"
      ; local "mina_numbers"
      ; local "mina_wire_types"
      ; local "pickles"
      ; local "ppx_version.runtime"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "sgn"
      ; local "snark_bits"
      ; local "snark_params"
      ; local "snarky.backendless"
      ; local "test_util"
      ; local "unsigned_extended"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_annot"
         ; "ppx_assert"
         ; "ppx_bin_prot"
         ; "ppx_compare"
         ; "ppx_custom_printf"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_fields_conv"
         ; "ppx_hash"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] )
    ~inline_tests:true ~library_flags:[ "-linkall" ] ;

  (* ============================================================ *)
  (* Tier 3: Virtual modules                                      *)
  (* ============================================================ *)

  (* -- mina_version ----------------------------------------------- *)
  library "mina_version" ~path:"src/lib/mina_version" ~deps:[ core_kernel ]
    ~ppx:Ppx.minimal ~virtual_modules:[ "mina_version" ]
    ~default_implementation:"mina_version.normal" ;

  (* -- mina_version.normal ---------------------------------------- *)
  library "mina_version.normal" ~internal_name:"mina_version_normal"
    ~path:"src/lib/mina_version/normal" ~deps:[ base; core_kernel ]
    ~ppx:Ppx.minimal ~implements:"mina_version"
    ~extra_stanzas:
      [ "rule"
        @: [ "targets" @: [ atom "mina_version.ml" ]
           ; "deps"
             @: [ "sandbox" @: [ atom "none" ]
                ; list [ atom ":<"; atom "gen.sh" ]
                ; list [ atom "universe" ]
                ]
           ; "action"
             @: [ "run" @: [ atom "bash"; atom "%{<}"; atom "%{targets}" ] ]
           ]
      ] ;

  (* ============================================================ *)
  (* Tier 4: Edge cases                                           *)
  (* ============================================================ *)

  (* -- child_processes -------------------------------------------- *)
  library "child_processes" ~path:"src/lib/child_processes"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_internalhash_types
      ; base_caml
      ; core
      ; core_kernel
      ; ctypes
      ; ctypes_foreign
      ; integers
      ; ppx_hash_runtime_lib
      ; ppx_inline_test_config
      ; sexplib0
      ; local "error_json"
      ; local "logger"
      ; local "mina_stdlib_unix"
      ; local "pipe_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_assert"
         ; "ppx_custom_printf"
         ; "ppx_deriving.show"
         ; "ppx_here"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_pipebang"
         ; "ppx_version"
         ] )
    ~inline_tests:true
    ~foreign_stubs:("c", [ "caml_syslimits" ]) ;

  (* -- mina_base -------------------------------------------------- *)
  library "mina_base" ~path:"src/lib/mina_base"
    ~synopsis:"Snarks and friends necessary for keypair generation"
    ~deps:
      [ async_kernel
      ; base
      ; base_internalhash_types
      ; base_caml
      ; base_quickcheck
      ; base_quickcheck_ppx
      ; bin_prot_shape
      ; core_kernel
      ; core_kernel_uuid
      ; digestif
      ; integers
      ; ppx_inline_test_config
      ; result
      ; sexp_diff_kernel
      ; sexplib0
      ; yojson
      ; local "base58_check"
      ; local "bignum_bigint"
      ; local "blake2"
      ; local "block_time"
      ; local "codable"
      ; local "crypto_params"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "dummy_values"
      ; local "error_json"
      ; local "fields_derivers.graphql"
      ; local "fields_derivers.json"
      ; local "fields_derivers.zkapps"
      ; local "fold_lib"
      ; local "genesis_constants"
      ; local "hash_prefix_create"
      ; local "hash_prefix_states"
      ; local "hex"
      ; local "kimchi_backend"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "mina_base.import"
      ; local "mina_base.util"
      ; local "mina_numbers"
      ; local "mina_signature_kind"
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ; local "one_or_two"
      ; local "outside_hash_image"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "ppx_version.runtime"
      ; local "proof_cache_tag"
      ; local "protocol_version"
      ; local "quickcheck_lib"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "rosetta_coding"
      ; local "run_in_thread"
      ; local "sgn"
      ; local "sgn_type"
      ; local "signature_lib"
      ; local "snark_bits"
      ; local "snark_params"
      ; local "snarky.backendless"
      ; local "sparse_ledger_lib"
      ; local "test_util"
      ; local "unsigned_extended"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "base_quickcheck.ppx_quickcheck"
         ; "h_list.ppx"
         ; "ppx_annot"
         ; "ppx_assert"
         ; "ppx_base"
         ; "ppx_bench"
         ; "ppx_bin_prot"
         ; "ppx_compare"
         ; "ppx_custom_printf"
         ; "ppx_deriving.enum"
         ; "ppx_deriving.make"
         ; "ppx_deriving.ord"
         ; "ppx_deriving_yojson"
         ; "ppx_fields_conv"
         ; "ppx_here"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_pipebang"
         ; "ppx_sexp_conv"
         ; "ppx_snarky"
         ; "ppx_variants_conv"
         ; "ppx_version"
         ] )
    ~inline_tests:true ~library_flags:[ "-linkall" ] ;

  (* -- mina_base.import (sub-library) ----------------------------- *)
  library "mina_base.import" ~internal_name:"mina_base_import"
    ~path:"src/lib/mina_base/import"
    ~deps:[ local "signature_lib" ]
    ~ppx:Ppx.minimal ;

  (* -- mina_base.util (sub-library) ------------------------------- *)
  library "mina_base.util" ~internal_name:"mina_base_util"
    ~path:"src/lib/mina_base/util"
    ~deps:[ core_kernel; local "bignum_bigint"; local "snark_params" ]
    ~ppx:Ppx.minimal ;

  ()
