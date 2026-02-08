(** Mina transaction layer: transaction types, logic, witnesses, and scan state.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let user_command_input =
  library "user_command_input" ~path:"src/lib/user_command_input"
    ~deps:
      [ async
      ; async_kernel
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; sexplib0
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.participating_state
      ; Layer_base.unsigned_extended
      ; Layer_crypto.secrets
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; Layer_logging.logger
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_make
         ] )

let mina_transaction =
  library "mina_transaction" ~path:"src/lib/transaction" ~inline_tests:true
    ~deps:
      [ base
      ; base64
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core_kernel
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; Layer_base.base58_check
      ; Layer_base.codable
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.with_hash
      ; Layer_crypto.blake2
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_pickles.pickles
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarky_backendless
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
      ; base
      ; base_caml
      ; base_internalhash_types
      ; base_quickcheck
      ; bin_prot_shape
      ; core_kernel
      ; integers
      ; mina_transaction
      ; ppx_inline_test_config
      ; result
      ; sexp_diff_kernel
      ; sexplib0
      ; yojson
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarky_backendless
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
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
      ; mina_transaction
      ; mina_transaction_logic
      ; ppx_inline_test_config
      ; sexplib0
      ; yojson
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.monad_lib
      ; Layer_base.sgn_type
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.mina_base_test_helpers
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.mina_ledger_test_helpers
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; local "pasta_bindings"
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
      ; core
      ; core_kernel
      ; mina_transaction
      ; mina_transaction_logic
      ; sexplib0
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.with_hash
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_ppx.ppx_version_runtime
      ; local "mina_state"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_mina
         ] )
