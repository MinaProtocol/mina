(** Product: replayer — Replay transactions from archive database. *)

open Manifest
open Externals

let register () =
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
      ; local "archive_lib"
      ; local "block_time"
      ; local "cli_lib"
      ; local "codable"
      ; local "coda_genesis_ledger"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "genesis_constants"
      ; local "genesis_ledger_helper"
      ; local "genesis_ledger_helper.lib"
      ; local "kimchi_backend"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_caqti"
      ; local "mina_ledger"
      ; local "mina_numbers"
      ; local "mina_runtime_config"
      ; local "mina_state"
      ; local "mina_stdlib"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "mina_version"
      ; local "mina_wire_types"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "ppx_version.runtime"
      ; local "random_oracle"
      ; local "sgn"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "crypto_params"
      ; local "unsigned_extended"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "ppx_hash"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] ) ;

  ()
