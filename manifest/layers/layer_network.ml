(** Mina Blockchain, networking, and frontier libraries.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let network_peer =
  library "network_peer" ~path:"src/lib/network_peer"
    ~deps:
      [ async
      ; async_kernel
      ; async_rpc
      ; async_rpc_kernel
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; mina_metrics
      ; ppx_version_runtime
      ; result
      ; sexplib0
      ; Layer_base.mina_stdlib
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let trust_system =
  library "trust_system" ~path:"src/lib/trust_system"
    ~synopsis:"Track how much we trust peers" ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; network_peer
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; Layer_base.mina_stdlib
      ; Layer_ppx.ppx_version_runtime
      ; Layer_storage.key_value_database
      ; Layer_test.test_util
      ; local "logger"
      ; local "mina_metrics"
      ; local "pipe_lib"
      ; local "rocksdb"
      ; local "run_in_thread"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_register_event
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ] )

let mina_block =
  library "mina_block" ~path:"src/lib/mina_block"
    ~deps:
      [ base64
      ; core
      ; integers
      ; Layer_base.allocation_functor
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_consensus.coda_genesis_proof
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.blake2
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.proof_carrying_data
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_ppx.ppx_version_runtime
      ; Layer_protocol.blockchain_snark
      ; Layer_protocol.protocol_version
      ; Layer_service.verifier
      ; Layer_snark_worker.ledger_proof
      ; Layer_snark_worker.transaction_snark_work
      ; Layer_tooling.internal_tracing
      ; Layer_transaction.mina_transaction
      ; local "mina_net2"
      ; local "pasta_bindings"
      ; local "staged_ledger"
      ; local "transition_chain_verifier"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let () =
  file_stanzas ~path:"src/lib/mina_block/tests"
    (Dune_s_expr.parse_string
       {|(rule
 (alias precomputed_block)
 (target hetzner-itn-1-1795.json)
 (deps
(env_var TEST_PRECOMPUTED_BLOCK_JSON_PATH))
 (enabled_if
(= %{env:TEST_PRECOMPUTED_BLOCK_JSON_PATH=n} n))
 (action
(progn
 (run
  curl
  -L
  -o
  %{target}.gz
  https://storage.googleapis.com/o1labs-ci-test-data/precomputed-blocks/hetzner-itn-1-1795-3NL9Vn7Rg1mz8cS1gVxFkVPsjESG1Zu1XRpMLRQAz3W24hctRoD6.json.gz)
 (run gzip -d %{target}.gz))))

(rule
 (enabled_if
(<> %{env:TEST_PRECOMPUTED_BLOCK_JSON_PATH=n} n))
 (target hetzner-itn-1-1795.json)
 (deps
(env_var TEST_PRECOMPUTED_BLOCK_JSON_PATH))
 (action
(progn
 (copy %{env:TEST_PRECOMPUTED_BLOCK_JSON_PATH=n} %{target}))))|} )

let () =
  test "main" ~path:"src/lib/mina_block/tests"
    ~deps:
      [ alcotest
      ; async
      ; core_kernel
      ; mina_block
      ; yojson
      ; Layer_storage.disk_cache_lmdb
      ]
    ~file_deps:
      [ "hetzner-itn-1-1795.json"
      ; {|regtest-devnet-319281-3NKq8WXEzMFJH3VdmK4seCTpciyjSY2Rf39K7q1Yyt1p4HkqSzqA.json|}
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])

let staged_ledger =
  library "staged_ledger" ~path:"src/lib/staged_ledger"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ async
      ; async_unix
      ; core
      ; integers
      ; lens
      ; ppx_hash_runtime_lib
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_ppx.ppx_version_runtime
      ; Layer_protocol.mina_signature_kind
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.zkapp_command_builder
      ; Layer_service.verifier
      ; Layer_snark_worker.ledger_proof
      ; Layer_snark_worker.snark_work_lib
      ; Layer_snark_worker.transaction_snark_scan_state
      ; Layer_snark_worker.transaction_snark_work
      ; Layer_storage.cache_dir
      ; Layer_test.quickcheck_lib
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Layer_transaction.transaction_witness
      ; Snarky_lib.snarky_backendless
      ; local "mina_generators"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.lens_ppx_deriving
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_make
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_pipebang
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"Staged Ledger updates the current ledger with new transactions"

let () =
  executable "mina-standalone-snark-worker" ~internal_name:"run_snark_worker"
    ~package:"mina_snark_worker" ~path:"src/lib/snark_worker/standalone"
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; core
      ; core_kernel
      ; sexplib0
      ; uri
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_crypto.key_gen
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; Layer_protocol.transaction_snark
      ; Layer_snark_worker.snark_worker
      ; local "graphql_lib"
      ; local "mina_graphql"
      ]
    ~preprocessor_deps:
      [ "../../../graphql-ppx-config.inc"; "../../../../graphql_schema.json" ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_let
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_version
         ; Ppx_lib.graphql_ppx
         ; "--"
         ; {|%{read-lines:../../../graphql-ppx-config.inc}|}
         ] )

