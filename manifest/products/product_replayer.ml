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
      ; base_caml
      ; base_internalhash_types
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
      ; Layer_base.codable
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_version
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.mina_state
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_network.genesis_ledger_helper
      ; Layer_network.genesis_ledger_helper_lib
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_ppx.ppx_version_runtime
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Product_archive.archive_lib
      ; local "cli_lib"
      ; local "mina_caqti"
      ; local "mina_runtime_config"
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
