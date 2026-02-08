(** Product: missing_blocks_auditor — Audit archive for missing blocks. *)

open Manifest
open Externals

let () =
  executable "missing_blocks_auditor" ~package:"missing_blocks_auditor"
    ~path:"src/app/missing_blocks_auditor"
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; async_unix
      ; base
      ; caqti
      ; caqti_async
      ; caqti_driver_postgresql
      ; core
      ; core_kernel
      ; uri
      ; Layer_base.mina_stdlib
      ; Layer_logging.logger
      ; local "mina_caqti"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_let; Ppx_lib.ppx_mina; Ppx_lib.ppx_version ])
