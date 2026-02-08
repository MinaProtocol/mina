(** Product: test_executive — Mina integration test executive. *)

open Manifest
open Externals

let register () =
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
      ; local "block_time"
      ; local "cache_dir"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "genesis_constants"
      ; local "integration_test_lib"
      ; local "integration_test_local_engine"
      ; local "key_gen"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_generators"
      ; local "mina_numbers"
      ; local "mina_runtime_config"
      ; local "mina_signature_kind"
      ; local "mina_stdlib"
      ; local "mina_stdlib_unix"
      ; local "mina_transaction"
      ; local "network_pool"
      ; local "participating_state"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "pipe_lib"
      ; local "protocol_version"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "secrets"
      ; local "sgn"
      ; local "signature_lib"
      ; local "snarky.backendless"
      ; local "snark_params"
      ; local "transaction_snark"
      ; local "user_command_input"
      ; local "visualization"
      ; local "with_hash"
      ; local "zkapp_command_builder"
      ; local "zkapps_examples"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  ()
