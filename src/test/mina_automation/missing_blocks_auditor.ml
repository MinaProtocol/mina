open Async
open Core

(**
Module to run missing_block_auditor scripts which finds gaps in given Postgresql database
*)

module Paths = struct
  let dune_name = "src/app/missing_blocks_auditor/missing_blocks_auditor.exe"

  let official_name = "mina-missing-blocks-auditor"
end

module PathFinder = Executor.Make_PathFinder (Paths)

let path =
  Deferred.map PathFinder.standalone_path ~f:(fun opt ->
      Option.value_exn opt
        ~message:
          "Could not find standalone path. App is not executable outside the \
           dune" )
