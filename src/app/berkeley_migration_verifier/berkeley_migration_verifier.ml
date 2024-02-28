(* berkeley_migration_verifier.ml -- verify integrity of migrated archive db from original Mina mainnet schema *)

open Core_kernel
open Async
open Yojson.Basic.Util

module Check = struct
  type t = Ok | Error of string list

  let ok = Ok

  let err error = Error [ error ]

  let errors errors = Error errors

  let _combine checks =
    List.fold checks ~init:ok ~f:(fun acc item ->
        match (acc, item) with
        | Error e1, Error e2 ->
            errors (e1 @ e2)
        | Error e, _ ->
            errors e
        | _, Error e ->
            errors e
        | _, _ ->
            Ok )
end

let test_count = 12

let exit_code = ref 0

module Test = struct
  type t = { check : Check.t; name : string }

  let of_check check ~name ~idx ~prefix =
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

let migrated_db_is_connected query_migrated_db =
  let open Deferred.Let_syntax in
  let%bind block_height =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.block_height db)
  in
  let%bind canonical_blocks_count_till_height =
    query_migrated_db ~f:(fun db ->
        Sql.Berkeley.canonical_blocks_count_till_height db block_height )
  in
  if Int.equal canonical_blocks_count_till_height block_height then
    Deferred.return Check.ok
  else
    Deferred.return
      (Check.err
         (sprintf
            "Expected to have the same amount of blocks as blockchain height. \
             However got %d vs %d"
            canonical_blocks_count_till_height block_height ) )

let no_pending_and_orphaned_blocks_in_migrated_db query_migrated_db =
  let open Deferred.Let_syntax in
  let%bind block_height =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.block_height db)
  in
  let%bind blocks_count =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.blocks_count db)
  in
  if Int.equal blocks_count block_height then Deferred.return Check.ok
  else
    Deferred.return
      (Check.err
         (sprintf
            "Expected to have the same amount of canonical blocks as \
             blockchain height. However got %d vs %d"
            blocks_count block_height ) )

let diff_files left right =
  match%bind
    Process.run ~prog:"diff" ~args:[ left; right ] ~accept_nonzero_exit:[ 1 ] ()
  with
  | Ok output ->
      if String.is_empty output then return Check.ok
      else return (Check.err (sprintf "Discrepancies found:"))
  | Error error ->
      return
        (Check.err
           (sprintf "Internal error when comparing files, due to %s"
              (Error.to_string_hum error) ) )

let all_accounts_referred_in_commands_are_recorded query_migrated_db =
  let open Deferred.Let_syntax in
  let%bind () =
    query_migrated_db ~f:(fun db ->
        Sql.Berkeley.dump_internal_accounts_to_csv db "/tmp/accesssed1.csv" )
  in

  let%bind () =
    query_migrated_db ~f:(fun db ->
        Sql.Berkeley.dump_accounts_accessed_to_csv db "/tmp/accesssed2.csv" )
  in

  diff_files "/tmp/accesssed1.csv" "/tmp/accesssed2.csv"

let compare_hashes migrated_pool mainnet_pool =
  let query_mainnet_db = Mina_caqti.query mainnet_pool in
  let query_migrated_db = Mina_caqti.query migrated_pool in

  let open Deferred.Let_syntax in
  let%bind block_height =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.block_height db)
  in

  let%bind () =
    query_migrated_db ~f:(fun db ->
        Sql.Berkeley.dump_state_and_ledger_hashes_to_csv db
          "/tmp/state_hashes1.csv" block_height )
  in

  let%bind () =
    query_mainnet_db ~f:(fun db ->
        Sql.Mainnet.dump_state_and_ledger_hashes_to_csv db
          "/tmp/state_hashes2.csv" block_height )
  in

  diff_files "/tmp/state_hashes1.csv" "/tmp/state_hashes2.csv"

let compare_user_commands migrated_pool mainnet_pool =
  let query_mainnet_db = Mina_caqti.query mainnet_pool in
  let query_migrated_db = Mina_caqti.query migrated_pool in

  let open Deferred.Let_syntax in
  let%bind block_height =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.block_height db)
  in

  let%bind () =
    query_migrated_db ~f:(fun db ->
        Sql.Berkeley.dump_user_command_info_to_csv db
          "/tmp/user_commands_info1.csv" block_height )
  in

  let%bind () =
    query_mainnet_db ~f:(fun db ->
        Sql.Mainnet.dump_user_command_info_to_csv db
          "/tmp/user_commands_info2.csv" block_height )
  in

  diff_files "/tmp/user_commands_info1.csv" "/tmp/user_commands_info2.csv"