let genesis_ledger_helper_lib =
  library "genesis_ledger_helper.lib" ~internal_name:"genesis_ledger_helper_lib"
    ~path:"src/lib/genesis_ledger_helper/lib" ~inline_tests:true
    ~deps:
      [ base64
      ; core
      ; core_kernel
      ; integers
      ; sexplib0
      ; splittable_random
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_consensus.coda_genesis_proof
      ; Layer_crypto.random_oracle
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_logging.logger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_storage.key_cache_native
      ; local "mina_runtime_config"
      ; local "ppx_inline_test.config"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_custom_printf
         ] )

let genesis_ledger_helper =
  library "genesis_ledger_helper" ~path:"src/lib/genesis_ledger_helper"
    ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_caml
      ; core
      ; core_kernel
      ; core_kernel_uuid
      ; core_uuid
      ; digestif
      ; genesis_ledger_helper_lib
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_stdlib_unix
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.coda_genesis_proof
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.blake2
      ; Layer_crypto.random_oracle
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_pickles.pickles
      ; Layer_protocol.blockchain_snark
      ; Layer_storage.cache_dir
      ; local "cli_lib"
      ; local "mina_runtime_config"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_custom_printf
         ] )

let vrf_lib_tests =
  library "vrf_lib_tests" ~path:"src/lib/vrf_lib/tests"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ core
      ; core_kernel
      ; ppx_deriving_runtime
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.mina_base
      ; Layer_consensus.vrf_lib
      ; Layer_crypto.bignum_bigint
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_snarky.snarky_curves
      ; Layer_snarky.snarky_field_extensions
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.fold_lib
      ; Snarky_lib.snarky
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_bench
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_version
         ] )

let vrf_evaluator =
  library "vrf_evaluator" ~path:"src/lib/vrf_evaluator"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; integers
      ; rpc_parallel
      ; sexplib0
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.interruptible
      ; Layer_consensus.consensus
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; Layer_logging.logger
      ; Layer_logging.logger_file_system
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let snark_profiler_lib =
  library "snark_profiler_lib" ~path:"src/lib/snark_profiler_lib"
    ~deps:
      [ astring
      ; async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; base_internalhash_types
      ; core
      ; core_kernel
      ; genesis_ledger_helper
      ; genesis_ledger_helper_lib
      ; integers
      ; result
      ; sexplib0
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.parallel
      ; Layer_consensus.coda_genesis_proof
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.transaction_snark_tests
      ; Layer_protocol.zkapp_command_builder
      ; Layer_service.verifier
      ; Layer_snark_worker.snark_work_lib
      ; Layer_snark_worker.snark_worker
      ; Layer_test.test_util
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; local "generated_graphql_queries"
      ; local "mina_generators"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_bench
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_fixed_literal
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_module_timer
         ; Ppx_lib.ppx_optional
         ; Ppx_lib.ppx_pipebang
         ; Ppx_lib.ppx_sexp_message
         ; Ppx_lib.ppx_sexp_value
         ; Ppx_lib.ppx_string
         ; Ppx_lib.ppx_typerep_conv
         ; Ppx_lib.ppx_variants_conv
         ] )

