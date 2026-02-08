(** Product: runtime_genesis_ledger — Generate genesis ledgers at runtime. *)

open Manifest
open Externals

let () =
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
      ; Layer_storage.cache_dir
      ; local "cli_lib"
      ; Layer_consensus.coda_genesis_ledger
      ; Layer_consensus.consensus
      ; Layer_domain.genesis_constants
      ; Layer_network.genesis_ledger_helper
      ; Layer_infra.logger
      ; Layer_base.mina_base
      ; Layer_ledger.mina_ledger
      ; local "mina_runtime_config"
      ; Layer_base.mina_stdlib
      ; Layer_consensus.precomputed_values
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )
