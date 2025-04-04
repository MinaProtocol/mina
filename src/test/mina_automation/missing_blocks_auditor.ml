(**
Module to run missing_block_auditor scripts which finds gaps in given Postgresql database
*)

module Paths = struct
  let dune_name = "src/app/missing_blocks_auditor/missing_blocks_auditor.exe"

  let official_name = "mina-missing-blocks-auditor"
end

module PathFinder = Executor.Make_PathFinder (Paths)

let path = PathFinder.standalone_path_exn
