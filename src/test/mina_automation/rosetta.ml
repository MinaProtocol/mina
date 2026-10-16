(**
Module to run a Rosetta API server over an archive database and a daemon.
*)

open Core
open Async

module Config = struct
  type t =
    { archive_uri : Uri.t
    ; graphql_uri : Uri.t
    ; port : int
    ; log_level : string option
    ; max_db_pool_size : int
          (** MINA_ROSETTA_MAX_DB_POOL_SIZE; rosetta does not start without
              it *)
    }

  let create ?log_level ?(max_db_pool_size = 80) ~archive_uri ~graphql_uri ~port
      () =
    { archive_uri; graphql_uri; port; log_level; max_db_pool_size }

  let to_args t =
    [ "--archive-uri"
    ; Uri.to_string t.archive_uri
    ; "--graphql-uri"
    ; Uri.to_string t.graphql_uri
    ; "--port"
    ; Int.to_string t.port
    ]
    @ Option.value_map t.log_level ~default:[] ~f:(fun level ->
          [ "--log-level"; level ] )

  let to_env t =
    `Extend
      [ ("MINA_ROSETTA_MAX_DB_POOL_SIZE", Int.to_string t.max_db_pool_size) ]

  let uri t = Uri.make ~scheme:"http" ~host:"127.0.0.1" ~port:t.port ()
end

module Paths = struct
  let dune_name = "src/app/rosetta/rosetta.exe"

  let official_name = "mina-rosetta"
end

module Executor = Executor.Make (Paths)

type t = { config : Config.t; executor : Executor.t }

let of_config config = { config; executor = Executor.AutoDetect }

module Process = struct
  type t = { process : Process.t; config : Config.t }

  let uri t = Config.uri t.config
end

(** [start t] starts rosetta in the background. It answers once it has
    connected to the archive; callers poll [/network/status] for that. *)
let start t =
  let%map _, process =
    Executor.run_in_background t.executor ~args:(Config.to_args t.config)
      ~env:(Config.to_env t.config) ()
  in
  Process.{ process; config = t.config }
