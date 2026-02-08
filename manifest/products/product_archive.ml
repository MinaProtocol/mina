(** Product: archive — Mina blockchain archive node.

    Stores blockchain data in a PostgreSQL database. *)

open Manifest

let register () =
  (* -- archive (executable) ------------------------------------------- *)
  executable "archive" ~package:"archive" ~path:"src/app/archive"
    ~deps:
      [ opam "archive_cli"
      ; opam "async"
      ; opam "async_unix"
      ; opam "core_kernel"
      ; local "mina_version"
      ]
    ~modules:[ "archive" ] ~modes:[ "native" ] ~ppx:Ppx.minimal
    ~bisect_sigterm:true ;

  (* -- archive_cli (library) ------------------------------------------ *)
  library "archive.cli" ~internal_name:"archive_cli" ~path:"src/app/archive/cli"
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "caqti"
      ; opam "caqti-async"
      ; opam "core"
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
      [ opam "async"
      ; opam "async.async_rpc"
      ; opam "async_kernel"
      ; opam "async_rpc_kernel"
      ; opam "async_unix"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "base64"
      ; opam "bin_prot.shape"
      ; opam "caqti"
      ; opam "caqti-async"
      ; opam "caqti-driver-postgresql"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "ppx_inline_test.config"
      ; opam "ppx_version.runtime"
      ; opam "sexplib0"
      ; opam "uri"
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
