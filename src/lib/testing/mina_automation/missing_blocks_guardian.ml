(**
Module to run missing_block_guardian app which should fill any gaps in given archive database
*)

open Core

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

  let to_args t =
    let archive =
      [ "--archive-uri"
      ; Uri.to_string t.archive_uri
      ; "--missing-blocks-auditor"
      ; t.missing_blocks_auditor
      ]
    in
    match t.run_mode with
    | Audit ->
        "audit" :: archive
    | Run ->
        ("single-run" :: archive)
        @ [ "--precomputed-blocks-url"
          ; Uri.to_string t.precomputed_blocks
          ; "--network"
          ; t.network
          ; "--block-format"
          ; ( match t.block_format with
            | `Precomputed ->
                "precomputed"
            | `Extensional ->
                "extensional" )
          ; "--archive-blocks"
          ; t.archive_blocks
          ]
end

module Paths = struct
  let dune_name = "src/app/missing_blocks_guardian/missing_blocks_guardian.exe"

  let official_name = "mina-missing-blocks-guardian"
end

module Executor = Executor.Make (Paths)

type t = Executor.t

let default = Executor.default

let run t ~config = Executor.run t ~args:(Config.to_args config) ()
