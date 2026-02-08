(** Product: reformat — OCaml source code reformatter. *)

open Manifest

let register () =
  executable "reformat" ~path:"src/app/reformat" ~modes:[ "native" ]
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ]
    ~ppx:(Ppx.custom [ "ppx_jane" ])
    ~no_instrumentation:true ;

  ()
