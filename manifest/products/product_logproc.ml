(** Product: logproc — Mina log processor. *)

open Manifest
open Externals

let () =
  executable "logproc" ~path:"src/app/logproc" ~modules:[ "logproc" ]
    ~deps:
      [ cmdliner
      ; core
      ; core_kernel
      ; ppx_deriving_yojson_runtime
      ; result
      ; stdio
      ; yojson
      ; Layer_base.interpolator_lib
      ; Layer_base.logproc_lib
      ; Layer_base.mina_stdlib
      ; Layer_logging.logger
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_std; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ] )
