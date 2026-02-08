(** Product: missing_blocks_auditor — Audit archive for missing blocks. *)

open Manifest
open Externals

let register () =
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
      ; local "logger"
      ; local "mina_caqti"
      ; local "mina_stdlib"
      ]
    ~ppx:(Ppx.custom [ "ppx_let"; "ppx_mina"; "ppx_version" ]) ;

  ()
