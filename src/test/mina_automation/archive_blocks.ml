open Executor
open Core
include Executor

let of_context context =
  Executor.of_context ~context
    ~dune_name:"src/app/archive_blocks/archive_blocks.exe"
    ~official_name:"mina-archive-blocks"

let run t ~blocks ~archive_uri =
  run t ~args:([ "--archive-uri"; archive_uri; "-precomputed" ] @ blocks)
