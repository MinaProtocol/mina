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
      ; base_caml
      ; base_internalhash_types
      ; cmdliner
      ; core
      ; core_kernel
      ; integers
      ; sexplib0
      ; stdio
      ; unsigned_extended
      ; uri
      ; yojson
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_stdlib_unix
      ; Layer_base.participating_state
      ; Layer_base.visualization
      ; Layer_base.with_hash
      ; Layer_concurrency.pipe_lib
      ; Layer_crypto.key_gen
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.secrets
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_logging.logger
      ; Layer_network.network_pool
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_protocol.mina_signature_kind
      ; Layer_protocol.protocol_version
      ; Layer_protocol.transaction_snark
      ; Layer_protocol.zkapp_command_builder
      ; Layer_storage.cache_dir
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.user_command_input
      ; Product_zkapps_examples.zkapps_examples
      ; Snarky_lib.snarky_backendless
      ; local "integration_test_lib"
      ; local "integration_test_local_engine"
      ; local "mina_generators"
      ; local "mina_runtime_config"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )
