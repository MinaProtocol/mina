(** Mina service layer: verification and proving services.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let verifier =
  library "verifier" ~path:"src/lib/verifier"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; rpc_parallel
      ; sexplib0
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_consensus.mina_state
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_logging.logger
      ; Layer_logging.logger_file_system
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_protocol.blockchain_snark
      ; Layer_protocol.transaction_snark
      ; Layer_snark_worker.ledger_proof
      ; Layer_tooling.internal_tracing
      ; Snarky_lib.snarky_backendless
      ; local "itn_logger"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_register_event
         ] )

let prover =
  library "prover" ~path:"src/lib/prover"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base64
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; rpc_parallel
      ; sexplib0
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.sgn_type
      ; Layer_base.with_hash
      ; Layer_concurrency.child_processes
      ; Layer_concurrency.promise
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.coda_genesis_proof
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_crypto.sgn
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.staged_ledger_diff
      ; Layer_logging.logger
      ; Layer_logging.logger_file_system
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_ppx.ppx_version_runtime
      ; Layer_protocol.blockchain_snark
      ; Layer_protocol.transaction_snark
      ; Layer_snark_worker.ledger_proof
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; Layer_transaction.mina_transaction_logic
      ; Snarky_lib.snarky_backendless
      ; local "itn_logger"
      ; local "mina_block"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_bin_prot
         ] )
