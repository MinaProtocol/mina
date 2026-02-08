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
      [ async
      ; async_kernel
      ; async_rpc
      ; async_rpc_kernel
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; ppx_deriving_yojson_runtime
      ; ppx_inline_test_config
      ; yojson
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
    ~deps:[ async_kernel; base_internalhash_types; core_kernel; sexplib0 ]
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
      [ async_kernel
      ; core
      ; internal_tracing_context_call
      ; yojson
      ; Layer_base.mina_base
      ; local "logger"
      ; local "logger_context_logger"
      ; local "mina_numbers"
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
    ~deps:[ async_kernel; core_kernel; logger; uri ]
    ~ppx:Ppx.minimal ~virtual_modules:[ "mina_metrics" ]
    ~default_implementation:"mina_metrics.prometheus"

let mina_metrics_none =
  library "mina_metrics.none" ~internal_name:"mina_metrics_none"
    ~path:"src/lib/mina_metrics/no_metrics"
    ~deps:[ async_kernel; core_kernel; logger; uri ]
    ~ppx:Ppx.minimal ~implements:"mina_metrics"

let mina_metrics_prometheus =
  library "mina_metrics.prometheus" ~internal_name:"mina_metrics_prometheus"
    ~path:"src/lib/mina_metrics/prometheus_metrics"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; base_internalhash_types
      ; cohttp
      ; cohttp_async
      ; conduit_async
      ; core
      ; core_kernel
      ; fmt
      ; ppx_hash_runtime_lib
      ; prometheus
      ; re
      ; uri
      ; Layer_node.mina_node_config
      ; local "logger"
      ; local "o1trace"
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
