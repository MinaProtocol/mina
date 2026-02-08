(** Product: archive_blocks — Extract blocks from archive database. *)

open Manifest
open Externals

let register () =
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
      ; local "archive_lib"
      ; local "genesis_constants"
      ; local "logger"
      ; local "mina_block"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_hash"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] ) ;

  ()
