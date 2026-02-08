(** Mina Blockchain, networking, and frontier libraries.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

(* ================================================================ *)
(* Blockchain & Network Layer                                       *)
(* ================================================================ *)

(* -- mina_block ---------------------------------------------------- *)
let mina_block =
  library "mina_block" ~path:"src/lib/mina_block"
  ~deps:
    [ integers
    ; base64
    ; core
    ; Layer_ledger.mina_ledger
    ; Layer_infra.mina_numbers
    ; Layer_base.currency
    ; Layer_base.unsigned_extended
    ; Layer_snark_worker.ledger_proof
    ; Layer_infra.logger
    ; Layer_protocol.blockchain_snark
    ; Layer_base.allocation_functor
    ; Layer_service.verifier
    ; Layer_ledger.staged_ledger_diff
    ; Layer_protocol.protocol_version
    ; Layer_consensus.consensus
    ; Layer_consensus.precomputed_values
    ; Layer_consensus.mina_state
    ; local "mina_net2"

    ; Layer_base.mina_base
    ; Layer_transaction.mina_transaction
    ; Layer_base.mina_stdlib
    ; local "transition_chain_verifier"

    ; local "staged_ledger"

    ; Layer_domain.data_hash_lib
    ; Layer_domain.block_time
    ; Layer_base.with_hash
    ; Layer_crypto.signature_lib
    ; Layer_domain.genesis_constants
    ; Layer_snark_worker.transaction_snark_work
    ; Layer_consensus.coda_genesis_proof
    ; Layer_crypto.blake2
    ; Layer_crypto.snark_params
    ; Layer_crypto.crypto_params
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; local "pasta_bindings"
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_crypto.random_oracle
    ; Layer_crypto.random_oracle_input
    ; Layer_ppx.ppx_version_runtime
    ; Layer_base.mina_wire_types
    ; Layer_tooling.internal_tracing
    ; Layer_domain.proof_carrying_data
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_version
       ; Ppx_lib.ppx_jane
       ; Ppx_lib.ppx_deriving_std
       ; Ppx_lib.ppx_deriving_yojson
       ] )

(* -- mina_block/tests ---------------------------------------------- *)
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
    ; Layer_storage.disk_cache_lmdb
    ; mina_block
    ; yojson
    ]
  ~file_deps:
    [ "hetzner-itn-1-1795.json"
    ; {|regtest-devnet-319281-3NKq8WXEzMFJH3VdmK4seCTpciyjSY2Rf39K7q1Yyt1p4HkqSzqA.json|}
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])

(* -- staged_ledger ------------------------------------------------- *)
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
    ; Layer_base.mina_stdlib
    ; Layer_storage.cache_dir
    ; Layer_base.child_processes
    ; Layer_consensus.coda_genesis_ledger
    ; Layer_consensus.consensus
    ; Layer_base.currency
    ; Layer_domain.data_hash_lib
    ; Layer_base.error_json
    ; Layer_domain.genesis_constants
    ; Layer_tooling.internal_tracing
    ; Layer_crypto.kimchi_backend
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_snark_worker.ledger_proof
    ; Layer_infra.logger
    ; Layer_ledger.merkle_ledger
    ; Layer_base.mina_base
    ; local "mina_generators"
    ; Layer_ledger.mina_ledger
    ; Layer_tooling.mina_metrics
    ; Layer_infra.mina_numbers
    ; Layer_infra.mina_signature_kind
    ; Layer_consensus.mina_state
    ; Layer_transaction.mina_transaction
    ; Layer_transaction.mina_transaction_logic
    ; Layer_base.mina_wire_types
    ; Layer_infra.o1trace
    ; Layer_base.one_or_two
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.pickles_types
    ; Layer_ppx.ppx_version_runtime
    ; Layer_test.quickcheck_lib
    ; Layer_crypto.random_oracle
    ; Layer_crypto.random_oracle_input
    ; Layer_crypto.sgn
    ; Layer_crypto.signature_lib
    ; local "snarky.backendless"
    ; Layer_crypto.snark_params
    ; Layer_snark_worker.snark_work_lib
    ; Layer_ledger.staged_ledger_diff
    ; Layer_protocol.transaction_snark
    ; Layer_snark_worker.transaction_snark_scan_state
    ; Layer_snark_worker.transaction_snark_work
    ; Layer_transaction.transaction_witness
    ; Layer_service.verifier
    ; Layer_base.with_hash
    ; Layer_protocol.zkapp_command_builder
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

(* -- snark_worker/standalone --------------------------------------- *)
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
    ; Layer_domain.genesis_constants
    ; local "graphql_lib"
    ; Layer_crypto.key_gen
    ; Layer_base.mina_base
    ; Layer_base.mina_base_import
    ; local "mina_graphql"
    ; Layer_crypto.signature_lib
    ; Layer_snark_worker.snark_worker
    ; Layer_protocol.transaction_snark
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

