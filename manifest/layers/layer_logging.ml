(** Mina logging libraries: structured logging, tracing, and log context.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let structured_log_events =
  library "structured_log_events" ~path:"src/lib/structured_log_events"
    ~synopsis:"Events, logging and parsing" ~library_flags:[ "-linkall" ]
    ~deps:[ core_kernel; sexplib0; yojson; Layer_base.interpolator_lib ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_inline_test
         ] )
    ~inline_tests:true

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
      [ async_kernel
      ; base_internalhash_types
      ; core_kernel
      ; logger
      ; sexplib0
      ]
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
      [ base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core_kernel
      ; result
      ; sexplib0
      ; Layer_base.interpolator_lib
      ; Layer_base.mina_stdlib
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:Ppx.mina_rich ~implements:"logger"

let logger_file_system =
  library "logger.file_system" ~internal_name:"logger_file_system"
    ~path:"src/lib/logger/file_system" ~synopsis:"Logging library"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:[ core; core_kernel; logger; yojson ]
    ~ppx:Ppx.mina_rich

let logger_native =
  library "logger.native" ~internal_name:"logger_native"
    ~path:"src/lib/logger/native" ~synopsis:"Logging library"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; result
      ; sexplib0
      ; Layer_base.interpolator_lib
      ; Layer_base.mina_stdlib
      ; Layer_ppx.ppx_version_runtime
      ; local "itn_logger"
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
      ; logger
      ; ocamlgraph
      ; ppx_inline_test_config
      ; sexplib0
      ]
    ~ppx:Ppx.mina

let o1trace_webkit_event =
  library "o1trace_webkit_event" ~path:"src/lib/o1trace/webkit_event"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; core
      ; core_kernel
      ; core_time_stamp_counter
      ; o1trace
      ; sexplib0
      ; Layer_base.webkit_trace_event
      ; Layer_base.webkit_trace_event_binary
      ]
    ~ppx:Ppx.standard

