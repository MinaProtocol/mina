open Executor
include Executor

let of_context context =
  Executor.of_context ~context
    ~dune_name:"src/app/berkeley_migration/berkeley_migration.exe"
    ~official_name:"mina-berkeley-migration"

let run t ~batch_size ~genesis_ledger ~source_archive_uri ~source_blocks_bucket
    ~target_archive_uri ~end_global_slot =
  let maybe_end_global_slot =
    match end_global_slot with
    | None ->
        []
    | Some end_global_slot ->
        [ "--end-global-slot"; string_of_int end_global_slot ]
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
    ; "--mainnet-blocks-bucket"
    ; source_blocks_bucket
    ]
    @ maybe_end_global_slot
  in
  run t ~args
