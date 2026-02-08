(** Product: zkapp_test_transaction — Test zkApp transactions. *)

open Manifest

let register () =
  (* -- zkapp_test_transaction_lib (library) --------------------------- *)
  library "zkapp_test_transaction_lib"
    ~path:"src/app/zkapp_test_transaction/lib" ~inline_tests:true
    ~deps:
      [ opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "base_quickcheck"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "graphql-async"
      ; opam "graphql_parser"
      ; opam "ppx_inline_test.config"
      ; opam "result"
      ; opam "sexplib0"
      ; opam "splittable_random"
      ; local "coda_genesis_ledger"
      ; local "consensus"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "genesis_constants"
      ; local "genesis_ledger_helper"
      ; local "genesis_ledger_helper.lib"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_generators"
      ; local "mina_graphql"
      ; local "mina_ledger"
      ; local "mina_numbers"
      ; local "mina_runtime_config"
      ; local "mina_state"
      ; local "mina_stdlib"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "mina_wire_types"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "secrets"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "staged_ledger_diff"
      ; local "transaction_protocol_state"
      ; local "transaction_snark"
      ; local "transaction_witness"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_compare"
         ; "ppx_custom_printf"
         ; "ppx_deriving_yojson"
         ; "ppx_hash"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] ) ;

  (* -- zkapp_test_transaction (executable) ---------------------------- *)
  executable "zkapp_test_transaction" ~package:"zkapp_test_transaction"
    ~path:"src/app/zkapp_test_transaction"
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "zkapp_test_transaction_lib"
      ; local "cli_lib"
      ; local "currency"
      ; local "mina_base"
      ; local "mina_graphql"
      ; local "mina_numbers"
      ; local "mina_stdlib"
      ; local "signature_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_assert"
         ; "ppx_compare"
         ; "ppx_custom_printf"
         ; "ppx_deriving_yojson"
         ; "ppx_hash"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] ) ;

  ()
