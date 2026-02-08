(** Product: delegation_verify — Verify delegation proofs. *)

open Manifest

let register () =
  private_executable "delegation_verify" ~path:"src/app/delegation_verify"
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "base.caml"
      ; opam "base64"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "hex"
      ; opam "integers"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "sexplib"
      ; opam "sexplib0"
      ; opam "stdio"
      ; opam "yojson"
      ; local "blockchain_snark"
      ; local "consensus"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "genesis_constants"
      ; local "genesis_ledger_helper"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "ledger_proof"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_block"
      ; local "mina_numbers"
      ; local "mina_runtime_config"
      ; local "mina_state"
      ; local "mina_wire_types"
      ; local "pasta_bindings"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "precomputed_values"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "transaction_snark"
      ; local "uptime_service"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_custom_printf"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  ()
