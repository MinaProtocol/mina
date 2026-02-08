(** Product: batch_txn_tool — Batch transaction submission tool. *)

open Manifest
open Externals

let () =
  executable "mina-batch-txn" ~internal_name:"batch_txn_tool"
    ~package:"mina_batch_txn" ~path:"src/app/batch_txn_tool"
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; async_unix
      ; base
      ; core
      ; core_kernel
      ; integers
      ; uri
      ; yojson
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_crypto.secrets
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_logging.logger
      ; local "graphql_lib"
      ; local "integration_test_lib"
      ]
    ~preprocessor_deps:[ "../../../graphql_schema.json" ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_let; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])
