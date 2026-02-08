(** Mina concurrency layer: threading, promises, and async primitives.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let run_in_thread =
  library "run_in_thread" ~path:"src/lib/concurrency/run_in_thread"
    ~deps:[ async_kernel ] ~ppx:Ppx.minimal ~virtual_modules:[ "run_in_thread" ]
    ~default_implementation:"run_in_thread.native"

let run_in_thread_native =
  library "run_in_thread.native" ~internal_name:"run_in_thread_native"
    ~path:"src/lib/concurrency/run_in_thread/native" ~deps:[ async; async_unix ]
    ~ppx:Ppx.minimal ~implements:"run_in_thread"

let run_in_thread_fake =
  library "run_in_thread.fake" ~internal_name:"run_in_thread_fake"
    ~path:"src/lib/concurrency/run_in_thread/fake" ~deps:[ async_kernel ]
    ~ppx:Ppx.minimal ~implements:"run_in_thread"

let interruptible =
  library "interruptible" ~path:"src/lib/concurrency/interruptible"
    ~synopsis:"Interruptible monad (deferreds, that can be triggered to cancel)"
    ~library_flags:[ "-linkall" ]
    ~deps:[ async_kernel; core_kernel; run_in_thread ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_std; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ] )

let promise =
  library "promise" ~path:"src/lib/concurrency/promise"
    ~deps:[ base; async_kernel ] ~ppx:Ppx.minimal ~virtual_modules:[ "promise" ]
    ~default_implementation:"promise.native"

let promise_native =
  library "promise.native" ~internal_name:"promise_native"
    ~path:"src/lib/concurrency/promise/native"
    ~deps:[ base; async_kernel; run_in_thread ]
    ~ppx:Ppx.minimal ~implements:"promise"

let promise_js =
  library "promise.js" ~internal_name:"promise_js"
    ~path:"src/lib/concurrency/promise/js" ~deps:[ base; async_kernel ]
    ~ppx:Ppx.minimal ~implements:"promise"
    ~js_of_ocaml:
      ("js_of_ocaml" @: [ "javascript_files" @: [ atom "promise.js" ] ])

let promise_js_helpers =
  library "promise.js_helpers" ~internal_name:"promise_js_helpers"
    ~path:"src/lib/concurrency/promise/js_helpers" ~deps:[ promise_js ]
    ~ppx:Ppx.minimal

let timeout_lib =
  library "timeout_lib" ~path:"src/lib/timeout_lib"
    ~deps:[ core_kernel; async_kernel; Layer_infra.logger ]
    ~ppx:Ppx.mina
