(** Product: validate_keypair — Validate Mina key pairs. *)

open Manifest
open Externals
open Dune_s_expr

let () =
  executable "validate_keypair" ~package:"validate_keypair"
    ~path:"src/app/validate_keypair" ~modes:[ "native" ]
    ~flags:
      [ atom "-short-paths"
      ; atom "-w"
      ; atom "@a-4-29-40-41-42-44-45-48-58-59-60"
      ]
    ~deps:
      [ async
      ; async_unix
      ; core_kernel
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_version
      ; local "cli_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_let; Ppx_lib.ppx_sexp_conv; Ppx_lib.ppx_version ] )
