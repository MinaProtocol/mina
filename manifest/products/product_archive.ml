(** Product: archive — Mina blockchain archive node.

  Stores blockchain data in a PostgreSQL database. *)

open Manifest
open Externals

let () =
  executable "archive" ~package:"archive" ~path:"src/app/archive"
    ~deps:
      [ async
      ; async_unix
      ; core_kernel
      ; Layer_base.mina_version
      ; local "archive_cli"
      ]
    ~modules:[ "archive" ] ~modes:[ "native" ] ~ppx:Ppx.minimal
    ~bisect_sigterm:true

let archive_cli =
  library "archive.cli" ~internal_name:"archive_cli" ~path:"src/app/archive/cli"
    ~deps:
      [ async
      ; async_command
      ; caqti
      ; caqti_async
      ; core
      ; Layer_base.mina_version
      ; Layer_domain.block_time
      ; Layer_domain.genesis_constants
      ; Layer_logging.logger
      ; local "archive_lib"
      ; local "cli_lib"
      ; local "mina_caqti"
      ; local "mina_runtime_config"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])
    ~bisect_sigterm:true

let archive_lib =
  library "archive_lib" ~path:"src/app/archive/lib"
    ~deps:
      [ async
      ; async_kernel
      ; async_rpc
      ; async_rpc_kernel
      ; async_unix
      ; base64
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; caqti
      ; caqti_async
      ; caqti_driver_postgresql
      ; core
      ; core_kernel
      ; integers
      ; ppx_deriving_yojson_runtime
      ; ppx_inline_test_config
      ; ppx_version_runtime
      ; sexplib0
      ; uri
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_base_util
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.consensus
      ; Layer_consensus.consensus_vrf
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.random_oracle
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
      ; Layer_network.genesis_ledger_helper
      ; Layer_network.genesis_ledger_helper_lib
      ; Layer_network.mina_block
      ; Layer_network.staged_ledger
      ; Layer_network.transition_frontier
      ; Layer_network.transition_frontier_base
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_protocol.protocol_version
      ; Layer_protocol.zkapp_command_builder
      ; Layer_service.verifier
      ; Layer_test.quickcheck_lib
      ; Layer_tooling.mina_metrics
      ; Layer_transaction.mina_transaction
      ; local "mina_caqti"
      ; local "mina_generators"
      ; local "mina_runtime_config"
      ]
    ~inline_tests:true ~modes:[ "native" ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )
    ~bisect_sigterm:true
