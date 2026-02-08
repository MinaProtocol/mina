(** Mina tooling layer: tracing, metrics, and observability.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let perf_histograms =
  library "perf_histograms" ~path:"src/lib/perf_histograms"
    ~synopsis:"Performance monitoring with histograms"
    ~modules:
      [ "perf_histograms0"; "perf_histograms"; "histogram"; "rpc"; "intf" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_inline_test_config
      ; bin_prot_shape
      ; async_rpc_kernel
      ; yojson
      ; async
      ; core
      ; core_kernel
      ; ppx_deriving_yojson_runtime
      ; async_rpc
      ; base_caml
      ; async_kernel
      ; local "mina_metrics"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~inline_tests:true

let internal_tracing_context_call =
  library "internal_tracing.context_call"
    ~internal_name:"internal_tracing_context_call"
    ~path:"src/lib/internal_tracing/context_call"
    ~synopsis:"Internal tracing context call ID helper"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:[ base_internalhash_types; core_kernel; sexplib0; async_kernel ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let internal_tracing =
  library "internal_tracing" ~path:"src/lib/internal_tracing"
    ~synopsis:"Internal tracing" ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ core
      ; yojson
      ; async_kernel
      ; local "logger"
      ; Layer_base.mina_base
      ; local "mina_numbers"
      ; internal_tracing_context_call
      ; local "logger_context_logger"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let mina_metrics =
  library "mina_metrics" ~path:"src/lib/mina_metrics"
    ~deps:[ async_kernel; logger; uri; core_kernel ]
    ~ppx:Ppx.minimal ~virtual_modules:[ "mina_metrics" ]
    ~default_implementation:"mina_metrics.prometheus"

let mina_metrics_none =
  library "mina_metrics.none" ~internal_name:"mina_metrics_none"
    ~path:"src/lib/mina_metrics/no_metrics"
    ~deps:[ async_kernel; logger; uri; core_kernel ]
    ~ppx:Ppx.minimal ~implements:"mina_metrics"

let mina_metrics_prometheus =
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
      ; Layer_node.mina_node_config
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_pipebang
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_here
         ] )
    ~implements:"mina_metrics"
