(** Product: dump_blocks — Dump blocks from transition frontier. *)

open Manifest
open Externals

let () =
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
      ; Layer_base.mina_base
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_domain.block_time
      ; Layer_logging.logger
      ; Layer_network.mina_block
      ; Layer_network.transition_frontier
      ; Layer_network.transition_frontier_base
      ; Layer_network.transition_frontier_full_frontier
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_custom_printf; Ppx_lib.ppx_let; Ppx_lib.ppx_version ] )
