(** Product: generate_keypair — Generate Mina key pairs. *)

open Manifest
open Externals
open Dune_s_expr

let () =
  executable "mina-generate-keypair" ~internal_name:"generate_keypair"
    ~package:"generate_keypair" ~path:"src/app/generate_keypair"
    ~deps:[ async; async_unix; cli_lib; core_kernel; Layer_base.mina_version ]
    ~modes:[ "native" ]
    ~flags:[ atom ":standard"; atom "-w"; atom "+a" ]
    ~ppx:Ppx.minimal
