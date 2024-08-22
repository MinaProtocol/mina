open Executor
open Core
include Executor

let of_context context =
  Executor.of_context ~context
    ~dune_name:"src/app/archive_blocks/archive_blocks.exe"
    ~official_name:"/usr/local/bin/mina-archive-blocks"

type format = Precomputed | Extensional

let format_to_string format =
  match format with
  | Precomputed ->
      "precomputed"
  | Extensional ->
      "extensional"

let run t ~blocks ~archive_uri ?(format = Precomputed) =
  run t
    ~args:
      ([ "--archive-uri"; archive_uri; "--" ^ format_to_string format ] @ blocks)
    ()
