(**
Module to run missing_block_guardian app which should fill any gaps in given archive database
*)

open Core

module Config = struct
  (** [Daemon] keeps checking, sleeping [interval] between checks. *)
  type mode = Audit | Run | Daemon of { interval : Time.Span.t }

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
    match t.run_mode with
    | Audit ->
        [ "audit" ]
    | Run ->
        [ "single-run" ]
    | Daemon _ ->
        [ "daemon" ]

  let to_envs t =
    let path = Uri.path t.archive_uri in
    let path_no_leading_slash =
      String.sub path ~pos:1 ~len:(String.length path - 1)
    in

    `Extend
      ( [ ("MINA_NETWORK", t.network)
        ; ("PRECOMPUTED_BLOCKS_URL", Uri.to_string t.precomputed_blocks)
        ; ("DB_USERNAME", Option.value_exn (Uri.user t.archive_uri))
        ; ("DB_HOST", Uri.host_with_default ~default:"localhost" t.archive_uri)
        ; ("DB_PORT", Int.to_string (Option.value_exn (Uri.port t.archive_uri)))
        ; ("DB_NAME", path_no_leading_slash)
        ; ("PGPASSWORD", Option.value_exn (Uri.password t.archive_uri))
        ; ( "BLOCKS_FORMAT"
          , match t.block_format with
            | `Precomputed ->
                "precomputed"
            | `Extensional ->
                "extensional" )
        ; ("MISSING_BLOCKS_AUDITOR", t.missing_blocks_auditor)
        ; ("ARCHIVE_BLOCKS", t.archive_blocks)
        ]
      @
      match t.run_mode with
      | Daemon { interval } ->
          [ ( "TIMEOUT"
            , Int.to_string (Time.Span.to_sec interval |> Int.of_float) )
          ]
      | Audit | Run ->
          [] )
end

module Paths = struct
  let dune_name = "scripts/archive/missing-blocks-guardian.sh"

  let official_name = "mina-missing-blocks-guardian"
end

module Executor = Executor.Make (Paths)

type t = Executor.t

let default = Executor.default

let run t ~config =
  Executor.run t ~args:(Config.to_args config) ~env:(Config.to_envs config) ()

(** [run_in_background t ~config] starts the guardian, typically in [Daemon]
    mode, and returns its process. *)
let run_in_background t ~config =
  let open Async in
  let%map _, process =
    Executor.run_in_background t ~args:(Config.to_args config)
      ~env:(Config.to_envs config) ()
  in
  process
