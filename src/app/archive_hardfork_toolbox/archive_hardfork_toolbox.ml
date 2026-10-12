(* berkeley_migration_verifier.ml -- verify integrity of migrated archive db from original Mina mainnet schema *)

open Async
open Cli_lib.Flag
open Archive_hardfork_toolbox_lib.Logic

let run_check_and_exit check_fn () =
  let%bind results = check_fn () in
  report_all_checks results ;
  if has_failures results then Shutdown.exit 1 else Deferred.return ()

let fork_state_hash =
  Command.Param.(
    flag "--fork-state-hash" (required string)
      ~doc:"String Hash of the fork state")

let fork_slot =
  Command.Param.(
    flag "--fork-slot" (required int)
      ~doc:"Int64 Global slot since genesis of the fork block")

let is_in_best_chain_command =
  Async.Command.async ~summary:"Verify fork block is in best chain"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and fork_state_hash = fork_state_hash
     and fork_height =
       Command.Param.(flag "--fork-height" (required int))
         ~doc:"Int Height of the fork block"
     and fork_slot = fork_slot in

     run_check_and_exit
       (is_in_best_chain ~postgres_uri ~fork_state_hash ~fork_height ~fork_slot)
    )

let confirmations_command =
  Async.Command.async
    ~summary:"Verify number of confirmations for the fork block"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and latest_state_hash =
       Command.Param.(flag "--latest-state-hash" (required string))
         ~doc:"String Hash of the latest state"
     and fork_slot = fork_slot
     and required_confirmations =
       Command.Param.(flag "--required-confirmations" (required int))
         ~doc:"Int Number of confirmations required for the fork block"
     in

     run_check_and_exit
       (confirmations_check ~postgres_uri ~latest_state_hash
          ~required_confirmations ~fork_slot ) )

let no_commands_after_command =
  Async.Command.async ~summary:"Verify no commands after the fork block"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and fork_state_hash = fork_state_hash
     and fork_slot = fork_slot in

     run_check_and_exit
       (no_commands_after ~postgres_uri ~fork_state_hash ~fork_slot) )

let verify_upgrade_command =
  Async.Command.async
    ~summary:"Verify upgrade from pre-fork to post-fork schema"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and expected_protocol_version =
       Command.Param.(flag "--protocol-version" (required string))
         ~doc:"String Protocol Version to upgrade to (e.g. 3.2.0 etc)"
     and expected_migration_version =
       Command.Param.(flag "--migration-version" (required string))
         ~doc:"String Migration Version that generates current schema"
     in
     run_check_and_exit
       (verify_upgrade ~postgres_uri ~expected_protocol_version
          ~expected_migration_version ) )

let validate_fork_command =
  Async.Command.async ~summary:"Validate fork block and its ancestors"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and fork_state_hash = fork_state_hash
     and fork_slot = fork_slot in
     run_check_and_exit
       (validate_fork ~postgres_uri ~fork_state_hash ~fork_slot) )

let settle_pending_blocks_command =
  Async.Command.async_or_error
    ~summary:
      "Settle the pending blocks a hard fork leaves: the chain to the fork \
       block becomes canonical, the rest of the ended chain and the pending \
       blocks at decided heights are orphaned. The archive does the same when \
       it adds a fork genesis; this repairs an archive that did not."
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and fork_genesis_hash =
       Command.Param.(flag "--fork-genesis-hash" (optional string))
         ~doc:"String State hash of the fork genesis (default: the newest)"
     and dry_run =
       Command.Param.(flag "--dry-run" no_arg)
         ~doc:"Report what would change, then roll back"
     in
     fun () ->
       let%map.Deferred.Or_error result =
         settle_pending_blocks ~postgres_uri ?fork_genesis_hash ~dry_run ()
       in
       print_endline
         (Yojson.Safe.to_string
            (`Assoc
              [ ("dry_run", `Bool dry_run)
              ; ("result", Archive_lib.Settle_pending_blocks.to_yojson result)
              ] ) ) )

let fetch_last_filled_block_command =
  Async.Command.async ~summary:"Select last filled block"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres in
     fetch_last_filled_block ~postgres_uri )

let populate_genesis_accounts_command =
  Async.Command.async
    ~summary:
      "Populate accounts_accessed for the genesis block (including a fork \
       genesis) from the runtime config's genesis ledger. Repairs a hardfork \
       archive whose fork genesis block is missing its ledger accounts."
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and runtime_config_file =
       Command.Param.(flag "--config-file" (required string))
         ~doc:"PATH runtime config file containing the (fork) genesis ledger"
     and chunks_length =
       Command.Param.(flag "--chunks-length" (optional_with_default 100 int))
         ~doc:
           "Int number of accounts to insert per transaction, to avoid \
            Postgres OOM on large ledgers (default 100)"
     in
     populate_genesis_accounts ~postgres_uri ~runtime_config_file ~chunks_length
    )

(* TODO: consider refactor these commands to reuse queries in the future. *)
let commands =
  [ ( "fork-candidate"
    , Async_command.group ~summary:"Pre-fork verifications"
        ~preserve_subcommand_order:()
        [ ("is-in-best-chain", is_in_best_chain_command)
        ; ("confirmations", confirmations_command)
        ; ("no-commands-after", no_commands_after_command)
        ; ("last-filled-block", fetch_last_filled_block_command)
        ] )
  ; ("verify-upgrade", verify_upgrade_command)
  ; ("validate-fork", validate_fork_command)
  ; ("settle-pending-blocks", settle_pending_blocks_command)
  ; ("populate-genesis-accounts", populate_genesis_accounts_command)
  ]

let () =
  Async_command.run
    (Async_command.group ~summary:"Archive hardfork toolbox"
       ~preserve_subcommand_order:() commands )
