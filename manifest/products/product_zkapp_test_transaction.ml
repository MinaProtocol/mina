(** Product: zkapp_test_transaction — Test zkApp transactions. *)

open Manifest
open Externals

let zkapp_test_transaction_lib =
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
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.consensus
      ; Layer_base.currency
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_network.genesis_ledger_helper
      ; Layer_network.genesis_ledger_helper_lib
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; local "mina_generators"
      ; local "mina_graphql"
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_numbers
      ; local "mina_runtime_config"
      ; Layer_consensus.mina_state
      ; Layer_base.mina_stdlib
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.mina_wire_types
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.secrets
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_ledger.staged_ledger_diff
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; Layer_transaction.transaction_witness
      ; Layer_base.with_hash
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )

let () =
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
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; local "mina_graphql"
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_crypto.signature_lib
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )
