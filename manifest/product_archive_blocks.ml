(** Product: archive_blocks — Extract blocks from archive database. *)

open Manifest

let register () =
  executable "archive_blocks" ~package:"archive_blocks"
    ~path:"src/app/archive_blocks"
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "base.caml"
      ; opam "caqti"
      ; opam "caqti-async"
      ; opam "caqti-driver-postgresql"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "result"
      ; opam "stdio"
      ; opam "uri"
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
