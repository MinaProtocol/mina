(** Mina protocol layer: protocol versioning, snarks, and proving.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let mina_signature_kind_type =
  library "mina_signature_kind.type" ~internal_name:"mina_signature_kind_type"
    ~path:"src/lib/signature_kind/type" ~deps:[ core_kernel ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_yojson; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ] )

let mina_signature_kind =
  library "mina_signature_kind" ~path:"src/lib/signature_kind"
    ~deps:[ mina_signature_kind_type ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~virtual_modules:[ "mina_signature_kind" ]
    ~default_implementation:"mina_signature_kind_config"

let mina_signature_kind_config =
  library "mina_signature_kind.config"
    ~internal_name:"mina_signature_kind_config"
    ~path:"src/lib/signature_kind/compile_config"
    ~deps:[ Layer_node.mina_node_config ]
    ~ppx:Ppx.minimal ~implements:"mina_signature_kind"

let mina_signature_kind_testnet =
  library "mina_signature_kind.testnet"
    ~internal_name:"mina_signature_kind_testnet"
    ~path:"src/lib/signature_kind/testnet" ~ppx:Ppx.minimal
    ~implements:"mina_signature_kind"

let mina_signature_kind_mainnet =
  library "mina_signature_kind.mainnet"
    ~internal_name:"mina_signature_kind_mainnet"
    ~path:"src/lib/signature_kind/mainnet" ~ppx:Ppx.minimal
    ~implements:"mina_signature_kind"

let protocol_version =
  library "protocol_version" ~path:"src/lib/protocol_version"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ core_kernel
      ; sexplib0
      ; bin_prot_shape
      ; base_caml
      ; base
      ; ppx_version_runtime
      ; Layer_base.mina_wire_types
      ; Layer_node.mina_node_config_version
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~synopsis:"Protocol version representation"

let transaction_protocol_state =
  library "transaction_protocol_state"
    ~path:"src/lib/transaction_protocol_state" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ sexplib0
      ; core_kernel
      ; core
      ; bin_prot_shape
      ; base_caml
      ; Layer_pickles.pickles
      ; Layer_domain.genesis_constants
      ; Layer_crypto.snark_params
      ; local "snarky.backendless"
      ; Layer_consensus.mina_state
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~synopsis:"Transaction protocol state library"

let zkapp_command_builder =
  library "zkapp_command_builder" ~path:"src/lib/zkapp_command_builder"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async_kernel
      ; async_unix
      ; core_kernel
      ; Layer_base.mina_base
      ; Layer_base.currency
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.signature_lib
      ; Layer_crypto.sgn
      ; Layer_crypto.snark_params
      ; local "snarky.backendless"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_annot
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"Builder Zkapp_command.t via combinators"

let transaction_snark =
  library "transaction_snark" ~path:"src/lib/transaction_snark"
    ~inline_tests:true ~library_flags:[ "-linkall" ]
    ~deps:
      [ async
      ; async_unix
      ; bignum
      ; core
      ; splittable_random
      ; local "bitstring_lib"
      ; Layer_base.mina_stdlib
      ; Layer_storage.cache_dir
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.consensus
      ; Layer_crypto.crypto_params
      ; Layer_base.currency
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.hash_prefix_states
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_logging.logger
      ; Layer_ledger.merkle_ledger
      ; Layer_base.mina_base
      ; Layer_base.mina_base_util
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_numbers
      ; mina_signature_kind
      ; Layer_consensus.mina_state
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.mina_wire_types
      ; Layer_logging.o1trace
      ; Layer_base.one_or_two
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_base
      ; Layer_pickles.pickles_types
      ; Layer_ppx.ppx_version_runtime
      ; Layer_domain.proof_carrying_data
      ; Layer_test.quickcheck_lib
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_base.sgn_type
      ; Layer_crypto.signature_lib
      ; local "snarky.backendless"
      ; local "snarky_integer"
      ; Layer_crypto.snark_keys_header
      ; Layer_crypto.snark_params
      ; Layer_test.test_util
      ; transaction_protocol_state
      ; Layer_transaction.transaction_witness
      ; local "tuple_lib"
      ; Layer_base.with_hash
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"Transaction state transition snarking library"

let blockchain_snark =
  library "blockchain_snark" ~path:"src/lib/blockchain_snark" ~inline_tests:true
    ~flags:[ atom ":standard"; atom "-warn-error"; atom "+a" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async
      ; async_kernel
      ; base_caml
      ; base_md5
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; sexplib0
      ; Layer_base.allocation_functor
      ; Layer_storage.cache_dir
      ; Layer_consensus.consensus
      ; Layer_crypto.crypto_params
      ; Layer_base.currency
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_logging.logger
      ; Layer_base.mina_base
      ; Layer_consensus.mina_state
      ; Layer_transaction.mina_transaction_logic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_base
      ; Layer_pickles.pickles_types
      ; Layer_ppx.ppx_version_runtime
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; local "snarky.backendless"
      ; Layer_crypto.snark_keys_header
      ; Layer_crypto.snark_params
      ; transaction_snark
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"blockchain state transition snarking library"

let () =
  private_executable
    ~path:"src/lib/blockchain_snark/tests/print_blockchain_snark_vk"
    ~deps:
      [ blockchain_snark
      ; Layer_domain.genesis_constants
      ; Layer_node.mina_node_config
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version ])
    ~extra_stanzas:
      [ "rule"
        @: [ "deps" @: [ atom "print_blockchain_snark_vk.exe" ]
           ; "targets"
             @: [ atom "%{profile}_blockchain_snark_vk.json.computed" ]
           ; "action"
             @: [ "with-stdout-to"
                  @: [ atom "%{targets}"; "run" @: [ atom "%{deps}" ] ]
                ]
           ]
      ; "rule"
        @: [ "deps"
             @: [ list
                    [ atom ":orig"; atom "%{profile}_blockchain_snark_vk.json" ]
                ; list
                    [ atom ":computed"
                    ; atom "%{profile}_blockchain_snark_vk.json.computed"
                    ]
                ]
           ; "alias" @: [ atom "runtest" ]
           ; "action" @: [ "diff" @: [ atom "%{orig}"; atom "%{computed}" ] ]
           ]
      ]
    "print_blockchain_snark_vk"

let () =
  private_executable
    ~path:"src/lib/transaction_snark/test/print_transaction_snark_vk"
    ~deps:
      [ Layer_domain.genesis_constants
      ; Layer_node.mina_node_config
      ; transaction_snark
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version ])
    ~extra_stanzas:
      [ "rule"
        @: [ "deps" @: [ atom "print_transaction_snark_vk.exe" ]
           ; "targets"
             @: [ atom "%{profile}_transaction_snark_vk.json.computed" ]
           ; "action"
             @: [ "with-stdout-to"
                  @: [ atom "%{targets}"; "run" @: [ atom "%{deps}" ] ]
                ]
           ]
      ; "rule"
        @: [ "deps"
             @: [ list
                    [ atom ":orig"
                    ; atom "%{profile}_transaction_snark_vk.json"
                    ]
                ; list
                    [ atom ":computed"
                    ; atom "%{profile}_transaction_snark_vk.json.computed"
                    ]
                ]
           ; "alias" @: [ atom "runtest" ]
           ; "action" @: [ "diff" @: [ atom "%{orig}"; atom "%{computed}" ] ]
           ]
      ]
    "print_transaction_snark_vk"

let transaction_snark_tests =
  library "transaction_snark_tests" ~path:"src/lib/transaction_snark/test"
    ~inline_tests:true ~inline_tests_deps:[ "proof_cache.json" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; base
      ; core_kernel
      ; base64
      ; yojson
      ; integers
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_stdlib
      ; Layer_logging.logger
      ; Layer_crypto.random_oracle_input
      ; Layer_pickles.pickles_backend
      ; Layer_base.mina_base_import
      ; Layer_crypto.crypto_params
      ; Layer_kimchi.kimchi_backend
      ; Layer_base.with_hash
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_base
      ; Layer_consensus.consensus
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; local "snarky.backendless"
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_pickles.pickles_types
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_storage.cache_dir
      ; Layer_domain.data_hash_lib
      ; Layer_base.mina_numbers
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_base.sgn_type
      ; local "sexplib0"
      ; Layer_test.test_util
      ; Layer_transaction.transaction_witness
      ; Layer_ledger.staged_ledger_diff
      ; Layer_base.mina_wire_types
      ; Layer_domain.block_time
      ; local "zkapps_examples"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_sexp_conv
         ] )