let compare_internal_commands migrated_pool mainnet_pool =
  let query_mainnet_db = Mina_caqti.query mainnet_pool in
  let query_migrated_db = Mina_caqti.query migrated_pool in

  let open Deferred.Let_syntax in
  let%bind block_height =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.block_height db)
  in

  let%bind () =
    query_migrated_db ~f:(fun db ->
        Sql.Berkeley.dump_internal_command_info_to_csv db
          "/tmp/internal_commands_info1.csv" block_height )
  in

  let%bind () =
    query_mainnet_db ~f:(fun db ->
        Sql.Mainnet.dump_internal_command_info_to_csv db
          "/tmp/internal_commands_info2.csv" block_height )
  in

  diff_files "/tmp/internal_commands_info1.csv"
    "/tmp/internal_commands_info2.csv"

(*
   let get_migration_end_slot_for_state_hash ~query_mainnet_db state_hash =
     let open Deferred.Let_syntax in
     let%bind maybe_slot =
       query_mainnet_db ~f:(fun db ->
           Sql.Mainnet.global_slot_since_genesis_at_state_hash db state_hash )
     in
     Deferred.return
       (Option.value_exn maybe_slot
          ~message:
            (Printf.sprintf "Cannot find slot for state hash: %s" state_hash) )


   let assert_migrated_db_has_account_accessed query_migrated_db =
     let%bind account_accessed_count =
       query_migrated_db ~f:(fun db -> Sql.Berkeley.count_account_accessed db)
     in
     if Int.( > ) account_accessed_count 0 then Deferred.return Check.ok
     else
       Deferred.return
         (Check.err
            (sprintf
               "Expected to have at least one entry in account accessed table" ) )

   let assert_all_user_and_interal_commands_account_ids_appear_in_accounts_accessed
       query_migrated_db =
     let%bind account_accessed_in_commands_count =
       query_migrated_db ~f:(fun db ->
           Sql.Berkeley.get_account_id_accessed_in_commands db )
     in
     let%bind account_accessed =
       query_migrated_db ~f:(fun db -> Sql.Berkeley.count_account_accessed db)
     in
     if Int.equal account_accessed account_accessed_in_commands_count then
       Deferred.return Check.ok
     else
       Deferred.return
         (Check.err
            (sprintf
               "Unmigrated accounts in user or internal commands found. Expected: \
                '%d' unique accounts based on commands tables but got '%d'"
               account_accessed account_accessed_in_commands_count ) )

   let compare_db_content ~mainnet_archive_uri ~migrated_archive_uri
       ~fork_state_hash () =
     printf
       "Running verifications between '%s' and '%s' schemas. It may take a couple \
        of minutes... \n"
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
         Test.of_check Check.ok ~name:"Connection to orignal and migrated schema"
           ~idx:1
         |> Test.eval ;

         let query_mainnet_db = Mina_caqti.query mainnet_pool in
         let query_migrated_db = Mina_caqti.query migrated_pool in

         let%bind end_global_slot =
           get_migration_end_slot_for_state_hash ~query_mainnet_db fork_state_hash
         in

         let%bind fork_block_height =
           query_migrated_db ~f:(fun db ->
               Sql.Mainnet.blockchain_length_for_state_hash db fork_state_hash )
         in
         let fork_block_height =
           match fork_block_height with
           | Some height ->
               height
           | None ->
               failwith
                 "Migrated data is corrupted cannot get fork block height ❌. \
                  Exiting \n"
         in
         let compare_hashes ~fetch_data_sql ~find_element_sql ~name =
           let%bind expected_hashes = query_mainnet_db ~f:fetch_data_sql in
           let%bind checks =
             Deferred.List.map expected_hashes ~f:(fun hash ->
                 let%bind element_id = find_element_sql hash in
                 if element_id |> Option.is_none then
                   return
                     (Check.err
                        (sprintf "Cannot find %s hash ('%s') in migrated database"
                           name hash ) )
                 else return Check.ok )
           in

           Deferred.return (Check.combine checks)
         in

         let%bind check =
           compare_hashes
             ~fetch_data_sql:(fun db ->
               Sql.Mainnet.user_commands_hashes db end_global_slot )
             ~find_element_sql:(fun hash ->
               query_migrated_db ~f:(fun db ->
                   Sql.Berkeley.find_user_command_id_by_hash db hash ) )
             ~name:"user_commands"
         in
         Test.of_check check ~name:"No missing user commands" ~idx:2 |> Test.eval ;

         let%bind check =
           compare_hashes
             ~fetch_data_sql:(fun db ->
               Sql.Mainnet.internal_commands_hashes db end_global_slot )
             ~find_element_sql:(fun hash ->
               query_migrated_db ~f:(fun db ->
                   Sql.Berkeley.find_internal_command_id_by_hash db hash ) )
             ~name:"internal_commands"
         in
         Test.of_check check ~name:"No missing internal commands" ~idx:3
         |> Test.eval ;

         let%bind check =
           assert_migrated_db_contains_only_canonical_blocks query_migrated_db
             fork_block_height
         in
         Test.of_check check ~name:"Only canonical blocks in migrated archive"
           ~idx:4
         |> Test.eval ;

         let%bind check =
           assert_migrated_db_has_account_accessed query_migrated_db
         in
         Test.of_check check ~name:"Account accessed sanity" ~idx:5 |> Test.eval ;

         let%bind check =
           compare_hashes
             ~fetch_data_sql:(fun db ->
               Sql.Mainnet.block_hashes_only_canonical db end_global_slot )
             ~find_element_sql:(fun hash ->
               query_migrated_db ~f:(fun db ->
                   Sql.Berkeley.find_block_by_state_hash db hash ) )
             ~name:"block_state_hashes"
         in
         Test.of_check check ~name:"No missing Blocks by state hashes" ~idx:6
         |> Test.eval ;

         let%bind check =
           assert_all_user_and_interal_commands_account_ids_appear_in_accounts_accessed
             query_migrated_db
         in
         Test.of_check check
           ~name:
             "All user and internal commands accounts appears in account accessed \
              table"
           ~idx:7
         |> Test.eval ;

         let%bind check =
           compare_hashes
             ~fetch_data_sql:(fun db ->
               Sql.Mainnet.block_parent_hashes_no_orphaned db end_global_slot )
             ~find_element_sql:(fun hash ->
               query_migrated_db ~f:(fun db ->
                   Sql.Berkeley.find_block_by_parent_hash db hash ) )
             ~name:"orphaned block"
         in
         Test.of_check check ~name:"No orphaned blocks in migrated schema" ~idx:8
         |> Test.eval ;

         let%bind check =
           compare_hashes
             ~fetch_data_sql:(fun db ->
               Sql.Mainnet.ledger_hashes_no_orphaned db end_global_slot )
             ~find_element_sql:(fun hash ->
               query_migrated_db ~f:(fun db ->
                   Sql.Berkeley.find_block_by_ledger_hash db hash ) )
             ~name:"ledger_hashes"
         in

         Test.of_check check ~name:"No orphaned ledger hashes in migrated schema"
           ~idx:9
         |> Test.eval ;

         let%bind expected_hashes =
           query_mainnet_db ~f:(fun db ->
               Sql.Common.block_state_hashes db end_global_slot )
         in
         let%bind actual_hashes =
           query_migrated_db ~f:(fun db ->
               Sql.Common.block_state_hashes db end_global_slot )
         in

         List.map expected_hashes ~f:(fun (expected_child, expected_parent) ->
             if
               List.exists actual_hashes ~f:(fun (actual_child, actual_parent) ->
                   String.equal expected_child actual_child
                   && String.equal expected_parent actual_parent )
             then Check.ok
             else
               Check.err
                 (sprintf
                    "Relation between blocks is skewed. Cannot find original \
                     subchain '%s' -> '%s' in migrated database"
                    expected_child expected_parent ) )
         |> Check.combine
         |> Test.of_check ~name:"Block relation parent -> child preserved" ~idx:10
         |> Test.eval ;
         Deferred.unit

   let get_forked_blockchain uri fork_point =
     match Caqti_async.connect_pool ~max_size:128 uri with
     | Error _ ->
         failwithf "Failed to create Caqti pools for Postgresql to %s"
           (Uri.to_string uri) ()
     | Ok pool ->
         let query_db = Mina_caqti.query pool in
         query_db ~f:(fun db ->
             Sql.Berkeley.Block_info.forked_blockchain db fork_point )

   let check_forked_chain ~migrated_archive_uri ~fork_state_hash =
     let%bind forked_blockchain =
       get_forked_blockchain (Uri.of_string migrated_archive_uri) fork_state_hash
     in

     match forked_blockchain with
     | [] ->
         Deferred.return (Check.skipped "Forked state hash does not exist")
     | [ _fork_point ] ->
         Deferred.return (Check.skipped "Forked blockchain is empty")
     | fork_point :: fork_chain ->
         Deferred.return
           ( List.mapi fork_chain ~f:(fun idx block ->
                 let idx_64 = Int64.of_int idx in
                 let protocol_version_check =
                   if Int.( <> ) block.protocol_version_id 2 then
                     Check.err
                       (sprintf
                          "block with id (%d) has unexpected protocol version"
                          block.id )
                   else Check.ok
                 in
                 let global_slot_since_hardfork_check =
                   if Int64.( = ) block.global_slot_since_hard_fork idx_64 then
                     Check.err
                       (sprintf
                          "block with id (%d) has unexpected \
                           global_slot_since_hard_fork"
                          block.id )
                   else Check.ok
                 in
                 let global_slot_since_genesis_check =
                   if
                     Int64.( > ) block.global_slot_since_genesis
                       (Int64.( + ) fork_point.global_slot_since_genesis
                          (Int64.( + ) idx_64 Int64.one) )
                   then
                     Check.err
                       (sprintf
                          "block with id (%d) has unexpected \
                           global_slot_since_genesis"
                          block.id )
                   else Check.ok
                 in
                 let block_height_check =
                   if Int.( > ) block.height (fork_point.height + idx + 1) then
                     Check.err
                       (sprintf
                          "block with id (%d) has unexpected \
                           global_slot_since_genesis"
                          block.id )
                   else Check.ok
                 in

                 Check.combine
                   [ protocol_version_check
                   ; global_slot_since_genesis_check
                   ; global_slot_since_hardfork_check
                   ; block_height_check
                   ] )
           |> Check.combine )

   let compare_migrated_replayer_output ~migrated_replayer_output ~fork_config_file
       =
     let compare_script_download_uri =
       "https://raw.githubusercontent.com/MinaProtocol/mina/berkeley/scripts/compare-replayer-and-fork-config.sh"
     in
     let%bind tmpd = Async.Unix.mkdtemp "berkeley_migration_verifier_output" in
     let compare_script_name = "compare_fork_and_replayer_script.sh" in
     let compare_script = Filename.concat tmpd compare_script_name in

     let%bind result =
       Process.run ~prog:"wget"
         ~args:[ compare_script_download_uri; "-O"; compare_script ]
         ()
     in
     let download_check =
       match result with
       | Error exn ->
           Check.err
             (sprintf "Internal error: Cannot download compare script, due to '%s'"
                (Error.to_string_hum exn) )
       | Ok _ ->
           Check.ok
     in
     let%bind result =
       Process.run ~prog:"chmod" ~args:[ "755"; compare_script ] ()
     in
     let update_perms_check =
       match result with
       | Error exn ->
           Check.err
             (sprintf "Internal error: Cannot download compare script, due to '%s'"
                (Error.to_string_hum exn) )
       | Ok _ ->
           Check.ok
     in
     let%bind result =
       Process.run ~prog:"cp"
         ~args:[ migrated_replayer_output; fork_config_file; tmpd ]
         ()
     in
     let copy_files =
       match result with
       | Error exn ->
           Check.err
             (sprintf
                "Internal error: Cannot copy files to temp directory, due to '%s'"
                (Error.to_string_hum exn) )
       | Ok _ ->
           Check.ok
     in
     let%bind result =
       Process.run
         ~prog:(String.concat ~sep:"/" [ "."; compare_script_name ])
         ~args:[ migrated_replayer_output; fork_config_file ]
         ~working_dir:tmpd ~accept_nonzero_exit:[ 1 ] ()
     in
     let run_check =
       match result with
       | Ok output ->
           if String.is_empty output then Check.ok
           else (
             Out_channel.write_all (Filename.concat tmpd "diff.out") ~data:output ;
             Check.err
               (sprintf
                  "Discrepances found between fork config and replayer files. \
                   Please refer to '%s' folder for more details"
                  tmpd ) )
       | Error exn ->
           Check.err
             (sprintf "Exception while comparing files: %s..."
                (Error.to_string_hum exn) )
     in
     Deferred.return
       (Check.combine
          [ download_check; update_perms_check; copy_files; run_check ] )
*)