(* -- genesis_ledger_helper/lib ------------------------------------- *)
let genesis_ledger_helper_lib =
  library "genesis_ledger_helper.lib" ~internal_name:"genesis_ledger_helper_lib"
  ~path:"src/lib/genesis_ledger_helper/lib" ~inline_tests:true
  ~deps:
    [ splittable_random
    ; integers
    ; core_kernel
    ; core
    ; sexplib0
    ; base64
    ; Layer_base.mina_wire_types
    ; Layer_base.mina_base_import
    ; Layer_crypto.random_oracle
    ; Layer_domain.data_hash_lib
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_types
    ; Layer_base.unsigned_extended
    ; Layer_base.mina_stdlib
    ; Layer_storage.key_cache_native
    ; Layer_base.mina_base
    ; local "mina_runtime_config"
    ; Layer_domain.genesis_constants
    ; Layer_consensus.coda_genesis_proof
    ; Layer_crypto.signature_lib
    ; Layer_infra.mina_numbers
    ; Layer_base.with_hash
    ; Layer_base.currency
    ; Layer_crypto.pickles_backend
    ; Layer_infra.logger
    ; Layer_crypto.snark_params
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
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

(* -- genesis_ledger_helper ----------------------------------------- *)
let genesis_ledger_helper =
  library "genesis_ledger_helper" ~path:"src/lib/genesis_ledger_helper"
  ~inline_tests:true
  ~deps:
    [ ppx_inline_test_config
    ; core_kernel_uuid
    ; async_unix
    ; async
    ; core_kernel
    ; core
    ; async_kernel
    ; core_uuid
    ; base_caml
    ; sexplib0
    ; digestif
    ; Layer_ledger.mina_ledger
    ; Layer_base.with_hash
    ; Layer_base.mina_stdlib
    ; Layer_protocol.blockchain_snark
    ; Layer_base.error_json
    ; Layer_consensus.mina_state
    ; Layer_crypto.random_oracle
    ; Layer_crypto.blake2
    ; Layer_infra.mina_numbers
    ; genesis_ledger_helper_lib
    ; Layer_consensus.precomputed_values
    ; Layer_consensus.coda_genesis_ledger
    ; local "mina_runtime_config"
    ; Layer_crypto.signature_lib
    ; Layer_base.mina_base
    ; Layer_domain.genesis_constants
    ; Layer_storage.cache_dir
    ; Layer_consensus.coda_genesis_proof
    ; Layer_base.currency
    ; Layer_domain.data_hash_lib
    ; Layer_crypto.snark_params
    ; Layer_base.unsigned_extended
    ; Layer_consensus.consensus
    ; Layer_crypto.pickles
    ; Layer_infra.logger
    ; Layer_base.mina_base_import
    ; Layer_ledger.staged_ledger_diff
    ; Layer_infra.mina_stdlib_unix
    ; local "cli_lib"
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

(* -- vrf_lib/tests ------------------------------------------------- *)
let vrf_lib_tests =
  library "vrf_lib_tests" ~path:"src/lib/vrf_lib/tests"
  ~library_flags:[ "-linkall" ] ~inline_tests:true
  ~deps:
    [ core
    ; core_kernel
    ; ppx_inline_test_config
    ; sexplib0
    ; ppx_deriving_runtime
    ; Layer_crypto.snark_params
    ; Layer_crypto.signature_lib
    ; local "snarky_curves"
    ; local "snarky"
    ; Layer_consensus.vrf_lib
    ; Layer_base.mina_base
    ; Layer_crypto.random_oracle
    ; local "fold_lib"
    ; Layer_crypto.pickles
    ; Layer_crypto.bignum_bigint
    ; local "snarky.backendless"
    ; local "bitstring_lib"
    ; Layer_crypto.crypto_params
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.kimchi_backend
    ; local "kimchi_bindings"
    ; local "kimchi_types"
    ; local "pasta_bindings"
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; local "snarky_field_extensions"
    ; local "tuple_lib"
    ; Layer_domain.genesis_constants
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.h_list_ppx; Ppx_lib.ppx_bench; Ppx_lib.ppx_compare; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ] )

(* -- vrf_evaluator ------------------------------------------------- *)
let vrf_evaluator =
  library "vrf_evaluator" ~path:"src/lib/vrf_evaluator"
  ~deps:
    [ async_unix
    ; async_kernel
    ; rpc_parallel
    ; core
    ; async
    ; core_kernel
    ; bin_prot_shape
    ; sexplib0
    ; base_caml
    ; integers
    ; Layer_base.mina_wire_types
    ; Layer_base.error_json
    ; Layer_base.currency
    ; Layer_base.unsigned_extended
    ; Layer_concurrency.interruptible
    ; Layer_crypto.signature_lib
    ; Layer_consensus.consensus
    ; Layer_base.mina_base
    ; Layer_base.child_processes
    ; Layer_infra.mina_numbers
    ; Layer_domain.genesis_constants
    ; Layer_infra.logger
    ; Layer_infra.logger_file_system
    ; Layer_ppx.ppx_version_runtime
    ; Layer_base.mina_compile_config
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

(* -- snark_profiler_lib -------------------------------------------- *)
let snark_profiler_lib =
  library "snark_profiler_lib" ~path:"src/lib/snark_profiler_lib"
  ~deps:
    [ integers
    ; astring
    ; sexplib0
    ; result
    ; async_kernel
    ; async_unix
    ; core_kernel
    ; core
    ; base
    ; async
    ; base_caml
    ; base_internalhash_types
    ; Layer_base.mina_stdlib
    ; Layer_base.mina_wire_types
    ; Layer_base.child_processes
    ; Layer_snark_worker.snark_worker
    ; genesis_ledger_helper_lib
    ; Layer_infra.logger
    ; Layer_consensus.coda_genesis_proof
    ; Layer_domain.data_hash_lib
    ; Layer_base.currency
    ; Layer_domain.genesis_constants
    ; local "generated_graphql_queries"

    ; Layer_transaction.mina_transaction
    ; local "mina_generators"
    ; Layer_ledger.mina_ledger
    ; Layer_base.mina_base
    ; Layer_consensus.mina_state
    ; genesis_ledger_helper
    ; Layer_crypto.signature_lib
    ; Layer_base.mina_base_import
    ; Layer_infra.mina_numbers
    ; Layer_consensus.precomputed_values
    ; Layer_base.with_hash
    ; Layer_protocol.transaction_snark
    ; Layer_protocol.transaction_snark_tests
    ; Layer_protocol.transaction_protocol_state
    ; Layer_test.test_util
    ; Layer_crypto.sgn
    ; Layer_base.unsigned_extended
    ; Layer_snark_worker.snark_work_lib
    ; Layer_base.mina_compile_config
    ; Layer_transaction.mina_transaction_logic
    ; Layer_service.verifier
    ; Layer_infra.parallel
    ; Layer_crypto.random_oracle
    ; Layer_crypto.kimchi_backend
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_crypto.pickles_types
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.snark_params
    ; Layer_protocol.zkapp_command_builder
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

(* -- rosetta_lib --------------------------------------------------- *)
let rosetta_lib =
  library "rosetta_lib" ~path:"src/lib/rosetta_lib"
  ~library_flags:[ "-linkall" ]
  ~deps:
    [ result
    ; base_caml
    ; caqti
    ; core_kernel
    ; base
    ; async_kernel
    ; uri
    ; sexplib0
    ; integers
    ; Layer_base.mina_wire_types
    ; Layer_base.hex
    ; Layer_crypto.random_oracle_input
    ; Layer_infra.mina_numbers
    ; Layer_base.mina_stdlib
    ; Layer_crypto.signature_lib
    ; Layer_crypto.snark_params
    ; Layer_base.rosetta_models
    ; Layer_base.mina_base
    ; Layer_base.currency
    ; Layer_base.unsigned_extended
    ; Layer_base.mina_base_import
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_version
       ; Ppx_lib.ppx_assert
       ; Ppx_lib.ppx_let
       ; Ppx_lib.ppx_sexp_conv
       ; Ppx_lib.ppx_compare
       ; Ppx_lib.ppx_deriving_std
       ; Ppx_lib.ppx_custom_printf
       ; Ppx_lib.ppx_deriving_yojson
       ; Ppx_lib.ppx_inline_test
       ] )
  ~synopsis:"Rosetta-related support code"

(* -- generated_graphql_queries ------------------------------------- *)
let generated_graphql_queries =
  library "generated_graphql_queries" ~path:"src/lib/generated_graphql_queries"
  ~preprocessor_deps:
    [ "../../../graphql_schema.json"; "../../graphql-ppx-config.inc" ]
  ~deps:
    [ async
    ; cohttp
    ; core
    ; cohttp_async
    ; Layer_base.mina_base
    ; graphql_async
    ; graphql_cohttp
    ; yojson
    ; local "graphql_lib"
    ; base
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

(* -- generated_graphql_queries/gen --------------------------------- *)
let () =
  private_executable ~path:"src/lib/generated_graphql_queries/gen"
  ~modes:[ "native" ]
  ~deps:
    [ base
    ; core_kernel
    ; ppxlib
    ; ppxlib_ast
    ; ppxlib_astlib
    ; yojson
    ; Layer_base.mina_base
    ; base_caml
    ; compiler_libs
    ; ocaml_migrate_parsetree
    ; stdio
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_base; Ppx_lib.ppx_version; Ppx_lib.ppxlib_metaquot; Ppx_lib.graphql_ppx ] )
  "gen"

(* -- mina_incremental ---------------------------------------------- *)
let mina_incremental =
  library "mina_incremental" ~path:"src/lib/mina_incremental"
  ~deps:[ incremental; Layer_base.pipe_lib; async_kernel ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_version ])

(* -- mina_plugins -------------------------------------------------- *)
let mina_plugins =
  library "mina_plugins" ~path:"src/lib/mina_plugins"
  ~deps:[ core_kernel; dynlink; core; base; local "mina_lib"; Layer_infra.logger ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])

