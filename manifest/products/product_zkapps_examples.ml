(** Product: zkapps_examples — Example zkApp smart contracts and tests. *)

open Manifest
open Externals

let zkapps_examples =
  library "zkapps_examples" ~path:"src/app/zkapps_examples"
    ~deps:
      [ async_kernel
      ; base
      ; core_kernel
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.with_hash
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "pasta_bindings"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_let; Ppx_lib.ppx_version ])

let zkapps_actions =
  private_library "zkapps_actions" ~path:"src/app/zkapps_examples/actions"
    ~deps:
      [ base
      ; core_kernel
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_crypto.crypto_params
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_types
      ; Snarky_lib.snarky_backendless
      ]
    ~ppx:Ppx.minimal

let zkapps_add_events =
  private_library "zkapps_add_events" ~path:"src/app/zkapps_examples/add_events"
    ~deps:
      [ base
      ; core_kernel
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_crypto.crypto_params
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_types
      ; Snarky_lib.snarky_backendless
      ]
    ~ppx:Ppx.minimal

let zkapps_big_circuit =
  private_library "zkapps_big_circuit"
    ~path:"src/app/zkapps_examples/big_circuit"
    ~deps:
      [ core_kernel
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_kimchi.kimchi_pasta_constraint_system
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "pasta_bindings"
      ]
    ~ppx:Ppx.minimal

let zkapps_calls =
  private_library "zkapps_calls" ~path:"src/app/zkapps_examples/calls"
    ~deps:
      [ base
      ; core_kernel
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.with_hash
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "pasta_bindings"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.h_list_ppx; Ppx_lib.ppx_version ])

let zkapps_empty_update =
  private_library "zkapps_empty_update"
    ~path:"src/app/zkapps_examples/empty_update"
    ~deps:
      [ core_kernel
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "pasta_bindings"
      ]
    ~ppx:Ppx.minimal

let zkapps_initialize_state =
  private_library "zkapps_initialize_state"
    ~path:"src/app/zkapps_examples/initialize_state"
    ~deps:
      [ base
      ; core_kernel
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "pasta_bindings"
      ]
    ~ppx:Ppx.minimal

let zkapps_tokens =
  private_library "zkapps_tokens" ~path:"src/app/zkapps_examples/tokens"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; core_kernel
      ; yojson
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.with_hash
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_base
      ; Layer_pickles.pickles_types
      ; Layer_storage.cache_dir
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.h_list_ppx; Ppx_lib.ppx_let; Ppx_lib.ppx_version ])

let tokens =
  private_library "tokens" ~path:"src/app/zkapps_examples/test/tokens"
    ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; core
      ; core_kernel
      ; ppx_inline_test_config
      ; yojson
      ; zkapps_examples
      ; zkapps_tokens
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.with_hash
      ; Layer_consensus.mina_state
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.transaction_snark_tests
      ; Layer_storage.cache_dir
      ; Layer_transaction.mina_transaction_logic
      ; Snarky_lib.snarky_backendless
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_snarky; Ppx_lib.ppx_version ])

let () =
  test "actions" ~path:"src/app/zkapps_examples/test/actions"
    ~deps:
      [ alcotest
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; core_kernel
      ; yojson
      ; zkapps_actions
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.with_hash
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.merkle_list_verifier
      ; Layer_ledger.mina_ledger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_base
      ; Layer_pickles.pickles_types
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.transaction_snark_tests
      ; Layer_storage.cache_dir
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])

let () =
  test "add_events" ~path:"src/app/zkapps_examples/test/add_events"
    ~deps:
      [ alcotest
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; core_kernel
      ; zkapps_add_events
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.with_hash
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.merkle_list_verifier
      ; Layer_ledger.mina_ledger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.transaction_snark_tests
      ; Layer_storage.cache_dir
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])

let () =
  test "big_circuit" ~path:"src/app/zkapps_examples/test/big_circuit"
    ~deps:
      [ alcotest
      ; async
      ; async_kernel
      ; async_unix
      ; base
      ; core
      ; core_kernel
      ; yojson
      ; zkapps_big_circuit
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.with_hash
      ; Layer_consensus.mina_state
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_base
      ; Layer_pickles.pickles_types
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.transaction_snark_tests
      ; Layer_storage.cache_dir
      ; Layer_transaction.mina_transaction_logic
      ; Snarky_lib.snarky_backendless
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_snarky; Ppx_lib.ppx_version ])

let () =
  test "calls" ~path:"src/app/zkapps_examples/test/calls"
    ~deps:
      [ alcotest
      ; async
      ; async_kernel
      ; async_unix
      ; base
      ; core
      ; core_kernel
      ; yojson
      ; zkapps_calls
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.with_hash
      ; Layer_consensus.mina_state
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.transaction_snark_tests
      ; Layer_storage.cache_dir
      ; Layer_transaction.mina_transaction_logic
      ; Snarky_lib.snarky_backendless
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_snarky; Ppx_lib.ppx_version ])

let () =
  test "empty_update" ~path:"src/app/zkapps_examples/test/empty_update"
    ~deps:
      [ alcotest
      ; async
      ; async_kernel
      ; async_unix
      ; base
      ; core
      ; core_kernel
      ; yojson
      ; zkapps_empty_update
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.with_hash
      ; Layer_consensus.mina_state
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_base
      ; Layer_pickles.pickles_types
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.transaction_snark_tests
      ; Layer_storage.cache_dir
      ; Layer_transaction.mina_transaction_logic
      ; Snarky_lib.snarky_backendless
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_snarky; Ppx_lib.ppx_version ])

let () =
  test "initialize_state" ~path:"src/app/zkapps_examples/test/initialize_state"
    ~deps:
      [ alcotest
      ; async
      ; async_kernel
      ; async_unix
      ; base
      ; core
      ; core_kernel
      ; yojson
      ; zkapps_examples
      ; zkapps_initialize_state
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.with_hash
      ; Layer_consensus.mina_state
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.transaction_snark_tests
      ; Layer_storage.cache_dir
      ; Layer_transaction.mina_transaction_logic
      ; Snarky_lib.snarky_backendless
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_snarky; Ppx_lib.ppx_version ])

let () =
  test "zkapp_optional_custom_gates_tests"
    ~path:"src/app/zkapps_examples/test/optional_custom_gates"
    ~deps:
      [ alcotest
      ; async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; core
      ; core_kernel
      ; integers
      ; result
      ; sexplib0
      ; zkapps_examples
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_ledger.mina_ledger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_types
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.transaction_snark_tests
      ; Layer_protocol.zkapp_command_builder
      ; Layer_snarky.snark_keys_header
      ; Layer_test.test_util
      ; Layer_transaction.mina_transaction_logic
      ; local "mina_generators"
      ; local "pickles_optional_custom_gates_circuits"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ] )