let generated_graphql_queries =
  library "generated_graphql_queries" ~path:"src/lib/generated_graphql_queries"
    ~preprocessor_deps:
      [ "../../../graphql_schema.json"; "../../graphql-ppx-config.inc" ]
    ~deps:
      [ async
      ; base
      ; cohttp
      ; cohttp_async
      ; core
      ; graphql_async
      ; graphql_cohttp
      ; yojson
      ; Layer_base.mina_base
      ; local "graphql_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_base
         ; Ppx_lib.ppx_version
         ; Ppx_lib.graphql_ppx
         ; "--"
         ; {|%{read-lines:../../graphql-ppx-config.inc}|}
         ] )
    ~extra_stanzas:
      [ Dune_s_expr.parse_string
          {|(rule
 (targets generated_graphql_queries.ml)
 (deps
(:< gen/gen.exe))
 (action
(run %{<} %{targets})))|}
        |> List.hd
      ]

let () =
  private_executable ~path:"src/lib/generated_graphql_queries/gen"
    ~modes:[ "native" ]
    ~deps:
      [ base
      ; base_caml
      ; compiler_libs
      ; core_kernel
      ; ocaml_migrate_parsetree
      ; ppxlib
      ; ppxlib_ast
      ; ppxlib_astlib
      ; stdio
      ; yojson
      ; Layer_base.mina_base
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_base
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppxlib_metaquot
         ; Ppx_lib.graphql_ppx
         ] )
    "gen"

let mina_incremental =
  library "mina_incremental" ~path:"src/lib/mina_incremental"
    ~deps:[ async_kernel; incremental; Layer_concurrency.pipe_lib ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version ])

let mina_plugins =
  library "mina_plugins" ~path:"src/lib/mina_plugins"
    ~deps:
      [ base
      ; core
      ; core_kernel
      ; dynlink
      ; Layer_logging.logger
      ; local "mina_lib"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])

let plugin_do_nothing =
  private_library ~path:"src/lib/mina_plugins/examples/do_nothing"
    ~deps:
      [ core
      ; core_kernel
      ; mina_plugins
      ; Layer_logging.logger
      ; local "mina_lib"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_mina ])
    "plugin_do_nothing"

(* Networking & Frontier Layer                                      *)

let gossip_net =
  library "gossip_net" ~path:"src/lib/gossip_net" ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_rpc
      ; async_rpc_kernel
      ; async_unix
      ; base
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; cohttp_async
      ; core
      ; core_kernel
      ; integers
      ; mina_block
      ; network_peer
      ; ppx_hash_runtime_lib
      ; sexplib0
      ; trust_system
      ; uri
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_stdlib
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.pipe_lib
      ; Layer_domain.block_time
      ; Layer_domain.genesis_constants
      ; Layer_domain.node_addrs_and_ports
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_ppx.ppx_version_runtime
      ; Layer_tooling.mina_metrics
      ; Layer_tooling.perf_histograms
      ; Layer_transaction.mina_transaction
      ; local "mina_net2"
      ; local "network_pool"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_make
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_pipebang
         ] )
    ~synopsis:"Gossip Network"