let () =
  file_stanzas ~path:"src/lib/transaction_snark/test/constraint_count"
    [ "tests"
      @: [ "names" @: [ atom "test_constraint_count" ]
         ; "libraries"
           @: [ atom "alcotest"
              ; atom "core_kernel"
              ; atom "genesis_constants"
              ; atom "mina_signature_kind"
              ; atom "node_config"
              ; atom "snark_params"
              ; atom "transaction_snark"
              ]
         ; "preprocess" @: [ "pps" @: [ atom "ppx_jane" ] ]
         ]
    ]

let transaction_snark_tests_access_permission =
  private_library "transaction_snark_tests_access_permission"
    ~path:"src/lib/transaction_snark/test/access_permission" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; core
      ; core_kernel
      ; ppx_inline_test_config
      ; sexplib0
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_storage.cache_dir
      ; Layer_base.currency
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; local "pasta_bindings"
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_numbers
      ; Layer_consensus.mina_state
      ; Layer_transaction.mina_transaction_logic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; local "snarky.backendless"
      ; transaction_protocol_state
      ; transaction_snark
      ; transaction_snark_tests
      ; Layer_base.with_hash
      ; local "zkapps_empty_update"
      ; local "zkapps_examples"
      ; Layer_base.mina_stdlib
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_sexp_conv
         ] )

