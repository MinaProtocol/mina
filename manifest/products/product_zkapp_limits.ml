(** Product: zkapp_limits — Display zkApp limits. *)

open Manifest
open Externals

let register () =
  executable "zkapp_limits" ~package:"zkapp_limits" ~path:"src/app/zkapp_limits"
    ~deps:
      [ base
      ; base_caml
      ; core_kernel
      ; local "genesis_constants"
      ; local "mina_base"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_custom_printf"
         ; "ppx_hash"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] ) ;

  ()