let mina_net2 =
  library "mina_net2" ~path:"src/lib/mina_net2" ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base58
      ; base64
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; capnp
      ; core
      ; core_kernel
      ; digestif
      ; integers
      ; libp2p_ipc
      ; network_peer
      ; ppx_inline_test_config
      ; sexplib0
      ; splittable_random
      ; stdio
      ; yojson
      ; Layer_base.error_json
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_stdlib_unix
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.pipe_lib
      ; Layer_concurrency.timeout_lib
      ; Layer_consensus.consensus
      ; Layer_crypto.blake2
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_ppx.ppx_version_runtime
      ; Layer_tooling.mina_metrics
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let mina_net2_tests =
  private_library ~path:"src/lib/mina_net2/tests" ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; mina_net2
      ; network_peer
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_stdlib_unix
      ; Layer_concurrency.child_processes
      ; Layer_logging.logger
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])
    "mina_net2_tests"

let mina_networking =
  library "mina_networking" ~path:"src/lib/mina_networking"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_rpc_kernel
      ; async_unix
      ; base
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; gossip_net
      ; mina_block
      ; mina_net2
      ; network_peer
      ; result
      ; sexplib0
      ; staged_ledger
      ; trust_system
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_stdlib
      ; Layer_base.sync_status
      ; Layer_base.with_hash
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.signature_lib
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.proof_carrying_data
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_ppx.ppx_version_runtime
      ; Layer_protocol.protocol_version
      ; Layer_snark_worker.work_selector
      ; Layer_tooling.mina_metrics
      ; Layer_tooling.perf_histograms
      ; local "downloader"
      ; local "network_pool"
      ; local "sync_handler"
      ; local "syncable_ledger"
      ; local "transition_chain_prover"
      ; local "transition_handler"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_make
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_register_event
         ; Ppx_lib.ppx_custom_printf
         ] )
    ~synopsis:"Networking layer for coda"

let network_pool =
  library "network_pool" ~path:"src/lib/network_pool" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async
      ; async_unix
      ; core
      ; integers
      ; mina_net2
      ; network_peer
      ; staged_ledger
      ; stdio
      ; trust_system
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.sgn_type
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.interruptible
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_ppx.ppx_version_runtime
      ; Layer_protocol.mina_signature_kind
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.zkapp_command_builder
      ; Layer_service.verifier
      ; Layer_snark_worker.ledger_proof
      ; Layer_snark_worker.snark_work_lib
      ; Layer_snark_worker.transaction_snark_work
      ; Layer_storage.zkapp_vk_cache_tag
      ; Layer_test.quickcheck_lib
      ; Layer_tooling.mina_metrics
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; local "transition_frontier"
      ; local "transition_frontier_base"
      ; local "transition_frontier_extensions"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_pipebang
         ; Ppx_lib.ppx_register_event
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:
      "Network pool is an interface that processes incoming diffs and then \
       broadcasts them"

let syncable_ledger =
  library "syncable_ledger" ~path:"src/lib/syncable_ledger"
    ~library_flags:[ "-linkall" ]
    ~flags:[ Dune_s_expr.atom ":standard"; Dune_s_expr.atom "-short-paths" ]
    ~deps:
      [ async
      ; async_kernel
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; network_peer
      ; sexplib0
      ; trust_system
      ; Layer_base.error_json
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_stdlib
      ; Layer_concurrency.pipe_lib
      ; Layer_ledger.merkle_address
      ; Layer_ledger.merkle_ledger
      ; Layer_logging.logger
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_register_event
         ] )
    ~synopsis:"Synchronization of Merkle-tree backed ledgers"

let syncable_ledger_test =
  private_library ~path:"src/lib/syncable_ledger/test" ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; network_peer
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; syncable_ledger
      ; trust_system
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_concurrency.pipe_lib
      ; Layer_crypto.signature_lib
      ; Layer_domain.data_hash_lib
      ; Layer_ledger.merkle_address
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.merkle_ledger_tests
      ; Layer_logging.logger
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    "test"

