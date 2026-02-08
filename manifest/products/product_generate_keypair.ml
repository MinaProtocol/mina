(** Product: generate_keypair — Generate Mina key pairs. *)

open Manifest
open Dune_s_expr

let register () =
  executable "mina-generate-keypair" ~internal_name:"generate_keypair"
    ~package:"generate_keypair" ~path:"src/app/generate_keypair"
    ~deps:
      [ opam "async"
      ; opam "async_unix"
      ; opam "cli_lib"
      ; opam "core_kernel"
      ; local "mina_version"
      ]
    ~modes:[ "native" ]
    ~flags:[ atom ":standard"; atom "-w"; atom "+a" ]
    ~ppx:Ppx.minimal ;

  ()
