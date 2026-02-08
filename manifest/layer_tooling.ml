(** Mina tooling layer: tracing, metrics, and observability.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest

let register () =
  (* -- internal_tracing.context_call ------------------------------ *)
  library "internal_tracing.context_call"
    ~internal_name:"internal_tracing_context_call"
    ~path:"src/lib/internal_tracing/context_call"
    ~synopsis:"Internal tracing context call ID helper"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "async_kernel"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_mina"; "ppx_version"; "ppx_deriving_yojson" ] ) ;

  (* -- internal_tracing ------------------------------------------- *)
  library "internal_tracing" ~path:"src/lib/internal_tracing"
    ~synopsis:"Internal tracing" ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ opam "core"
      ; opam "yojson"
      ; opam "async_kernel"
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
    ~deps:[ opam "async_kernel"; opam "logger"; opam "uri"; opam "core_kernel" ]
    ~ppx:Ppx.minimal ~virtual_modules:[ "mina_metrics" ]
    ~default_implementation:"mina_metrics.prometheus" ;

  (* -- mina_metrics.none ------------------------------------------ *)
  library "mina_metrics.none" ~internal_name:"mina_metrics_none"
    ~path:"src/lib/mina_metrics/no_metrics"
    ~deps:[ opam "async_kernel"; opam "logger"; opam "uri"; opam "core_kernel" ]
    ~ppx:Ppx.minimal ~implements:"mina_metrics" ;

  (* -- mina_metrics.prometheus ------------------------------------ *)
  library "mina_metrics.prometheus" ~internal_name:"mina_metrics_prometheus"
    ~path:"src/lib/mina_metrics/prometheus_metrics"
    ~deps:
      [ opam "conduit-async"
      ; opam "ppx_hash.runtime-lib"
      ; opam "fmt"
      ; opam "re"
      ; opam "base"
      ; opam "core"
      ; opam "async_kernel"
      ; opam "core_kernel"
      ; opam "prometheus"
      ; opam "cohttp-async"
      ; opam "cohttp"
      ; opam "async"
      ; opam "base.base_internalhash_types"
      ; opam "uri"
      ; opam "async_unix"
      ; opam "base.caml"
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
