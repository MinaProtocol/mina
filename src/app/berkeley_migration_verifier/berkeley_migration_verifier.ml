(* berkeley_migration_verifier.ml -- verify integrity of migrated archive db from original Mina mainnet schema *)

open Async
open Yojson.Basic.Util
open Core
open Mina_base

module Check = struct
  type t = Ok | Error of string list

  let ok = Ok

  let err error = Error [ error ]

  let comparison_failed ~left ~right ~left_content ~right_content =
    let left_file = Filename.(concat temp_dir_name "left.json")
    and right_file = Filename.(concat temp_dir_name "right.json") in
    let%map () =
      Deferred.all_unit
        [ Writer.with_file left_file ~f:(fun w ->
              return @@ Writer.write w @@ Yojson.Safe.pretty_to_string left )
        ; Writer.with_file right_file ~f:(fun w ->
              return @@ Writer.write w @@ Yojson.Safe.pretty_to_string right )
        ]
    in
    err
    @@ sprintf
         "Discrepancies found between %s and %s. To reproduce please run `diff \
          %s %s`."
         left_content right_content left_file right_file
end

let exit_code = ref 0

module Test = struct
  type t = { check : Check.t; name : string }

  let of_check check ~name ~idx ~prefix test_count =
    { check; name = sprintf "[%d/%d] %s) %s " idx test_count prefix name }

  let print_errors error_messages =
    if List.length error_messages > 10 then (
      Async.printf " Details (truncated to only 10 errors out of %d ): \n"
        (List.length error_messages) ;
      List.iter (List.take error_messages 10) ~f:(fun error_message ->
          Async.printf " - %s\n" error_message ) )
    else (
      printf " - Details : \n" ;
      List.iter error_messages ~f:(fun error_message ->
          Async.printf "\t%s\n" error_message ) )

  let eval t =
    match t.check with
    | Ok ->
        Async.printf "%s ... ✅ \n" t.name
    | Error error_messages ->
        exit_code := !exit_code + 1 ;
        Async.printf "%s ... ❌ \n" t.name ;
        print_errors error_messages
end

let migrated_db_is_connected query_migrated_db ~height =
  let open Deferred.Let_syntax in
  let%bind canonical_blocks_count_till_height =
    query_migrated_db ~f:(fun db ->
        Sql.Berkeley.canonical_blocks_count_till_height db height )
  in
  if Int.equal canonical_blocks_count_till_height height then
    Deferred.return Check.ok
  else
    Deferred.return
      (Check.err
         (sprintf
            "Expected to have the same amount of blocks as blockchain height. \
             However got %d vs %d"
            canonical_blocks_count_till_height height ) )

let no_pending_and_orphaned_blocks_in_migrated_db query_migrated_db ~height =
  let open Deferred.Let_syntax in
  let%bind blocks_count =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.blocks_count db)
  in
  if Int.equal blocks_count height then Deferred.return Check.ok
  else
    Deferred.return
      (Check.err
         (sprintf
            "Expected to have the same amount of canonical blocks as \
             blockchain height. However got %d vs %d"
            blocks_count height ) )

let all_accounts_referred_in_commands_are_recorded migrated_pool =
  let query_migrated_db = Mina_caqti.query migrated_pool in
  let open Deferred.Let_syntax in
  let%bind left =
    query_migrated_db ~f:(fun db ->
        Sql.Berkeley.dump_user_and_internal_command_info db )
  in

  let%bind right =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.dump_accounts_accessed db)
  in
  if List.equal Sql.Accounts_accessed.equal left right then return Check.ok
  else
    Check.comparison_failed
      ~left:(Sql.Accounts_accessed.list_to_yojson left)
      ~right:(Sql.Accounts_accessed.list_to_yojson right)
      ~left_content:"Berkeley.user_and_internal_command"
      ~right_content:"Berkeley.accounts_accessed"

