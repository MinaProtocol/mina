(** Product: dump_blocks — Dump blocks from transition frontier. *)

open Manifest

let register () =
  executable "dump_blocks" ~path:"src/app/dump_blocks" ~modes:[ "native" ]
    ~deps:
      [ opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "core_unix.command_unix"
      ; opam "ppx_inline_test.runner.lib"
      ; opam "sexplib0"
      ; opam "yojson"
      ; local "block_time"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_block"
      ; local "mina_state"
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ; local "precomputed_values"
      ; local "transition_frontier"
      ; local "transition_frontier_base"
      ; local "transition_frontier_full_frontier"
      ]
    ~ppx:(Ppx.custom [ "ppx_custom_printf"; "ppx_let"; "ppx_version" ]) ;

  ()
