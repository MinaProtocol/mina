(** Product: archive — Mina blockchain archive node.

    Stores blockchain data in a PostgreSQL database. *)

open Manifest
open Externals

let register () =
  (* -- archive (executable) ------------------------------------------- *)
  executable "archive" ~package:"archive" ~path:"src/app/archive"
    ~deps:[ archive_cli; async; async_unix; core_kernel; local "mina_version" ]
    ~modules:[ "archive" ] ~modes:[ "native" ] ~ppx:Ppx.minimal
    ~bisect_sigterm:true ;

  (* -- archive_cli (library) ------------------------------------------ *)
  library "archive.cli" ~internal_name:"archive_cli" ~path:"src/app/archive/cli"
    ~deps:
      [ async
      ; async_command
      ; caqti
      ; caqti_async
      ; core
      ; local "archive_lib"
      ; local "block_time"
      ; local "cli_lib"
      ; local "genesis_constants"
      ; local "logger"
      ; local "mina_caqti"
      ; local "mina_runtime_config"
      ; local "mina_version"
      ]
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_mina"; "ppx_version" ])
    ~bisect_sigterm:true ;

  (* -- archive_lib (library) ------------------------------------------ *)
  library "archive_lib" ~path:"src/app/archive/lib"
    ~deps:
      [ async
      ; async_rpc
      ; async_kernel
      ; async_rpc_kernel
      ; async_unix
      ; base_internalhash_types
      ; base_caml
      ; base64
      ; bin_prot_shape
      ; caqti
      ; caqti_async
      ; caqti_driver_postgresql
      ; core
      ; core_kernel
      ; integers
      ; ppx_deriving_yojson_runtime
      ; ppx_inline_test_config
      ; ppx_version_runtime
      ; sexplib0
      ; uri
      ; local "block_time"
      ; local "child_processes"
      ; local "coda_genesis_ledger"
      ; local "consensus"
      ; local "consensus.vrf"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "error_json"
      ; local "genesis_constants"
      ; local "genesis_ledger_helper"
      ; local "genesis_ledger_helper.lib"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_base.util"
      ; local "mina_block"
      ; local "mina_caqti"
      ; local "mina_generators"
      ; local "mina_ledger"
      ; local "mina_metrics"
      ; local "mina_numbers"
      ; local "mina_runtime_config"
      ; local "mina_state"
      ; local "mina_stdlib"
      ; local "mina_transaction"
      ; local "mina_wire_types"
      ; local "o1trace"
      ; local "one_or_two"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "pipe_lib"
      ; local "precomputed_values"
      ; local "protocol_version"
      ; local "quickcheck_lib"
      ; local "random_oracle"
      ; local "sgn"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "staged_ledger"
      ; local "staged_ledger_diff"
      ; local "transition_frontier"
      ; local "transition_frontier_base"
      ; local "unsigned_extended"
      ; local "verifier"
      ; local "with_hash"
      ; local "zkapp_command_builder"
      ]
    ~inline_tests:true ~modes:[ "native" ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_custom_printf"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ] )
    ~bisect_sigterm:true ;

  ()
