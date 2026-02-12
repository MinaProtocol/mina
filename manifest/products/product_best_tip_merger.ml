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
      ; base_caml
      ; base_internalhash_types
      ; core
      ; core_kernel
      ; lib
      ; ppx_deriving_yojson_runtime
      ; result
      ; sexplib0
      ; stdio
      ; yojson
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.visualization
      ; Layer_consensus.consensus
      ; Layer_consensus.mina_state
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_kimchi.kimchi_pasta
      ; Layer_logging.logger
      ; Layer_logging.logger_file_system
      ; Layer_network.transition_frontier
      ; Layer_network.transition_frontier_extensions
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; local "cli_lib"
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
