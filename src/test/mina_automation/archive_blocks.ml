(**
Module to run archive_blocks utility for the given list of block files and an archive PostgreSQL database.
*)

open Core

module Paths = struct
  let dune_name = "src/app/archive_blocks/archive_blocks.exe"

  let official_name = "mina-archive-blocks"
end

module Executor = Executor.Make (Paths)

type t = Executor.t

let default = Executor.default

type format = Precomputed | Extensional

let path = Executor.PathFinder.standalone_path_exn Paths.official_name

let format_to_string format =
  match format with
  | Precomputed ->
      "precomputed"
  | Extensional ->
      "extensional"

let run t ~blocks ~archive_uri ?(format = Precomputed) =
  Executor.run t
    ~args:
      ([ "--archive-uri"; archive_uri; "--" ^ format_to_string format ] @ blocks)
    ()