let accounts_created_table_is_correct migrated_pool mainnet_pool =
  let query_mainnet_db = Mina_caqti.query mainnet_pool in
  let query_migrated_db = Mina_caqti.query migrated_pool in
  let open Deferred.Let_syntax in
  let%bind left =
    query_mainnet_db ~f:(fun db -> Sql.Mainnet.dump_accounts_created db)
  in
  let%bind right =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.dump_accounts_created db)
  in
  if List.equal Sql.Accounts_created.equal left right then return Check.ok
  else
    Check.comparison_failed
      ~left:(Sql.Accounts_created.list_to_yojson left)
      ~right:(Sql.Accounts_created.list_to_yojson right)
      ~left_content:"Mainnet.accounts_created"
      ~right_content:"Berkeley.accounts_created"

let compare_hashes_till_height migrated_pool mainnet_pool ~height =
  let query_mainnet_db = Mina_caqti.query mainnet_pool in
  let query_migrated_db = Mina_caqti.query migrated_pool in
  let open Deferred.Let_syntax in
  let%bind left =
    query_mainnet_db ~f:(fun db ->
        Sql.Mainnet.dump_block_hashes_till_height db height )
  in
  let%bind right =
    query_migrated_db ~f:(fun db ->
        Sql.Berkeley.dump_block_hashes_till_height db height )
  in

  if List.equal Sql.State_hash_and_ledger_hash.equal left right then
    return Check.ok
  else
    Check.comparison_failed
      ~left:(Sql.State_hash_and_ledger_hash.list_to_yojson left)
      ~right:(Sql.State_hash_and_ledger_hash.list_to_yojson right)
      ~left_content:"Mainnet.state_hashes_and_ledger_hashes"
      ~right_content:"Berkeley.state_hashes_and_ledger_hashes"

let compare_hashes migrated_pool mainnet_pool =
  let query_mainnet_db = Mina_caqti.query mainnet_pool in
  let query_migrated_db = Mina_caqti.query migrated_pool in
  let open Deferred.Let_syntax in
  let%bind left =
    query_mainnet_db ~f:(fun db -> Sql.Mainnet.dump_block_hashes db)
  in
  let%bind right =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.dump_block_hashes db)
  in

  if List.equal Sql.State_hash_and_ledger_hash.equal left right then
    return Check.ok
  else
    Check.comparison_failed
      ~left:(Sql.State_hash_and_ledger_hash.list_to_yojson left)
      ~right:(Sql.State_hash_and_ledger_hash.list_to_yojson right)
      ~left_content:"Mainnet.state_hashes_and_ledger_hashes"
      ~right_content:"Berkeley.state_hashes_and_ledger_hashes"

let compare_user_commands_till_height migrated_pool mainnet_pool ~height =
  let query_mainnet_db = Mina_caqti.query mainnet_pool in
  let query_migrated_db = Mina_caqti.query migrated_pool in
  let open Deferred.Let_syntax in
  let%bind left =
    query_mainnet_db ~f:(fun db ->
        Sql.Mainnet.dump_user_commands_till_height db height )
  in
  let%bind right =
    query_migrated_db ~f:(fun db ->
        Sql.Berkeley.dump_user_commands_till_height db height )
  in
  if List.equal Sql.User_command.equal left right then return Check.ok
  else
    Check.comparison_failed
      ~left:(Sql.User_command.list_to_yojson left)
      ~right:(Sql.User_command.list_to_yojson right)
      ~left_content:"Mainnet.user_command"
      ~right_content:"Berkeley.user_command"

let compare_internal_commands_till_height migrated_pool mainnet_pool ~height =
  let query_mainnet_db = Mina_caqti.query mainnet_pool in
  let query_migrated_db = Mina_caqti.query migrated_pool in
  let open Deferred.Let_syntax in
  let%bind left =
    query_mainnet_db ~f:(fun db ->
        Sql.Mainnet.dump_internal_commands_till_height db height )
  in
  let%bind right =
    query_migrated_db ~f:(fun db ->
        Sql.Berkeley.dump_internal_commands_till_height db height )
  in
  if List.equal Sql.Internal_command.equal left right then return Check.ok
  else
    Check.comparison_failed
      ~left:(Sql.Internal_command.list_to_yojson left)
      ~right:(Sql.Internal_command.list_to_yojson right)
      ~left_content:"Mainnet.internal_command"
      ~right_content:"Berkeley.internal_command"