let sync_handler =
  library "sync_handler" ~path:"src/lib/sync_handler" ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; core
      ; core_kernel
      ; mina_block
      ; network_peer
      ; sexplib0
      ; staged_ledger
      ; syncable_ledger
      ; trust_system
      ; Layer_base.mina_base
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.with_hash
      ; Layer_consensus.consensus
      ; Layer_consensus.precomputed_values
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.proof_carrying_data
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; local "best_tip_prover"
      ; local "mina_intf"
      ; local "transition_frontier"
      ; local "transition_frontier_base"
      ; local "transition_frontier_extensions"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let transition_chain_prover =
  library "transition_chain_prover" ~path:"src/lib/transition_chain_prover"
    ~deps:
      [ core
      ; core_kernel
      ; mina_block
      ; Layer_base.mina_base
      ; Layer_base.mina_wire_types
      ; Layer_base.with_hash
      ; Layer_consensus.mina_state
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_list_prover
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; local "mina_intf"
      ; local "transition_frontier"
      ; local "transition_frontier_base"
      ; local "transition_frontier_extensions"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let transition_chain_verifier =
  library "transition_chain_verifier" ~path:"src/lib/transition_chain_verifier"
    ~deps:
      [ core
      ; core_kernel
      ; Layer_base.mina_base
      ; Layer_base.mina_stdlib
      ; Layer_consensus.mina_state
      ; Layer_domain.data_hash_lib
      ; Layer_ledger.merkle_list_verifier
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_compare ] )

let transition_frontier_base =
  library "transition_frontier_base" ~internal_name:"frontier_base"
    ~path:"src/lib/transition_frontier/frontier_base"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; integers
      ; mina_block
      ; mina_net2
      ; network_peer
      ; sexplib0
      ; staged_ledger
      ; trust_system
      ; Layer_base.allocation_functor
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.sgn_type
      ; Layer_base.unsigned_extended
      ; Layer_base.visualization
      ; Layer_base.with_hash
      ; Layer_consensus.coda_genesis_proof
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_ppx.ppx_version_runtime
      ; Layer_protocol.protocol_version
      ; Layer_protocol.transaction_snark
      ; Layer_service.verifier
      ; Layer_snark_worker.ledger_proof
      ; Layer_snark_worker.transaction_snark_work
      ; Layer_tooling.internal_tracing
      ; Layer_transaction.mina_transaction_logic
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let transition_frontier_full_frontier =
  library "transition_frontier_full_frontier" ~internal_name:"full_frontier"
    ~path:"src/lib/transition_frontier/full_frontier"
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
      ; integers
      ; mina_block
      ; sexplib0
      ; staged_ledger
      ; stdio
      ; transition_frontier_base
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_base.visualization
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_protocol.protocol_version
      ; Layer_service.verifier
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; Layer_transaction.mina_transaction_logic
      ; local "transition_frontier_persistent_root"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let transition_frontier_persistent_root =
  library "transition_frontier_persistent_root" ~internal_name:"persistent_root"
    ~path:"src/lib/transition_frontier/persistent_root"
    ~deps:
      [ base_caml
      ; core
      ; core_kernel
      ; core_kernel_uuid
      ; core_uuid
      ; transition_frontier_base
      ; Layer_base.mina_base
      ; Layer_base.mina_stdlib_unix
      ; Layer_consensus.precomputed_values
      ; Layer_domain.data_hash_lib
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])

let transition_frontier_persistent_frontier =
  library "transition_frontier_persistent_frontier"
    ~internal_name:"persistent_frontier"
    ~path:"src/lib/transition_frontier/persistent_frontier"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; mina_block
      ; result
      ; sexplib0
      ; staged_ledger
      ; transition_frontier_base
      ; transition_frontier_full_frontier
      ; transition_frontier_persistent_root
      ; trust_system
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_stdlib_unix
      ; Layer_base.mina_wire_types
      ; Layer_base.otp_lib
      ; Layer_base.sgn_type
      ; Layer_base.with_hash
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.sgn
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_ppx.ppx_version_runtime
      ; Layer_service.verifier
      ; Layer_storage.rocksdb
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; Layer_transaction.mina_transaction_logic
      ; local "transition_frontier_extensions"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let transition_frontier_extensions =
  library "transition_frontier_extensions" ~internal_name:"extensions"
    ~path:"src/lib/transition_frontier/extensions"
    ~deps:
      [ async_kernel
      ; base_caml
      ; base_internalhash_types
      ; core_kernel
      ; mina_block
      ; result
      ; sexplib0
      ; staged_ledger
      ; transition_frontier_base
      ; transition_frontier_full_frontier
      ; Layer_base.mina_base
      ; Layer_base.mina_wire_types
      ; Layer_base.with_hash
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.mina_state
      ; Layer_domain.data_hash_lib
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_snark_worker.transaction_snark_work
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])

