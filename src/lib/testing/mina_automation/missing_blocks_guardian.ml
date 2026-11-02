(**
Module to run missing_block_guardian app which should fill any gaps in given archive database
*)

open Core

(* The environment variables that the guardian reads. *)
module Env_var = struct
  let mina_network = "MINA_NETWORK"

  let precomputed_blocks_url = "PRECOMPUTED_BLOCKS_URL"

  let db_username = "DB_USERNAME"

  let db_host = "DB_HOST"

  let db_port = "DB_PORT"

  let db_name = "DB_NAME"

  let pgpassword = "PGPASSWORD"

  let blocks_format = "BLOCKS_FORMAT"

  let missing_blocks_auditor = "MISSING_BLOCKS_AUDITOR"

  let archive_blocks = "ARCHIVE_BLOCKS"
end

module Config = struct
  type mode = Audit | Run

  type t =
    { archive_uri : Uri.t
    ; precomputed_blocks : Uri.t
    ; network : string
    ; run_mode : mode
    ; missing_blocks_auditor : string
    ; archive_blocks : string
    ; block_format : [ `Precomputed | `Extensional ]
    }

  (* [Audit] passes its settings as flags. [Run] passes them as the environment
     variables that the deployments use, so that CI covers both ways. *)
  let to_args t =
    match t.run_mode with
    | Audit ->
        [ "audit"
        ; "--archive-uri"
        ; Uri.to_string t.archive_uri
        ; "--missing-blocks-auditor"
        ; t.missing_blocks_auditor
        ]
    | Run ->
        [ "single-run" ]

  let to_envs t =
    match t.run_mode with
    | Audit ->
        None
    | Run ->
        let path = Uri.path t.archive_uri in
        let path_no_leading_slash =
          String.sub path ~pos:1 ~len:(String.length path - 1)
        in
        Some
          (`Extend
            [ (Env_var.mina_network, t.network)
            ; ( Env_var.precomputed_blocks_url
              , Uri.to_string t.precomputed_blocks )
            ; (Env_var.db_username, Option.value_exn (Uri.user t.archive_uri))
            ; ( Env_var.db_host
              , Uri.host_with_default ~default:"localhost" t.archive_uri )
            ; ( Env_var.db_port
              , Int.to_string (Option.value_exn (Uri.port t.archive_uri)) )
            ; (Env_var.db_name, path_no_leading_slash)
            ; (Env_var.pgpassword, Option.value_exn (Uri.password t.archive_uri))
            ; ( Env_var.blocks_format
              , match t.block_format with
                | `Precomputed ->
                    "precomputed"
                | `Extensional ->
                    "extensional" )
            ; (Env_var.missing_blocks_auditor, t.missing_blocks_auditor)
            ; (Env_var.archive_blocks, t.archive_blocks)
            ] )
end

module Paths = struct
  let dune_name = "src/app/missing_blocks_guardian/missing_blocks_guardian.exe"

  let official_name = "mina-missing-blocks-guardian"
end

module Executor = Executor.Make (Paths)

type t = Executor.t

let default = Executor.default

let run t ~config =
  Executor.run t ~args:(Config.to_args config) ?env:(Config.to_envs config) ()
