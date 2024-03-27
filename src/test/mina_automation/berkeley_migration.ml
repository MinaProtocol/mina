open Executor
include Executor

let of_context context =
  Executor.of_context ~context
    ~dune_name:"src/app/berkeley_migration/berkeley_migration.exe"
    ~official_name:"mina-berkeley-migration"

let run t ~batch_size ~genesis_ledger ~source_archive_uri ~source_blocks_bucket
    ~target_archive_uri ~network ~(fork_block_hash : string option) =
  let fork_block_hash_arg =
    match fork_block_hash with
    | Some fork_block_hash ->
        [ "--fork-state-hash"; fork_block_hash ]
    | None ->
        []
  in

  let args =
    [ "--batch-size"
    ; string_of_int batch_size
    ; "--config-file"
    ; genesis_ledger
    ; "--mainnet-archive-uri"
    ; source_archive_uri
    ; "--migrated-archive-uri"
    ; target_archive_uri
    ; "--blocks-bucket"
    ; source_blocks_bucket
    ; "--network"
    ; network
    ]
    @ fork_block_hash_arg
  in

  run t ~args
