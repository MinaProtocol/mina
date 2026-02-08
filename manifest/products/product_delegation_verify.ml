(** Product: delegation_verify — Verify delegation proofs. *)

open Manifest
open Externals

let () =
  private_executable "delegation_verify" ~path:"src/app/delegation_verify"
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; async_unix
      ; base
      ; base64
      ; base_caml
      ; core
      ; core_kernel
      ; hex
      ; integers
      ; ppx_deriving_yojson_runtime
      ; sexplib
      ; sexplib0
      ; stdio
      ; yojson
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_logging.logger
      ; Layer_network.genesis_ledger_helper
      ; Layer_network.mina_block
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_protocol.blockchain_snark
      ; Layer_protocol.transaction_snark
      ; Layer_snark_worker.ledger_proof
      ; local "mina_runtime_config"
      ; local "pasta_bindings"
      ; local "uptime_service"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )
