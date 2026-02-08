(** Product: heap_usage — Analyze Mina heap memory usage. *)

open Manifest
open Externals

let register () =
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
      ; local "blake2"
      ; local "currency"
      ; local "crypto_params"
      ; local "data_hash_lib"
      ; local "genesis_constants"
      ; local "kimchi_backend"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "ledger_proof"
      ; local "merkle_ledger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_block"
      ; local "mina_compile_config"
      ; local "mina_generators"
      ; local "mina_ledger"
      ; local "mina_numbers"
      ; local "mina_state"
      ; local "mina_stdlib"
      ; local "mina_transaction_logic"
      ; local "parallel_scan"
      ; local "pasta_bindings"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "proof_cache_tag"
      ; local "random_oracle"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "snark_profiler_lib"
      ; local "staged_ledger_diff"
      ; local "transaction_snark"
      ; local "transaction_snark_scan_state"
      ; local "transaction_snark_tests"
      ; local "with_hash"
      ; local "zkapp_command_builder"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_hash"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] ) ;

  ()
