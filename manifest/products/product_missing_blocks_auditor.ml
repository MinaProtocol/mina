(** Product: missing_blocks_auditor — Audit archive for missing blocks. *)

open Manifest

let register () =
  executable "missing_blocks_auditor" ~package:"missing_blocks_auditor"
    ~path:"src/app/missing_blocks_auditor"
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "caqti"
      ; opam "caqti-async"
      ; opam "caqti-driver-postgresql"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "uri"
      ; local "logger"
      ; local "mina_caqti"
      ; local "mina_stdlib"
      ]
    ~ppx:(Ppx.custom [ "ppx_let"; "ppx_mina"; "ppx_version" ]) ;

  ()
