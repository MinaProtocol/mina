(**
Module to run missing_block_auditor scripts which finds gaps in given Postgresql database
*)

open Executor
include Executor

let of_context context =
  Executor.of_context ~context
    ~dune_name:"src/app/missing_blocks_auditor/missing_blocks_auditor.exe"
    ~official_name:"mina-missing-blocks-auditor"
