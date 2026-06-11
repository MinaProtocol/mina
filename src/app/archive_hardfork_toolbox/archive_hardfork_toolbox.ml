(* berkeley_migration_verifier.ml -- verify integrity of migrated archive db from original Mina mainnet schema *)

open Async
open Cli_lib.Flag
open Archive_hardfork_toolbox_lib.Logic
module Config = Archive_hardfork_toolbox_lib.Config

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
    (let%map_open.Command { value = postgres_uri; _ } = Lazy.force Uri.Archive.postgres
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
    (let%map_open.Command { value = postgres_uri; _ } = Lazy.force Uri.Archive.postgres
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
    (let%map_open.Command { value = postgres_uri; _ } = Lazy.force Uri.Archive.postgres
     and fork_state_hash = fork_state_hash
     and fork_slot = fork_slot in

     run_check_and_exit
       (no_commands_after ~postgres_uri ~fork_state_hash ~fork_slot) )

let verify_upgrade_command =
  Async.Command.async
    ~summary:"Verify upgrade from pre-fork to post-fork schema"
    (let%map_open.Command { value = postgres_uri; _ } = Lazy.force Uri.Archive.postgres
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
    (let%map_open.Command { value = postgres_uri; _ } = Lazy.force Uri.Archive.postgres
     and fork_state_hash = fork_state_hash
     and fork_slot = fork_slot in
     run_check_and_exit
       (validate_fork ~postgres_uri ~fork_state_hash ~fork_slot) )

let convert_chain_to_canonical_command =
  Async.Command.async_or_error
    ~summary:
      "Mark the chain leading to the target block as canonical for a protocol \
       version"
    (let%map_open.Command { value = postgres_uri; _ } = Lazy.force Uri.Archive.postgres
     and latest_block_state_hash =
       Command.Param.(flag "--target-block-hash" (required string))
         ~doc:"String State hash of block that should remain canonical"
     and expected_protocol_version_str =
       Command.Param.(flag "--protocol-version" (required string))
         ~doc:
           "String Protocol version in format <transaction>.<network>.<patch>"
     and stop_at_slot =
       Command.Param.(flag "--stop-at-slot" (optional int))
         ~doc:
           "Int If provided, stops marking blocks as canonical when that's \
            older than this global slot since genesis slot"
     in
     convert_chain_to_canonical ~postgres_uri ~latest_block_state_hash
       ~expected_protocol_version_str ~stop_at_slot )

let fetch_last_filled_block_command =
  Async.Command.async ~summary:"Select last filled block"
    (let%map_open.Command { value = postgres_uri; _ } = Lazy.force Uri.Archive.postgres in
     fetch_last_filled_block ~postgres_uri )

let run_all_verifications_command =
  Async.Command.async
    ~summary:
      "Run all hardfork verifications (best chain, confirmations, \
       no-commands-after, schema upgrade, fork block). Accepts a Mina runtime \
       config providing proof.fork.* (state hash, blockchain length, global \
       slot) and an optional verify config providing latest_state_hash, \
       protocol_version, required_confirmations (default 290), \
       migration_version (default 0.0.5). Individual CLI flags override config \
       values."
    (let%map_open.Command { value = postgres_uri; _ } = Lazy.force Uri.Archive.postgres
     and runtime_config_path =
       Command.Param.(flag "--runtime-config" (required string))
         ~doc:
           "Path Mina runtime config JSON containing the proof.fork section \
            (state_hash, blockchain_length, global_slot_since_genesis)"
     and verify_config_path =
       Command.Param.(flag "--verify-config" (optional string))
         ~doc:
           "Path Optional JSON config with latest_state_hash, \
            protocol_version, required_confirmations, migration_version"
     and fork_state_hash_flag =
       Command.Param.(flag "--fork-state-hash" (optional string))
         ~doc:"String Override fork state hash from the runtime config"
     and fork_height_flag =
       Command.Param.(flag "--fork-height" (optional int))
         ~doc:"Int Override fork height from the runtime config"
     and fork_slot_flag =
       Command.Param.(flag "--fork-slot" (optional int))
         ~doc:"Int Override fork slot from the runtime config"
     and latest_state_hash_flag =
       Command.Param.(flag "--latest-state-hash" (optional string))
         ~doc:"String Hash of the latest state (overrides verify config)"
     and required_confirmations_flag =
       Command.Param.(flag "--required-confirmations" (optional int))
         ~doc:
           "Int Number of confirmations required (default 290 if not in verify \
            config)"
     and protocol_version_flag =
       Command.Param.(flag "--protocol-version" (optional string))
         ~doc:"String Protocol Version (overrides verify config)"
     and migration_version_flag =
       Command.Param.(flag "--migration-version" (optional string))
         ~doc:"String Migration Version (default 0.0.5 if not in verify config)"
     in
     fun () ->
       let fork = Config.Runtime.load runtime_config_path in
       let verify =
         Core.Option.value_map verify_config_path ~default:Config.Verify.empty
           ~f:Config.Verify.load
       in
       let fork_state_hash =
         Config.pick ~flag:fork_state_hash_flag
           ~from_config:(Some fork.state_hash) ~default:None
           ~name:"fork_state_hash"
       in
       let fork_height =
         Config.pick ~flag:fork_height_flag
           ~from_config:(Some fork.blockchain_length) ~default:None
           ~name:"fork_height"
       in
       let fork_slot =
         Config.pick ~flag:fork_slot_flag
           ~from_config:(Some fork.global_slot_since_genesis) ~default:None
           ~name:"fork_slot"
       in
       let latest_state_hash =
         Config.pick ~flag:latest_state_hash_flag
           ~from_config:verify.latest_state_hash ~default:None
           ~name:"latest_state_hash"
       in
       let required_confirmations =
         Config.pick ~flag:required_confirmations_flag
           ~from_config:verify.required_confirmations
           ~default:(Some Config.default_required_confirmations)
           ~name:"required_confirmations"
       in
       let expected_protocol_version =
         Config.pick ~flag:protocol_version_flag
           ~from_config:verify.protocol_version ~default:None
           ~name:"protocol_version"
       in
       let expected_migration_version =
         Config.pick ~flag:migration_version_flag
           ~from_config:verify.migration_version
           ~default:(Some Config.default_migration_version)
           ~name:"migration_version"
       in
       run_check_and_exit
         (run_all_verifications ~postgres_uri ~fork_state_hash ~fork_height
            ~fork_slot ~latest_state_hash ~required_confirmations
            ~expected_protocol_version ~expected_migration_version )
         () )

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
  ; ("run-all-verifications", run_all_verifications_command)
  ]

let () =
  Async_command.run
    (Async_command.group ~summary:"Archive hardfork toolbox"
       ~preserve_subcommand_order:() commands )