(* -- mina_plugins/examples/do_nothing ------------------------------ *)
let plugin_do_nothing =
  private_library ~path:"src/lib/mina_plugins/examples/do_nothing"
  ~deps:
    [ core_kernel
    ; core
    ; mina_plugins
    ; local "mina_lib"
    ; Layer_infra.logger
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_mina ])
  "plugin_do_nothing"

(* ================================================================ *)
(* Networking & Frontier Layer                                      *)
(* ================================================================ *)

(* -- gossip_net ---------------------------------------------------- *)
let gossip_net =
  library "gossip_net" ~path:"src/lib/gossip_net" ~library_flags:[ "-linkall" ]
  ~inline_tests:true
  ~deps:
    [ uri
    ; async_rpc
    ; async_kernel
    ; base
    ; base_caml
    ; bin_prot_shape
    ; async_rpc_kernel
    ; async
    ; core
    ; core_kernel
    ; sexplib0
    ; cohttp_async
    ; async_unix
    ; base_internalhash_types
    ; ppx_hash_runtime_lib
    ; integers
    ; Layer_ppx.ppx_version_runtime
    ; Layer_domain.network_peer
    ; Layer_infra.logger
    ; Layer_base.pipe_lib
    ; Layer_infra.trust_system
    ; local "network_pool"

    ; local "mina_net2"

    ; mina_block
    ; Layer_base.mina_base
    ; Layer_transaction.mina_transaction
    ; Layer_base.perf_histograms
    ; Layer_infra.o1trace
    ; Layer_domain.node_addrs_and_ports
    ; Layer_tooling.mina_metrics
    ; Layer_base.child_processes
    ; Layer_base.error_json
    ; Layer_domain.block_time
    ; Layer_domain.genesis_constants
    ; Layer_base.mina_stdlib
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

(* -- mina_net2 ----------------------------------------------------- *)
let mina_net2 =
  library "mina_net2" ~path:"src/lib/mina_net2" ~inline_tests:true
  ~deps:
    [ async
    ; base58
    ; base64
    ; capnp
    ; digestif
    ; stdio
    ; core
    ; libp2p_ipc
    ; yojson
    ; async_kernel
    ; core_kernel
    ; bin_prot_shape
    ; ppx_inline_test_config
    ; async_unix
    ; sexplib0
    ; base_caml
    ; base_internalhash_types
    ; splittable_random
    ; integers
    ; Layer_crypto.blake2
    ; Layer_base.error_json
    ; Layer_base.child_processes
    ; Layer_infra.mina_stdlib_unix
    ; Layer_infra.logger
    ; Layer_domain.network_peer
    ; Layer_base.pipe_lib
    ; Layer_concurrency.timeout_lib
    ; Layer_tooling.mina_metrics
    ; Layer_infra.o1trace
    ; Layer_ledger.staged_ledger_diff
    ; Layer_ppx.ppx_version_runtime
    ; Layer_consensus.consensus
    ; Layer_base.mina_stdlib
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

(* -- mina_net2/tests ----------------------------------------------- *)
let mina_net2_tests =
  private_library ~path:"src/lib/mina_net2/tests" ~inline_tests:true
  ~deps:
    [ core
    ; async
    ; ppx_inline_test_config
    ; async_kernel
    ; async_unix
    ; core_kernel
    ; sexplib0
    ; bin_prot_shape
    ; base_caml
    ; mina_net2
    ; Layer_base.mina_stdlib
    ; Layer_infra.logger
    ; Layer_base.child_processes
    ; Layer_domain.network_peer
    ; Layer_infra.mina_stdlib_unix
    ; Layer_base.mina_compile_config
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])
  "mina_net2_tests"

(* -- mina_networking ----------------------------------------------- *)
let mina_networking =
  library "mina_networking" ~path:"src/lib/mina_networking"
  ~library_flags:[ "-linkall" ] ~inline_tests:true
  ~deps:
    [ base_caml
    ; async_rpc_kernel
    ; result
    ; core
    ; async
    ; core_kernel
    ; sexplib0
    ; base
    ; bin_prot_shape
    ; async_unix
    ; async_kernel
    ; base_internalhash_types
    ; Layer_consensus.precomputed_values
    ; Layer_ledger.merkle_ledger
    ; local "downloader"

    ; Layer_protocol.protocol_version
    ; Layer_base.error_json
    ; mina_net2
    ; Layer_domain.block_time
    ; Layer_infra.trust_system
    ; Layer_crypto.signature_lib
    ; Layer_base.with_hash
    ; Layer_consensus.mina_state
    ; Layer_base.pipe_lib
    ; staged_ledger
    ; mina_block
    ; Layer_consensus.consensus
    ; Layer_base.perf_histograms
    ; Layer_base.mina_base
    ; gossip_net
    ; Layer_domain.proof_carrying_data
    ; local "network_pool"

    ; Layer_base.sync_status
    ; Layer_domain.network_peer
    ; Layer_domain.data_hash_lib
    ; Layer_infra.logger
    ; Layer_domain.genesis_constants
    ; Layer_tooling.mina_metrics
    ; local "syncable_ledger"

    ; Layer_ledger.mina_ledger
    ; local "transition_handler"

    ; Layer_infra.o1trace
    ; Layer_ppx.ppx_version_runtime
    ; Layer_base.mina_stdlib
    ; local "sync_handler"

    ; local "transition_chain_prover"

    ; Layer_snark_worker.work_selector
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

(* -- network_pool -------------------------------------------------- *)
let network_pool =
  library "network_pool" ~path:"src/lib/network_pool" ~inline_tests:true
  ~library_flags:[ "-linkall" ]
  ~deps:
    [ async
    ; async_unix
    ; core
    ; integers
    ; stdio
    ; Layer_domain.block_time
    ; Layer_base.mina_stdlib
    ; Layer_base.child_processes
    ; Layer_consensus.coda_genesis_ledger
    ; Layer_consensus.consensus
    ; Layer_base.currency
    ; Layer_domain.data_hash_lib
    ; Layer_base.error_json
    ; Layer_domain.genesis_constants
    ; Layer_concurrency.interruptible
    ; Layer_crypto.kimchi_backend
    ; Layer_crypto.kimchi_backend_common
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_snark_worker.ledger_proof
    ; Layer_infra.logger
    ; Layer_ledger.merkle_ledger
    ; Layer_base.mina_base
    ; Layer_ledger.mina_ledger
    ; Layer_tooling.mina_metrics
    ; mina_net2
    ; Layer_infra.mina_numbers
    ; Layer_infra.mina_signature_kind
    ; Layer_consensus.mina_state
    ; Layer_transaction.mina_transaction
    ; Layer_transaction.mina_transaction_logic
    ; Layer_base.mina_wire_types
    ; Layer_domain.network_peer
    ; Layer_infra.o1trace
    ; Layer_base.one_or_two
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.pickles_types
    ; Layer_base.pipe_lib
    ; Layer_ppx.ppx_version_runtime
    ; Layer_consensus.precomputed_values
    ; Layer_test.quickcheck_lib
    ; Layer_crypto.random_oracle
    ; Layer_crypto.random_oracle_input
    ; Layer_crypto.sgn
    ; Layer_base.sgn_type
    ; Layer_crypto.signature_lib
    ; Layer_crypto.snark_params
    ; Layer_snark_worker.snark_work_lib
    ; staged_ledger
    ; Layer_ledger.staged_ledger_diff
    ; Layer_protocol.transaction_snark
    ; Layer_snark_worker.transaction_snark_work
    ; local "transition_frontier"

    ; local "transition_frontier_base"

    ; local "transition_frontier_extensions"

    ; Layer_infra.trust_system
    ; Layer_service.verifier
    ; Layer_base.with_hash
    ; Layer_protocol.zkapp_command_builder
    ; Layer_storage.zkapp_vk_cache_tag
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

(* -- syncable_ledger ----------------------------------------------- *)
let syncable_ledger =
  library "syncable_ledger" ~path:"src/lib/syncable_ledger"
  ~library_flags:[ "-linkall" ]
  ~flags:[ Dune_s_expr.atom ":standard"; Dune_s_expr.atom "-short-paths" ]
  ~deps:
    [ async_kernel
    ; core_kernel
    ; bin_prot_shape
    ; base_caml
    ; sexplib0
    ; core
    ; async
    ; Layer_infra.trust_system
    ; Layer_infra.logger
    ; Layer_ledger.merkle_ledger
    ; Layer_base.pipe_lib
    ; Layer_domain.network_peer
    ; Layer_ledger.merkle_address
    ; Layer_base.mina_stdlib
    ; Layer_base.error_json
    ; Layer_ppx.ppx_version_runtime
    ; Layer_base.mina_compile_config
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

(* -- syncable_ledger/test ------------------------------------------ *)
let syncable_ledger_test =
  private_library ~path:"src/lib/syncable_ledger/test" ~inline_tests:true
  ~deps:
    [ result
    ; base_internalhash_types
    ; bin_prot_shape
    ; async_unix
    ; async_kernel
    ; core_kernel
    ; core
    ; async
    ; sexplib0
    ; ppx_inline_test_config
    ; base_caml
    ; Layer_infra.mina_numbers
    ; Layer_base.mina_base
    ; Layer_ledger.merkle_address
    ; Layer_infra.logger
    ; Layer_base.pipe_lib
    ; Layer_ledger.merkle_ledger_tests
    ; Layer_ledger.merkle_ledger
    ; syncable_ledger
    ; Layer_domain.network_peer
    ; Layer_infra.trust_system
    ; Layer_base.currency
    ; Layer_domain.data_hash_lib
    ; Layer_base.mina_base_import
    ; Layer_crypto.signature_lib
    ; Layer_base.mina_stdlib
    ; Layer_base.mina_compile_config
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_compare; Ppx_lib.ppx_deriving_yojson ] )
  "test"

(* -- sync_handler -------------------------------------------------- *)
let sync_handler =
  library "sync_handler" ~path:"src/lib/sync_handler" ~inline_tests:true
  ~deps:
    [ sexplib0
    ; core
    ; async
    ; core_kernel
    ; async_kernel
    ; Layer_base.with_hash
    ; Layer_domain.data_hash_lib
    ; Layer_consensus.precomputed_values
    ; Layer_domain.genesis_constants
    ; Layer_infra.trust_system
    ; local "transition_frontier_extensions"

    ; local "transition_frontier_base"

    ; Layer_consensus.consensus
    ; syncable_ledger
    ; Layer_base.mina_base
    ; local "mina_intf"
    ; local "transition_frontier"

    ; local "best_tip_prover"

    ; mina_block
    ; Layer_domain.network_peer
    ; Layer_infra.logger
    ; Layer_ledger.merkle_ledger
    ; staged_ledger
    ; Layer_base.mina_stdlib
    ; Layer_domain.proof_carrying_data
    ; Layer_ledger.mina_ledger
    ; Layer_base.mina_wire_types
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

(* -- transition_chain_prover --------------------------------------- *)
let transition_chain_prover =
  library "transition_chain_prover" ~path:"src/lib/transition_chain_prover"
  ~deps:
    [ core
    ; core_kernel
    ; local "transition_frontier_extensions"

    ; mina_block
    ; Layer_consensus.mina_state
    ; local "mina_intf"
    ; Layer_base.mina_base
    ; local "transition_frontier"

    ; Layer_ledger.merkle_list_prover
    ; local "transition_frontier_base"

    ; Layer_domain.data_hash_lib
    ; Layer_base.with_hash
    ; Layer_base.mina_wire_types
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.snark_params
    ; Layer_crypto.pickles
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

(* -- transition_chain_verifier ------------------------------------- *)
let transition_chain_verifier =
  library "transition_chain_verifier" ~path:"src/lib/transition_chain_verifier"
  ~deps:
    [ core_kernel
    ; core
    ; Layer_ledger.merkle_list_verifier
    ; Layer_consensus.mina_state
    ; Layer_base.mina_base
    ; Layer_base.mina_stdlib
    ; Layer_domain.data_hash_lib
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_compare ])

(* -- transition_frontier/frontier_base ----------------------------- *)
let transition_frontier_base =
  library "transition_frontier_base" ~internal_name:"frontier_base"
  ~path:"src/lib/transition_frontier/frontier_base"
  ~deps:
    [ async_unix
    ; base_caml
    ; async_kernel
    ; core_kernel
    ; bin_prot_shape
    ; sexplib0
    ; integers
    ; core
    ; async
    ; base_internalhash_types
    ; Layer_base.unsigned_extended
    ; Layer_ledger.staged_ledger_diff
    ; Layer_domain.block_time
    ; Layer_base.one_or_two
    ; Layer_base.mina_base_import
    ; Layer_base.currency
    ; Layer_base.mina_stdlib
    ; Layer_base.allocation_functor
    ; Layer_domain.genesis_constants
    ; Layer_snark_worker.transaction_snark_work
    ; Layer_infra.trust_system
    ; Layer_consensus.precomputed_values
    ; Layer_consensus.consensus
    ; Layer_domain.network_peer
    ; Layer_ledger.mina_ledger
    ; mina_block
    ; Layer_base.mina_base
    ; Layer_transaction.mina_transaction_logic
    ; Layer_consensus.mina_state
    ; staged_ledger
    ; Layer_domain.data_hash_lib
    ; Layer_crypto.signature_lib
    ; Layer_infra.logger
    ; Layer_service.verifier
    ; Layer_base.with_hash
    ; Layer_infra.o1trace
    ; Layer_base.visualization
    ; Layer_infra.mina_numbers
    ; Layer_snark_worker.ledger_proof
    ; Layer_protocol.protocol_version
    ; mina_net2
    ; Layer_protocol.transaction_snark
    ; Layer_consensus.coda_genesis_proof
    ; Layer_ppx.ppx_version_runtime
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.snark_params
    ; Layer_crypto.pickles
    ; Layer_crypto.kimchi_backend
    ; Layer_crypto.sgn
    ; Layer_base.sgn_type
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_base.mina_wire_types
    ; Layer_tooling.internal_tracing
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_jane
       ; Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_version
       ; Ppx_lib.ppx_deriving_std
       ; Ppx_lib.ppx_deriving_yojson
       ] )

(* -- transition_frontier/full_frontier ----------------------------- *)
let transition_frontier_full_frontier =
  library "transition_frontier_full_frontier" ~internal_name:"full_frontier"
  ~path:"src/lib/transition_frontier/full_frontier"
  ~deps:
    [ integers
    ; core
    ; base_caml
    ; core_kernel
    ; sexplib0
    ; base_internalhash_types
    ; stdio
    ; Layer_base.mina_wire_types
    ; Layer_base.unsigned_extended
    ; Layer_infra.o1trace
    ; Layer_base.visualization
    ; Layer_tooling.mina_metrics
    ; Layer_domain.block_time
    ; Layer_infra.logger
    ; staged_ledger
    ; Layer_consensus.mina_state
    ; Layer_base.mina_base
    ; local "transition_frontier_persistent_root"

    ; transition_frontier_base
    ; Layer_consensus.consensus
    ; Layer_ledger.mina_ledger
    ; mina_block
    ; Layer_domain.data_hash_lib
    ; Layer_consensus.precomputed_values
    ; Layer_base.with_hash
    ; Layer_base.mina_stdlib
    ; Layer_ledger.staged_ledger_diff
    ; Layer_infra.mina_numbers
    ; Layer_tooling.internal_tracing
    ; async
    ; async_kernel
    ; async_unix
    ; Layer_base.child_processes
    ; Layer_consensus.coda_genesis_ledger
    ; core_uuid
    ; core_kernel_uuid
    ; Layer_domain.genesis_constants
    ; Layer_ledger.merkle_ledger
    ; Layer_protocol.protocol_version
    ; Layer_crypto.signature_lib
    ; Layer_service.verifier
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.snark_params
    ; Layer_crypto.pickles
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
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

(* -- transition_frontier/persistent_root --------------------------- *)
let transition_frontier_persistent_root =
  library "transition_frontier_persistent_root" ~internal_name:"persistent_root"
  ~path:"src/lib/transition_frontier/persistent_root"
  ~deps:
    [ core_kernel_uuid
    ; core_kernel
    ; core
    ; core_uuid
    ; base_caml
    ; Layer_consensus.precomputed_values
    ; Layer_infra.mina_stdlib_unix
    ; Layer_ledger.merkle_ledger
    ; transition_frontier_base
    ; Layer_base.mina_base
    ; Layer_ledger.mina_ledger
    ; Layer_infra.logger
    ; Layer_domain.data_hash_lib
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])

(* -- transition_frontier/persistent_frontier ----------------------- *)
let transition_frontier_persistent_frontier =
  library "transition_frontier_persistent_frontier"
  ~internal_name:"persistent_frontier"
  ~path:"src/lib/transition_frontier/persistent_frontier"
  ~deps:
    [ result
    ; bin_prot_shape
    ; core_kernel
    ; async
    ; core
    ; async_kernel
    ; base_caml
    ; sexplib0
    ; async_unix
    ; Layer_base.mina_stdlib
    ; Layer_infra.o1trace
    ; Layer_tooling.mina_metrics
    ; Layer_infra.trust_system
    ; staged_ledger
    ; Layer_consensus.precomputed_values
    ; Layer_domain.data_hash_lib
    ; Layer_infra.logger
    ; Layer_base.otp_lib
    ; Layer_consensus.consensus
    ; Layer_ledger.mina_ledger
    ; Layer_infra.mina_stdlib_unix
    ; transition_frontier_full_frontier
    ; transition_frontier_persistent_root
    ; transition_frontier_base
    ; Layer_domain.block_time
    ; local "transition_frontier_extensions"

    ; Layer_base.mina_base
    ; Layer_transaction.mina_transaction_logic
    ; Layer_storage.rocksdb
    ; mina_block
    ; Layer_consensus.mina_state
    ; Layer_domain.genesis_constants
    ; Layer_service.verifier
    ; Layer_base.with_hash
    ; Layer_ppx.ppx_version_runtime
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.snark_params
    ; Layer_crypto.pickles
    ; Layer_crypto.kimchi_backend
    ; Layer_crypto.sgn
    ; Layer_base.sgn_type
    ; Layer_base.currency
    ; Layer_infra.mina_numbers
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_base.mina_wire_types
    ; Layer_tooling.internal_tracing
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

(* -- transition_frontier/extensions -------------------------------- *)
let transition_frontier_extensions =
  library "transition_frontier_extensions" ~internal_name:"extensions"
  ~path:"src/lib/transition_frontier/extensions"
  ~deps:
    [ base_caml
    ; async_kernel
    ; core_kernel
    ; sexplib0
    ; result
    ; base_internalhash_types
    ; Layer_base.with_hash
    ; mina_block
    ; Layer_snark_worker.transaction_snark_work
    ; Layer_domain.data_hash_lib
    ; Layer_base.pipe_lib
    ; Layer_base.mina_base
    ; transition_frontier_base
    ; transition_frontier_full_frontier
    ; Layer_ledger.mina_ledger
    ; Layer_infra.logger
    ; Layer_consensus.mina_state
    ; staged_ledger
    ; Layer_base.mina_wire_types
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])

(* -- transition_frontier ------------------------------------------- *)
let transition_frontier =
  library "transition_frontier" ~path:"src/lib/transition_frontier"
  ~deps:
    [ async_unix
    ; integers
    ; async
    ; core
    ; Layer_infra.o1trace
    ; Layer_tooling.mina_metrics
    ; Layer_base.mina_wire_types
    ; Layer_ledger.merkle_ledger
    ; staged_ledger
    ; Layer_consensus.mina_state
    ; Layer_crypto.signature_lib
    ; Layer_ledger.mina_ledger
    ; Layer_consensus.consensus
    ; Layer_domain.genesis_constants
    ; Layer_infra.mina_numbers
    ; mina_block
    ; Layer_infra.logger
    ; transition_frontier_full_frontier
    ; transition_frontier_persistent_root
    ; local "downloader"

    ; transition_frontier_base
    ; transition_frontier_persistent_frontier
    ; transition_frontier_extensions
    ; Layer_base.mina_base
    ; Layer_infra.cache_lib
    ; Layer_domain.data_hash_lib
    ; Layer_domain.network_peer
    ; Layer_base.unsigned_extended
    ; Layer_service.verifier
    ; Layer_consensus.precomputed_values
    ; Layer_domain.block_time
    ; Layer_infra.trust_system
    ; Layer_base.with_hash
    ; Layer_base.mina_stdlib
    ; Layer_test.quickcheck_lib
    ; Layer_protocol.protocol_version
    ; mina_net2
    ; Layer_tooling.internal_tracing
    ; Layer_transaction.mina_transaction
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_jane
       ; Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_version
       ; Ppx_lib.ppx_compare
       ; Ppx_lib.ppx_deriving_yojson
       ] )

(* -- transition_frontier/tests ------------------------------------- *)
let transition_frontier_tests =
  private_library ~path:"src/lib/transition_frontier/tests" ~inline_tests:true
  ~deps:
    [ core_uuid
    ; core
    ; async
    ; async_kernel
    ; core_kernel
    ; ppx_inline_test_config
    ; async_unix
    ; core_kernel_uuid
    ; sexplib0
    ; Layer_consensus.mina_state
    ; staged_ledger
    ; Layer_base.with_hash
    ; Layer_ledger.mina_ledger
    ; Layer_base.child_processes
    ; Layer_domain.genesis_constants
    ; Layer_infra.logger
    ; mina_block
    ; transition_frontier_persistent_root
    ; Layer_base.mina_base
    ; Layer_consensus.precomputed_values
    ; Layer_service.verifier
    ; Layer_consensus.coda_genesis_ledger
    ; Layer_ledger.merkle_ledger
    ; Layer_consensus.consensus
    ; Layer_domain.data_hash_lib
    ; Layer_domain.block_time
    ; transition_frontier_full_frontier
    ; transition_frontier_base
    ; transition_frontier
    ; Layer_protocol.protocol_version
    ; yojson
    ; mina_net2
    ; libp2p_ipc
    ; Layer_ledger.staged_ledger_diff
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version; Ppx_lib.ppx_mina ])
  "transition_frontier_tests"

(* -- transition_frontier_controller -------------------------------- *)
let transition_frontier_controller =
  library "transition_frontier_controller"
  ~path:"src/lib/transition_frontier_controller"
  ~deps:
    [ base
    ; async_kernel
    ; core_kernel
    ; core
    ; transition_frontier
    ; Layer_domain.data_hash_lib
    ; Layer_tooling.mina_metrics
    ; Layer_domain.network_peer
    ; Layer_infra.cache_lib
    ; mina_block
    ; Layer_infra.o1trace
    ; Layer_base.pipe_lib
    ; Layer_base.mina_base
    ; local "transition_handler"

    ; local "ledger_catchup"

    ; transition_frontier_extensions
    ; transition_frontier_base
    ; Layer_consensus.precomputed_values
    ; Layer_infra.logger
    ; Layer_base.with_hash
    ; Layer_domain.genesis_constants
    ; Layer_consensus.consensus
    ; local "bootstrap_controller"

    ; staged_ledger
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_mina ])

