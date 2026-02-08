(** Product: extract_blocks — Extract blocks from archive database. *)

open Manifest
open Externals

let () =
  executable "extract_blocks" ~package:"extract_blocks"
    ~path:"src/app/extract_blocks"
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; async_unix
      ; base
      ; base64
      ; caqti
      ; caqti_async
      ; caqti_driver_postgresql
      ; core_kernel
      ; integers
      ; uri
      ; Product_archive.archive_lib
      ; Layer_domain.block_time
      ; Layer_consensus.consensus_vrf
      ; Layer_base.currency
      ; Layer_domain.data_hash_lib
      ; Layer_base.error_json
      ; Layer_crypto.kimchi_pasta
      ; Layer_crypto.kimchi_pasta_basic
      ; Layer_logging.logger
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; local "mina_caqti"
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_transaction.mina_transaction
      ; Layer_base.mina_wire_types
      ; local "pasta_bindings"
      ; Layer_crypto.pickles
      ; Layer_crypto.pickles_backend
      ; Layer_crypto.pickles_types
      ; Layer_protocol.protocol_version
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )
