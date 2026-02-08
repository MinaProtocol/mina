(** Product: archive — Mina blockchain archive node.

  Stores blockchain data in a PostgreSQL database. *)

open Manifest
open Externals

(* -- archive (executable) ------------------------------------------- *)
let () =
  executable "archive" ~package:"archive" ~path:"src/app/archive"
  ~deps:[ local "archive_cli"; async; async_unix; core_kernel; Layer_base.mina_version ]
  ~modules:[ "archive" ] ~modes:[ "native" ] ~ppx:Ppx.minimal
  ~bisect_sigterm:true

(* -- archive_cli (library) ------------------------------------------ *)
let archive_cli =
  library "archive.cli" ~internal_name:"archive_cli" ~path:"src/app/archive/cli"
  ~deps:
    [ async
    ; async_command
    ; caqti
    ; caqti_async
    ; core
    ; local "archive_lib"

    ; Layer_domain.block_time
    ; local "cli_lib"
    ; Layer_domain.genesis_constants
    ; Layer_infra.logger
    ; local "mina_caqti"
    ; local "mina_runtime_config"
    ; Layer_base.mina_version
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])
  ~bisect_sigterm:true

(* -- archive_lib (library) ------------------------------------------ *)
let archive_lib =
  library "archive_lib" ~path:"src/app/archive/lib"
  ~deps:
    [ async
    ; async_rpc
    ; async_kernel
    ; async_rpc_kernel
    ; async_unix
    ; base_internalhash_types
    ; base_caml
    ; base64
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
    ; Layer_domain.block_time
    ; Layer_base.child_processes
    ; Layer_consensus.coda_genesis_ledger
    ; Layer_consensus.consensus
    ; Layer_consensus.consensus_vrf
    ; Layer_base.currency
    ; Layer_domain.data_hash_lib
    ; Layer_base.error_json
    ; Layer_domain.genesis_constants
    ; Layer_network.genesis_ledger_helper
    ; Layer_network.genesis_ledger_helper_lib
    ; Layer_crypto.kimchi_backend
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_infra.logger
    ; Layer_base.mina_base
    ; Layer_base.mina_base_import
    ; Layer_base.mina_base_util
    ; Layer_network.mina_block
    ; local "mina_caqti"
    ; local "mina_generators"
    ; Layer_ledger.mina_ledger
    ; Layer_tooling.mina_metrics
    ; Layer_infra.mina_numbers
    ; local "mina_runtime_config"
    ; Layer_consensus.mina_state
    ; Layer_base.mina_stdlib
    ; Layer_transaction.mina_transaction
    ; Layer_base.mina_wire_types
    ; Layer_infra.o1trace
    ; Layer_base.one_or_two
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.pickles_types
    ; Layer_base.pipe_lib
    ; Layer_consensus.precomputed_values
    ; Layer_protocol.protocol_version
    ; Layer_test.quickcheck_lib
    ; Layer_crypto.random_oracle
    ; Layer_crypto.sgn
    ; Layer_crypto.signature_lib
    ; Layer_crypto.snark_params
    ; Layer_network.staged_ledger
    ; Layer_ledger.staged_ledger_diff
    ; Layer_network.transition_frontier
    ; Layer_network.transition_frontier_base
    ; Layer_base.unsigned_extended
    ; Layer_service.verifier
    ; Layer_base.with_hash
    ; Layer_protocol.zkapp_command_builder
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

