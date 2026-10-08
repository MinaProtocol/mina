(**
Module to run the missing_blocks_guardian app, which reports the gaps in a
given archive database and fills them from a block source. Use [run] with
[run_mode = Audit] to audit only.
*)

open Async
open Core

module Config = struct
  type mode = Audit | Run

  type t =
    { archive_uri : Uri.t
    ; precomputed_blocks : Uri.t
    ; network : string
    ; run_mode : mode
    ; block_format : [ `Precomputed | `Extensional ]
    ; min_height : int option
          (** Lowest height the guardian may fetch. Set it when the archive
              under test does not reach back to a genesis or hard-fork block,
              so that the walk stops there instead of asking for blocks that
              cannot exist. *)
    }

  let block_format_to_string = function
    | `Precomputed ->
        "precomputed"
    | `Extensional ->
        "extensional"

  (* The app also reads the DB_*, PRECOMPUTED_BLOCKS_URL and MINA_NETWORK
     environment variables, but flags are unambiguous and do not leak into
     other processes started by the test. *)
  let to_args t =
    let subcommand =
      match t.run_mode with Audit -> "audit" | Run -> "single-run"
    in
    [ subcommand
    ; "--archive-uri"
    ; Uri.to_string t.archive_uri
    ; "--precomputed-blocks-url"
    ; Uri.to_string t.precomputed_blocks
    ; "--network"
    ; t.network
    ; "--block-format"
    ; block_format_to_string t.block_format
    ]
    @
    match t.min_height with
    | None ->
        []
    | Some height ->
        [ "--min-height"; Int.to_string height ]
end

module Paths = struct
  let dune_name = "src/app/missing_blocks_guardian/missing_blocks_guardian.exe"

  let official_name = "mina-missing-blocks-guardian"
end

module Executor = Executor.Make (Paths)

type t = Executor.t

let default = Executor.default

let run t ~config = Executor.run t ~args:(Config.to_args config) ()

(** What one guardian run produced. [audit] exits 1 on an unhealthy archive,
    and a repair that refuses a bad download exits non-zero on purpose, so a
    test needs the code as well as the output. *)
type outcome = Utils.process_outcome =
  { exit_code : int; stdout : string; stderr : string }

let run_capturing t ~config =
  let%bind _prog, process =
    Executor.run_in_background t ~args:(Config.to_args config) ()
  in
  Utils.collect_outcome process
