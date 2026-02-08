(** Product: logproc — Mina log processor. *)

open Manifest
open Externals

let register () =
  executable "logproc" ~path:"src/app/logproc" ~modules:[ "logproc" ]
    ~deps:
      [ cmdliner
      ; core
      ; core_kernel
      ; ppx_deriving_yojson_runtime
      ; result
      ; stdio
      ; yojson
      ; local "interpolator_lib"
      ; local "logger"
      ; local "logproc_lib"
      ; local "mina_stdlib"
      ]
    ~ppx:(Ppx.custom [ "ppx_deriving.std"; "ppx_jane"; "ppx_version" ]) ;

  ()