let transition_frontier =
  library "transition_frontier" ~path:"src/lib/transition_frontier"
    ~deps:
      [ async
      ; async_unix
      ; core
      ; integers
      ; mina_block
      ; mina_net2
      ; network_peer
      ; staged_ledger
      ; transition_frontier_base
      ; transition_frontier_extensions
      ; transition_frontier_full_frontier
      ; transition_frontier_persistent_frontier
      ; transition_frontier_persistent_root
      ; trust_system
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.signature_lib
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_protocol.protocol_version
      ; Layer_service.verifier
      ; Layer_storage.cache_lib
      ; Layer_test.quickcheck_lib
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; Layer_transaction.mina_transaction
      ; local "downloader"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let transition_frontier_tests =
  private_library ~path:"src/lib/transition_frontier/tests" ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; core
      ; core_kernel
      ; core_kernel_uuid
      ; core_uuid
      ; libp2p_ipc
      ; mina_block
      ; mina_net2
      ; ppx_inline_test_config
      ; sexplib0
      ; staged_ledger
      ; transition_frontier
      ; transition_frontier_base
      ; transition_frontier_full_frontier
      ; transition_frontier_persistent_root
      ; yojson
      ; Layer_base.mina_base
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_protocol.protocol_version
      ; Layer_service.verifier
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version; Ppx_lib.ppx_mina ])
    "transition_frontier_tests"

let transition_frontier_controller =
  library "transition_frontier_controller"
    ~path:"src/lib/transition_frontier_controller"
    ~deps:
      [ async_kernel
      ; base
      ; core
      ; core_kernel
      ; mina_block
      ; network_peer
      ; staged_ledger
      ; transition_frontier
      ; transition_frontier_base
      ; transition_frontier_extensions
      ; Layer_base.mina_base
      ; Layer_base.with_hash
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.consensus
      ; Layer_consensus.precomputed_values
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_storage.cache_lib
      ; Layer_tooling.mina_metrics
      ; local "bootstrap_controller"
      ; local "ledger_catchup"
      ; local "transition_handler"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_mina ])

let transition_handler =
  library "transition_handler" ~path:"src/lib/transition_handler"
    ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_internalhash_types
      ; core
      ; core_kernel
      ; integers
      ; mina_block
      ; mina_net2
      ; network_peer
      ; network_pool
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; staged_ledger
      ; transition_frontier
      ; transition_frontier_base
      ; transition_frontier_extensions
      ; trust_system
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.otp_lib
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_service.verifier
      ; Layer_storage.cache_lib
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; Layer_tooling.perf_histograms
      ; Layer_transaction.mina_transaction
      ; local "mina_runtime_config"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let transition_router =
  library "transition_router" ~path:"src/lib/transition_router"
    ~deps:
      [ async
      ; async_kernel
      ; base_caml
      ; core
      ; core_kernel
      ; integers
      ; mina_block
      ; mina_net2
      ; mina_networking
      ; network_peer
      ; sexplib0
      ; transition_frontier
      ; transition_frontier_base
      ; transition_frontier_controller
      ; transition_frontier_persistent_frontier
      ; transition_frontier_persistent_root
      ; transition_handler
      ; trust_system
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_concurrency.interruptible
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.signature_lib
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.proof_carrying_data
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; local "best_tip_prover"
      ; local "bootstrap_controller"
      ; local "ledger_catchup"
      ; local "mina_intf"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ] )

