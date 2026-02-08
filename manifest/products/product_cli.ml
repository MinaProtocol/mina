(** Product: cli — Mina daemon command-line interface.

    The main mina executable with testnet/mainnet signature variants. *)

open Manifest
open Dune_s_expr

let register () =
  (* -- mina (executable) ---------------------------------------------- *)
  executable "mina" ~package:"cli" ~path:"src/app/cli/src" ~modules:[ "mina" ]
    ~modes:[ "native" ]
    ~flags:[ atom ":standard"; atom "-warn-error"; atom "+a" ]
    ~deps:[ local "disk_cache.lmdb"; local "mina_cli_entrypoint" ]
    ~ppx:Ppx.minimal ;

  (* -- mina-testnet (executable) -------------------------------------- *)
  executable "mina-testnet" ~internal_name:"mina_testnet_signatures"
    ~package:"cli" ~path:"src/app/cli/src"
    ~modules:[ "mina_testnet_signatures" ]
    ~modes:[ "native" ]
    ~flags:[ atom ":standard"; atom "-warn-error"; atom "+a" ]
    ~deps:
      [ local "disk_cache.lmdb"
      ; local "mina_cli_entrypoint"
      ; local "mina_signature_kind.testnet"
      ]
    ~ppx:Ppx.minimal ;

  (* -- mina-mainnet (executable) -------------------------------------- *)
  executable "mina-mainnet" ~internal_name:"mina_mainnet_signatures"
    ~package:"cli" ~path:"src/app/cli/src"
    ~modules:[ "mina_mainnet_signatures" ]
    ~modes:[ "native" ]
    ~flags:[ atom ":standard"; atom "-warn-error"; atom "+a" ]
    ~deps:
      [ local "disk_cache.lmdb"
      ; local "mina_cli_entrypoint"
      ; local "mina_signature_kind.mainnet"
      ]
    ~ppx:Ppx.minimal ;

  (* -- init: rule for assets.ml generation ----------------------------- *)
  file_stanzas ~path:"src/app/cli/src/init"
    (Dune_s_expr.parse_string
       "(rule\n\
       \ (targets assets.ml)\n\
       \ (deps\n\
       \  (source_tree assets))\n\
       \ (action\n\
       \  (run %{bin:ocaml-crunch} -m plain assets -o assets.ml)))" ) ;

  (* -- init (library) ------------------------------------------------- *)
  library "init" ~path:"src/app/cli/src/init"
    ~deps:
      [ opam "astring"
      ; opam "async"
      ; opam "async.async_command"
      ; opam "async.async_rpc"
      ; opam "async_kernel"
      ; opam "async_rpc_kernel"
      ; opam "async_ssl"
      ; opam "async_unix"
      ; opam "base"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "base_quickcheck"
      ; opam "cohttp"
      ; opam "cohttp-async"
      ; opam "core"
      ; opam "core.uuid"
      ; opam "core_kernel"
      ; opam "core_kernel.uuid"
      ; opam "graphql"
      ; opam "graphql-async"
      ; opam "graphql-cohttp"
      ; opam "graphql_parser"
      ; opam "integers"
      ; opam "mirage-crypto-ec"
      ; opam "result"
      ; opam "sexplib0"
      ; opam "stdio"
      ; opam "uri"
      ; local "allocation_functor"
      ; local "archive_lib"
      ; local "block_time"
      ; local "blockchain_snark"
      ; local "child_processes"
      ; local "cli_lib"
      ; local "coda_genesis_ledger"
      ; local "coda_genesis_proof"
      ; local "consensus"
      ; local "currency"
      ; local "daemon_rpcs"
      ; local "data_hash_lib"
      ; local "error_json"
      ; local "generated_graphql_queries"
      ; local "genesis_constants"
      ; local "genesis_ledger_helper"
      ; local "genesis_ledger_helper.lib"
      ; local "graphql_lib"
      ; local "group_map"
      ; local "internal_tracing"
      ; local "itn_crypto"
      ; local "itn_logger"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_block"
      ; local "mina_commands"
      ; local "mina_compile_config"
      ; local "mina_generators"
      ; local "mina_graphql"
      ; local "mina_ledger"
      ; local "mina_lib"
      ; local "mina_metrics"
      ; local "mina_net2"
      ; local "mina_networking"
      ; local "mina_numbers"
      ; local "mina_runtime_config"
      ; local "mina_signature_kind"
      ; local "mina_state"
      ; local "mina_stdlib"
      ; local "mina_stdlib_unix"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "mina_version"
      ; local "mina_wire_types"
      ; local "network_peer"
      ; local "network_pool"
      ; local "node_error_service"
      ; local "o1trace"
      ; local "o1trace_webkit_event"
      ; local "one_or_two"
      ; local "parallel"
      ; local "participating_state"
      ; local "perf_histograms"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "precomputed_values"
      ; local "protocol_version"
      ; local "random_oracle"
      ; local "secrets"
      ; local "sgn"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "snark_profiler_lib"
      ; local "snark_work_lib"
      ; local "snark_worker"
      ; local "staged_ledger"
      ; local "string_sign"
      ; local "test_util"
      ; local "transaction_inclusion_status"
      ; local "transaction_protocol_state"
      ; local "transaction_snark"
      ; local "transaction_snark_scan_state"
      ; local "transaction_snark_tests"
      ; local "trust_system"
      ; local "unsigned_extended"
      ; local "user_command_input"
      ; local "verifier"
      ; local "with_hash"
      ; local "zkapp_command_builder"
      ]
    ~preprocessor_deps:
      [ "../../../../../graphql_schema.json"
      ; "../../../../graphql-ppx-config.inc"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_assert"
         ; "ppx_base"
         ; "ppx_bench"
         ; "ppx_bin_prot"
         ; "ppx_custom_printf"
         ; "ppx_deriving_yojson"
         ; "ppx_fields_conv"
         ; "ppx_fixed_literal"
         ; "ppx_here"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_module_timer"
         ; "ppx_optional"
         ; "ppx_pipebang"
         ; "ppx_sexp_message"
         ; "ppx_sexp_value"
         ; "ppx_string"
         ; "ppx_typerep_conv"
         ; "ppx_variants_conv"
         ; "ppx_version"
         ; "graphql_ppx"
         ; "--"
         ; "%{read-lines:../../../../graphql-ppx-config.inc}"
         ] ) ;

  (* -- mina_cli_entrypoint (library) ---------------------------------- *)
  library "cli.mina_cli_entrypoint" ~internal_name:"mina_cli_entrypoint"
    ~path:"src/app/cli/src/cli_entrypoint" ~modes:[ "native" ]
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "base.caml"
      ; opam "bin_prot"
      ; opam "bin_prot.shape"
      ; opam "core"
      ; opam "core.daemon"
      ; opam "core_kernel"
      ; opam "init"
      ; opam "memtrace"
      ; opam "result"
      ; opam "sexplib0"
      ; opam "stdio"
      ; opam "uri"
      ; local "blake2"
      ; local "block_producer"
      ; local "block_time"
      ; local "blockchain_snark"
      ; local "cache_dir"
      ; local "child_processes"
      ; local "cli_lib"
      ; local "coda_genesis_proof"
      ; local "consensus"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "error_json"
      ; local "genesis_constants"
      ; local "genesis_ledger_helper"
      ; local "gossip_net"
      ; local "internal_tracing"
      ; local "itn_logger"
      ; local "ledger_proof"
      ; local "logger"
      ; local "logger.file_system"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_block"
      ; local "mina_compile_config"
      ; local "mina_ledger"
      ; local "mina_lib"
      ; local "mina_metrics"
      ; local "mina_net2"
      ; local "mina_networking"
      ; local "mina_plugins"
      ; local "mina_runtime_config"
      ; local "mina_stdlib"
      ; local "mina_stdlib_unix"
      ; local "mina_version"
      ; local "node_addrs_and_ports"
      ; local "node_error_service"
      ; local "o1trace"
      ; local "parallel"
      ; local "pipe_lib"
      ; local "ppx_version.runtime"
      ; local "precomputed_values"
      ; local "protocol_version"
      ; local "prover"
      ; local "secrets"
      ; local "signature_lib"
      ; local "snarky.backendless"
      ; local "snark_work_lib"
      ; local "snark_worker"
      ; local "transaction_snark"
      ; local "transaction_witness"
      ; local "trust_system"
      ; local "verifier"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving_yojson"
         ; "ppx_here"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] ) ;

  ()
