(** Product: reformat — OCaml source code reformatter. *)

open Manifest
open Externals

let () =
  executable "reformat" ~path:"src/app/reformat" ~modes:[ "native" ]
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; async_unix
      ; core
      ; core_kernel
      ; sexplib0
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane ])
    ~no_instrumentation:true
