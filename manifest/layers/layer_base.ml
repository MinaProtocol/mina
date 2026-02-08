(** Mina Base libraries: trivial, moderate, virtual modules, and edge cases.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let hex =
  library "hex" ~path:"src/lib/hex" ~deps:[ core_kernel ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version; Ppx_lib.ppx_inline_test ] )
    ~inline_tests:true

let monad_lib =
  library "monad_lib" ~path:"src/lib/monad_lib" ~deps:[ core_kernel ]
    ~ppx:Ppx.standard

let with_hash =
  library "with_hash" ~path:"src/lib/with_hash"
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; core_kernel
      ; sexplib0
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_annot
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_fields_conv
         ] )

let allocation_functor =
  library "allocation_functor" ~path:"src/lib/allocation_functor"
    ~deps:
      [ core_kernel
      ; result
      ; ppx_inline_test_config
      ; sexplib0
      ; local "mina_metrics"
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_version
         ] )
    ~inline_tests:true

let codable =
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
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_yojson; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ] )
    ~inline_tests:true ~library_flags:[ "-linkall" ]

let comptime =
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
      ]

let error_json =
  library "error_json" ~path:"src/lib/error_json"
    ~deps:[ base; sexplib; sexplib0; yojson ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_deriving_yojson; Ppx_lib.ppx_version ])

let integers_stubs_js =
  library "integers_stubs_js" ~path:"src/lib/integers_stubs_js"
    ~deps:[ zarith_stubs_js ] ~ppx:Ppx.minimal
    ~js_of_ocaml:
      ("js_of_ocaml" @: [ "javascript_files" @: [ atom "./runtime.js" ] ])

let key_value_database =
  library "key_value_database" ~path:"src/lib/key_value_database"
    ~synopsis:"Collection of key-value databases used in Coda"
    ~deps:[ core_kernel ] ~ppx:Ppx.standard ~library_flags:[ "-linkall" ]

let linked_tree =
  library "linked_tree" ~path:"src/lib/linked_tree"
    ~deps:[ core_kernel; local "mina_numbers" ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_compare ] )

let logproc_lib =
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
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_deriving_std ] )
    ~inline_tests:true

let interpolator_lib =
  library "interpolator_lib" ~path:"src/lib/logproc_lib"
    ~modules:[ "interpolator" ]
    ~deps:[ core_kernel; yojson; angstrom ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_deriving_std ] )
    ~inline_tests:true

let () =
  file_stanzas ~path:"src/lib/mina_wire_types"
    [ "include_subdirs" @: [ atom "unqualified" ] ]

let mina_wire_types =
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
      [ "documentation" @: [ "package" @: [ atom "mina_wire_types" ] ] ]

let one_or_two =
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
         [ Ppx_lib.ppx_base
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_let
         ] )

let otp_lib =
  library "otp_lib" ~path:"src/lib/otp_lib"
    ~deps:[ core_kernel; async_kernel; ppx_inline_test_config; local "pipe_lib" ]
    ~ppx:Ppx.standard ~inline_tests:true

let participating_state =
  library "participating_state" ~path:"src/lib/participating_state"
    ~deps:[ async_kernel; core_kernel; base ]
    ~ppx:Ppx.minimal

let perf_histograms =
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
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~inline_tests:true

let rosetta_coding =
  library "rosetta_coding" ~path:"src/lib/rosetta_coding"
    ~synopsis:"Encoders and decoders for Rosetta" ~library_flags:[ "-linkall" ]
    ~deps:
      [ base
      ; core_kernel
      ; local "mina_stdlib"
      ; local "signature_lib"
      ; local "snark_params"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_assert; Ppx_lib.ppx_let ])

let rosetta_models =
  library "rosetta_models" ~path:"src/lib/rosetta_models"
    ~deps:[ ppx_deriving_yojson_runtime; yojson ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_deriving_eq
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_version
         ] )

let sgn_type =
  library "sgn_type" ~path:"src/lib/sgn_type"
    ~deps:
      [ core_kernel
      ; ppx_deriving_yojson_runtime
      ; yojson
      ; sexplib0
      ; bin_prot_shape
      ; base_caml
      ; ppx_version_runtime
      ; mina_wire_types
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let structured_log_events =
  library "structured_log_events" ~path:"src/lib/structured_log_events"
    ~synopsis:"Events, logging and parsing" ~library_flags:[ "-linkall" ]
    ~deps:[ core_kernel; yojson; sexplib0; interpolator_lib ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_inline_test
         ] )
    ~inline_tests:true

let sync_status =
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
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_enumerate
         ] )

let unsigned_extended =
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
      ; Layer_test.test_util
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~inline_tests:true

let visualization =
  library "visualization" ~path:"src/lib/visualization"
    ~deps:[ core_kernel; async_kernel; ocamlgraph; yojson; sexplib0 ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_sexp_conv
         ] )

let webkit_trace_event =
  library "webkit_trace_event" ~path:"src/lib/webkit_trace_event"
    ~synopsis:"Binary and JSON output of WebKit trace events"
    ~deps:[ core_kernel; base ] ~ppx:Ppx.minimal

let webkit_trace_event_binary =
  library "webkit_trace_event.binary"
    ~internal_name:"webkit_trace_event_binary_output"
    ~path:"src/lib/webkit_trace_event/binary_output"
    ~deps:[ core; async; base; core_kernel; async_unix; webkit_trace_event ]
    ~ppx:Ppx.minimal

let graphql_basic_scalars =
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
      ; Layer_test.quickcheck_lib
      ; local "unix"
      ]
    ~ppx:Ppx.standard ~inline_tests:true

