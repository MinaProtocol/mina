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
    ~flags:[ ":standard"; "-short-paths" ]
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
    ~flags:[ ":standard"; "-w"; "+a" ]
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

  ()