(* -- transition_handler -------------------------------------------- *)
let transition_handler =
  library "transition_handler" ~path:"src/lib/transition_handler"
  ~inline_tests:true
  ~deps:
    [ ppx_inline_test_config
    ; sexplib0
    ; core_kernel
    ; core
    ; async
    ; async_unix
    ; base_internalhash_types
    ; async_kernel
    ; integers
    ; result
    ; Layer_base.error_json
    ; Layer_domain.data_hash_lib
    ; Layer_domain.block_time
    ; Layer_infra.trust_system
    ; Layer_infra.o1trace
    ; transition_frontier_base
    ; Layer_infra.cache_lib
    ; Layer_base.mina_base
    ; Layer_base.otp_lib
    ; Layer_base.pipe_lib
    ; Layer_base.mina_stdlib
    ; Layer_consensus.consensus
    ; transition_frontier
    ; Layer_base.perf_histograms
    ; Layer_tooling.mina_metrics
    ; mina_block
    ; Layer_transaction.mina_transaction
    ; Layer_domain.network_peer
    ; Layer_base.with_hash
    ; Layer_infra.logger
    ; Layer_consensus.mina_state
    ; Layer_consensus.precomputed_values
    ; Layer_base.child_processes
    ; Layer_service.verifier
    ; Layer_domain.genesis_constants
    ; network_pool
    ; mina_net2
    ; Layer_infra.mina_numbers
    ; Layer_base.mina_wire_types
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.snark_params
    ; Layer_crypto.pickles
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_tooling.internal_tracing
    ; transition_frontier_extensions
    ; Layer_ledger.staged_ledger_diff
    ; staged_ledger
    ; local "mina_runtime_config"
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

(* -- transition_router --------------------------------------------- *)
let transition_router =
  library "transition_router" ~path:"src/lib/transition_router"
  ~deps:
    [ integers
    ; base_caml
    ; async_kernel
    ; core_kernel
    ; core
    ; async
    ; sexplib0
    ; local "best_tip_prover"

    ; transition_handler
    ; Layer_infra.o1trace
    ; Layer_base.mina_stdlib
    ; mina_net2
    ; Layer_consensus.consensus
    ; Layer_infra.logger
    ; Layer_base.error_json
    ; Layer_infra.trust_system
    ; mina_block
    ; Layer_consensus.mina_state
    ; transition_frontier_persistent_frontier
    ; mina_networking
    ; transition_frontier_controller
    ; Layer_base.pipe_lib
    ; transition_frontier
    ; local "bootstrap_controller"

    ; local "mina_intf"
    ; transition_frontier_persistent_root
    ; transition_frontier_base
    ; Layer_base.mina_base
    ; Layer_crypto.signature_lib
    ; Layer_domain.network_peer
    ; Layer_base.with_hash
    ; Layer_domain.block_time
    ; Layer_tooling.mina_metrics
    ; Layer_consensus.precomputed_values
    ; Layer_infra.mina_numbers
    ; Layer_concurrency.interruptible
    ; Layer_domain.genesis_constants
    ; Layer_base.unsigned_extended
    ; Layer_domain.proof_carrying_data
    ; local "ledger_catchup"

    ; Layer_domain.data_hash_lib
    ; Layer_base.mina_wire_types
    ; Layer_tooling.internal_tracing
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_compare ])