let graphql_wrapper =
  library "graphql_wrapper" ~path:"src/lib/graphql_wrapper"
    ~deps:[ graphql; graphql_async; graphql_parser ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_version
         ] )

let mina_compile_config =
  library "mina_compile_config" ~path:"src/lib/mina_compile_config"
    ~deps:
      [ Layer_node.mina_node_config
      ; Layer_node.mina_node_config_for_unit_tests
      ; core_kernel
      ; local "currency"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_base; Ppx_lib.ppx_deriving_yojson ] )

let storage =
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
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:Ppx.standard ~inline_tests:true

let mina_stdlib =
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
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let mina_stdlib_unix =
  library "mina_stdlib_unix" ~path:"src/lib/mina_stdlib_unix"
    ~synopsis:"Mina standard library Unix utilities"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async; async_kernel; async_unix; core; core_kernel; ptime; local "logger" ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_here
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let mina_numbers =
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
      ; mina_wire_types
      ; local "bignum_bigint"
      ; local "pickles"
      ; codable
      ; local "snarky.backendless"
      ; local "fold_lib"
      ; local "tuple_lib"
      ; Layer_snarky.snark_bits
      ; local "snark_params"
      ; unsigned_extended
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "bitstring_lib"
      ; Layer_test.test_util
      ; local "kimchi_backend_common"
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_assert
         ] )

let base58_check =
  library "base58_check" ~path:"src/lib/base58_check"
    ~synopsis:"Base58Check implementation"
    ~deps:[ base; base58; core_kernel; digestif; ppx_inline_test_config ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )
    ~inline_tests:true ~library_flags:[ "-linkall" ]

let currency =
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
      ; codable
      ; local "kimchi_backend_common"
      ; local "mina_numbers"
      ; mina_wire_types
      ; local "pickles"
      ; Layer_ppx.ppx_version_runtime
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "sgn"
      ; Layer_snarky.snark_bits
      ; local "snark_params"
      ; local "snarky.backendless"
      ; Layer_test.test_util
      ; unsigned_extended
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_annot
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )
    ~inline_tests:true ~library_flags:[ "-linkall" ]

let mina_version =
  library "mina_version" ~path:"src/lib/mina_version" ~deps:[ core_kernel ]
    ~ppx:Ppx.minimal ~virtual_modules:[ "mina_version" ]
    ~default_implementation:"mina_version.normal"

let mina_version_normal =
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
      ]

let mina_version_dummy =
  library "mina_version.dummy" ~internal_name:"mina_version_dummy"
    ~path:"src/lib/mina_version/dummy" ~deps:[ core_kernel; base ]
    ~ppx:Ppx.minimal ~implements:"mina_version"

let mina_version_runtime =
  library "mina_version.runtime" ~internal_name:"mina_version_runtime"
    ~path:"src/lib/mina_version/runtime"
    ~deps:[ core_kernel; base; unix ]
    ~ppx:Ppx.minimal ~implements:"mina_version"

let child_processes =
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
      ; error_json
      ; local "logger"
      ; local "mina_stdlib_unix"
      ; local "pipe_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_pipebang
         ; Ppx_lib.ppx_version
         ] )
    ~inline_tests:true
    ~foreign_stubs:("c", [ "caml_syslimits" ])

let mina_base =
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
      ; base58_check
      ; local "bignum_bigint"
      ; local "blake2"
      ; local "block_time"
      ; codable
      ; local "crypto_params"
      ; currency
      ; local "data_hash_lib"
      ; local "dummy_values"
      ; error_json
      ; local "fields_derivers_graphql"
      ; local "fields_derivers_json"
      ; local "fields_derivers_zkapps"
      ; local "fold_lib"
      ; local "genesis_constants"
      ; local "hash_prefix_create"
      ; local "hash_prefix_states"
      ; hex
      ; local "kimchi_backend"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta_basic"
      ; local "mina_base_import"
      ; local "mina_base_util"
      ; local "mina_numbers"
      ; local "mina_signature_kind"
      ; mina_stdlib
      ; mina_wire_types
      ; one_or_two
      ; local "outside_hash_image"
      ; local "pickles"
      ; local "pickles_backend"
      ; local "pickles_types"
      ; Layer_ppx.ppx_version_runtime
      ; local "proof_cache_tag"
      ; local "protocol_version"
      ; Layer_test.quickcheck_lib
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; rosetta_coding
      ; local "run_in_thread"
      ; local "sgn"
      ; sgn_type
      ; local "signature_lib"
      ; Layer_snarky.snark_bits
      ; local "snark_params"
      ; local "snarky.backendless"
      ; local "sparse_ledger_lib"
      ; Layer_test.test_util
      ; unsigned_extended
      ; with_hash
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.base_quickcheck_ppx_quickcheck
         ; Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_annot
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_bench
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_enum
         ; Ppx_lib.ppx_deriving_make
         ; Ppx_lib.ppx_deriving_ord
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_pipebang
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_variants_conv
         ; Ppx_lib.ppx_version
         ] )
    ~inline_tests:true ~library_flags:[ "-linkall" ]

let mina_base_import =
  library "mina_base.import" ~internal_name:"mina_base_import"
    ~path:"src/lib/mina_base/import"
    ~deps:[ local "signature_lib" ]
    ~ppx:Ppx.minimal

let mina_base_util =
  library "mina_base.util" ~internal_name:"mina_base_util"
    ~path:"src/lib/mina_base/util"
    ~deps:[ core_kernel; local "bignum_bigint"; local "snark_params" ]
    ~ppx:Ppx.minimal
