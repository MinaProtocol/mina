(** Product: extract_blocks — Extract blocks from archive database. *)

open Manifest
open Externals

let register () =
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
      ; local "archive_lib"
      ; local "block_time"
      ; local "consensus.vrf"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "error_json"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_caqti"
      ; local "mina_numbers"
      ; local "mina_stdlib"
      ; local "mina_transaction"
      ; local "mina_wire_types"
      ; local "pasta_bindings"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "protocol_version"
      ; local "sgn"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "unsigned_extended"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_compare"
         ; "ppx_hash"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] ) ;

  ()
