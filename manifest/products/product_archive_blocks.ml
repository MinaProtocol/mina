(** Product: archive_blocks — Extract blocks from archive database. *)

open Manifest
open Externals

let () =
  executable "archive_blocks" ~package:"archive_blocks"
  ~path:"src/app/archive_blocks"
  ~deps:
    [ async
    ; async_command
    ; async_kernel
    ; async_unix
    ; base
    ; base_caml
    ; caqti
    ; caqti_async
    ; caqti_driver_postgresql
    ; core
    ; core_kernel
    ; result
    ; stdio
    ; uri
    ; Product_archive.archive_lib
    ; Layer_domain.genesis_constants
    ; Layer_infra.logger
    ; Layer_network.mina_block
    ; Layer_base.mina_stdlib
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_compare
       ; Ppx_lib.ppx_hash
       ; Ppx_lib.ppx_let
       ; Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_sexp_conv
       ; Ppx_lib.ppx_version
       ] )