let account_timing_tests =
  private_library "account_timing_tests"
    ~path:"src/lib/transaction_snark/test/account_timing" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; base
      ; base_caml
      ; core_kernel
      ; sexplib0
      ; yojson
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_consensus.coda_genesis_proof
      ; Layer_base.mina_stdlib
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction
      ; Layer_base.mina_compile_config
      ; Layer_consensus.precomputed_values
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_crypto.random_oracle
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_base.with_hash
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ; Layer_test.test_util
      ; Layer_consensus.consensus
      ; Layer_base.one_or_two
      ; Layer_consensus.coda_genesis_ledger
      ; local "snarky.backendless"
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.mina_wire_types
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let account_update_network_id =
  private_library "account_update_network_id"
    ~path:"src/lib/transaction_snark/test/account_update_network_id"
    ~inline_tests:true ~inline_tests_bare:true ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; sexplib0
      ; Layer_logging.logger
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; mina_signature_kind
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ; Layer_test.test_util
      ; Layer_transaction.mina_transaction_logic
      ; Layer_transaction.mina_transaction
      ; Layer_base.mina_stdlib
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ] )

let app_state_tests =
  private_library "app_state_tests"
    ~path:"src/lib/transaction_snark/test/app_state" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async_unix
      ; async
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let delegate_tests =
  private_library "delegate_tests"
    ~path:"src/lib/transaction_snark/test/delegate" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async_unix
      ; async
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_transaction.mina_transaction_logic
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let fee_payer_tests =
  private_library "fee_payer_tests"
    ~path:"src/lib/transaction_snark/test/fee_payer" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async_unix
      ; async
      ; async_kernel
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; sexplib0
      ; integers
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let multisig_tests =
  private_library "multisig_tests"
    ~path:"src/lib/transaction_snark/test/multisig_account" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_wire_types
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_base
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_backend
      ; Layer_storage.cache_dir
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_crypto.crypto_params
      ; local "snarky.backendless"
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_transaction.mina_transaction_logic
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_base.with_hash
      ; Layer_domain.data_hash_lib
      ; Layer_base.mina_stdlib
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let permissions_tests =
  private_library "permissions_tests"
    ~path:"src/lib/transaction_snark/test/permissions" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async_unix
      ; async
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let token_symbol_tests =
  private_library "token_symbol_tests"
    ~path:"src/lib/transaction_snark/test/token_symbol" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async_unix
      ; async
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.currency
      ; Layer_base.mina_stdlib
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let transaction_union_tests =
  private_library "transaction_union_tests"
    ~path:"src/lib/transaction_snark/test/transaction_union" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; Layer_base.mina_base_import
      ; Layer_base.mina_stdlib
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ; Layer_test.test_util
      ; Layer_consensus.consensus
      ; Layer_base.one_or_two
      ; Layer_consensus.coda_genesis_ledger
      ; local "sexplib0"
      ; Layer_test.quickcheck_lib
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Layer_ledger.staged_ledger_diff
      ; Layer_base.mina_wire_types
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let verification_key_tests =
  private_library "verification_key_tests"
    ~path:"src/lib/transaction_snark/test/verification_key" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async_unix
      ; async
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_transaction.mina_transaction_logic
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ; Layer_base.with_hash
      ; Layer_crypto.random_oracle
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let verification_key_permission_tests =
  private_library "verification_key_permission_tests"
    ~path:"src/lib/transaction_snark/test/verification_key_permission"
    ~inline_tests:true ~inline_tests_deps:[ "proof_cache.json" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async_unix
      ; async
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; protocol_version
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let transaction_snark_tests_verify_simple_test =
  private_library "transaction_snark_tests_verify_simple_test"
    ~path:"src/lib/transaction_snark/test/verify-simple-test" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; base
      ; core_kernel
      ; base64
      ; yojson
      ; Layer_crypto.random_oracle_input
      ; Layer_pickles.pickles_backend
      ; Layer_base.mina_base_import
      ; Layer_crypto.crypto_params
      ; Layer_kimchi.kimchi_backend
      ; Layer_base.with_hash
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_base
      ; Layer_consensus.consensus
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; local "snarky.backendless"
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_pickles.pickles_types
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_storage.cache_dir
      ; Layer_domain.data_hash_lib
      ; Layer_base.mina_numbers
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_base.sgn_type
      ; local "sexplib0"
      ; Layer_test.test_util
      ; Layer_transaction.transaction_witness
      ; Layer_ledger.staged_ledger_diff
      ; Layer_base.mina_wire_types
      ; Layer_domain.block_time
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_sexp_conv
         ] )

