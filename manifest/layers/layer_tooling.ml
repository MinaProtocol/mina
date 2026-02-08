(** Mina tooling layer: tracing, metrics, and observability.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let register () =
  (* -- internal_tracing.context_call ------------------------------ *)
  library "internal_tracing.context_call"
    ~internal_name:"internal_tracing_context_call"
    ~path:"src/lib/internal_tracing/context_call"
    ~synopsis:"Internal tracing context call ID helper"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:[ base_internalhash_types; core_kernel; sexplib0; async_kernel ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_mina"; "ppx_version"; "ppx_deriving_yojson" ] ) ;

  (* -- internal_tracing ------------------------------------------- *)
  library "internal_tracing" ~path:"src/lib/internal_tracing"
    ~synopsis:"Internal tracing" ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ core
      ; yojson
      ; async_kernel
      ; local "logger"
      ; local "mina_base"
      ; local "mina_numbers"
      ; local "internal_tracing.context_call"
      ; local "logger.context_logger"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_mina"; "ppx_version"; "ppx_deriving_yojson" ] ) ;

  (* -- mina_metrics (virtual) ------------------------------------- *)
  library "mina_metrics" ~path:"src/lib/mina_metrics"
    ~deps:[ async_kernel; logger; uri; core_kernel ]
    ~ppx:Ppx.minimal ~virtual_modules:[ "mina_metrics" ]
    ~default_implementation:"mina_metrics.prometheus" ;

  (* -- mina_metrics.none ------------------------------------------ *)
  library "mina_metrics.none" ~internal_name:"mina_metrics_none"
    ~path:"src/lib/mina_metrics/no_metrics"
    ~deps:[ async_kernel; logger; uri; core_kernel ]
    ~ppx:Ppx.minimal ~implements:"mina_metrics" ;

  (* -- mina_metrics.prometheus ------------------------------------ *)
  library "mina_metrics.prometheus" ~internal_name:"mina_metrics_prometheus"
    ~path:"src/lib/mina_metrics/prometheus_metrics"
    ~deps:
      [ conduit_async
      ; ppx_hash_runtime_lib
      ; fmt
      ; re
      ; base
      ; core
      ; async_kernel
      ; core_kernel
      ; prometheus
      ; cohttp_async
      ; cohttp
      ; async
      ; base_internalhash_types
      ; uri
      ; async_unix
      ; base_caml
      ; local "logger"
      ; local "o1trace"
      ; local "mina_node_config"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_let"
         ; "ppx_version"
         ; "ppx_pipebang"
         ; "ppx_custom_printf"
         ; "ppx_here"
         ] )
    ~implements:"mina_metrics" ;

  ()
