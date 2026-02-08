(** Mina Core infrastructure libraries: logging, metrics, config, etc.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let logger =
  library "logger" ~path:"src/lib/logger"
    ~deps:[ core_kernel; sexplib0; Layer_base.interpolator_lib ]
    ~ppx:Ppx.mina_rich ~virtual_modules:[ "logger" ]
    ~default_implementation:"logger.native"

let logger_context_logger =
  library "logger.context_logger" ~internal_name:"context_logger"
    ~path:"src/lib/logger/context_logger"
    ~synopsis:
      "Context logger: useful for passing logger down the deep callstacks"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ base_internalhash_types; core_kernel; sexplib0; async_kernel; logger ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let logger_fake =
  library "logger.fake" ~internal_name:"logger_fake" ~path:"src/lib/logger/fake"
    ~synopsis:"Fake logging library"
    ~deps:
      [ result
      ; core_kernel
      ; sexplib0
      ; bin_prot_shape
      ; base_caml
      ; base_internalhash_types
      ; Layer_base.interpolator_lib
      ; Layer_ppx.ppx_version_runtime
      ; Layer_base.mina_stdlib
      ]
    ~ppx:Ppx.mina_rich ~implements:"logger"

let logger_file_system =
  library "logger.file_system" ~internal_name:"logger_file_system"
    ~path:"src/lib/logger/file_system" ~synopsis:"Logging library"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:[ core; yojson; core_kernel; logger ]
    ~ppx:Ppx.mina_rich

let logger_native =
  library "logger.native" ~internal_name:"logger_native"
    ~path:"src/lib/logger/native" ~synopsis:"Logging library"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ result
      ; core
      ; core_kernel
      ; sexplib0
      ; bin_prot_shape
      ; base_caml
      ; base_internalhash_types
      ; local "itn_logger"
      ; Layer_base.interpolator_lib
      ; Layer_ppx.ppx_version_runtime
      ; Layer_base.mina_stdlib
      ]
    ~ppx:Ppx.mina_rich ~implements:"logger"

let o1trace =
  library "o1trace" ~path:"src/lib/o1trace" ~synopsis:"Basic event tracing"
    ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_internalhash_types
      ; core
      ; core_kernel
      ; ocamlgraph
      ; ppx_inline_test_config
      ; sexplib0
      ; logger
      ]
    ~ppx:Ppx.mina

let o1trace_webkit_event =
  library "o1trace_webkit_event" ~path:"src/lib/o1trace/webkit_event"
    ~deps:
      [ base
      ; base_caml
      ; async
      ; async_kernel
      ; async_unix
      ; core
      ; core_time_stamp_counter
      ; core_kernel
      ; sexplib0
      ; Layer_base.webkit_trace_event_binary
      ; Layer_base.webkit_trace_event
      ; o1trace
      ]
    ~ppx:Ppx.standard

