(** Mina service layer: verification and proving services.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

(* -- verifier ------------------------------------------------------------- *)
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
    ; Layer_protocol.blockchain_snark
    ; Layer_base.child_processes
    ; Layer_base.error_json
    ; Layer_domain.genesis_constants
    ; Layer_tooling.internal_tracing
    ; local "itn_logger"
    ; Layer_crypto.kimchi_backend
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_snark_worker.ledger_proof
    ; Layer_infra.logger
    ; Layer_infra.logger_file_system
    ; Layer_base.mina_base
    ; Layer_base.mina_base_import
    ; Layer_consensus.mina_state
    ; Layer_infra.o1trace
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.random_oracle
    ; Layer_crypto.random_oracle_input
    ; Layer_crypto.signature_lib
    ; Layer_crypto.snark_params
    ; local "snarky.backendless"
    ; Layer_protocol.transaction_snark
    ; Layer_base.with_hash
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

(* -- prover --------------------------------------------------------------- *)
let prover =
  library "prover" ~path:"src/lib/prover"
  ~deps:
    [ base64
    ; async_unix
    ; rpc_parallel
    ; core
    ; async
    ; async_kernel
    ; core_kernel
    ; bin_prot_shape
    ; base_caml
    ; sexplib0
    ; Layer_base.with_hash
    ; Layer_consensus.coda_genesis_ledger
    ; Layer_tooling.mina_metrics
    ; Layer_base.error_json
    ; Layer_crypto.pickles_types
    ; local "snarky.backendless"
    ; Layer_crypto.snark_params
    ; Layer_crypto.pickles
    ; Layer_crypto.sgn
    ; Layer_base.currency
    ; Layer_base.child_processes
    ; Layer_protocol.blockchain_snark
    ; local "mina_block"
    ; Layer_consensus.mina_state
    ; Layer_base.mina_base
    ; Layer_base.mina_compile_config
    ; Layer_infra.logger
    ; local "itn_logger"
    ; Layer_tooling.internal_tracing
    ; Layer_domain.genesis_constants
    ; Layer_snark_worker.ledger_proof
    ; Layer_consensus.consensus
    ; Layer_consensus.coda_genesis_proof
    ; Layer_protocol.transaction_snark
    ; Layer_infra.logger_file_system
    ; Layer_domain.data_hash_lib
    ; Layer_ledger.staged_ledger_diff
    ; Layer_ppx.ppx_version_runtime
    ; Layer_transaction.mina_transaction_logic
    ; Layer_crypto.pickles_backend
    ; Layer_base.sgn_type
    ; Layer_crypto.kimchi_backend
    ; Layer_infra.mina_numbers
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_base.mina_wire_types
    ; Layer_concurrency.promise
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_mina; Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_bin_prot ])