let compare_user_commands migrated_pool mainnet_pool =
  let query_mainnet_db = Mina_caqti.query mainnet_pool in
  let query_migrated_db = Mina_caqti.query migrated_pool in
  let open Deferred.Let_syntax in
  let%bind left =
    query_mainnet_db ~f:(fun db -> Sql.Mainnet.dump_user_commands db)
  in
  let%bind right =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.dump_user_commands db)
  in
  if List.equal Sql.User_command.equal left right then return Check.ok
  else
    Check.comparison_failed
      ~left:(Sql.User_command.list_to_yojson left)
      ~right:(Sql.User_command.list_to_yojson right)
      ~left_content:"Mainnet.user_command"
      ~right_content:"Berkeley.user_command"

let compare_internal_commands migrated_pool mainnet_pool =
  let query_mainnet_db = Mina_caqti.query mainnet_pool in
  let query_migrated_db = Mina_caqti.query migrated_pool in
  let open Deferred.Let_syntax in
  let%bind left =
    query_mainnet_db ~f:(fun db -> Sql.Mainnet.dump_internal_commands db)
  in
  let%bind right =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.dump_internal_commands db)
  in
  if List.equal Sql.Internal_command.equal left right then return Check.ok
  else
    Check.comparison_failed
      ~left:(Sql.Internal_command.list_to_yojson left)
      ~right:(Sql.Internal_command.list_to_yojson right)
      ~left_content:"Mainnet.internal_command"
      ~right_content:"Berkeley.internal_command"

let compare_ledger_hash ~migrated_replayer_output ~fork_genesis_config_file =
  let checkpoint_ledger_hash =
    Yojson.Basic.from_file migrated_replayer_output
    |> member "genesis_ledger" |> member "hash" |> to_string
    |> Ledger_hash.of_base58_check_exn
  in
  let fork_ledger_hash =
    Yojson.Basic.from_file fork_genesis_config_file
    |> member "ledger" |> member "hash" |> to_string
    |> Ledger_hash.of_base58_check_exn
  in
  if Ledger_hash.equal checkpoint_ledger_hash fork_ledger_hash then Check.ok
  else
    Check.err
      (sprintf
         "Ledger hash computed from checkpoint file %s is different from \
          ledger hash in fork genesis config %s"
         (Ledger_hash.to_base58_check checkpoint_ledger_hash)
         (Ledger_hash.to_base58_check fork_ledger_hash) )

