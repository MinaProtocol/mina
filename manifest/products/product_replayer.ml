(** Product: replayer — Replay transactions from archive database. *)

open Manifest
open Externals

let () =
  executable "replayer" ~package:"replayer" ~path:"src/app/replayer"
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; async_unix
      ; base
      ; base_internalhash_types
      ; base_caml
      ; bin_prot_shape
      ; caqti
      ; caqti_async
      ; caqti_driver_postgresql
      ; core
      ; core_kernel
      ; integers
      ; result
      ; sexplib0
      ; stdio
      ; uri
      ; yojson
      ; Product_archive.archive_lib
      ; Layer_domain.block_time
      ; local "cli_lib"
      ; Layer_base.codable
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_base.currency
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_network.genesis_ledger_helper
      ; Layer_network.genesis_ledger_helper_lib
      ; Layer_crypto.kimchi_backend
      ; Layer_crypto.kimchi_backend_common
      ; Layer_crypto.kimchi_pasta
      ; Layer_crypto.kimchi_pasta_basic
      ; Layer_infra.logger
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; local "mina_caqti"
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_numbers
      ; local "mina_runtime_config"
      ; Layer_consensus.mina_state
      ; Layer_base.mina_stdlib
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.mina_version
      ; Layer_base.mina_wire_types
      ; Layer_crypto.pickles
      ; Layer_crypto.pickles_backend
      ; Layer_crypto.pickles_types
      ; Layer_ppx.ppx_version_runtime
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_crypto.crypto_params
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )
