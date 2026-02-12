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
      ; base_caml
      ; base_internalhash_types
      ; core
      ; core_kernel
      ; result
      ; sexplib0
      ; stdio
      ; yojson
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.with_hash
      ; Layer_consensus.mina_state
      ; Layer_crypto.blake2
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.parallel_scan
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.staged_ledger_diff
      ; Layer_network.mina_block
      ; Layer_network.snark_profiler_lib
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_pickles.proof_cache_tag
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.transaction_snark_tests
      ; Layer_protocol.zkapp_command_builder
      ; Layer_snark_worker.ledger_proof
      ; Layer_snark_worker.transaction_snark_scan_state
      ; Layer_transaction.mina_transaction_logic
      ; local "kimchi_bindings"
      ; local "mina_generators"
      ; local "pasta_bindings"
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