let bootstrap_controller =
  library "bootstrap_controller" ~path:"src/lib/bootstrap_controller"
    ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; core
      ; core_kernel
      ; mina_block
      ; mina_net2
      ; mina_networking
      ; network_peer
      ; ppx_inline_test_config
      ; sexplib0
      ; staged_ledger
      ; sync_handler
      ; syncable_ledger
      ; transition_frontier
      ; transition_frontier_base
      ; transition_frontier_persistent_frontier
      ; transition_frontier_persistent_root
      ; trust_system
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_base_util
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.sgn_type
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.sgn
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_service.verifier
      ; Layer_tooling.mina_metrics
      ; Layer_transaction.mina_transaction_logic
      ; local "fake_network"
      ; local "mina_intf"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_register_event
         ; Ppx_lib.ppx_version
         ] )

let best_tip_prover =
  library "best_tip_prover" ~path:"src/lib/best_tip_prover"
    ~deps:
      [ async_kernel
      ; core
      ; core_kernel
      ; mina_block
      ; transition_frontier
      ; transition_frontier_base
      ; Layer_base.mina_base
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.with_hash
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.proof_carrying_data
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_list_prover
      ; Layer_ledger.merkle_list_verifier
      ; Layer_logging.logger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; local "mina_intf"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ] )

let ledger_catchup =
  library "ledger_catchup" ~path:"src/lib/ledger_catchup" ~inline_tests:true
    ~deps:
      [ async
      ; core
      ; mina_block
      ; mina_net2
      ; mina_networking
      ; network_peer
      ; network_pool
      ; transition_chain_verifier
      ; transition_frontier
      ; transition_frontier_base
      ; transition_frontier_extensions
      ; transition_handler
      ; trust_system
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.proof_carrying_data
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_protocol.protocol_version
      ; Layer_service.verifier
      ; Layer_snark_worker.transaction_snark_work
      ; Layer_storage.cache_lib
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; local "downloader"
      ; local "fake_network"
      ; local "mina_runtime_config"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let downloader =
  library "downloader" ~path:"src/lib/downloader"
    ~deps:
      [ async
      ; async_unix
      ; core
      ; core_kernel_pairing_heap
      ; network_peer
      ; trust_system
      ; Layer_base.mina_stdlib
      ; Layer_concurrency.pipe_lib
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let block_producer =
  library "block_producer" ~path:"src/lib/block_producer"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; core
      ; core_kernel
      ; integers
      ; mina_block
      ; mina_net2
      ; mina_networking
      ; network_pool
      ; sexplib0
      ; staged_ledger
      ; transition_chain_prover
      ; transition_frontier
      ; transition_frontier_base
      ; transition_frontier_extensions
      ; vrf_evaluator
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.otp_lib
      ; Layer_base.sgn_type
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_concurrency.interruptible
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.coda_genesis_proof
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_protocol.blockchain_snark
      ; Layer_protocol.protocol_version
      ; Layer_protocol.transaction_snark
      ; Layer_service.prover
      ; Layer_snark_worker.ledger_proof
      ; Layer_snark_worker.transaction_snark_scan_state
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; local "mina_intf"
      ; local "mina_runtime_config"
      ; local "node_error_service"
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_register_event
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"Coda block producer"

let fake_network =
  library "fake_network" ~path:"src/lib/fake_network"
    ~deps:
      [ async
      ; async_unix
      ; core
      ; core_uuid
      ; mina_block
      ; mina_networking
      ; network_peer
      ; network_pool
      ; staged_ledger
      ; sync_handler
      ; transition_chain_prover
      ; transition_frontier
      ; transition_handler
      ; trust_system
      ; Layer_base.mina_base
      ; Layer_base.mina_stdlib
      ; Layer_base.with_hash
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.coda_genesis_proof
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.proof_carrying_data
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_service.verifier
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "mina_intf"
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )
