open Executor
include Executor

let of_context context =
  Executor.of_context ~context
    ~dune_name:"src/app/missing_blocks_auditor/missing_blocks_auditor.exe"
    ~official_name:"/usr/local/bin/mina-missing-blocks-auditor"
