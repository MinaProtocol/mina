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
      ; base_caml
      ; base64
      ; core
      ; core_kernel
      ; hex
      ; integers
      ; ppx_deriving_yojson_runtime
      ; sexplib
      ; sexplib0
      ; stdio
      ; yojson
      ; Layer_protocol.blockchain_snark
      ; Layer_consensus.consensus
      ; Layer_base.currency
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_network.genesis_ledger_helper
      ; Layer_crypto.kimchi_pasta
      ; Layer_crypto.kimchi_pasta_basic
      ; Layer_snark_worker.ledger_proof
      ; Layer_infra.logger
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_network.mina_block
      ; Layer_infra.mina_numbers
      ; local "mina_runtime_config"
      ; Layer_consensus.mina_state
      ; Layer_base.mina_wire_types
      ; local "pasta_bindings"
      ; Layer_crypto.pickles
      ; Layer_crypto.pickles_backend
      ; Layer_crypto.pickles_types
      ; Layer_consensus.precomputed_values
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_protocol.transaction_snark
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