(* -- bootstrap_controller ------------------------------------------ *)
let bootstrap_controller =
  library "bootstrap_controller" ~path:"src/lib/bootstrap_controller"
  ~inline_tests:true
  ~deps:
    [ async
    ; async_kernel
    ; async_unix
    ; core
    ; core_kernel
    ; ppx_inline_test_config
    ; sexplib0
    ; Layer_domain.block_time
    ; Layer_base.child_processes
    ; Layer_consensus.coda_genesis_ledger
    ; Layer_consensus.consensus
    ; Layer_base.currency
    ; Layer_domain.data_hash_lib
    ; Layer_base.error_json
    ; local "fake_network"

    ; Layer_domain.genesis_constants
    ; Layer_crypto.kimchi_backend
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_infra.logger
    ; Layer_ledger.merkle_ledger
    ; Layer_base.mina_base
    ; Layer_base.mina_base_util
    ; mina_block
    ; local "mina_intf"
    ; Layer_ledger.mina_ledger
    ; Layer_tooling.mina_metrics
    ; mina_net2
    ; mina_networking
    ; Layer_infra.mina_numbers
    ; Layer_consensus.mina_state
    ; Layer_base.mina_stdlib
    ; Layer_transaction.mina_transaction_logic
    ; Layer_base.mina_wire_types
    ; Layer_domain.network_peer
    ; Layer_infra.o1trace
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; Layer_base.pipe_lib
    ; Layer_consensus.precomputed_values
    ; Layer_crypto.sgn
    ; Layer_base.sgn_type
    ; Layer_crypto.snark_params
    ; staged_ledger
    ; sync_handler
    ; syncable_ledger
    ; transition_frontier
    ; transition_frontier_base
    ; transition_frontier_persistent_frontier
    ; transition_frontier_persistent_root
    ; Layer_infra.trust_system
    ; Layer_service.verifier
    ; Layer_base.with_hash
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_compare
       ; Ppx_lib.ppx_jane
       ; Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_register_event
       ; Ppx_lib.ppx_version
       ] )

