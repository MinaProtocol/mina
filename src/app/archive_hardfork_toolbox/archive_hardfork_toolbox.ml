(* berkeley_migration_verifier.ml -- verify integrity of migrated archive db from original Mina mainnet schema *)

open Async
open Cli_lib.Flag
open Logic

let run_check_and_exit check_fn () =
  let open Deferred.Let_syntax in
  let%bind results = check_fn () in
  report_all_checks results ;
  if has_failures results then Shutdown.exit 1 else Deferred.return ()

let is_in_best_chain_command =
  Async.Command.async ~summary:"Verify fork block is in best chain"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and fork_state_hash =
       Command.Param.flag "--fork-state-hash"
         Command.Param.(required string)
         ~doc:"String Hash of the fork state"
     and fork_height =
       Command.Param.flag "--fork-height"
         Command.Param.(required int)
         ~doc:"Int Height of the fork block"
     and fork_slot =
       Command.Param.flag "--fork-slot"
         Command.Param.(required int)
         ~doc:"Int64 Global slot since genesis of the fork block"
     in

     run_check_and_exit
       (is_in_best_chain ~postgres_uri ~fork_state_hash ~fork_height ~fork_slot)
    )

let confirmations_command =
  Async.Command.async
    ~summary:"Verify number of confirmations for the fork block"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and latest_state_hash =
       Command.Param.flag "--latest-state-hash"
         Command.Param.(required string)
         ~doc:"String Hash of the latest state"
     and fork_slot =
       Command.Param.flag "--fork-slot"
         Command.Param.(required int)
         ~doc:"Int64 Global slot since genesis of the fork block"
     and required_confirmations =
       Command.Param.flag "--required-confirmations"
         Command.Param.(required int)
         ~doc:"Int Number of confirmations required for the fork block"
     in

     run_check_and_exit
       (confirmations_check ~postgres_uri ~latest_state_hash
          ~required_confirmations ~fork_slot ) )

let no_commands_after_command =
  Async.Command.async ~summary:"Verify no commands after the fork block"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and fork_state_hash =
       Command.Param.flag "--fork-state-hash"
         Command.Param.(required string)
         ~doc:"String Hash of the fork state"
     and fork_slot =
       Command.Param.flag "--fork-slot"
         Command.Param.(required int)
         ~doc:"Int64 Global slot since genesis of the fork block"
     in

     run_check_and_exit
       (no_commands_after ~postgres_uri ~fork_state_hash ~fork_slot) )

let verify_upgrade_command =
  Async.Command.async
    ~summary:"Verify upgrade from pre-fork to post-fork schema"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and version =
       Command.Param.flag "--version"
         Command.Param.(required string)
         ~doc:"String Version to upgrade to (e.g. 3.2.0 etc)"
     in
     run_check_and_exit (verify_upgrade ~postgres_uri ~version) )

let validate_fork_command =
  Async.Command.async ~summary:"Validate fork block and its ancestors"
    (let%map_open.Command { value = postgres_uri; _ } = Uri.Archive.postgres
     and fork_state_hash =
       Command.Param.flag "--fork-state-hash"
         Command.Param.(required string)
         ~doc:"String Hash of the fork state"
     and fork_slot =
       Command.Param.flag "--fork-slot"
         Command.Param.(required int)
         ~doc:"Int64 Global slot since genesis of the fork block"
     in
     run_check_and_exit
       (validate_fork ~postgres_uri ~fork_state_hash ~fork_slot) )

(* TODO: consider refactor these commands to reuse queries in the future. *)
let commands =
  [ ( "fork-candidate"
    , Async_command.group ~summary:"Pre-fork verifications"
        ~preserve_subcommand_order:()
        [ ("is-in-best-chain", is_in_best_chain_command)
        ; ("confirmations", confirmations_command)
        ; ("no-commands-after", no_commands_after_command)
        ] )
  ; ("verify-upgrade", verify_upgrade_command)
  ; ("validate-fork", validate_fork_command)
  ]

let () =
  Async_command.run
    (Async_command.group ~summary:"Archive hardfork toolbox"
       ~preserve_subcommand_order:() commands )