let pre_fork_validations ~mainnet_archive_uri ~migrated_archive_uri () =
  Async.printf
    "Running verifications for incremental migration between '%s' and '%s' \
     schemas. It may take a couple of minutes... \n"
    mainnet_archive_uri migrated_archive_uri ;

  let mainnet_archive_uri = Uri.of_string mainnet_archive_uri in
  let migrated_archive_uri = Uri.of_string migrated_archive_uri in
  let mainnet_pool =
    Caqti_async.connect_pool ~max_size:128 mainnet_archive_uri
  in
  let migrated_pool =
    Caqti_async.connect_pool ~max_size:128 migrated_archive_uri
  in

  match (mainnet_pool, migrated_pool) with
  | Error _e, _ | _, Error _e ->
      failwithf "Connection failed to orignal and migrated schema" ()
  | Ok mainnet_pool, Ok migrated_pool ->
      let query_migrated_db = Mina_caqti.query migrated_pool in

      let%bind height =
        query_migrated_db ~f:(fun db -> Sql.Berkeley.block_height db)
      in

      let test_count = 6 in
      let%bind check = migrated_db_is_connected query_migrated_db ~height in
      Test.of_check check ~name:"Migrated blocks are connected" ~idx:1
        ~prefix:"D3.1" test_count
      |> Test.eval ;

      let%bind check =
        no_pending_and_orphaned_blocks_in_migrated_db query_migrated_db ~height
      in
      Test.of_check check ~name:"No orphaned nor pending blocks in migrated db"
        ~idx:2 ~prefix:"D3.2" test_count
      |> Test.eval ;

      let%bind check =
        all_accounts_referred_in_commands_are_recorded migrated_pool
      in
      Test.of_check check
        ~name:
          "All accounts referred in internal commands or transactions are \
           recorded in the accounts_accessed table."
        ~idx:3 ~prefix:"D3.3" test_count
      |> Test.eval ;

      let%bind check =
        compare_hashes_till_height migrated_pool mainnet_pool ~height
      in
      Test.of_check check
        ~name:"All block hashes (state_hash, ledger_hashes) are equal" ~idx:4
        ~prefix:"D3.4" test_count
      |> Test.eval ;

      let%bind check =
        compare_user_commands_till_height migrated_pool mainnet_pool ~height
      in

      Test.of_check check ~name:"Verify user commands" ~idx:5 ~prefix:"D3.5"
        test_count
      |> Test.eval ;

      let%bind check =
        compare_internal_commands_till_height migrated_pool mainnet_pool ~height
      in

      Test.of_check check ~name:"Verify internal commands" ~idx:6 ~prefix:"D3.6"
        test_count
      |> Test.eval ;

      if Int.( = ) !exit_code 0 then Deferred.Or_error.ok_unit
      else
        Deferred.Or_error.errorf
          "Some tests failed. Please refer to above output for details"

let fork_config_exn ~fork_genesis_config_file =
  Yojson.Basic.from_file fork_genesis_config_file
  |> member "proof" |> member "fork"

let fork_block_state_hash_exn ~fork_genesis_config_file =
  fork_config_exn ~fork_genesis_config_file |> member "state_hash" |> to_string

let fork_block_height_exn ~fork_genesis_config_file =
  fork_config_exn ~fork_genesis_config_file
  |> member "blockchain_length" |> to_int

