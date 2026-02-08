(** Product: cli — Mina daemon command-line interface.

  The main mina executable with testnet/mainnet signature variants. *)

open Manifest
open Externals
open Dune_s_expr

let () =
  executable "mina" ~package:"cli" ~path:"src/app/cli/src" ~modules:[ "mina" ]
    ~modes:[ "native" ]
    ~flags:[ atom ":standard"; atom "-warn-error"; atom "+a" ]
    ~deps:[ Layer_storage.disk_cache_lmdb; local "mina_cli_entrypoint" ]
    ~ppx:Ppx.minimal

let () =
  executable "mina-testnet" ~internal_name:"mina_testnet_signatures"
    ~package:"cli" ~path:"src/app/cli/src"
    ~modules:[ "mina_testnet_signatures" ]
    ~modes:[ "native" ]
    ~flags:[ atom ":standard"; atom "-warn-error"; atom "+a" ]
    ~deps:
      [ Layer_protocol.mina_signature_kind_testnet
      ; Layer_storage.disk_cache_lmdb
      ; local "mina_cli_entrypoint"
      ]
    ~ppx:Ppx.minimal

let () =
  executable "mina-mainnet" ~internal_name:"mina_mainnet_signatures"
    ~package:"cli" ~path:"src/app/cli/src"
    ~modules:[ "mina_mainnet_signatures" ]
    ~modes:[ "native" ]
    ~flags:[ atom ":standard"; atom "-warn-error"; atom "+a" ]
    ~deps:
      [ Layer_protocol.mina_signature_kind_mainnet
      ; Layer_storage.disk_cache_lmdb
      ; local "mina_cli_entrypoint"
      ]
    ~ppx:Ppx.minimal

let () =
  file_stanzas ~path:"src/app/cli/src/init"
    (Dune_s_expr.parse_string
       "(rule\n\
       \ (targets assets.ml)\n\
       \ (deps\n\
       \  (source_tree assets))\n\
       \ (action\n\
       \  (run %{bin:ocaml-crunch} -m plain assets -o assets.ml)))" )

let init =
  library "init" ~path:"src/app/cli/src/init"
    ~deps:
      [ astring
      ; async
      ; async_command
      ; async_kernel
      ; async_rpc
      ; async_rpc_kernel
      ; async_ssl
      ; async_unix
      ; base
      ; base_caml
      ; base_internalhash_types
      ; base_quickcheck
      ; cohttp
      ; cohttp_async
      ; core
      ; core_kernel
      ; core_kernel_uuid
      ; core_uuid
      ; graphql
      ; graphql_async
      ; graphql_cohttp
      ; graphql_parser
      ; integers
      ; mirage_crypto_ec
      ; result
      ; sexplib0
      ; stdio
      ; uri
      ; Layer_base.allocation_functor
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_stdlib_unix
      ; Layer_base.mina_version
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.participating_state
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.parallel
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.coda_genesis_proof
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.random_oracle
      ; Layer_crypto.secrets
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_crypto.string_sign
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_logging.o1trace_webkit_event
      ; Layer_network.generated_graphql_queries
      ; Layer_network.genesis_ledger_helper
      ; Layer_network.genesis_ledger_helper_lib
      ; Layer_network.mina_block
      ; Layer_network.mina_net2
      ; Layer_network.mina_networking
      ; Layer_network.network_peer
      ; Layer_network.network_pool
      ; Layer_network.snark_profiler_lib
      ; Layer_network.staged_ledger
      ; Layer_network.trust_system
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_protocol.blockchain_snark
      ; Layer_protocol.mina_signature_kind
      ; Layer_protocol.protocol_version
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.transaction_snark_tests
      ; Layer_protocol.zkapp_command_builder
      ; Layer_service.verifier
      ; Layer_snark_worker.snark_work_lib
      ; Layer_snark_worker.snark_worker
      ; Layer_snark_worker.transaction_snark_scan_state
      ; Layer_test.test_util
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; Layer_tooling.perf_histograms
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Layer_transaction.user_command_input
      ; Product_archive.archive_lib
      ; Snarky_lib.group_map
      ; local "cli_lib"
      ; local "daemon_rpcs"
      ; local "graphql_lib"
      ; local "itn_crypto"
      ; local "itn_logger"
      ; local "mina_commands"
      ; local "mina_generators"
      ; local "mina_graphql"
      ; local "mina_lib"
      ; local "mina_runtime_config"
      ; local "node_error_service"
      ; local "transaction_inclusion_status"
      ]
    ~preprocessor_deps:
      [ "../../../../../graphql_schema.json"
      ; "../../../../graphql-ppx-config.inc"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_bench
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_fixed_literal
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_module_timer
         ; Ppx_lib.ppx_optional
         ; Ppx_lib.ppx_pipebang
         ; Ppx_lib.ppx_sexp_message
         ; Ppx_lib.ppx_sexp_value
         ; Ppx_lib.ppx_string
         ; Ppx_lib.ppx_typerep_conv
         ; Ppx_lib.ppx_variants_conv
         ; Ppx_lib.ppx_version
         ; Ppx_lib.graphql_ppx
         ; "--"
         ; "%{read-lines:../../../../graphql-ppx-config.inc}"
         ] )

let cli_mina_cli_entrypoint =
  library "cli.mina_cli_entrypoint" ~internal_name:"mina_cli_entrypoint"
    ~path:"src/app/cli/src/cli_entrypoint" ~modes:[ "native" ]
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; bin_prot
      ; bin_prot_shape
      ; core
      ; core_daemon
      ; core_kernel
      ; init
      ; memtrace
      ; result
      ; sexplib0
      ; stdio
      ; uri
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_stdlib_unix
      ; Layer_base.mina_version
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.parallel
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.coda_genesis_proof
      ; Layer_consensus.consensus
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.blake2
      ; Layer_crypto.secrets
      ; Layer_crypto.signature_lib
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.node_addrs_and_ports
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_logging.logger_file_system
      ; Layer_logging.o1trace
      ; Layer_network.block_producer
      ; Layer_network.genesis_ledger_helper
      ; Layer_network.gossip_net
      ; Layer_network.mina_block
      ; Layer_network.mina_net2
      ; Layer_network.mina_networking
      ; Layer_network.mina_plugins
      ; Layer_network.trust_system
      ; Layer_ppx.ppx_version_runtime
      ; Layer_protocol.blockchain_snark
      ; Layer_protocol.protocol_version
      ; Layer_protocol.transaction_snark
      ; Layer_service.prover
      ; Layer_service.verifier
      ; Layer_snark_worker.ledger_proof
      ; Layer_snark_worker.snark_work_lib
      ; Layer_snark_worker.snark_worker
      ; Layer_storage.cache_dir
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; Layer_transaction.transaction_witness
      ; Snarky_lib.snarky_backendless
      ; local "cli_lib"
      ; local "itn_logger"
      ; local "mina_lib"
      ; local "mina_runtime_config"
      ; local "node_error_service"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )
