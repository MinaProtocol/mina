(** Product: ledger_export_bench — Ledger export benchmarking. *)

open Manifest
open Externals
open Dune_s_expr

let () =
  executable "mina-ledger-export-benchmark"
    ~internal_name:"ledger_export_benchmark"
    ~package:"mina_ledger_export_benchmark" ~path:"src/app/ledger_export_bench"
    ~modes:[ "native" ]
    ~flags:
      [ atom "-short-paths"
      ; atom "-g"
      ; atom "-w"
      ; atom "@a-4-29-40-41-42-44-45-48-58-59-60"
      ]
    ~deps:
      [ base
      ; core
      ; core_bench
      ; core_kernel
      ; yojson
      ; local "mina_runtime_config"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])
