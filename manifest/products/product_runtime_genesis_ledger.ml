(** Product: runtime_genesis_ledger — Generate genesis ledgers at runtime. *)

open Manifest
open Externals

let register () =
  executable "runtime_genesis_ledger" ~path:"src/app/runtime_genesis_ledger"
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; async_unix
      ; base
      ; core
      ; core_kernel
      ; result
      ; yojson
      ; local "cache_dir"
      ; local "cli_lib"
      ; local "coda_genesis_ledger"
      ; local "consensus"
      ; local "genesis_constants"
      ; local "genesis_ledger_helper"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_ledger"
      ; local "mina_runtime_config"
      ; local "mina_stdlib"
      ; local "precomputed_values"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving_yojson"; "ppx_let"; "ppx_mina"; "ppx_version" ] ) ;

  ()
