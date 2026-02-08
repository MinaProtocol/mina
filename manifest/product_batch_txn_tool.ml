(** Product: batch_txn_tool — Batch transaction submission tool. *)

open Manifest

let register () =
  executable "mina-batch-txn" ~internal_name:"batch_txn_tool"
    ~package:"mina_batch_txn" ~path:"src/app/batch_txn_tool"
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "uri"
      ; opam "yojson"
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
