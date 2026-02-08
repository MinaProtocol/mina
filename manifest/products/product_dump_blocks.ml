(** Product: dump_blocks — Dump blocks from transition frontier. *)

open Manifest
open Externals

let register () =
  executable "dump_blocks" ~path:"src/app/dump_blocks" ~modes:[ "native" ]
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; core
      ; core_kernel
      ; core_unix_command_unix
      ; ppx_inline_test_runner_lib
      ; sexplib0
      ; yojson
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