let post_fork_validations ~mainnet_archive_uri ~migrated_archive_uri
    ~migrated_replayer_output ~fork_genesis_config_file () =
  Async.printf
    "Running verifications for incremental migration between '%s' and '%s' \
     schemas. It may take a couple of minutes... \n"
    mainnet_archive_uri migrated_archive_uri ;

  let fork_height = fork_block_height_exn ~fork_genesis_config_file in
  let fork_state_hash = fork_block_state_hash_exn ~fork_genesis_config_file in

  let mainnet_archive_uri = Uri.of_string mainnet_archive_uri in
  let migrated_archive_uri = Uri.of_string migrated_archive_uri in
  let mainnet_pool =
    Caqti_async.connect_pool ~max_size:128 mainnet_archive_uri
  in
  let migrated_pool =
    Caqti_async.connect_pool ~max_size:128 migrated_archive_uri
  in

  match (mainnet_pool, migrated_pool) with
  | Error _e, _ | _, Error _e ->
      failwithf "Connection failed to orignal and migrated schema" ()
  | Ok mainnet_pool, Ok migrated_pool ->
      let query_mainnet_db = Mina_caqti.query mainnet_pool in
      let query_migrated_db = Mina_caqti.query migrated_pool in

      let test_count = 8 in
      let%bind check =
        migrated_db_is_connected query_migrated_db ~height:fork_height
      in
      Test.of_check check ~name:"Migrated blocks are connected" ~idx:1
        ~prefix:"D3.2" test_count
      |> Test.eval ;

      let%bind check =
        no_pending_and_orphaned_blocks_in_migrated_db query_migrated_db
          ~height:fork_height
      in
      Test.of_check check ~name:"No orphaned nor pending blocks in migrated db"
        ~idx:2 ~prefix:"D3.3" test_count
      |> Test.eval ;

      let%bind check =
        all_accounts_referred_in_commands_are_recorded migrated_pool
      in
      Test.of_check check
        ~name:
          "All accounts referred in internal commands or transactions are \
           recorded in the accounts_accessed table."
        ~idx:3 ~prefix:"D3.4" test_count
      |> Test.eval ;

      let%bind check =
        accounts_created_table_is_correct migrated_pool mainnet_pool
      in
      Test.of_check check
        ~name:
          "The content of accounts_created table is correct (by checking \
           against pre-migrated database)"
        ~idx:4 ~prefix:"D3.5" test_count
      |> Test.eval ;
      let%bind _ =
        query_mainnet_db ~f:(fun db ->
            Sql.Mainnet.mark_chain_till_fork_block_as_canonical db
              fork_state_hash )
      in

      let%bind check = compare_hashes migrated_pool mainnet_pool in
      Test.of_check check
        ~name:"All block hashes (state_hash, ledger_hashes) are equal" ~idx:5
        ~prefix:"D3.6" test_count
      |> Test.eval ;

      let%bind check = compare_user_commands migrated_pool mainnet_pool in
      Test.of_check check ~name:"Verify user commands" ~idx:6 ~prefix:"D3.7"
        test_count
      |> Test.eval ;

      let%bind check = compare_internal_commands migrated_pool mainnet_pool in
      Test.of_check check ~name:"Verify internal commands" ~idx:7 ~prefix:"D3.8"
        test_count
      |> Test.eval ;

      let check =
        compare_ledger_hash ~migrated_replayer_output ~fork_genesis_config_file
      in
      Test.of_check check ~name:"Verify fork config vs migrated replayer output"
        ~idx:8 ~prefix:"A10.3" test_count
      |> Test.eval ;

      if Int.( = ) !exit_code 0 then Deferred.Or_error.ok_unit
      else
        Deferred.Or_error.errorf
          "Some tests failed. Please refer to above output for details"

let incremental_migration_command =
  Async.Command.async_or_error
    ~summary:"Verify migrated mainnet archive with original one"
    (let open Command.Let_syntax in
    let%map mainnet_archive_uri =
      Command.Param.flag "--mainnet-archive-uri"
        ~doc:"URI URI for connecting to the mainnet archive database"
        Command.Param.(required string)
    and migrated_archive_uri =
      Command.Param.flag "--migrated-archive-uri"
        ~doc:"URI URI for connecting to the migrated archive database"
        Command.Param.(required string)
    in
    pre_fork_validations ~mainnet_archive_uri ~migrated_archive_uri)

let post_fork_migration_command =
  Async.Command.async_or_error
    ~summary:"Verify migrated mainnet archive with original one"
    (let open Command.Let_syntax in
    let%map mainnet_archive_uri =
      Command.Param.flag "--mainnet-archive-uri"
        ~doc:"URI URI for connecting to the mainnet archive database"
        Command.Param.(required string)
    and migrated_archive_uri =
      Command.Param.flag "--migrated-archive-uri"
        ~doc:"URI URI for connecting to the migrated archive database"
        Command.Param.(required string)
    and migrated_replayer_output =
      Command.Param.flag "--migrated-replayer-output"
        ~aliases:[ "-migrated-replayer-output" ]
        Command.Param.(required string)
        ~doc:"Path Path to migrated replayer output"
    and fork_genesis_config_file =
      Command.Param.flag "--fork-genesis-config"
        ~aliases:[ "-fork-genesis-config" ]
        Command.Param.(required string)
        ~doc:"String Path to config file of the fork network"
    in

    post_fork_validations ~mainnet_archive_uri ~migrated_archive_uri
      ~migrated_replayer_output ~fork_genesis_config_file)

let commands =
  [ ("pre-fork", incremental_migration_command)
  ; ("post-fork", post_fork_migration_command)
  ]

let () =
  Async_command.run
    (Async_command.group ~summary:"Berkeley migration verifier"
       ~preserve_subcommand_order:() commands )