(* -- best_tip_prover ----------------------------------------------- *)
let best_tip_prover =
  library "best_tip_prover" ~path:"src/lib/best_tip_prover"
  ~deps:
    [ core
    ; core_kernel
    ; async_kernel
    ; Layer_domain.genesis_constants
    ; Layer_consensus.consensus
    ; Layer_base.with_hash
    ; Layer_consensus.precomputed_values
    ; Layer_domain.proof_carrying_data
    ; Layer_infra.logger
    ; Layer_ledger.merkle_list_verifier
    ; transition_frontier
    ; Layer_base.mina_base
    ; local "mina_intf"
    ; Layer_consensus.mina_state
    ; mina_block
    ; Layer_domain.data_hash_lib
    ; transition_frontier_base
    ; Layer_ledger.merkle_list_prover
    ; Layer_base.mina_stdlib
    ; Layer_base.mina_wire_types
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.snark_params
    ; Layer_crypto.pickles
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_compare ])

(* -- ledger_catchup ------------------------------------------------ *)
let ledger_catchup =
  library "ledger_catchup" ~path:"src/lib/ledger_catchup" ~inline_tests:true
  ~deps:
    [ async
    ; core
    ; Layer_base.mina_stdlib
    ; Layer_base.mina_wire_types
    ; Layer_domain.genesis_constants
    ; Layer_base.mina_base_import
    ; Layer_crypto.pickles_backend
    ; Layer_base.one_or_two
    ; transition_frontier_extensions
    ; Layer_base.child_processes
    ; Layer_domain.block_time
    ; Layer_base.unsigned_extended
    ; local "downloader"

    ; Layer_consensus.mina_state
    ; Layer_protocol.protocol_version
    ; Layer_service.verifier
    ; Layer_base.with_hash
    ; Layer_domain.data_hash_lib
    ; Layer_consensus.precomputed_values
    ; Layer_infra.mina_numbers
    ; mina_networking
    ; Layer_tooling.mina_metrics
    ; Layer_base.pipe_lib
    ; transition_handler
    ; transition_frontier
    ; Layer_consensus.consensus
    ; Layer_base.mina_base
    ; transition_chain_verifier
    ; local "fake_network"

    ; mina_block
    ; Layer_domain.proof_carrying_data
    ; Layer_infra.cache_lib
    ; Layer_domain.network_peer
    ; Layer_infra.logger
    ; Layer_infra.trust_system
    ; Layer_base.error_json
    ; transition_frontier_base
    ; network_pool
    ; Layer_ledger.staged_ledger_diff
    ; Layer_snark_worker.transaction_snark_work
    ; Layer_crypto.pickles
    ; Layer_crypto.snark_params
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_infra.o1trace
    ; mina_net2
    ; Layer_tooling.internal_tracing
    ; local "mina_runtime_config"
    ; Layer_base.mina_compile_config
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

(* -- downloader ---------------------------------------------------- *)
let downloader =
  library "downloader" ~path:"src/lib/downloader"
  ~deps:
    [ async
    ; async_unix
    ; core
    ; core_kernel_pairing_heap
    ; Layer_base.mina_stdlib
    ; Layer_infra.logger
    ; Layer_domain.network_peer
    ; Layer_infra.o1trace
    ; Layer_base.pipe_lib
    ; Layer_infra.trust_system
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_deriving_std
       ; Ppx_lib.ppx_deriving_yojson
       ; Ppx_lib.ppx_jane
       ; Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_version
       ] )

