(** Product: zkapp_limits — Display zkApp limits. *)

open Manifest
open Externals

let () =
  executable "zkapp_limits" ~package:"zkapp_limits" ~path:"src/app/zkapp_limits"
  ~deps:
    [ base
    ; base_caml
    ; core_kernel
    ; Layer_domain.genesis_constants
    ; Layer_base.mina_base
    ; Layer_base.mina_stdlib
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_compare
       ; Ppx_lib.ppx_custom_printf
       ; Ppx_lib.ppx_hash
       ; Ppx_lib.ppx_let
       ; Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_sexp_conv
       ; Ppx_lib.ppx_version
       ] )

