(** Product: validate_keypair — Validate Mina key pairs. *)

open Manifest
open Externals
open Dune_s_expr

let register () =
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
      ; local "cli_lib"
      ; local "mina_stdlib"
      ; local "mina_version"
      ]
    ~ppx:(Ppx.custom [ "ppx_let"; "ppx_sexp_conv"; "ppx_version" ]) ;

  ()