let pre_fork_validations ~mainnet_archive_uri ~migrated_archive_uri () =
  printf
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
      let _query_mainnet_db = Mina_caqti.query mainnet_pool in
      let query_migrated_db = Mina_caqti.query migrated_pool in

      let%bind check = migrated_db_is_connected query_migrated_db in
      Test.of_check check ~name:"Migrated blocks are connected" ~idx:1
        ~prefix:"D3.1"
      |> Test.eval ;

      let%bind check =
        no_pending_and_orphaned_blocks_in_migrated_db query_migrated_db
      in
      Test.of_check check ~name:"No orphaned nor pending blocks in migrated db"
        ~idx:2 ~prefix:"D3.2"
      |> Test.eval ;

      let%bind check =
        all_accounts_referred_in_commands_are_recorded query_migrated_db
      in
      Test.of_check check
        ~name:
          "All accounts referred in internal commands or transactions are \
           recorded in the accounts_accessed table."
        ~idx:3 ~prefix:"D3.3"
      |> Test.eval ;

      let%bind check = compare_hashes migrated_pool mainnet_pool in
      Test.of_check check
        ~name:
          "All hashes (state_hash in blocks,internal_commands,user_commands \
           and ledger_hashes) are equal"
        ~idx:4 ~prefix:"D3.4"
      |> Test.eval ;

      let%bind check = compare_user_commands migrated_pool mainnet_pool in
      Test.of_check check ~name:"Verify user commands" ~idx:5 ~prefix:"D3.5"
      |> Test.eval ;

      let%bind check = compare_internal_commands migrated_pool mainnet_pool in
      Test.of_check check ~name:"Verify internal commands" ~idx:6 ~prefix:"D3.6"
      |> Test.eval ;

      Deferred.Or_error.ok_unit

