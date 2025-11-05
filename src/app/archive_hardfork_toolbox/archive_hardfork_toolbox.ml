(* berkeley_migration_verifier.ml -- verify integrity of migrated archive db from original Mina mainnet schema *)

open Async
open Cli_lib.Flag
open Logic

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

let convert_chain_to_canonical_command =
  Async.Command.async_or_error
    ~summary:
      "Mark the chain leading to the target block as canonical for a protocol \
       version"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and target_block_hash =
       Command.Param.(flag "--target-block-hash" (required string))
         ~doc:"String State hash of block that should remain canonical"
     and protocol_version_str =
       Command.Param.(flag "--protocol-version" (required string))
         ~doc:
           "String Protocol version in format <transaction>.<network>.<patch>"
     and stop_at_slot =
       Command.Param.(flag "--stop-at-slot" (optional int))
         ~doc:
           "Int If provided, stops marking blocks as canonical when this \
            global slot since genesis is reached"
     in
     convert_chain_to_canonical ~postgres_uri ~target_block_hash
       ~protocol_version_str ~stop_at_slot )

let fetch_last_filled_block_command =
  Async.Command.async ~summary:"Select last filled block"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres in
     Logic.fetch_last_filled_block ~postgres_uri )

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
  ; ("convert-chain-to-canonical", convert_chain_to_canonical_command)
  ]

let () =
  Async_command.run
    (Async_command.group ~summary:"Archive hardfork toolbox"
       ~preserve_subcommand_order:() commands )
