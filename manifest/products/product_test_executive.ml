(** Product: test_executive — Mina integration test executive. *)

open Manifest
open Externals

let () =
  executable "mina-test-executive" ~internal_name:"test_executive"
  ~package:"mina_test_executive" ~path:"src/app/test_executive"
  ~deps:
    [ async
    ; async_kernel
    ; async_unix
    ; base_internalhash_types
    ; base_caml
    ; cmdliner
    ; core
    ; core_kernel
    ; integers
    ; sexplib0
    ; stdio
    ; unsigned_extended
    ; uri
    ; yojson
    ; Layer_domain.block_time
    ; Layer_storage.cache_dir
    ; Layer_base.currency
    ; Layer_domain.data_hash_lib
    ; Layer_domain.genesis_constants
    ; local "integration_test_lib"
    ; local "integration_test_local_engine"
    ; Layer_crypto.key_gen
    ; Layer_crypto.kimchi_backend
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_infra.logger
    ; Layer_base.mina_base
    ; Layer_base.mina_base_import
    ; local "mina_generators"
    ; Layer_infra.mina_numbers
    ; local "mina_runtime_config"
    ; Layer_infra.mina_signature_kind
    ; Layer_base.mina_stdlib
    ; Layer_infra.mina_stdlib_unix
    ; Layer_transaction.mina_transaction
    ; Layer_network.network_pool
    ; Layer_base.participating_state
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.pickles_types
    ; Layer_base.pipe_lib
    ; Layer_protocol.protocol_version
    ; Layer_crypto.random_oracle
    ; Layer_crypto.random_oracle_input
    ; Layer_crypto.secrets
    ; Layer_crypto.sgn
    ; Layer_crypto.signature_lib
    ; local "snarky.backendless"
    ; Layer_crypto.snark_params
    ; Layer_protocol.transaction_snark
    ; Layer_domain.user_command_input
    ; Layer_base.visualization
    ; Layer_base.with_hash
    ; Layer_protocol.zkapp_command_builder
    ; Product_zkapps_examples.zkapps_examples
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_deriving_yojson
       ; Ppx_lib.ppx_jane
       ; Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_version
       ] )