let voting_for_tests =
  private_library "voting_for_tests"
    ~path:"src/lib/transaction_snark/test/voting_for" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async_unix
      ; async
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ; Layer_base.with_hash
      ; Layer_crypto.random_oracle
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let zkapp_deploy_tests =
  private_library "zkapp_deploy_tests"
    ~path:"src/lib/transaction_snark/test/zkapp_deploy" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let () =
  private_executable ~path:"src/lib/transaction_snark/test/zkapp_fuzzy"
    ~link_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async
      ; async_kernel
      ; async_unix
      ; async_command
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; splittable_random
      ; Layer_logging.logger
      ; Layer_base.mina_base_import
      ; Layer_domain.data_hash_lib
      ; local "mina_generators"
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ; Layer_test.test_util
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.with_hash
      ; Layer_crypto.random_oracle
      ; local "sexplib0"
      ; zkapp_command_builder
      ; Layer_base.mina_stdlib
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ] )
    "zkapp_fuzzy"

let zkapp_payments_tests =
  private_library "zkapp_payments_tests"
    ~path:"src/lib/transaction_snark/test/zkapp_payments" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; sexplib0
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_logging.logger
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ; Layer_test.test_util
      ; Layer_transaction.mina_transaction_logic
      ; Layer_transaction.mina_transaction
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ] )

let account_update_precondition_tests =
  private_library "account_update_precondition_tests"
    ~path:"src/lib/transaction_snark/test/zkapp_preconditions"
    ~inline_tests:true ~inline_tests_deps:[ "proof_cache.json" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async_unix
      ; async
      ; async_kernel
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_base_import
      ; Layer_domain.data_hash_lib
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; transaction_snark
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; local "mina_generators"
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; zkapp_command_builder
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let zkapp_tokens_tests =
  private_library "zkapp_tokens_tests"
    ~path:"src/lib/transaction_snark/test/zkapp_tokens" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async
      ; async_kernel
      ; async_unix
      ; core_kernel
      ; sexplib0
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_base_import
      ; transaction_snark
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; local "mina_generators"
      ; Layer_base.currency
      ; Layer_pickles.pickles
      ; Layer_base.mina_numbers
      ; zkapp_command_builder
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ; Layer_test.test_util
      ; Layer_transaction.mina_transaction_logic
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ] )

let zkapp_uri_tests =
  private_library "zkapp_uri_tests"
    ~path:"src/lib/transaction_snark/test/zkapp_uri" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; async_unix
      ; async
      ; core
      ; base
      ; core_kernel
      ; yojson
      ; ppx_deriving_yojson_runtime
      ; result
      ; Layer_base.mina_base_import
      ; Layer_pickles.pickles
      ; transaction_snark
      ; Layer_base.mina_stdlib
      ; Layer_crypto.snark_params
      ; Layer_ledger.mina_ledger
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.currency
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; transaction_protocol_state
      ; Layer_pickles.pickles_types
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; transaction_snark_tests
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_snarky; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])