(* -- block_producer ------------------------------------------------ *)
let block_producer =
  library "block_producer" ~path:"src/lib/block_producer"
  ~library_flags:[ "-linkall" ] ~inline_tests:true
  ~deps:
    [ async
    ; async_kernel
    ; core
    ; core_kernel
    ; integers
    ; sexplib0
    ; Layer_domain.block_time
    ; Layer_protocol.blockchain_snark
    ; Layer_consensus.coda_genesis_proof
    ; Layer_consensus.consensus
    ; Layer_base.currency
    ; Layer_domain.data_hash_lib
    ; Layer_base.error_json
    ; Layer_domain.genesis_constants
    ; Layer_tooling.internal_tracing
    ; Layer_concurrency.interruptible
    ; Layer_crypto.kimchi_backend
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_snark_worker.ledger_proof
    ; Layer_infra.logger
    ; Layer_base.mina_base
    ; mina_block
    ; Layer_base.mina_compile_config
    ; local "mina_intf"
    ; Layer_ledger.mina_ledger
    ; Layer_tooling.mina_metrics
    ; mina_net2
    ; mina_networking
    ; Layer_infra.mina_numbers
    ; local "mina_runtime_config"
    ; Layer_consensus.mina_state
    ; Layer_base.mina_stdlib
    ; Layer_transaction.mina_transaction
    ; Layer_transaction.mina_transaction_logic
    ; Layer_base.mina_wire_types
    ; network_pool
    ; local "node_error_service"
    ; Layer_infra.o1trace
    ; Layer_base.otp_lib
    ; local "pasta_bindings"
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; Layer_base.pipe_lib
    ; Layer_consensus.precomputed_values
    ; Layer_protocol.protocol_version
    ; Layer_service.prover
    ; Layer_crypto.sgn
    ; Layer_base.sgn_type
    ; Layer_crypto.signature_lib
    ; Layer_crypto.snark_params
    ; staged_ledger
    ; Layer_ledger.staged_ledger_diff
    ; Layer_protocol.transaction_snark
    ; Layer_snark_worker.transaction_snark_scan_state
    ; transition_chain_prover
    ; transition_frontier
    ; transition_frontier_base
    ; transition_frontier_extensions
    ; Layer_base.unsigned_extended
    ; vrf_evaluator
    ; Layer_base.with_hash
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_jane; Ppx_lib.ppx_mina; Ppx_lib.ppx_register_event; Ppx_lib.ppx_version ] )
  ~synopsis:"Coda block producer"

