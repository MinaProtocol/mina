open Executor
open Core
include Executor

module Config = struct
  
  type range = AllBlocks | Range of (String.t * String.t)
  
  type t = {
    archive_uri:  String.t
    ; range: range
  }

  let to_args t = 
    let blocks =   match t.range with 
      | AllBlocks -> ["--all-blocks"]
      | Range (start_hash , end_hash ) -> ["--start-hash"; start_hash; "--end-hash"; end_hash]
    in
    ["--archive-uri"; t.archive_uri] @ blocks

end


let of_context context =
  Executor.of_context ~context
    ~dune_name:"src/app/extract_blocks/extract_blocks.exe"
    ~official_name:"mina-extract-blocks"

let run t ~config =
  run t ~args:(Config.to_args config)
