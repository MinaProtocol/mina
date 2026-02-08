(** Mina concurrency layer: threading, promises, and async primitives.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let register () =
  (* -- run_in_thread (virtual) ------------------------------------ *)
  library "run_in_thread" ~path:"src/lib/concurrency/run_in_thread"
    ~deps:[ async_kernel ] ~ppx:Ppx.minimal ~virtual_modules:[ "run_in_thread" ]
    ~default_implementation:"run_in_thread.native" ;

  (* -- run_in_thread.native --------------------------------------- *)
  library "run_in_thread.native" ~internal_name:"run_in_thread_native"
    ~path:"src/lib/concurrency/run_in_thread/native" ~deps:[ async; async_unix ]
    ~ppx:Ppx.minimal ~implements:"run_in_thread" ;

  (* -- run_in_thread.fake ----------------------------------------- *)
  library "run_in_thread.fake" ~internal_name:"run_in_thread_fake"
    ~path:"src/lib/concurrency/run_in_thread/fake" ~deps:[ async_kernel ]
    ~ppx:Ppx.minimal ~implements:"run_in_thread" ;

  (* -- interruptible ---------------------------------------------- *)
  library "interruptible" ~path:"src/lib/concurrency/interruptible"
    ~synopsis:"Interruptible monad (deferreds, that can be triggered to cancel)"
    ~library_flags:[ "-linkall" ]
    ~deps:[ async_kernel; core_kernel; local "run_in_thread" ]
    ~ppx:(Ppx.custom [ "ppx_deriving.std"; "ppx_jane"; "ppx_version" ]) ;

  (* -- promise (virtual) ------------------------------------------ *)
  library "promise" ~path:"src/lib/concurrency/promise"
    ~deps:[ base; async_kernel ] ~ppx:Ppx.minimal ~virtual_modules:[ "promise" ]
    ~default_implementation:"promise.native" ;

  (* -- promise.native --------------------------------------------- *)
  library "promise.native" ~internal_name:"promise_native"
    ~path:"src/lib/concurrency/promise/native"
    ~deps:[ base; async_kernel; local "run_in_thread" ]
    ~ppx:Ppx.minimal ~implements:"promise" ;

  (* -- promise.js ------------------------------------------------- *)
  library "promise.js" ~internal_name:"promise_js"
    ~path:"src/lib/concurrency/promise/js" ~deps:[ base; async_kernel ]
    ~ppx:Ppx.minimal ~implements:"promise"
    ~js_of_ocaml:
      ("js_of_ocaml" @: [ "javascript_files" @: [ atom "promise.js" ] ]) ;

  (* -- promise.js_helpers ----------------------------------------- *)
  library "promise.js_helpers" ~internal_name:"promise_js_helpers"
    ~path:"src/lib/concurrency/promise/js_helpers"
    ~deps:[ local "promise.js" ]
    ~ppx:Ppx.minimal ;

  (* -- timeout_lib ------------------------------------------------ *)
  library "timeout_lib" ~path:"src/lib/timeout_lib"
    ~deps:[ core_kernel; async_kernel; local "logger" ]
    ~ppx:Ppx.mina ;

  ()
