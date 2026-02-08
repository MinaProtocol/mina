(** Product: heap_usage — Analyze Mina heap memory usage. *)

open Manifest
open Externals

let () =
  executable "heap_usage" ~package:"heap_usage" ~path:"src/app/heap_usage"
  ~deps:
    [ async
    ; async_command
    ; async_kernel
    ; async_unix
    ; base
    ; base_internalhash_types
    ; base_caml
    ; core
    ; core_kernel
    ; result
    ; sexplib0
    ; stdio
    ; yojson
    ; Layer_crypto.blake2
    ; Layer_base.currency
    ; Layer_crypto.crypto_params
    ; Layer_domain.data_hash_lib
    ; Layer_domain.genesis_constants
    ; Layer_crypto.kimchi_backend
    ; local "kimchi_bindings"
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_snark_worker.ledger_proof
    ; Layer_ledger.merkle_ledger
    ; Layer_base.mina_base
    ; Layer_base.mina_base_import
    ; Layer_network.mina_block
    ; Layer_base.mina_compile_config
    ; local "mina_generators"
    ; Layer_ledger.mina_ledger
    ; Layer_infra.mina_numbers
    ; Layer_consensus.mina_state
    ; Layer_base.mina_stdlib
    ; Layer_transaction.mina_transaction_logic
    ; Layer_domain.parallel_scan
    ; local "pasta_bindings"
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.pickles_types
    ; Layer_crypto.proof_cache_tag
    ; Layer_crypto.random_oracle
    ; Layer_crypto.signature_lib
    ; Layer_crypto.snark_params
    ; Layer_network.snark_profiler_lib
    ; Layer_ledger.staged_ledger_diff
    ; Layer_protocol.transaction_snark
    ; Layer_snark_worker.transaction_snark_scan_state
    ; Layer_protocol.transaction_snark_tests
    ; Layer_base.with_hash
    ; Layer_protocol.zkapp_command_builder
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_compare
       ; Ppx_lib.ppx_hash
       ; Ppx_lib.ppx_let
       ; Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_sexp_conv
       ; Ppx_lib.ppx_version
       ] )

