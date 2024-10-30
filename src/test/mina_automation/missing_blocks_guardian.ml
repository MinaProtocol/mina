(**
Module to run missing_block_guardian app which should fill any gaps in given archive database
*)

open Executor
open Core
include Executor

module Config = struct
  type mode = Audit | Run

  type t =
    { archive_uri : Uri.t
    ; precomputed_blocks : Uri.t
    ; network : string
    ; run_mode : mode
    ; missing_blocks_auditor : string
    ; archive_blocks : string
    ; block_format : Archive_blocks.format
    }

  let to_args t =
    match t.run_mode with Audit -> [ "audit" ] | Run -> [ "single-run" ]

  let to_envs t =
    let path = Uri.path t.archive_uri in
    let path_no_leading_slash =
      String.sub path ~pos:1 ~len:(String.length path - 1)
    in

    `Extend
      [ ("MINA_NETWORK", t.network)
      ; ("PRECOMPUTED_BLOCKS_URL", Uri.to_string t.precomputed_blocks)
      ; ("DB_USERNAME", Option.value_exn (Uri.user t.archive_uri))
      ; ("DB_HOST", Uri.host_with_default ~default:"localhost" t.archive_uri)
      ; ("DB_PORT", Int.to_string (Option.value_exn (Uri.port t.archive_uri)))
      ; ("DB_NAME", path_no_leading_slash)
      ; ("PGPASSWORD", Option.value_exn (Uri.password t.archive_uri))
      ; ("BLOCKS_FORMAT", Archive_blocks.format_to_string t.block_format)
      ; ("MISSING_BLOCKS_AUDITOR", t.missing_blocks_auditor)
      ; ("ARCHIVE_BLOCKS", t.archive_blocks)
      ]
end

let of_context context =
  Executor.of_context ~context
    ~dune_name:"scripts/archive/missing-blocks-guardian.sh"
    ~official_name:"mina-missing-blocks-guardian"

let run t ~config =
  run t ~args:(Config.to_args config) ~env:(Config.to_envs config) ()
