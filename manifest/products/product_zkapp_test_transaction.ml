(** Product: zkapp_test_transaction — Test zkApp transactions. *)

open Manifest
open Externals

let register () =
  (* -- zkapp_test_transaction_lib (library) --------------------------- *)
  library "zkapp_test_transaction_lib"
    ~path:"src/app/zkapp_test_transaction/lib" ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_quickcheck
      ; core
      ; core_kernel
      ; graphql_async
      ; graphql_parser
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; splittable_random
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
      [ async
      ; async_command
      ; async_kernel
      ; async_unix
      ; base
      ; core
      ; core_kernel
      ; zkapp_test_transaction_lib
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
