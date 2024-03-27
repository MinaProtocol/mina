open Executor
include Executor

let of_context context =
  Executor.of_context ~context
    ~dune_name:
      "src/app/berkeley_migration_verifier/berkeley_migration_verifier.exe"
    ~official_name:"mina-berkeley-migration-verifier"

let run t ~source_archive_uri ~target_archive_uri
    ~(migrated_replayer_output : string option)
    ~(fork_config_path : string option) =
  let args =
    match (migrated_replayer_output, fork_config_path) with
    | Some migrated_replayer_output, Some fork_config_path ->
        [ "post-fork"
        ; "--mainnet-archive-uri"
        ; source_archive_uri
        ; "--migrated-archive-uri"
        ; target_archive_uri
        ; "--fork-config-file"
        ; fork_config_path
        ; "--migrated-replayer-output"
        ; migrated_replayer_output
        ]
    | Some _, None ->
        failwith
          "migrated replayer output file provided but no fork config file path \
           provided. Can't determine which mode you want to user (pre-fork or \
           post-fork"
    | None, Some _ ->
        failwith
          "fork config file defined but no migrated replayer output file \
           provided. Can't determine which mode you want to user (pre-fork or \
           post-fork"
    | None, None ->
        [ "pre-fork"
        ; "--mainnet-archive-uri"
        ; source_archive_uri
        ; "--migrated-archive-uri"
        ; target_archive_uri
        ]
  in

  run t ~args
