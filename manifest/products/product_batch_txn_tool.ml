(** Product: batch_txn_tool — Batch transaction submission tool. *)

open Manifest
open Externals

let register () =
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
      ; local "currency"
      ; local "graphql_lib"
      ; local "integration_test_lib"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_compile_config"
      ; local "mina_numbers"
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ; local "secrets"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "unsigned_extended"
      ]
    ~preprocessor_deps:[ "../../../graphql_schema.json" ]
    ~ppx:(Ppx.custom [ "ppx_let"; "ppx_mina"; "ppx_version" ]) ;

  ()