let post_fork_validations ~_mainnet_archive_uri ~_migrated_archive_uri
    ~_migrated_replayer_output ~_fork_config_file () =
  Deferred.Or_error.ok_unit
(*
let main ~mainnet_archive_uri ~migrated_archive_uri ~migrated_replayer_output
    ~fork_config_file () =
  let fork_config =
    match
      Yojson.Safe.from_file fork_config_file |> Runtime_config.of_yojson
    with
    | Ok fork_config ->
        fork_config
    | Error err ->
        failwithf "Cannot parse fork config '%s' due to : '%s'" fork_config_file
          err ()
  in
  let fork_state_hash =
    match fork_config.proof with
    | Some proof -> (
        match proof.fork with
        | Some fork ->
            fork.state_hash
        | None ->
            failwithf
              "Cannot parse fork config: Missing fork element under proof  in \
               fork config '%s' "
              fork_config_file () )
    | None ->
        failwithf
          "Cannot parse fork config: missing proof element in fork config '%s' "
          fork_config_file ()
  in
  let%bind _ =
    compare_db_content ~mainnet_archive_uri ~migrated_archive_uri
      ~fork_state_hash ()
  in
  let%bind forked_chain_check =
    check_forked_chain ~migrated_archive_uri ~fork_state_hash
  in
  Test.of_check forked_chain_check ~name:"Forked chain" ~idx:11 |> Test.eval ;
  let%bind fork_comparision =
    compare_migrated_replayer_output ~migrated_replayer_output ~fork_config_file
  in
  Test.of_check fork_comparision ~name:"Fork config" ~idx:12 |> Test.eval ;
  if Int.equal !exit_code 1 then
    Deferred.Or_error.error_string
      (sprintf
         "\n ❌ %d checks failed. Please refer to output above for more details"
         !exit_code )
  else Deferred.Or_error.ok_unit

*)

let incremental_migration_command =
  Command.async_or_error
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
  Command.async_or_error
    ~summary:"Verifye migrated mainnet archive with original one"
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
    and fork_config_file =
      Command.Param.flag "--fork-config-file" ~aliases:[ "-fork-config-file" ]
        Command.Param.(required string)
        ~doc:"String Path to fork config file"
    in

    post_fork_validations ~_mainnet_archive_uri:mainnet_archive_uri
      ~_migrated_archive_uri:migrated_archive_uri
      ~_migrated_replayer_output:migrated_replayer_output
      ~_fork_config_file:fork_config_file)

let commands =
  [ ("incremental", incremental_migration_command)
  ; ("post-fork", post_fork_migration_command)
  ]

let () =
  Async_command.run
    (Async_command.group ~summary:"Berkeley migration verifier"
       ~preserve_subcommand_order:() commands )
