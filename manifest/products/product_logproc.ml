(** Product: logproc — Mina log processor. *)

open Manifest

let register () =
  executable "logproc" ~path:"src/app/logproc" ~modules:[ "logproc" ]
    ~deps:
      [ opam "cmdliner"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; opam "stdio"
      ; opam "yojson"
      ; local "interpolator_lib"
      ; local "logger"
      ; local "logproc_lib"
      ; local "mina_stdlib"
      ]
    ~ppx:(Ppx.custom [ "ppx_deriving.std"; "ppx_jane"; "ppx_version" ]) ;

  ()
