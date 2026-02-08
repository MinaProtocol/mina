(** Mina product: library and executable declarations.

    Each declaration here corresponds to a dune file in the
    source tree. The manifest generates these files from
    the declarations below. *)

open Manifest
open Dune_s_expr

let register () =
  (* ============================================================ *)
  (* Tier 1: Trivial libraries                                    *)
  (* ============================================================ *)

  (* -- hex -------------------------------------------------------- *)
  library "hex"
    ~path:"src/lib/hex"
    ~deps:[ opam "core_kernel" ]
    ~ppx:(Ppx.custom
            [ "ppx_jane"; "ppx_version"; "ppx_inline_test" ])
    ~inline_tests:true;

  (* -- monad_lib -------------------------------------------------- *)
  library "monad_lib"
    ~path:"src/lib/monad_lib"
    ~deps:[ opam "core_kernel" ]
    ~ppx:Ppx.standard;

  (* -- with_hash -------------------------------------------------- *)
  library "with_hash"
    ~path:"src/lib/with_hash"
    ~deps:
      [ opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_annot"; "ppx_jane"; "ppx_deriving_yojson"
         ; "ppx_deriving.std"; "ppx_version"
         ; "ppx_fields_conv"
         ]);

  (* -- pipe_lib --------------------------------------------------- *)
  library "pipe_lib"
    ~path:"src/lib/concurrency/pipe_lib"
    ~deps:
      [ opam "async_kernel"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib"
      ; local "logger"
      ; local "o1trace"
      ; local "run_in_thread"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"; "ppx_version"; "ppx_jane"
         ; "ppx_deriving.make"
         ])
    ~inline_tests:true;

  (* -- allocation_functor --------------------------------------- *)
  library "allocation_functor"
    ~path:"src/lib/allocation_functor"
    ~deps:
      [ opam "core_kernel"
      ; opam "result"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; local "mina_metrics"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_compare"
         ; "ppx_deriving_yojson"; "ppx_version"
         ])
    ~inline_tests:true;

  (* -- codable -------------------------------------------------- *)
  library "codable"
    ~path:"src/lib/codable"
    ~synopsis:
      "Extension of Yojson to make it easy for a type to \
       derive yojson"
    ~deps:
      [ opam "base64"
      ; opam "core_kernel"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; opam "yojson"
      ; local "base58_check"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving_yojson"; "ppx_jane"; "ppx_version" ])
    ~inline_tests:true
    ~library_flags:[ "-linkall" ];

  (* -- comptime ------------------------------------------------- *)
  library "comptime"
    ~path:"src/lib/comptime"
    ~deps:[ opam "core_kernel"; opam "base" ]
    ~ppx:Ppx.minimal
    ~extra_stanzas:
      [ "rule"
        @: [ "target" @: [ atom "comptime.ml" ]
           ; "deps"
             @: [ list [ atom ":<"; atom "gen.sh" ]
                ; list [ atom "universe" ]
                ]
           ; "action"
             @: [ "run"
                  @: [ atom "bash"
                     ; atom "%{<}"
                     ; atom "%{target}"
                     ]
                ]
           ]
      ];

  (* -- error_json ----------------------------------------------- *)
  library "error_json"
    ~path:"src/lib/error_json"
    ~deps:
      [ opam "base"
      ; opam "sexplib"
      ; opam "sexplib0"
      ; opam "yojson"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving_yojson"; "ppx_version" ]);

  (* -- integers_stubs_js ---------------------------------------- *)
  library "integers_stubs_js"
    ~path:"src/lib/integers_stubs_js"
    ~deps:[ opam "zarith_stubs_js" ]
    ~ppx:Ppx.minimal
    ~js_of_ocaml:
      ("js_of_ocaml"
       @: [ "javascript_files"
            @: [ atom "./runtime.js" ] ]);

  (* -- key_value_database --------------------------------------- *)
  library "key_value_database"
    ~path:"src/lib/key_value_database"
    ~synopsis:
      "Collection of key-value databases used in Coda"
    ~deps:[ opam "core_kernel" ]
    ~ppx:Ppx.standard
    ~library_flags:[ "-linkall" ];

  (* -- linked_tree ---------------------------------------------- *)
  library "linked_tree"
    ~path:"src/lib/linked_tree"
    ~deps:
      [ opam "core_kernel"
      ; local "mina_numbers"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_compare" ]);

  (* -- logproc_lib ---------------------------------------------- *)
  library "logproc_lib"
    ~path:"src/lib/logproc_lib"
    ~modules:[ "logproc_lib"; "filter" ]
    ~deps:
      [ opam "core_kernel"
      ; opam "yojson"
      ; opam "angstrom"
      ; opam "re2"
      ; opam "ppx_inline_test.config"
      ; local "interpolator_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_deriving.std" ])
    ~inline_tests:true;

  (* -- interpolator_lib ----------------------------------------- *)
  library "interpolator_lib"
    ~path:"src/lib/logproc_lib"
    ~modules:[ "interpolator" ]
    ~deps:
      [ opam "core_kernel"
      ; opam "yojson"
      ; opam "angstrom"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_deriving.std" ])
    ~inline_tests:true;

  (* -- mina_wire_types ------------------------------------------ *)
  file_stanzas ~path:"src/lib/mina_wire_types"
    [ "include_subdirs" @: [ atom "unqualified" ] ];
  library "mina_wire_types"
    ~path:"src/lib/mina_wire_types"
    ~deps:
      [ opam "integers"
      ; opam "pasta_bindings"
      ; opam "kimchi_types"
      ; opam "kimchi_bindings"
      ; local "blake2"
      ]
    ~ppx:Ppx.minimal
    ~extra_stanzas:
      [ "documentation"
        @: [ "package" @: [ atom "mina_wire_types" ] ]
      ];

  (* -- one_or_two ----------------------------------------------- *)
  library "one_or_two"
    ~path:"src/lib/one_or_two"
    ~flags:[ atom ":standard"; atom "-short-paths" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "bin_prot.shape"
      ; opam "base"
      ; opam "async_kernel"
      ; opam "core_kernel"
      ; opam "ppx_hash.runtime-lib"
      ; opam "sexplib0"
      ; opam "base.caml"
      ; opam "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_base"; "ppx_bin_prot"; "ppx_version"
         ; "ppx_deriving.std"; "ppx_deriving_yojson"
         ; "ppx_let"
         ]);

  (* -- otp_lib -------------------------------------------------- *)
  library "otp_lib"
    ~path:"src/lib/otp_lib"
    ~deps:
      [ opam "core_kernel"
      ; opam "async_kernel"
      ; opam "ppx_inline_test.config"
      ; local "pipe_lib"
      ]
    ~ppx:Ppx.standard
    ~inline_tests:true;

  (* -- participating_state -------------------------------------- *)
  library "participating_state"
    ~path:"src/lib/participating_state"
    ~deps:
      [ opam "async_kernel"
      ; opam "core_kernel"
      ; opam "base"
      ]
    ~ppx:Ppx.minimal;

  (* -- perf_histograms ------------------------------------------ *)
  library "perf_histograms"
    ~path:"src/lib/perf_histograms"
    ~synopsis:"Performance monitoring with histograms"
    ~modules:
      [ "perf_histograms0"; "perf_histograms"
      ; "histogram"; "rpc"; "intf"
      ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "bin_prot.shape"
      ; opam "async_rpc_kernel"
      ; opam "yojson"
      ; opam "async"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "async.async_rpc"
      ; opam "base.caml"
      ; opam "async_kernel"
      ; local "mina_metrics"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_compare"
         ; "ppx_deriving_yojson"
         ])
    ~inline_tests:true;

  (* -- proof_cache_tag ------------------------------------------ *)
  library "proof_cache_tag"
    ~path:"src/lib/proof_cache_tag"
    ~deps:
      [ opam "core_kernel"
      ; opam "async_kernel"
      ; local "logger"
      ; local "disk_cache"
      ; local "pickles"
      ]
    ~ppx:Ppx.mina;

  (* -- rosetta_coding ------------------------------------------- *)
  library "rosetta_coding"
    ~path:"src/lib/rosetta_coding"
    ~synopsis:"Encoders and decoders for Rosetta"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "base"
      ; opam "core_kernel"
      ; local "mina_stdlib"
      ; local "signature_lib"
      ; local "snark_params"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_assert"; "ppx_let" ]);

  (* -- rosetta_models ------------------------------------------- *)
  library "rosetta_models"
    ~path:"src/lib/rosetta_models"
    ~deps:
      [ opam "ppx_deriving_yojson.runtime"
      ; opam "yojson"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving_yojson"; "ppx_deriving.eq"
         ; "ppx_deriving.show"; "ppx_version"
         ]);

  (* -- sgn_type ------------------------------------------------- *)
  library "sgn_type"
    ~path:"src/lib/sgn_type"
    ~deps:
      [ opam "core_kernel"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "yojson"
      ; opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "ppx_version.runtime"
      ; local "mina_wire_types"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_version"; "ppx_compare"
         ; "ppx_deriving_yojson"
         ]);

  (* -- structured_log_events ------------------------------------ *)
  library "structured_log_events"
    ~path:"src/lib/structured_log_events"
    ~synopsis:"Events, logging and parsing"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "core_kernel"
      ; opam "yojson"
      ; opam "sexplib0"
      ; local "interpolator_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_deriving.std"
         ; "ppx_deriving_yojson"; "ppx_inline_test"
         ])
    ~inline_tests:true;

  (* -- sync_status ---------------------------------------------- *)
  library "sync_status"
    ~path:"src/lib/sync_status"
    ~synopsis:"Different kinds of status for Coda "
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_version"
         ; "ppx_deriving_yojson"; "ppx_enumerate"
         ]);

  (* -- unsigned_extended ---------------------------------------- *)
  library "unsigned_extended"
    ~path:"src/lib/unsigned_extended"
    ~synopsis:"Unsigned integer functions"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "base.caml"
      ; opam "result"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "sexplib0"
      ; opam "bignum.bigint"
      ; opam "base.base_internalhash_types"
      ; opam "bin_prot.shape"
      ; opam "ppx_inline_test.config"
      ; local "bignum_bigint"
      ; local "snark_params"
      ; local "test_util"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"; "ppx_version"; "ppx_bin_prot"
         ; "ppx_sexp_conv"; "ppx_compare"; "ppx_hash"
         ; "ppx_inline_test"; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ])
    ~inline_tests:true;

  (* -- visualization -------------------------------------------- *)
  library "visualization"
    ~path:"src/lib/visualization"
    ~deps:
      [ opam "core_kernel"
      ; opam "async_kernel"
      ; opam "ocamlgraph"
      ; opam "yojson"
      ; opam "sexplib0"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"
         ; "ppx_deriving_yojson"; "ppx_sexp_conv"
         ]);

  (* -- webkit_trace_event --------------------------------------- *)
  library "webkit_trace_event"
    ~path:"src/lib/webkit_trace_event"
    ~synopsis:
      "Binary and JSON output of WebKit trace events"
    ~deps:[ opam "core_kernel"; opam "base" ]
    ~ppx:Ppx.minimal;

  (* -- webkit_trace_event.binary -------------------------------- *)
  library "webkit_trace_event.binary"
    ~internal_name:"webkit_trace_event_binary_output"
    ~path:"src/lib/webkit_trace_event/binary_output"
    ~deps:
      [ opam "core"
      ; opam "async"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "async_unix"
      ; local "webkit_trace_event"
      ]
    ~ppx:Ppx.minimal;

  (* -- graphql_basic_scalars ------------------------------------ *)
  library "graphql_basic_scalars"
    ~path:"src/lib/graphql_basic_scalars"
    ~deps:
      [ opam "async"
      ; opam "async_unix"
      ; opam "async_kernel"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "core"
      ; opam "graphql"
      ; opam "graphql-async"
      ; opam "graphql_parser"
      ; opam "yojson"
      ; opam "sexplib0"
      ; local "base_quickcheck"
      ; local "graphql_wrapper"
      ; local "quickcheck_lib"
      ; local "unix"
      ]
    ~ppx:Ppx.standard
    ~inline_tests:true;

  (* -- graphql_wrapper ------------------------------------------ *)
  library "graphql_wrapper"
    ~path:"src/lib/graphql_wrapper"
    ~deps:
      [ opam "graphql"
      ; opam "graphql-async"
      ; opam "graphql_parser"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving.show"; "ppx_deriving_yojson"
         ; "ppx_version"
         ]);

  (* -- mina_compile_config -------------------------------------- *)
  library "mina_compile_config"
    ~path:"src/lib/mina_compile_config"
    ~deps:
      [ local "mina_node_config"
      ; local "mina_node_config.for_unit_tests"
      ; opam "core_kernel"
      ; local "currency"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_base"
         ; "ppx_deriving_yojson"
         ]);

  (* -- ppx_annot ------------------------------------------------ *)
  library "ppx_annot"
    ~path:"src/lib/ppx_annot"
    ~kind:"ppx_deriver"
    ~deps:
      [ opam "ppxlib"
      ; opam "core_kernel"
      ; opam "base"
      ; opam "compiler-libs"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppxlib.metaquot" ]);

  (* -- ppx_register_event --------------------------------------- *)
  library "ppx_register_event"
    ~path:"src/lib/ppx_register_event"
    ~kind:"ppx_deriver"
    ~deps:
      [ opam "ocaml-compiler-libs.common"
      ; opam "ppxlib.ast"
      ; opam "ppx_deriving_yojson"
      ; opam "core_kernel"
      ; opam "ppxlib"
      ; opam "compiler-libs.common"
      ; opam "ocaml-migrate-parsetree"
      ; opam "base"
      ; local "interpolator_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppxlib.metaquot" ])
    ~ppx_runtime_libraries:
      [ "structured_log_events"; "yojson" ];

  (* -- ppx_version ---------------------------------------------- *)
  file_stanzas ~path:"src/lib/ppx_version"
    [ "vendored_dirs" @: [ atom "test" ] ];
  library "ppx_version"
    ~path:"src/lib/ppx_version"
    ~kind:"ppx_deriver"
    ~no_instrumentation:true
    ~deps:
      [ opam "compiler-libs.common"
      ; opam "ppxlib"
      ; opam "ppxlib.astlib"
      ; opam "ppx_derivers"
      ; opam "ppx_bin_prot"
      ; opam "base"
      ; opam "base.caml"
      ; opam "core_kernel"
      ; opam "ppx_version.runtime"
      ; opam "bin_prot"
      ]
    ~ppx:
      (Ppx.custom [ "ppx_compare"; "ppxlib.metaquot" ]);

  (* -- ppx_version.runtime -------------------------------------- *)
  library "ppx_version.runtime"
    ~internal_name:"ppx_version_runtime"
    ~path:"src/lib/ppx_version/runtime"
    ~no_instrumentation:true
    ~deps:
      [ opam "base"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "bin_prot"
      ; opam "bin_prot.shape"
      ];

  (* -- ppx_mina ------------------------------------------------- *)
  file_stanzas ~path:"src/lib/ppx_mina"
    [ "vendored_dirs" @: [ atom "tests" ] ];
  library "ppx_mina"
    ~path:"src/lib/ppx_mina"
    ~kind:"ppx_deriver"
    ~deps:
      [ opam "ppx_deriving.api"
      ; opam "ppxlib"
      ; opam "ppx_bin_prot"
      ; opam "core_kernel"
      ; opam "base"
      ; opam "base.caml"
      ; local "ppx_representatives"
      ; local "ppx_register_event"
      ; local "ppx_to_enum"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppxlib.metaquot" ]);

  (* -- ppx_to_enum ---------------------------------------------- *)
  library "ppx_to_enum"
    ~path:"src/lib/ppx_mina/ppx_to_enum"
    ~kind:"ppx_deriver"
    ~deps:
      [ opam "compiler-libs.common"
      ; opam "ppxlib"
      ; opam "base"
      ]
    ~ppx:(Ppx.custom [ "ppxlib.metaquot" ]);

  (* -- ppx_representatives -------------------------------------- *)
  library "ppx_representatives"
    ~path:"src/lib/ppx_mina/ppx_representatives"
    ~kind:"ppx_deriver"
    ~deps:
      [ opam "ppxlib.ast"
      ; opam "ocaml-compiler-libs.common"
      ; opam "compiler-libs.common"
      ; opam "ppxlib"
      ; opam "base"
      ]
    ~ppx:(Ppx.custom [ "ppxlib.metaquot" ])
    ~ppx_runtime_libraries:
      [ "ppx_representatives.runtime" ];

  (* -- ppx_representatives.runtime ------------------------------ *)
  library "ppx_representatives.runtime"
    ~internal_name:"ppx_representatives_runtime"
    ~path:"src/lib/ppx_mina/ppx_representatives/runtime"
    ~no_instrumentation:true;

  (* -- ppx_mina/tests ------------------------------------------- *)
  private_library "unexpired"
    ~path:"src/lib/ppx_mina/tests"
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "unexpired" ];
  private_library "define_locally_good"
    ~path:"src/lib/ppx_mina/tests"
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "define_locally_good" ];
  private_library "define_from_scope_good"
    ~path:"src/lib/ppx_mina/tests"
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "define_from_scope_good" ];
  private_library "expired"
    ~path:"src/lib/ppx_mina/tests"
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "expired" ];
  private_library "expiry_in_module"
    ~path:"src/lib/ppx_mina/tests"
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "expiry_in_module" ];
  private_library "expiry_invalid_date"
    ~path:"src/lib/ppx_mina/tests"
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "expiry_invalid_date" ];
  private_library "expiry_invalid_format"
    ~path:"src/lib/ppx_mina/tests"
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "expiry_invalid_format" ];

  (* -- storage -------------------------------------------------- *)
  library "storage"
    ~path:"src/lib/storage"
    ~synopsis:
      "Storage module checksums data and stores it"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "core"
      ; opam "async"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "bin_prot"
      ; opam "base"
      ; opam "sexplib0"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base.caml"
      ; local "logger"
      ; local "ppx_version.runtime"
      ]
    ~ppx:Ppx.standard
    ~inline_tests:true;

  (* ============================================================ *)
  (* Tier 2: Moderate libraries                                   *)
  (* ============================================================ *)

  (* -- base58_check ----------------------------------------------- *)
  library "base58_check"
    ~path:"src/lib/base58_check"
    ~synopsis:"Base58Check implementation"
    ~deps:
      [ opam "base"
      ; opam "base58"
      ; opam "core_kernel"
      ; opam "digestif"
      ; opam "ppx_inline_test.config"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_assert"; "ppx_base"; "ppx_deriving.std"
         ; "ppx_deriving_yojson"; "ppx_inline_test"
         ; "ppx_let"; "ppx_sexp_conv"; "ppx_version"
         ])
    ~inline_tests:true
    ~library_flags:[ "-linkall" ];

  (* -- currency --------------------------------------------------- *)
  library "currency"
    ~path:"src/lib/currency"
    ~synopsis:"Currency types"
    ~deps:
      [ opam "base"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "ppx_inline_test.config"
      ; opam "result"
      ; opam "sexplib0"
      ; opam "zarith"
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
         [ "h_list.ppx"; "ppx_annot"; "ppx_assert"
         ; "ppx_bin_prot"; "ppx_compare"
         ; "ppx_custom_printf"; "ppx_deriving.std"
         ; "ppx_deriving_yojson"; "ppx_fields_conv"
         ; "ppx_hash"; "ppx_inline_test"; "ppx_let"
         ; "ppx_mina"; "ppx_sexp_conv"; "ppx_version"
         ])
    ~inline_tests:true
    ~library_flags:[ "-linkall" ];

  (* ============================================================ *)
  (* Tier 3: Virtual modules                                      *)
  (* ============================================================ *)

  (* -- mina_version ----------------------------------------------- *)
  library "mina_version"
    ~path:"src/lib/mina_version"
    ~deps:[ opam "core_kernel" ]
    ~ppx:Ppx.minimal
    ~virtual_modules:[ "mina_version" ]
    ~default_implementation:"mina_version.normal";

  (* -- mina_version.normal ---------------------------------------- *)
  library "mina_version.normal"
    ~internal_name:"mina_version_normal"
    ~path:"src/lib/mina_version/normal"
    ~deps:
      [ opam "base"
      ; opam "core_kernel"
      ]
    ~ppx:Ppx.minimal
    ~implements:"mina_version"
    ~extra_stanzas:
      [ "rule"
        @: [ "targets" @: [ atom "mina_version.ml" ]
           ; "deps"
             @: [ "sandbox" @: [ atom "none" ]
                ; list [ atom ":<"; atom "gen.sh" ]
                ; list [ atom "universe" ]
                ]
           ; "action"
             @: [ "run"
                  @: [ atom "bash"
                     ; atom "%{<}"
                     ; atom "%{targets}"
                     ]
                ]
           ]
      ];

  (* ============================================================ *)
  (* Tier 4: Edge cases                                           *)
  (* ============================================================ *)

  (* -- child_processes -------------------------------------------- *)
  library "child_processes"
    ~path:"src/lib/child_processes"
    ~deps:
      [ opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ctypes"
      ; opam "ctypes.foreign"
      ; opam "integers"
      ; opam "ppx_hash.runtime-lib"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; local "error_json"
      ; local "logger"
      ; local "mina_stdlib_unix"
      ; local "pipe_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_assert"; "ppx_custom_printf"
         ; "ppx_deriving.show"; "ppx_here"
         ; "ppx_inline_test"; "ppx_let"; "ppx_mina"
         ; "ppx_pipebang"; "ppx_version"
         ])
    ~inline_tests:true
    ~foreign_stubs:("c", [ "caml_syslimits" ]);

  (* -- mina_base -------------------------------------------------- *)
  library "mina_base"
    ~path:"src/lib/mina_base"
    ~synopsis:
      "Snarks and friends necessary for keypair generation"
    ~deps:
      [ opam "async_kernel"
      ; opam "base"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "base_quickcheck"
      ; opam "base_quickcheck.ppx_quickcheck"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "core_kernel.uuid"
      ; opam "digestif"
      ; opam "integers"
      ; opam "ppx_inline_test.config"
      ; opam "result"
      ; opam "sexp_diff_kernel"
      ; opam "sexplib0"
      ; opam "yojson"
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
         [ "base_quickcheck.ppx_quickcheck"; "h_list.ppx"
         ; "ppx_annot"; "ppx_assert"; "ppx_base"
         ; "ppx_bench"; "ppx_bin_prot"; "ppx_compare"
         ; "ppx_custom_printf"; "ppx_deriving.enum"
         ; "ppx_deriving.make"; "ppx_deriving.ord"
         ; "ppx_deriving_yojson"; "ppx_fields_conv"
         ; "ppx_here"; "ppx_inline_test"; "ppx_let"
         ; "ppx_mina"; "ppx_pipebang"; "ppx_sexp_conv"
         ; "ppx_snarky"; "ppx_variants_conv"
         ; "ppx_version"
         ])
    ~inline_tests:true
    ~library_flags:[ "-linkall" ];

  (* -- mina_base.import (sub-library) ----------------------------- *)
  library "mina_base.import"
    ~internal_name:"mina_base_import"
    ~path:"src/lib/mina_base/import"
    ~deps:[ local "signature_lib" ]
    ~ppx:Ppx.minimal;

  (* -- mina_base.util (sub-library) ------------------------------- *)
  library "mina_base.util"
    ~internal_name:"mina_base_util"
    ~path:"src/lib/mina_base/util"
    ~deps:
      [ opam "core_kernel"
      ; local "bignum_bigint"
      ; local "snark_params"
      ]
    ~ppx:Ppx.minimal;

  (* ============================================================ *)
  (* Tier 2: Low-level crypto & utilities                         *)
  (* ============================================================ *)

  (* -- mina_stdlib ------------------------------------------------ *)
  library "mina_stdlib"
    ~path:"src/lib/mina_stdlib"
    ~synopsis:"Mina standard library"
    ~inline_tests:true
    ~modules_without_implementation:[ "generic_set"; "sigs" ]
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "a"
             ; atom "-warn-error"; atom "+a" ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ opam "async_kernel"
      ; opam "base.caml"
      ; opam "bin_prot"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "ppx_inline_test.config"
      ; opam "result"
      ; opam "sexplib0"
      ; opam "stdlib"
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
         ]);

  (* -- blake2 ----------------------------------------------------- *)
  library "blake2"
    ~path:"src/lib/crypto/blake2"
    ~inline_tests:true
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "bigarray-compat"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "digestif"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; local "mina_stdlib"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ]);

  (* -- bignum_bigint ---------------------------------------------- *)
  library "bignum_bigint"
    ~path:"src/lib/crypto/bignum_bigint"
    ~synopsis:"Bignum's bigint re-exported as Bignum_bigint"
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "core_kernel"
      ; opam "async_kernel"
      ; opam "bignum.bigint"
      ; local "fold_lib"
      ]
    ~ppx:Ppx.standard;

  (* -- string_sign ------------------------------------------------ *)
  library "string_sign"
    ~path:"src/lib/crypto/string_sign"
    ~synopsis:"Schnorr signatures for strings"
    ~deps:
      [ opam "core_kernel"
      ; opam "result"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "mina_base"
      ; local "mina_signature_kind"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "signature_lib"
      ; local "snark_params"
      ]
    ~ppx:Ppx.mina;

  (* -- snark_keys_header ------------------------------------------ *)
  library "snark_keys_header"
    ~path:"src/lib/crypto/snark_keys_header"
    ~deps:
      [ opam "base"
      ; opam "base.caml"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "result"
      ; opam "sexplib0"
      ; opam "stdio"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_deriving.ord"
         ; "ppx_deriving_yojson"
         ; "ppx_let"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ]);

  (* -- plonkish_prelude ------------------------------------------- *)
  library "plonkish_prelude"
    ~path:"src/lib/crypto/plonkish_prelude"
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a-40..42-44"
             ; atom "-warn-error"; atom "+a" ] ]
    ~modules_without_implementation:[ "sigs"; "poly_types" ]
    ~deps:
      [ opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "result"
      ; opam "sexplib0"
      ; local "mina_stdlib"
      ; local "kimchi_pasta_snarky_backend"
      ; local "mina_wire_types"
      ; local "ppx_version.runtime"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ]);

  (* -- random_oracle_input ---------------------------------------- *)
  library "random_oracle_input"
    ~path:"src/lib/crypto/random_oracle_input"
    ~inline_tests:true
    ~deps:
      [ opam "core_kernel"
      ; opam "sexplib0"
      ; opam "base.caml"
      ; opam "ppx_inline_test.config"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"
         ; "ppx_sexp_conv"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_version"
         ; "ppx_deriving_yojson"
         ]);

  (* -- outside_hash_image ----------------------------------------- *)
  library "outside_hash_image"
    ~path:"src/lib/crypto/outside_hash_image"
    ~deps:[ local "snark_params" ]
    ~ppx:Ppx.minimal;

  (* -- hash_prefixes ---------------------------------------------- *)
  library "hash_prefixes"
    ~path:"src/lib/hash_prefixes"
    ~deps:[ local "mina_signature_kind" ]
    ~ppx:Ppx.minimal;

  (* -- sgn -------------------------------------------------------- *)
  library "sgn"
    ~path:"src/lib/sgn"
    ~synopsis:"sgn library"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_deriving_yojson.runtime"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "sexplib0"
      ; opam "base"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; local "snark_params"
      ; local "sgn_type"
      ; local "pickles"
      ; local "snarky.backendless"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_bin_prot"
         ; "ppx_sexp_conv"
         ; "ppx_compare"
         ; "ppx_hash"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ]);

  (* -- timeout_lib ------------------------------------------------ *)
  library "timeout_lib"
    ~path:"src/lib/timeout_lib"
    ~deps:
      [ opam "core_kernel"
      ; opam "async_kernel"
      ; local "logger"
      ]
    ~ppx:Ppx.mina;

  (* -- quickcheck_lib --------------------------------------------- *)
  library "quickcheck_lib"
    ~path:"src/lib/testing/quickcheck_lib"
    ~inline_tests:true
    ~deps:
      [ opam "core_kernel"
      ; opam "base"
      ; opam "ppx_inline_test.config"
      ; local "currency"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_let"
         ; "ppx_inline_test"
         ; "ppx_custom_printf"
         ]);

  (* -- test_util -------------------------------------------------- *)
  library "test_util"
    ~path:"src/lib/testing/test_util"
    ~synopsis:"test utils"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "core_kernel"
      ; opam "base.caml"
      ; opam "bin_prot"
      ; local "snark_params"
      ; local "fold_lib"
      ; local "snarky.backendless"
      ; local "pickles"
      ; local "crypto_params"
      ]
    ~ppx:
      (Ppx.custom [ "ppx_version"; "ppx_jane"; "ppx_compare" ]);

  (* -- disk_cache.intf -------------------------------------------- *)
  library "disk_cache.intf"
    ~internal_name:"disk_cache_intf"
    ~path:"src/lib/disk_cache/intf"
    ~deps:
      [ opam "core_kernel"
      ; opam "async_kernel"
      ; local "logger"
      ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_version" ]);

  (* -- run_in_thread (virtual) ------------------------------------ *)
  library "run_in_thread"
    ~path:"src/lib/concurrency/run_in_thread"
    ~deps:[ opam "async_kernel" ]
    ~ppx:Ppx.minimal
    ~virtual_modules:[ "run_in_thread" ]
    ~default_implementation:"run_in_thread.native";

  (* -- run_in_thread.native --------------------------------------- *)
  library "run_in_thread.native"
    ~internal_name:"run_in_thread_native"
    ~path:"src/lib/concurrency/run_in_thread/native"
    ~deps:[ opam "async"; opam "async_unix" ]
    ~ppx:Ppx.minimal
    ~implements:"run_in_thread";

  (* -- run_in_thread.fake ----------------------------------------- *)
  library "run_in_thread.fake"
    ~internal_name:"run_in_thread_fake"
    ~path:"src/lib/concurrency/run_in_thread/fake"
    ~deps:[ opam "async_kernel" ]
    ~ppx:Ppx.minimal
    ~implements:"run_in_thread";

  (* -- interruptible ---------------------------------------------- *)
  library "interruptible"
    ~path:"src/lib/concurrency/interruptible"
    ~synopsis:
      "Interruptible monad (deferreds, that can be triggered to cancel)"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "async_kernel"
      ; opam "core_kernel"
      ; local "run_in_thread"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving.std"; "ppx_jane"; "ppx_version" ]);

  (* -- promise (virtual) ------------------------------------------ *)
  library "promise"
    ~path:"src/lib/concurrency/promise"
    ~deps:[ opam "base"; opam "async_kernel" ]
    ~ppx:Ppx.minimal
    ~virtual_modules:[ "promise" ]
    ~default_implementation:"promise.native";

  (* -- promise.native --------------------------------------------- *)
  library "promise.native"
    ~internal_name:"promise_native"
    ~path:"src/lib/concurrency/promise/native"
    ~deps:
      [ opam "base"
      ; opam "async_kernel"
      ; local "run_in_thread"
      ]
    ~ppx:Ppx.minimal
    ~implements:"promise";

  (* -- promise.js ------------------------------------------------- *)
  library "promise.js"
    ~internal_name:"promise_js"
    ~path:"src/lib/concurrency/promise/js"
    ~deps:[ opam "base"; opam "async_kernel" ]
    ~ppx:Ppx.minimal
    ~implements:"promise"
    ~js_of_ocaml:
      ("js_of_ocaml"
       @: [ "javascript_files" @: [ atom "promise.js" ] ]);

  (* -- promise.js_helpers ----------------------------------------- *)
  library "promise.js_helpers"
    ~internal_name:"promise_js_helpers"
    ~path:"src/lib/concurrency/promise/js_helpers"
    ~deps:[ local "promise.js" ]
    ~ppx:Ppx.minimal;

  (* -- internal_tracing.context_call ------------------------------ *)
  library "internal_tracing.context_call"
    ~internal_name:"internal_tracing_context_call"
    ~path:"src/lib/internal_tracing/context_call"
    ~synopsis:"Internal tracing context call ID helper"
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "async_kernel"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ; "ppx_deriving_yojson"
         ]);

  (* -- internal_tracing ------------------------------------------- *)
  library "internal_tracing"
    ~path:"src/lib/internal_tracing"
    ~synopsis:"Internal tracing"
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "core"
      ; opam "yojson"
      ; opam "async_kernel"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_numbers"
      ; local "internal_tracing.context_call"
      ; local "logger.context_logger"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ; "ppx_deriving_yojson"
         ]);

  (* -- mina_metrics (virtual) ------------------------------------- *)
  library "mina_metrics"
    ~path:"src/lib/mina_metrics"
    ~deps:
      [ opam "async_kernel"
      ; opam "logger"
      ; opam "uri"
      ; opam "core_kernel"
      ]
    ~ppx:Ppx.minimal
    ~virtual_modules:[ "mina_metrics" ]
    ~default_implementation:"mina_metrics.prometheus";

  (* -- mina_metrics.none ------------------------------------------ *)
  library "mina_metrics.none"
    ~internal_name:"mina_metrics_none"
    ~path:"src/lib/mina_metrics/no_metrics"
    ~deps:
      [ opam "async_kernel"
      ; opam "logger"
      ; opam "uri"
      ; opam "core_kernel"
      ]
    ~ppx:Ppx.minimal
    ~implements:"mina_metrics";

  (* -- mina_metrics.prometheus ------------------------------------ *)
  library "mina_metrics.prometheus"
    ~internal_name:"mina_metrics_prometheus"
    ~path:"src/lib/mina_metrics/prometheus_metrics"
    ~deps:
      [ opam "conduit-async"
      ; opam "ppx_hash.runtime-lib"
      ; opam "fmt"
      ; opam "re"
      ; opam "base"
      ; opam "core"
      ; opam "async_kernel"
      ; opam "core_kernel"
      ; opam "prometheus"
      ; opam "cohttp-async"
      ; opam "cohttp"
      ; opam "async"
      ; opam "base.base_internalhash_types"
      ; opam "uri"
      ; opam "async_unix"
      ; opam "base.caml"
      ; local "logger"
      ; local "o1trace"
      ; local "mina_node_config"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_let"
         ; "ppx_version"
         ; "ppx_pipebang"
         ; "ppx_custom_printf"
         ; "ppx_here"
         ])
    ~implements:"mina_metrics";

  (* -- cache_dir (virtual) ---------------------------------------- *)
  library "cache_dir"
    ~path:"src/lib/cache_dir"
    ~deps:
      [ opam "async_kernel"
      ; local "key_cache"
      ; local "logger"
      ]
    ~ppx:Ppx.minimal
    ~virtual_modules:[ "cache_dir" ]
    ~default_implementation:"cache_dir.native";

  (* -- cache_dir.native ------------------------------------------- *)
  library "cache_dir.native"
    ~internal_name:"cache_dir_native"
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
         ])
    ~implements:"cache_dir";

  (* -- cache_dir.fake --------------------------------------------- *)
  library "cache_dir.fake"
    ~internal_name:"cache_dir_fake"
    ~path:"src/lib/cache_dir/fake"
    ~deps:
      [ opam "async_kernel"
      ; opam "core_kernel"
      ; local "key_cache"
      ]
    ~ppx:Ppx.minimal
    ~implements:"cache_dir";

  (* -- mina_node_config.intf -------------------------------------- *)
  library "mina_node_config.intf"
    ~internal_name:"node_config_intf"
    ~path:"src/lib/node_config/intf"
    ~modules_without_implementation:[ "node_config_intf" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_base" ]);

  (* -- mina_node_config ------------------------------------------- *)
  library "mina_node_config"
    ~internal_name:"node_config"
    ~path:"src/lib/node_config"
    ~deps:
      [ local "node_config_intf"
      ; local "node_config_version"
      ; local "node_config_unconfigurable_constants"
      ; local "node_config_profiled"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_base" ]);

  (* -- mina_node_config.for_unit_tests ---------------------------- *)
  library "mina_node_config.for_unit_tests"
    ~internal_name:"node_config_for_unit_tests"
    ~path:"src/lib/node_config/for_unit_tests"
    ~deps:
      [ local "node_config_intf"
      ; local "node_config_version"
      ; local "node_config_unconfigurable_constants"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_base" ]);

  (* -- mina_node_config.profiled ---------------------------------- *)
  library "mina_node_config.profiled"
    ~internal_name:"node_config_profiled"
    ~path:"src/lib/node_config/profiled"
    ~deps:
      [ opam "core_kernel"
      ; local "comptime"
      ; local "node_config_intf"
      ]
    ~ppx:Ppx.minimal;

  (* -- mina_node_config.unconfigurable_constants ------------------ *)
  library "mina_node_config.unconfigurable_constants"
    ~internal_name:"node_config_unconfigurable_constants"
    ~path:"src/lib/node_config/unconfigurable_constants"
    ~deps:[ local "node_config_intf" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_base" ]);

  (* -- mina_node_config.version ----------------------------------- *)
  library "mina_node_config.version"
    ~internal_name:"node_config_version"
    ~path:"src/lib/node_config/version"
    ~deps:[ local "node_config_intf" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_base" ]);

  (* ============================================================ *)
  (* Tier 3: Core infrastructure libraries                         *)
  (* ============================================================ *)

  (* -- logger (virtual) ------------------------------------------- *)
  library "logger"
    ~path:"src/lib/logger"
    ~deps:
      [ opam "core_kernel"
      ; opam "sexplib0"
      ; local "interpolator_lib"
      ]
    ~ppx:Ppx.mina_rich
    ~virtual_modules:[ "logger" ]
    ~default_implementation:"logger.native";

  (* -- logger.context_logger -------------------------------------- *)
  library "logger.context_logger"
    ~internal_name:"context_logger"
    ~path:"src/lib/logger/context_logger"
    ~synopsis:
      "Context logger: useful for passing logger down the deep callstacks"
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "async_kernel"
      ; local "logger"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ; "ppx_deriving_yojson"
         ]);

  (* -- logger.fake ------------------------------------------------ *)
  library "logger.fake"
    ~internal_name:"logger_fake"
    ~path:"src/lib/logger/fake"
    ~synopsis:"Fake logging library"
    ~deps:
      [ opam "result"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "base.base_internalhash_types"
      ; local "interpolator_lib"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:Ppx.mina_rich
    ~implements:"logger";

  (* -- logger.file_system ----------------------------------------- *)
  library "logger.file_system"
    ~internal_name:"logger_file_system"
    ~path:"src/lib/logger/file_system"
    ~synopsis:"Logging library"
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "core"
      ; opam "yojson"
      ; opam "core_kernel"
      ; local "logger"
      ]
    ~ppx:Ppx.mina_rich;

  (* -- logger.native ---------------------------------------------- *)
  library "logger.native"
    ~internal_name:"logger_native"
    ~path:"src/lib/logger/native"
    ~synopsis:"Logging library"
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "result"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "base.base_internalhash_types"
      ; local "itn_logger"
      ; local "interpolator_lib"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:Ppx.mina_rich
    ~implements:"logger";

  (* -- o1trace ---------------------------------------------------- *)
  library "o1trace"
    ~path:"src/lib/o1trace"
    ~synopsis:"Basic event tracing"
    ~inline_tests:true
    ~deps:
      [ opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base.base_internalhash_types"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ocamlgraph"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; local "logger"
      ]
    ~ppx:Ppx.mina;

  (* -- o1trace_webkit_event --------------------------------------- *)
  library "o1trace_webkit_event"
    ~path:"src/lib/o1trace/webkit_event"
    ~deps:
      [ opam "base"
      ; opam "base.caml"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core"
      ; opam "core.time_stamp_counter"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; local "webkit_trace_event.binary"
      ; local "webkit_trace_event"
      ; local "o1trace"
      ]
    ~ppx:Ppx.standard;

  (* -- mina_stdlib_unix ------------------------------------------- *)
  library "mina_stdlib_unix"
    ~path:"src/lib/mina_stdlib_unix"
    ~synopsis:"Mina standard library Unix utilities"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ptime"
      ; local "logger"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_here"
         ; "ppx_jane"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_version"
         ]);

  (* -- mina_numbers ----------------------------------------------- *)
  library "mina_numbers"
    ~path:"src/lib/mina_numbers"
    ~synopsis:"Snark-friendly numbers used in Coda consensus"
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "result"
      ; opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "bignum.bigint"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "sexplib0"
      ; opam "base"
      ; opam "base.base_internalhash_types"
      ; opam "ppx_inline_test.config"
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
         ]);

  (* -- cache_lib -------------------------------------------------- *)
  library "cache_lib"
    ~path:"src/lib/cache_lib"
    ~inline_tests:true
    ~deps:
      [ opam "async_kernel"
      ; opam "base"
      ; opam "base.base_internalhash_types"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ppx_inline_test.config"
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
         ]);

  (* -- trust_system ----------------------------------------------- *)
  library "trust_system"
    ~path:"src/lib/trust_system"
    ~synopsis:"Track how much we trust peers"
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "sexplib0"
      ; opam "core"
      ; opam "ppx_inline_test.config"
      ; opam "base.caml"
      ; opam "async_kernel"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base"
      ; opam "result"
      ; opam "async"
      ; opam "async_unix"
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
         ]);

  (* -- parallel --------------------------------------------------- *)
  library "parallel"
    ~path:"src/lib/parallel"
    ~synopsis:
      "Template code to run programs that rely Rpc_parallel.Expert"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "async_rpc_kernel"
      ; opam "async"
      ; opam "core"
      ; opam "rpc_parallel"
      ; opam "async.async_rpc"
      ; opam "core_kernel"
      ]
    ~ppx:
      (Ppx.custom [ "ppx_version"; "ppx_jane"; "ppx_compare" ]);

  (* -- mina_version.dummy ----------------------------------------- *)
  library "mina_version.dummy"
    ~internal_name:"mina_version_dummy"
    ~path:"src/lib/mina_version/dummy"
    ~deps:[ opam "core_kernel"; opam "base" ]
    ~ppx:Ppx.minimal
    ~implements:"mina_version";

  (* -- mina_version.runtime --------------------------------------- *)
  library "mina_version.runtime"
    ~internal_name:"mina_version_runtime"
    ~path:"src/lib/mina_version/runtime"
    ~deps:[ opam "core_kernel"; opam "base"; opam "unix" ]
    ~ppx:Ppx.minimal
    ~implements:"mina_version";

  (* -- mina_signature_kind (virtual) ------------------------------ *)
  library "mina_signature_kind"
    ~path:"src/lib/signature_kind"
    ~deps:[ local "mina_signature_kind.type" ]
    ~ppx:
      (Ppx.custom
         [ "ppx_bin_prot"
         ; "ppx_version"
         ; "ppx_deriving_yojson"
         ])
    ~virtual_modules:[ "mina_signature_kind" ]
    ~default_implementation:"mina_signature_kind_config";

  (* -- mina_signature_kind.type ----------------------------------- *)
  library "mina_signature_kind.type"
    ~internal_name:"mina_signature_kind_type"
    ~path:"src/lib/signature_kind/type"
    ~deps:[ opam "core_kernel" ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving_yojson"; "ppx_jane"; "ppx_version" ]);

  (* -- mina_signature_kind.config --------------------------------- *)
  library "mina_signature_kind.config"
    ~internal_name:"mina_signature_kind_config"
    ~path:"src/lib/signature_kind/compile_config"
    ~deps:[ local "mina_node_config" ]
    ~ppx:Ppx.minimal
    ~implements:"mina_signature_kind";

  (* -- mina_signature_kind.testnet -------------------------------- *)
  library "mina_signature_kind.testnet"
    ~internal_name:"mina_signature_kind_testnet"
    ~path:"src/lib/signature_kind/testnet"
    ~ppx:Ppx.minimal
    ~implements:"mina_signature_kind";

  (* -- mina_signature_kind.mainnet -------------------------------- *)
  library "mina_signature_kind.mainnet"
    ~internal_name:"mina_signature_kind_mainnet"
    ~path:"src/lib/signature_kind/mainnet"
    ~ppx:Ppx.minimal
    ~implements:"mina_signature_kind";

  (* -- multi_key_file_storage ------------------------------------- *)
  library "multi_key_file_storage"
    ~path:"src/lib/multi-key-file-storage"
    ~deps:
      [ opam "core_kernel"
      ; opam "bin_prot"
      ; local "mina_stdlib"
      ]
    ~modules_without_implementation:[ "intf" ]
    ~ppx:Ppx.mina;

  (* ============================================================ *)
  (* Tier 4: Crypto layer                                          *)
  (* ============================================================ *)

  (* -- pasta_bindings.backend (virtual) --------------------------- *)
  library "pasta_bindings.backend"
    ~internal_name:"pasta_bindings_backend"
    ~path:"src/lib/crypto/kimchi_bindings/stubs/pasta_bindings_backend"
    ~modules:[ "pasta_bindings_backend" ]
    ~inline_tests:true
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_inline_test" ])
    ~virtual_modules:[ "pasta_bindings_backend" ]
    ~default_implementation:"pasta_bindings.backend.native";

  (* -- pasta_bindings.backend.none -------------------------------- *)
  library "pasta_bindings.backend.none"
    ~internal_name:"pasta_bindings_backend_none"
    ~path:
      "src/lib/crypto/kimchi_bindings/stubs/pasta_bindings_backend/none"
    ~inline_tests:true
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_inline_test" ])
    ~implements:"pasta_bindings.backend";

  (* -- bindings_js ------------------------------------------------ *)
  library "bindings_js"
    ~path:"src/lib/crypto/kimchi_bindings/js"
    ~ppx:Ppx.minimal
    ~js_of_ocaml:
      ("js_of_ocaml"
       @: [ "javascript_files"
            @: [ atom "bindings/bigint256.js"
               ; atom "bindings/field.js"
               ; atom "bindings/curve.js"
               ; atom "bindings/vector.js"
               ; atom "bindings/gate-vector.js"
               ; atom "bindings/oracles.js"
               ; atom "bindings/pickles-test.js"
               ; atom "bindings/proof.js"
               ; atom "bindings/prover-index.js"
               ; atom "bindings/util.js"
               ; atom "bindings/srs.js"
               ; atom "bindings/verifier-index.js"
               ] ]);

  (* -- bindings_js.node_backend ----------------------------------- *)
  library "bindings_js.node_backend"
    ~internal_name:"node_backend"
    ~path:"src/lib/crypto/kimchi_bindings/js/node_js"
    ~ppx:(Ppx.custom [ "ppx_version"; "js_of_ocaml-ppx" ])
    ~js_of_ocaml:
      ("js_of_ocaml"
       @: [ "flags" @: [ list [ atom ":include"; atom "flags.sexp" ] ]
          ; "javascript_files" @: [ atom "node_backend.js" ]
          ])
    ~extra_stanzas:
      [ "rule"
        @: [ "targets"
             @: [ atom "plonk_wasm_bg.wasm.d.ts"
                ; atom "plonk_wasm_bg.wasm"
                ; atom "plonk_wasm.d.ts"
                ; atom "plonk_wasm.js"
                ; atom "flags.sexp"
                ]
           ; "deps"
             @: [ atom "build.sh"
                ; atom "../../dune-build-root"
                ; list [ atom "source_tree"
                       ; atom "../../../proof-systems" ]
                ]
           ; "locks" @: [ atom "/cargo-lock" ]
           ; "action"
             @: [ list
                    [ atom "progn"
                    ; list
                        [ atom "setenv"
                        ; atom "CARGO_TARGET_DIR"
                        ; atom
                            {|%{read:../../dune-build-root}/cargo_kimchi_wasm|}
                        ; list [ atom "run"
                               ; atom "bash"
                               ; atom "build.sh" ] ]
                    ; list
                        [ atom "write-file"
                        ; atom "flags.sexp"
                        ; atom "()" ] ] ]
           ] ];

  (* -- bindings_js.web_backend ------------------------------------ *)
  library "bindings_js.web_backend"
    ~internal_name:"web_backend"
    ~path:"src/lib/crypto/kimchi_bindings/js/web"
    ~ppx:(Ppx.custom [ "ppx_version"; "js_of_ocaml-ppx" ])
    ~js_of_ocaml:
      ("js_of_ocaml"
       @: [ "flags" @: [ list [ atom ":include"; atom "flags.sexp" ] ]
          ; "javascript_files" @: [ atom "web_backend.js" ]
          ])
    ~extra_stanzas:
      [ "rule"
        @: [ "targets"
             @: [ atom "plonk_wasm_bg.wasm.d.ts"
                ; atom "plonk_wasm_bg.wasm"
                ; atom "plonk_wasm.d.ts"
                ; atom "plonk_wasm.js"
                ; atom "flags.sexp"
                ]
           ; "deps"
             @: [ atom "build.sh"
                ; atom "../../dune-build-root"
                ; list [ atom "source_tree"
                       ; atom "../../../proof-systems" ]
                ]
           ; "locks" @: [ atom "/cargo-lock" ]
           ; "action"
             @: [ list
                    [ atom "progn"
                    ; list
                        [ atom "setenv"
                        ; atom "CARGO_TARGET_DIR"
                        ; atom
                            {|%{read:../../dune-build-root}/cargo_kimchi_wasm|}
                        ; list [ atom "run"
                               ; atom "bash"
                               ; atom "build.sh" ] ]
                    ; list
                        [ atom "write-file"
                        ; atom "flags.sexp"
                        ; atom "()" ] ] ]
           ] ];

  (* -- kimchi_bindings.pasta_fp_poseidon -------------------------- *)
  library "kimchi_bindings.pasta_fp_poseidon"
    ~internal_name:"kimchi_pasta_fp_poseidon"
    ~path:"src/lib/crypto/kimchi_bindings/pasta_fp_poseidon"
    ~deps:[ local "kimchi_bindings" ]
    ~inline_tests:true
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_inline_test" ]);

  (* -- kimchi_bindings.pasta_fq_poseidon -------------------------- *)
  library "kimchi_bindings.pasta_fq_poseidon"
    ~internal_name:"kimchi_pasta_fq_poseidon"
    ~path:"src/lib/crypto/kimchi_bindings/pasta_fq_poseidon"
    ~deps:[ local "kimchi_bindings" ]
    ~inline_tests:true
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_inline_test" ]);

  (* -- kimchi_backend_common -------------------------------------- *)
  library "kimchi_backend_common"
    ~path:"src/lib/crypto/kimchi_backend/common"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "result"
      ; opam "async_kernel"
      ; opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "integers"
      ; opam "digestif"
      ; opam "core_kernel"
      ; opam "base.caml"
      ; opam "ppx_inline_test.config"
      ; opam "bignum.bigint"
      ; opam "zarith"
      ; opam "base.base_internalhash_types"
      ; local "tuple_lib"
      ; local "key_cache"
      ; local "hex"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_snarky_backend"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "plonkish_prelude"
      ; local "sponge"
      ; local "allocation_functor"
      ; local "snarky.intf"
      ; local "promise"
      ; local "logger"
      ; local "logger.context_logger"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_mina"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.std"
         ; "h_list.ppx"
         ]);

  (* -- kimchi_pasta ----------------------------------------------- *)
  library "kimchi_pasta"
    ~path:"src/lib/crypto/kimchi_backend/pasta"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; local "sponge"
      ; local "kimchi_backend_common"
      ; local "promise"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_basic"
      ; local "mina_stdlib"
      ; local "kimchi_pasta_constraint_system"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarkette"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.std"
         ]);

  (* -- kimchi_pasta.basic ----------------------------------------- *)
  library "kimchi_pasta.basic"
    ~internal_name:"kimchi_pasta_basic"
    ~path:"src/lib/crypto/kimchi_backend/pasta/basic"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; local "sponge"
      ; local "kimchi_backend_common"
      ; local "promise"
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "mina_stdlib"
      ; local "pasta_bindings"
      ; local "snarkette"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.std"
         ]);

  (* -- kimchi_pasta.constraint_system (virtual) ------------------- *)
  library "kimchi_pasta.constraint_system"
    ~internal_name:"kimchi_pasta_constraint_system"
    ~path:
      "src/lib/crypto/kimchi_backend/pasta/constraint_system"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; local "sponge"
      ; local "kimchi_backend_common"
      ; local "promise"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_basic"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarkette"
      ; local "ppx_version.runtime"
      ; local "snarky.backendless"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.std"
         ])
    ~virtual_modules:
      [ "pallas_constraint_system"
      ; "vesta_constraint_system"
      ]
    ~default_implementation:
      "kimchi_pasta.constraint_system.caml";

  (* -- kimchi_pasta.constraint_system.caml ------------------------ *)
  library "kimchi_pasta.constraint_system.caml"
    ~internal_name:"kimchi_pasta_constraint_system_caml"
    ~path:
      "src/lib/crypto/kimchi_backend/pasta/constraint_system/caml"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; local "sponge"
      ; local "kimchi_backend_common"
      ; local "promise"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_basic"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarkette"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.std"
         ])
    ~implements:"kimchi_pasta.constraint_system";

  (* -- kimchi_backend --------------------------------------------- *)
  library "kimchi_backend"
    ~path:"src/lib/crypto/kimchi_backend"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; local "hex"
      ; local "key_cache"
      ; local "kimchi_backend_common"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "kimchi_pasta.constraint_system"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarky.intf"
      ; local "snarkette"
      ; local "sponge"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_version"
         ]);

  (* -- kimchi_backend.gadgets ------------------------------------- *)
  library "kimchi_backend.gadgets"
    ~internal_name:"kimchi_gadgets"
    ~path:"src/lib/crypto/kimchi_backend/gadgets"
    ~inline_tests:true
    ~deps:
      [ opam "bignum.bigint"
      ; opam "core_kernel"
      ; opam "digestif"
      ; opam "ppx_inline_test.config"
      ; opam "zarith"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_gadgets_test_runner"
      ; local "mina_stdlib"
      ; local "snarky.backendless"
      ]
    ~ppx:Ppx.standard;

  (* -- kimchi_backend.gadgets_test_runner ------------------------- *)
  library "kimchi_backend.gadgets_test_runner"
    ~internal_name:"kimchi_gadgets_test_runner"
    ~path:"src/lib/crypto/kimchi_backend/gadgets/runner"
    ~deps:
      [ opam "stdio"
      ; opam "integers"
      ; opam "result"
      ; opam "base.caml"
      ; opam "bignum.bigint"
      ; opam "core_kernel"
      ; opam "base64"
      ; opam "digestif"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "base"
      ; opam "async_kernel"
      ; opam "bin_prot.shape"
      ; local "mina_wire_types"
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "kimchi_pasta.constraint_system"
      ; local "bitstring_lib"
      ; local "snarky.intf"
      ; local "snarky.backendless"
      ; local "snarky_group_map"
      ; local "sponge"
      ; local "kimchi_backend"
      ; local "base58_check"
      ; local "codable"
      ; local "random_oracle_input"
      ; local "snarky_log"
      ; local "group_map"
      ; local "snarky_curve"
      ; local "key_cache"
      ; local "snark_keys_header"
      ; local "tuple_lib"
      ; local "promise"
      ; local "kimchi_backend_common"
      ; local "ppx_version.runtime"
      ]
    ~ppx:Ppx.mina_rich;

  (* -- crypto_params ---------------------------------------------- *)
  library "crypto_params"
    ~path:"src/lib/crypto/crypto_params"
    ~synopsis:"Cryptographic parameters"
    ~flags:[ atom ":standard"; atom "-short-paths"
           ; atom "-warn-error"; atom "-58" ]
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; local "cache_dir"
      ; local "group_map"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ]
    ~ppx:
      (Ppx.custom [ "h_list.ppx"; "ppx_jane"; "ppx_version" ])
    ~extra_stanzas:
      [ "rule"
        @: [ "targets" @: [ atom "group_map_params.ml" ]
           ; "deps" @: [ list [ atom ":<"; atom "gen/gen.exe" ] ]
           ; "action"
             @: [ list [ atom "run"
                       ; atom "%{<}"
                       ; atom "%{targets}" ] ]
           ] ];

  (* -- pickles_base ----------------------------------------------- *)
  library "pickles_base"
    ~path:"src/lib/crypto/pickles_base"
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a-44"
             ; atom "-warn-error"; atom "+a" ] ]
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "ppxlib"
      ; opam "core_kernel"
      ; local "mina_wire_types"
      ; local "snarky.backendless"
      ; local "random_oracle_input"
      ; local "pickles_types"
      ; local "pickles_base.one_hot_vector"
      ; local "plonkish_prelude"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_version"
         ; "ppx_mina"
         ; "ppx_jane"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "h_list.ppx"
         ]);

  (* -- pickles_base.one_hot_vector -------------------------------- *)
  library "pickles_base.one_hot_vector"
    ~internal_name:"one_hot_vector"
    ~path:"src/lib/crypto/pickles_base/one_hot_vector"
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a-40..42-44"
             ; atom "-warn-error"; atom "+a" ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ opam "core_kernel"
      ; local "snarky.backendless"
      ; local "pickles_types"
      ]
    ~ppx:Ppx.standard;

  (* -- pickles_types ---------------------------------------------- *)
  library "pickles_types"
    ~path:"src/lib/crypto/pickles_types"
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a-40..42-44"
             ; atom "-warn-error"; atom "+a" ] ]
    ~deps:
      [ opam "sexplib0"
      ; opam "result"
      ; opam "core_kernel"
      ; opam "base.caml"
      ; opam "bin_prot.shape"
      ; local "kimchi_types"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta_snarky_backend"
      ; local "plonkish_prelude"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_deriving.std"
         ; "h_list.ppx"
         ]);

  (* -- snark_params ----------------------------------------------- *)
  library "snark_params"
    ~path:"src/lib/crypto/snark_params"
    ~synopsis:"Snark parameters"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "core_kernel"
      ; opam "digestif"
      ; opam "base"
      ; opam "sexplib0"
      ; local "mina_wire_types"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "bignum_bigint"
      ; local "pickles.backend"
      ; local "snarky_curves"
      ; local "snarky.backendless"
      ; local "snarky_group_map"
      ; local "sponge"
      ; local "group_map"
      ; local "fold_lib"
      ; local "bitstring_lib"
      ; local "snark_bits"
      ; local "pickles"
      ; local "crypto_params"
      ; local "snarky_field_extensions"
      ; local "snarky.intf"
      ; local "kimchi_backend"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_assert"
         ; "ppx_base"
         ; "ppx_bench"
         ; "ppx_let"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_sexp_conv"
         ; "ppx_bin_prot"
         ; "ppx_custom_printf"
         ; "ppx_snarky"
         ]);

  (* -- snark_bits ------------------------------------------------- *)
  library "snark_bits"
    ~path:"src/lib/crypto/snark_bits"
    ~synopsis:"Snark parameters"
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "core_kernel"
      ; opam "integers"
      ; opam "base"
      ; local "fold_lib"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ; local "bitstring_lib"
      ; local "snarky.intf"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_snarky"
         ; "ppx_let"
         ; "ppx_inline_test"
         ; "ppx_compare"
         ]);

  (* -- random_oracle ---------------------------------------------- *)
  library "random_oracle"
    ~path:"src/lib/crypto/random_oracle"
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; local "snark_params"
      ; local "pickles.backend"
      ; local "sponge"
      ; local "pickles"
      ; local "random_oracle_input"
      ; local "snarky.backendless"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "fold_lib"
      ; local "random_oracle.permutation"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_sexp_conv"
         ; "ppx_compare"
         ; "ppx_inline_test"
         ; "ppx_assert"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "ppx_let"
         ]);

  (* -- random_oracle.permutation (virtual) ------------------------ *)
  library "random_oracle.permutation"
    ~internal_name:"random_oracle_permutation"
    ~path:"src/lib/crypto/random_oracle/permutation"
    ~deps:
      [ local "sponge"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ]
    ~ppx:Ppx.minimal
    ~virtual_modules:[ "random_oracle_permutation" ]
    ~default_implementation:"random_oracle.permutation.external";

  (* -- random_oracle.permutation.external ------------------------- *)
  library "random_oracle.permutation.external"
    ~internal_name:"random_oracle_permutation_external"
    ~path:"src/lib/crypto/random_oracle/permutation/external"
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; local "sponge"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_bindings.pasta_fp_poseidon"
      ; local "kimchi_bindings"
      ; local "kimchi_backend"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_inline_test"
         ; "ppx_assert"
         ])
    ~implements:"random_oracle.permutation";

  (* -- random_oracle.permutation.ocaml ---------------------------- *)
  library "random_oracle.permutation.ocaml"
    ~internal_name:"random_oracle_permutation_ocaml"
    ~path:"src/lib/crypto/random_oracle/permutation/ocaml"
    ~deps:
      [ opam "base"
      ; opam "core_kernel"
      ; local "sponge"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ]
    ~ppx:Ppx.minimal
    ~implements:"random_oracle.permutation";

  (* -- non_zero_curve_point --------------------------------------- *)
  library "non_zero_curve_point"
    ~path:"src/lib/crypto/non_zero_curve_point"
    ~flags:[ atom ":standard"; atom "-short-paths" ]
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "base.caml"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base"
      ; opam "base.base_internalhash_types"
      ; local "mina_wire_types"
      ; local "snarky.backendless"
      ; local "random_oracle_input"
      ; local "pickles.backend"
      ; local "pickles"
      ; local "codable"
      ; local "snark_params"
      ; local "fold_lib"
      ; local "base58_check"
      ; local "random_oracle"
      ; local "bitstring_lib"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "test_util"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_snarky"
         ; "ppx_mina"
         ; "ppx_version"
         ; "ppx_let"
         ; "ppx_hash"
         ; "ppx_compare"
         ; "ppx_sexp_conv"
         ; "ppx_bin_prot"
         ; "ppx_inline_test"
         ; "ppx_deriving_yojson"
         ; "ppx_compare"
         ; "h_list.ppx"
         ; "ppx_custom_printf"
         ]);

  (* -- signature_lib --------------------------------------------- *)
  library "signature_lib"
    ~path:"src/lib/crypto/signature_lib"
    ~synopsis:"Schnorr signatures using the tick and tock curves"
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "bignum.bigint"
      ; opam "ppx_inline_test.config"
      ; opam "base"
      ; opam "sexplib0"
      ; opam "yojson"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "result"
      ; local "mina_wire_types"
      ; local "crypto_params"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "random_oracle_input"
      ; local "bitstring_lib"
      ; local "codable"
      ; local "snark_params"
      ; local "mina_debug"
      ; local "blake2"
      ; local "hash_prefix_states"
      ; local "non_zero_curve_point"
      ; local "random_oracle"
      ; local "snarky.backendless"
      ; local "bignum_bigint"
      ; local "base58_check"
      ; local "snarky_curves"
      ; local "pickles"
      ; local "fold_lib"
      ; local "pickles.backend"
      ; local "kimchi_backend"
      ; local "h_list"
      ; local "test_util"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_snarky"
         ; "ppx_mina"
         ; "ppx_version"
         ; "ppx_custom_printf"
         ; "ppx_sexp_conv"
         ; "ppx_bin_prot"
         ; "ppx_hash"
         ; "ppx_compare"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "ppx_inline_test"
         ; "ppx_let"
         ]);

  (* -- secrets ---------------------------------------------------- *)
  library "secrets"
    ~path:"src/lib/crypto/secrets"
    ~synopsis:"Managing secrets including passwords and keypairs"
    ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "result"
      ; opam "base.caml"
      ; opam "bignum.bigint"
      ; opam "async_kernel"
      ; opam "async"
      ; opam "core"
      ; opam "async_unix"
      ; opam "sodium"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "yojson"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "base58"
      ; opam "ppx_inline_test.config"
      ; local "mina_stdlib_unix"
      ; local "random_oracle"
      ; local "pickles"
      ; local "logger"
      ; local "snark_params"
      ; local "mina_stdlib"
      ; local "mina_net2"
      ; local "mina_base"
      ; local "base58_check"
      ; local "signature_lib"
      ; local "network_peer"
      ; local "mina_numbers"
      ; local "snarky.backendless"
      ; local "error_json"
      ; local "mina_base.import"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.make"
         ]);

  (* -- key_gen ---------------------------------------------------- *)
  library "key_gen"
    ~path:"src/lib/crypto/key_gen"
    ~deps:
      [ opam "core_kernel"
      ; local "signature_lib"
      ]
    ~ppx:Ppx.minimal;

  (* -- bowe_gabizon_hash ------------------------------------------ *)
  library "bowe_gabizon_hash"
    ~path:"src/lib/crypto/bowe_gabizon_hash"
    ~inline_tests:true
    ~deps:[ opam "core_kernel" ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"; "ppx_jane"; "ppx_version" ]);

  (* -- pickles.limb_vector ---------------------------------------- *)
  library "pickles.limb_vector"
    ~internal_name:"limb_vector"
    ~path:"src/lib/crypto/pickles/limb_vector"
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a-40..42-44"
             ; atom "-warn-error"; atom "+a" ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~modules_without_implementation:[ "limb_vector" ]
    ~deps:
      [ opam "bin_prot.shape"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "base.caml"
      ; opam "result"
      ; local "snarky.backendless"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "ppx_version.runtime"
      ]
    ~ppx:Ppx.mina_rich;

  (* -- pickles.pseudo --------------------------------------------- *)
  library "pickles.pseudo"
    ~internal_name:"pseudo"
    ~path:"src/lib/crypto/pickles/pseudo"
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a-40..42-44"
             ; atom "-warn-error"; atom "+a" ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ opam "core_kernel"
      ; local "pickles_types"
      ; local "pickles.plonk_checks"
      ; local "pickles_base.one_hot_vector"
      ; local "snarky.backendless"
      ; local "pickles_base"
      ]
    ~ppx:Ppx.mina_rich;

  (* -- pickles.composition_types ---------------------------------- *)
  library "pickles.composition_types"
    ~internal_name:"composition_types"
    ~path:"src/lib/crypto/pickles/composition_types"
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a-40..42-44"
             ; atom "-warn-error"; atom "+a-70-27" ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "base.caml"
      ; local "mina_wire_types"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "snarky.backendless"
      ; local "pickles_types"
      ; local "pickles.limb_vector"
      ; local "kimchi_backend"
      ; local "pickles_base"
      ; local "pickles.backend"
      ; local "kimchi_backend_common"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_mina"
         ; "ppx_jane"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "h_list.ppx"
         ]);

  (* -- pickles.plonk_checks -------------------------------------- *)
  library "pickles.plonk_checks"
    ~internal_name:"plonk_checks"
    ~path:"src/lib/crypto/pickles/plonk_checks"
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a-40..42-44"
             ; atom "-warn-error"; atom "+a-4-70" ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ opam "sexplib0"
      ; opam "ppxlib.ast"
      ; opam "core_kernel"
      ; opam "ocaml-migrate-parsetree"
      ; opam "base.base_internalhash_types"
      ; local "pickles_types"
      ; local "pickles_base"
      ; local "pickles.composition_types"
      ; local "kimchi_backend"
      ; local "kimchi_types"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ])
    ~extra_stanzas:
      [ "rule"
        @: [ "target" @: [ atom "scalars.ml" ]
           ; "mode" @: [ atom "promote" ]
           ; "deps"
             @: [ list [ atom ":<"
                       ; atom "gen_scalars/gen_scalars.exe" ] ]
           ; "action"
             @: [ list [ atom "progn"
                       ; list [ atom "run"
                              ; atom "%{<}"
                              ; atom "%{target}" ]
                       ; list [ atom "run"
                              ; atom "ocamlformat"
                              ; atom "-i"
                              ; atom "scalars.ml" ] ] ]
           ] ];

  (* -- pickles.backend -------------------------------------------- *)
  library "pickles.backend"
    ~internal_name:"backend"
    ~path:"src/lib/crypto/pickles/backend"
    ~deps:
      [ local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ]
    ~ppx:Ppx.mina_rich;

  (* -- pickles ---------------------------------------------------- *)
  library "pickles"
    ~path:"src/lib/crypto/pickles"
    ~inline_tests:true
    ~modules_without_implementation:
      [ "full_signature"; "type"; "intf"; "pickles_intf" ]
    ~flags:[ atom "-open"; atom "Core_kernel" ]
    ~deps:
      [ opam "stdio"
      ; opam "integers"
      ; opam "result"
      ; opam "base.caml"
      ; opam "bignum.bigint"
      ; opam "core_kernel"
      ; opam "base64"
      ; opam "digestif"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "base"
      ; opam "async_kernel"
      ; opam "bin_prot.shape"
      ; local "mina_wire_types"
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "kimchi_pasta.constraint_system"
      ; local "kimchi_pasta_snarky_backend"
      ; local "bitstring_lib"
      ; local "snarky.intf"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "snarky.backendless"
      ; local "snarky_group_map"
      ; local "sponge"
      ; local "pickles.pseudo"
      ; local "pickles.limb_vector"
      ; local "pickles_base"
      ; local "plonkish_prelude"
      ; local "kimchi_backend"
      ; local "base58_check"
      ; local "codable"
      ; local "random_oracle_input"
      ; local "pickles.composition_types"
      ; local "pickles.plonk_checks"
      ; local "pickles_base.one_hot_vector"
      ; local "snarky_log"
      ; local "group_map"
      ; local "snarky_curve"
      ; local "key_cache"
      ; local "snark_keys_header"
      ; local "tuple_lib"
      ; local "promise"
      ; local "kimchi_backend_common"
      ; local "logger"
      ; local "logger.context_logger"
      ; local "ppx_version.runtime"
      ; local "error_json"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_mina"
         ; "ppx_jane"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "h_list.ppx"
         ]);

  (* ============================================================ *)
  (* Executables (src/app)                                        *)
  (* ============================================================ *)

  (* -- archive ---------------------------------------------------- *)
  executable "archive"
    ~package:"archive"
    ~path:"src/app/archive"
    ~deps:
      [ opam "archive_cli"
      ; opam "async"
      ; opam "async_unix"
      ; opam "core_kernel"
      ; local "mina_version"
      ]
    ~modules:[ "archive" ]
    ~modes:[ "native" ]
    ~ppx:Ppx.minimal
    ~bisect_sigterm:true;

  (* -- generate_keypair ------------------------------------------- *)
  executable "mina-generate-keypair"
    ~internal_name:"generate_keypair"
    ~package:"generate_keypair"
    ~path:"src/app/generate_keypair"
    ~deps:
      [ opam "async"
      ; opam "async_unix"
      ; opam "cli_lib"
      ; opam "core_kernel"
      ; local "mina_version"
      ]
    ~modes:[ "native" ]
    ~flags:[ atom ":standard"; atom "-w"; atom "+a" ]
    ~ppx:Ppx.minimal;

  (* -- logproc ---------------------------------------------------- *)
  executable "logproc"
    ~path:"src/app/logproc"
    ~deps:
      [ opam "cmdliner"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; opam "stdio"
      ; opam "yojson"
      ; local "interpolator_lib"
      ; local "logger"
      ; local "logproc_lib"
      ; local "mina_stdlib"
      ]
    ~modules:[ "logproc" ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_deriving.std" ]);

  (* ================================================================ *)
  (* WAVE 5 — Core Domain Libraries                                   *)
  (* ================================================================ *)

  (* -- hash_prefix_states ------------------------------------------ *)
  library "hash_prefix_states"
    ~path:"src/lib/hash_prefix_states"
    ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "core_kernel"
      ; opam "base"
      ; local "snark_params"
      ; local "random_oracle"
      ; local "mina_signature_kind"
      ; local "hash_prefixes"
      ; local "hash_prefix_create"
      ; local "pickles"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_custom_printf"; "ppx_snarky"; "ppx_version"
         ; "ppx_inline_test"; "ppx_compare"
         ; "ppx_deriving_yojson"
         ])
    ~synopsis:
      "Values corresponding to the internal state of the \
       Pedersen hash function on the prefixes used in Coda";

  (* -- hash_prefix_create (virtual) -------------------------------- *)
  library "hash_prefix_create"
    ~path:"src/lib/hash_prefix_states/hash_prefix_create"
    ~deps:
      [ local "hash_prefixes"
      ; local "random_oracle"
      ]
    ~virtual_modules:[ "hash_prefix_create" ]
    ~default_implementation:"hash_prefix_create.native"
    ~ppx:Ppx.minimal;

  (* -- hash_prefix_create.native ----------------------------------- *)
  library "hash_prefix_create.native"
    ~internal_name:"hash_prefix_create_native"
    ~path:"src/lib/hash_prefix_states/hash_prefix_create/native"
    ~deps:[ local "random_oracle" ]
    ~implements:"hash_prefix_create"
    ~ppx:Ppx.minimal;

  (* -- hash_prefix_create.js --------------------------------------- *)
  library "hash_prefix_create.js"
    ~internal_name:"hash_prefix_create_js"
    ~path:"src/lib/hash_prefix_states/hash_prefix_create/js"
    ~deps:
      [ opam "js_of_ocaml"
      ; opam "base"
      ; opam "core_kernel"
      ; local "pickles"
      ; local "random_oracle"
      ]
    ~implements:"hash_prefix_create"
    ~ppx:Ppx.minimal;

  (* -- data_hash_lib ----------------------------------------------- *)
  library "data_hash_lib"
    ~path:"src/lib/data_hash_lib"
    ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "base"
      ; opam "core_kernel"
      ; opam "ppx_inline_test.config"
      ; local "base58_check"
      ; local "bignum_bigint"
      ; local "bitstring_lib"
      ; local "codable"
      ; local "fields_derivers"
      ; local "fields_derivers.graphql"
      ; local "fields_derivers.json"
      ; local "fields_derivers.zkapps"
      ; local "fold_lib"
      ; local "mina_wire_types"
      ; local "outside_hash_image"
      ; local "pickles"
      ; local "ppx_version.runtime"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "snark_bits"
      ; local "snark_params"
      ; local "snarky.backendless"
      ; local "snarky.intf"
      ; local "test_util"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_bench"; "ppx_compare"; "ppx_hash"
         ; "ppx_inline_test"; "ppx_let"; "ppx_mina"
         ; "ppx_sexp_conv"; "ppx_snarky"; "ppx_version"
         ])
    ~synopsis:"Data hash";

  (* -- sparse_ledger_lib ------------------------------------------- *)
  library "sparse_ledger_lib"
    ~path:"src/lib/sparse_ledger_lib"
    ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "base.caml"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "base"
      ; opam "ppx_inline_test.config"
      ; opam "bin_prot.shape"
      ; opam "result"
      ; opam "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_compare"
         ; "ppx_deriving_yojson"; "ppx_version"
         ])
    ~synopsis:"sparse Ledger implementation";

  (* -- block_time -------------------------------------------------- *)
  library "block_time"
    ~path:"src/lib/block_time"
    ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "integers"
      ; opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "sexplib0"
      ; opam "async_kernel"
      ; opam "core_kernel"
      ; opam "base"
      ; opam "base.base_internalhash_types"
      ; local "mina_wire_types"
      ; local "bitstring_lib"
      ; local "pickles"
      ; local "unsigned_extended"
      ; local "snark_params"
      ; local "mina_numbers"
      ; local "logger"
      ; local "snark_bits"
      ; local "timeout_lib"
      ; local "crypto_params"
      ; local "snarky.backendless"
      ; local "random_oracle_input"
      ; local "random_oracle"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_hash"; "ppx_let"; "ppx_mina"
         ; "ppx_version"; "ppx_deriving_yojson"
         ; "ppx_bin_prot"; "ppx_compare"; "ppx_sexp_conv"
         ; "ppx_compare"; "ppx_inline_test"
         ])
    ~synopsis:"Block time";

  (* -- proof_carrying_data ----------------------------------------- *)
  library "proof_carrying_data"
    ~path:"src/lib/proof_carrying_data"
    ~deps:
      [ opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base"
      ; opam "base.caml"
      ; opam "sexplib0"
      ; local "mina_wire_types"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving_yojson"; "ppx_version"; "ppx_jane" ]);

  (* -- protocol_version -------------------------------------------- *)
  library "protocol_version"
    ~path:"src/lib/protocol_version"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "core_kernel"
      ; opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "base"
      ; opam "ppx_version.runtime"
      ; local "mina_wire_types"
      ; local "mina_node_config.version"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_bin_prot"; "ppx_fields_conv"
         ; "ppx_sexp_conv"; "ppx_compare"
         ; "ppx_deriving_yojson"
         ])
    ~synopsis:"Protocol version representation";

  (* -- genesis_constants ------------------------------------------- *)
  library "genesis_constants"
    ~path:"src/lib/genesis_constants"
    ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "base"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "base.caml"
      ; opam "sexplib0"
      ; opam "integers"
      ; local "mina_node_config.intf"
      ; local "mina_node_config.for_unit_tests"
      ; local "mina_node_config"
      ; local "mina_wire_types"
      ; local "unsigned_extended"
      ; local "mina_numbers"
      ; local "pickles"
      ; local "currency"
      ; local "blake2"
      ; local "data_hash_lib"
      ; local "pickles.backend"
      ; local "snark_keys_header"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "test_util"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"; "ppx_version"; "ppx_bin_prot"
         ; "ppx_compare"; "ppx_hash"; "ppx_fields_conv"
         ; "ppx_compare"; "ppx_deriving.ord"
         ; "ppx_sexp_conv"; "ppx_let"; "ppx_custom_printf"
         ; "ppx_deriving_yojson"; "h_list.ppx"
         ; "ppx_inline_test"
         ])
    ~synopsis:"Coda genesis constants";

  (* -- network_peer ------------------------------------------------ *)
  library "network_peer"
    ~path:"src/lib/network_peer"
    ~deps:
      [ opam "core"
      ; opam "async"
      ; opam "async.async_rpc"
      ; opam "async_rpc_kernel"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "sexplib0"
      ; opam "base.caml"
      ; opam "base.base_internalhash_types"
      ; opam "result"
      ; opam "async_kernel"
      ; opam "mina_metrics"
      ; opam "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"; "ppx_mina"; "ppx_version"
         ; "ppx_jane"; "ppx_deriving_yojson"
         ]);

  (* -- node_addrs_and_ports ---------------------------------------- *)
  library "node_addrs_and_ports"
    ~path:"src/lib/node_addrs_and_ports"
    ~inline_tests:true
    ~deps:
      [ opam "core"
      ; opam "async"
      ; opam "yojson"
      ; opam "sexplib0"
      ; opam "base.caml"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; local "network_peer"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_let"
         ; "ppx_deriving_yojson"
         ]);

  (* -- user_command_input ------------------------------------------ *)
  library "user_command_input"
    ~path:"src/lib/user_command_input"
    ~deps:
      [ opam "bin_prot.shape"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "async_kernel"
      ; opam "sexplib0"
      ; opam "base.caml"
      ; opam "async"
      ; local "logger"
      ; local "genesis_constants"
      ; local "currency"
      ; local "unsigned_extended"
      ; local "participating_state"
      ; local "secrets"
      ; local "signature_lib"
      ; local "mina_base"
      ; local "mina_numbers"
      ; local "mina_base.import"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"; "ppx_version"; "ppx_deriving_yojson"
         ; "ppx_jane"; "ppx_deriving.make"
         ]);

  (* -- fields_derivers --------------------------------------------- *)
  library "fields_derivers"
    ~path:"src/lib/fields_derivers"
    ~inline_tests:true
    ~deps:
      [ opam "core_kernel"
      ; opam "fieldslib"
      ; opam "ppx_inline_test.config"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_annot"; "ppx_custom_printf"; "ppx_fields_conv"
         ; "ppx_inline_test"; "ppx_jane"; "ppx_let"
         ; "ppx_version"
         ]);

  (* -- fields_derivers.json ---------------------------------------- *)
  library "fields_derivers.json"
    ~internal_name:"fields_derivers_json"
    ~path:"src/lib/fields_derivers_json"
    ~inline_tests:true
    ~deps:
      [ opam "core_kernel"
      ; opam "fieldslib"
      ; opam "ppx_inline_test.config"
      ; opam "result"
      ; opam "yojson"
      ; local "fields_derivers"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_annot"; "ppx_custom_printf"
         ; "ppx_deriving_yojson"; "ppx_fields_conv"
         ; "ppx_inline_test"; "ppx_jane"; "ppx_let"
         ; "ppx_version"
         ]);

  (* -- fields_derivers.graphql ------------------------------------- *)
  library "fields_derivers.graphql"
    ~internal_name:"fields_derivers_graphql"
    ~path:"src/lib/fields_derivers_graphql"
    ~inline_tests:true
    ~deps:
      [ opam "async_kernel"
      ; opam "core_kernel"
      ; opam "fieldslib"
      ; opam "graphql"
      ; opam "graphql-async"
      ; opam "graphql_parser"
      ; opam "ppx_inline_test.config"
      ; opam "yojson"
      ; local "fields_derivers"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_annot"; "ppx_custom_printf"; "ppx_fields_conv"
         ; "ppx_inline_test"; "ppx_jane"; "ppx_let"
         ; "ppx_version"
         ]);

  (* -- fields_derivers.zkapps -------------------------------------- *)
  library "fields_derivers.zkapps"
    ~internal_name:"fields_derivers_zkapps"
    ~path:"src/lib/fields_derivers_zkapps"
    ~deps:
      [ opam "base"
      ; opam "base.caml"
      ; opam "core_kernel"
      ; opam "fieldslib"
      ; opam "graphql"
      ; opam "graphql_parser"
      ; opam "integers"
      ; opam "result"
      ; opam "sexplib0"
      ; local "currency"
      ; local "fields_derivers"
      ; local "fields_derivers.graphql"
      ; local "fields_derivers.json"
      ; local "mina_numbers"
      ; local "pickles"
      ; local "sgn"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "unsigned_extended"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_annot"; "ppx_assert"; "ppx_base"
         ; "ppx_custom_printf"; "ppx_deriving_yojson"
         ; "ppx_fields_conv"; "ppx_let"; "ppx_version"
         ]);

  (* -- rocksdb ----------------------------------------------------- *)
  library "rocksdb"
    ~path:"src/lib/rocksdb"
    ~inline_tests:false
    ~library_flags:[ "-linkall" ]
    ~flags:
      [ list [ atom ":standard"; atom "-warn-error"
             ; atom "+a" ] ]
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
    ~synopsis:"RocksDB Database module";

  (* -- key_cache --------------------------------------------------- *)
  library "key_cache"
    ~path:"src/lib/key_cache"
    ~deps:
      [ opam "core_kernel"
      ; opam "async_kernel"
      ]
    ~ppx:Ppx.minimal;

  (* -- key_cache.sync ---------------------------------------------- *)
  library "key_cache.sync"
    ~internal_name:"key_cache_sync"
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
         [ "ppx_mina"; "ppx_version"; "ppx_base"
         ; "ppx_here"; "ppx_let"
         ]);

  (* -- key_cache.async --------------------------------------------- *)
  library "key_cache.async"
    ~internal_name:"key_cache_async"
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
         [ "ppx_mina"; "ppx_version"; "ppx_base"
         ; "ppx_here"; "ppx_let"
         ]);

  (* -- key_cache.native -------------------------------------------- *)
  library "key_cache.native"
    ~internal_name:"key_cache_native"
    ~path:"src/lib/key_cache/native"
    ~deps:
      [ local "key_cache"
      ; local "key_cache.async"
      ; local "key_cache.sync"
      ]
    ~ppx:Ppx.minimal;

  (* -- parallel_scan ----------------------------------------------- *)
  library "parallel_scan"
    ~path:"src/lib/parallel_scan"
    ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "async"
      ; opam "digestif"
      ; opam "core"
      ; opam "lens"
      ; opam "async_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "async_unix"
      ; local "mina_metrics"
      ; local "mina_stdlib"
      ; local "pipe_lib"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_mina"; "ppx_version"
         ; "ppx_compare"; "lens.ppx_deriving"
         ])
    ~synopsis:
      "Parallel scan over an infinite stream \
       (incremental map-reduce)";

  (* -- merkle_address ---------------------------------------------- *)
  library "merkle_address"
    ~path:"src/lib/merkle_address"
    ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "bin_prot.shape"
      ; opam "bitstring"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "base.caml"
      ; opam "ppx_inline_test.config"
      ; local "mina_stdlib"
      ; local "ppx_version.runtime"
      ; local "test_util"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"; "ppx_version"; "ppx_jane"
         ; "ppx_hash"; "ppx_compare"
         ; "ppx_deriving_yojson"; "ppx_bitstring"
         ])
    ~synopsis:"Address for merkle database representations";

  (* -- merkle_list_prover ------------------------------------------ *)
  library "merkle_list_prover"
    ~path:"src/lib/merkle_list_prover"
    ~deps:[ opam "core_kernel" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane" ]);

  (* -- merkle_list_verifier ---------------------------------------- *)
  library "merkle_list_verifier"
    ~path:"src/lib/merkle_list_verifier"
    ~deps:
      [ opam "core_kernel"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_compare" ]);

  (* -- lmdb_storage ------------------------------------------------ *)
  library "lmdb_storage"
    ~path:"src/lib/lmdb_storage"
    ~deps:
      [ opam "lmdb"
      ; local "blake2"
      ; local "mina_stdlib_unix"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving.std"; "ppx_deriving_yojson"
         ; "ppx_jane"; "ppx_mina"; "ppx_version"
         ]);

  (* -- disk_cache (virtual) ---------------------------------------- *)
  library "disk_cache"
    ~path:"src/lib/disk_cache"
    ~virtual_modules:[ "disk_cache" ]
    ~default_implementation:"disk_cache.identity"
    ~deps:[ local "disk_cache.intf" ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_version" ]);

  (* -- disk_cache.filesystem --------------------------------------- *)
  library "disk_cache.filesystem"
    ~internal_name:"disk_cache_filesystem"
    ~path:"src/lib/disk_cache/filesystem"
    ~inline_tests:true
    ~implements:"disk_cache"
    ~deps:
      [ opam "core"
      ; opam "async"
      ; local "logger"
      ; local "mina_stdlib_unix"
      ; local "disk_cache.utils"
      ; local "disk_cache.test_lib"
      ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_version"; "ppx_jane" ]);

  (* -- disk_cache.identity ----------------------------------------- *)
  library "disk_cache.identity"
    ~internal_name:"disk_cache_identity"
    ~path:"src/lib/disk_cache/identity"
    ~inline_tests:true
    ~implements:"disk_cache"
    ~deps:
      [ opam "async_kernel"
      ; opam "core_kernel"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane" ]);

  (* -- disk_cache.lmdb --------------------------------------------- *)
  library "disk_cache.lmdb"
    ~internal_name:"disk_cache_lmdb"
    ~path:"src/lib/disk_cache/lmdb"
    ~inline_tests:true
    ~implements:"disk_cache"
    ~deps:
      [ opam "core_kernel"
      ; opam "core"
      ; local "lmdb_storage"
      ; local "disk_cache.utils"
      ; local "disk_cache.test_lib"
      ]
    ~ppx:
      (Ppx.custom [ "ppx_version"; "ppx_jane"; "ppx_mina" ]);

  (* -- disk_cache.test_lib ----------------------------------------- *)
  library "disk_cache.test_lib"
    ~internal_name:"disk_cache_test_lib"
    ~path:"src/lib/disk_cache/test_lib"
    ~deps:
      [ opam "core"
      ; opam "async"
      ; opam "mina_stdlib"
      ; local "logger"
      ; local "mina_stdlib_unix"
      ; local "disk_cache.intf"
      ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_version"; "ppx_jane" ]);

  (* -- disk_cache/test --------------------------------------------- *)
  (* library: test_cache_deadlock_lib *)
  private_library
    ~path:"src/lib/disk_cache/test"
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
      [ list [ atom ":standard"; atom "-w"; atom "+a"
             ; atom "-w"; atom "-22" ] ]
    "test_cache_deadlock_lib";

  (* test: test_lmdb_deadlock *)
  test "test_lmdb_deadlock"
    ~path:"src/lib/disk_cache/test"
    ~modules:[ "test_lmdb_deadlock" ]
    ~deps:
      [ opam "async"
      ; local "disk_cache.lmdb"
      ; local "test_cache_deadlock_lib"
      ]
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_version" ])
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a" ] ];

  (* test: test_filesystem_deadlock *)
  test "test_filesystem_deadlock"
    ~path:"src/lib/disk_cache/test"
    ~modules:[ "test_filesystem_deadlock" ]
    ~deps:
      [ opam "async"
      ; local "disk_cache.filesystem"
      ; local "test_cache_deadlock_lib"
      ]
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_version" ])
    ~flags:
      [ list [ atom ":standard"; atom "-w"; atom "+a" ] ];

  (* -- disk_cache.utils -------------------------------------------- *)
  library "disk_cache.utils"
    ~internal_name:"disk_cache_utils"
    ~path:"src/lib/disk_cache/utils"
    ~deps:
      [ opam "core"
      ; opam "async"
      ; local "mina_stdlib_unix"
      ; local "logger"
      ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_version"; "ppx_jane" ]);

  (* -- dummy_values ------------------------------------------------ *)
  library "dummy_values"
    ~path:"src/lib/dummy_values"
    ~flags:[ atom ":standard"; atom "-short-paths" ]
    ~deps:
      [ opam "core_kernel"
      ; local "crypto_params"
      ; local "snarky.backendless"
      ; local "pickles"
      ]
    ~ppx_runtime_libraries:[ "base" ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppxlib.metaquot" ])
    ~extra_stanzas:
      [ list
          [ atom "rule"
          ; list [ atom "targets"; atom "dummy_values.ml" ]
          ; list
              [ atom "deps"
              ; list
                  [ atom ":<"
                  ; atom "gen_values/gen_values.exe"
                  ]
              ]
          ; list
              [ atom "action"
              ; list
                  [ atom "run"
                  ; atom "%{<}"
                  ; atom "%{targets}"
                  ]
              ]
          ]
      ];

  (* -- gen_values (executable) ------------------------------------- *)
  private_executable
    ~path:"src/lib/dummy_values/gen_values"
    ~deps:
      [ opam "async_unix"
      ; opam "stdio"
      ; opam "base.caml"
      ; opam "ocaml-migrate-parsetree"
      ; opam "core"
      ; opam "async"
      ; opam "ppxlib"
      ; opam "ppxlib.ast"
      ; opam "ppxlib.astlib"
      ; opam "core_kernel"
      ; opam "compiler-libs"
      ; opam "async_kernel"
      ; opam "ocaml-compiler-libs.common"
      ; local "pickles_types"
      ; local "pickles"
      ; local "crypto_params"
      ; local "mina_metrics.none"
      ; local "logger.fake"
      ]
    ~forbidden_libraries:
      [ "mina_node_config"; "protocol_version" ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppxlib.metaquot" ])
    ~link_flags:[ "-linkall" ]
    ~modes:[ "native" ]
    "gen_values";

  (* -- mina_base.test_helpers -------------------------------------- *)
  library "mina_base.test_helpers"
    ~internal_name:"mina_base_test_helpers"
    ~path:"src/lib/mina_base/test/helpers"
    ~deps:
      [ opam "base"
      ; opam "base.caml"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "sexplib0"
      ; opam "yojson"
      ; local "currency"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_numbers"
      ; local "monad_lib"
      ; local "signature_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_base"; "ppx_let"; "ppx_assert"
         ; "ppx_version"
         ]);

  ()
