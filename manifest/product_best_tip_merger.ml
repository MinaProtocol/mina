(** Product: best_tip_merger — Merge best tips from multiple nodes. *)

open Manifest

let register () =
  executable "best_tip_merger" ~package:"best_tip_merger"
    ~path:"src/app/best_tip_merger" ~modes:[ "native" ]
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "lib"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; opam "sexplib0"
      ; opam "stdio"
      ; opam "yojson"
      ; local "cli_lib"
      ; local "consensus"
      ; local "data_hash_lib"
      ; local "kimchi_pasta"
      ; local "logger"
      ; local "logger.file_system"
      ; local "mina_base"
      ; local "mina_numbers"
      ; local "mina_state"
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "snark_params"
      ; local "transition_frontier"
      ; local "transition_frontier_extensions"
      ; local "visualization"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_deriving.show"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  ()
