(** Mina transaction layer: transaction types, logic, witnesses, and scan state.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let mina_transaction =
  library "mina_transaction" ~path:"src/lib/transaction" ~inline_tests:true
    ~deps:
      [ base_caml
      ; base
      ; base_internalhash_types
      ; bin_prot_shape
      ; core_kernel
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; base64
      ; Layer_base.base58_check
      ; Layer_crypto.blake2
      ; Layer_base.codable
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.one_or_two
      ; Layer_pickles.pickles
      ; Layer_crypto.random_oracle
      ; Layer_crypto.signature_lib
      ; Layer_crypto.sgn
      ; Layer_crypto.snark_params
      ; local "snarky.backendless"
      ; Layer_ppx.ppx_version_runtime
      ; Layer_base.with_hash
      ; Layer_base.mina_wire_types
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )

let mina_transaction_logic =
  library "mina_transaction_logic" ~path:"src/lib/transaction_logic"
    ~deps:
      [ async_kernel
      ; result
      ; bin_prot_shape
      ; ppx_inline_test_config
      ; sexplib0
      ; yojson
      ; sexp_diff_kernel
      ; core_kernel
      ; base_caml
      ; base
      ; base_internalhash_types
      ; integers
      ; base_quickcheck
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_domain.block_time
      ; Layer_base.currency
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; mina_transaction
      ; Layer_base.one_or_two
      ; Layer_pickles.pickles_types
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.signature_lib
      ; Layer_crypto.sgn
      ; local "snarky.backendless"
      ; Layer_crypto.snark_params
      ; Layer_base.unsigned_extended
      ; Layer_ppx.ppx_version_runtime
      ; Layer_base.with_hash
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )

let transaction_logic_tests =
  private_library "transaction_logic_tests"
    ~path:"src/lib/transaction_logic/test" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async_kernel
      ; async_unix
      ; base
      ; base_internalhash_types
      ; core
      ; core_kernel
      ; integers
      ; ppx_inline_test_config
      ; sexplib0
      ; yojson
      ; Layer_base.currency
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_domain.mina_base_test_helpers
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.mina_ledger_test_helpers
      ; mina_transaction
      ; mina_transaction_logic
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.monad_lib
      ; local "pasta_bindings"
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_base.sgn_type
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; local "zkapp_command_builder"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_assert
         ] )

let transaction_witness =
  library "transaction_witness" ~path:"src/lib/transaction_witness"
    ~inline_tests:true
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; sexplib0
      ; core_kernel
      ; core
      ; Layer_base.currency
      ; Layer_crypto.signature_lib
      ; Layer_ledger.mina_ledger
      ; local "mina_state"
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; mina_transaction
      ; mina_transaction_logic
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_crypto.sgn
      ; Layer_base.with_hash
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_mina
         ] )