(* -- fake_network -------------------------------------------------- *)
let fake_network =
  library "fake_network" ~path:"src/lib/fake_network"
  ~deps:
    [ async
    ; async_unix
    ; core
    ; core_uuid
    ; Layer_domain.block_time
    ; Layer_base.mina_stdlib
    ; Layer_consensus.coda_genesis_proof
    ; Layer_consensus.consensus
    ; Layer_domain.data_hash_lib
    ; Layer_domain.genesis_constants
    ; local "kimchi_bindings"
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; local "kimchi_types"
    ; Layer_infra.logger
    ; Layer_base.mina_base
    ; mina_block
    ; local "mina_intf"
    ; Layer_ledger.mina_ledger
    ; mina_networking
    ; Layer_consensus.mina_state
    ; Layer_domain.network_peer
    ; network_pool
    ; local "pasta_bindings"
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; Layer_base.pipe_lib
    ; Layer_consensus.precomputed_values
    ; Layer_domain.proof_carrying_data
    ; Layer_crypto.signature_lib
    ; Layer_crypto.snark_params
    ; staged_ledger
    ; sync_handler
    ; transition_chain_prover
    ; transition_frontier
    ; transition_handler
    ; Layer_infra.trust_system
    ; Layer_service.verifier
    ; Layer_base.with_hash
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_deriving_std; Ppx_lib.ppx_jane; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ] )

