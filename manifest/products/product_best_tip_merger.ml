(** Product: best_tip_merger — Merge best tips from multiple nodes. *)

open Manifest
open Externals

let () =
  executable "best_tip_merger" ~package:"best_tip_merger"
  ~path:"src/app/best_tip_merger" ~modes:[ "native" ]
  ~deps:
    [ async
    ; async_command
    ; async_kernel
    ; async_unix
    ; base_internalhash_types
    ; base_caml
    ; core
    ; core_kernel
    ; lib
    ; ppx_deriving_yojson_runtime
    ; result
    ; sexplib0
    ; stdio
    ; yojson
    ; local "cli_lib"
    ; Layer_consensus.consensus
    ; Layer_domain.data_hash_lib
    ; Layer_crypto.kimchi_pasta
    ; Layer_infra.logger
    ; Layer_infra.logger_file_system
    ; Layer_base.mina_base
    ; Layer_infra.mina_numbers
    ; Layer_consensus.mina_state
    ; Layer_base.mina_stdlib
    ; Layer_base.mina_wire_types
    ; Layer_crypto.pickles
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.snark_params
    ; Layer_network.transition_frontier
    ; Layer_network.transition_frontier_extensions
    ; Layer_base.visualization
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_compare
       ; Ppx_lib.ppx_deriving_show
       ; Ppx_lib.ppx_deriving_yojson
       ; Ppx_lib.ppx_jane
       ; Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_version
       ] )

