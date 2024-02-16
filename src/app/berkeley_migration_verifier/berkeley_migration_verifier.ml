(* berkeley_migration_verifier.ml -- verify integrity of migrated archive db from original Mina mainnet schema *)

open Core_kernel
open Async
open Yojson.Basic.Util

module ReplayerOutput = struct
  type t =
    { target_epoch_ledgers_state_hash : string
    ; target_fork_state_hash : string
    ; target_genesis_ledger : Runtime_config.Ledger.t
    ; target_epoch_data : Runtime_config.Epoch_data.t option
    }
  [@@deriving yojson]

  let of_json_file_exn file =
    Yojson.Safe.from_file file |> of_yojson |> Result.ok_or_failwith
end

let exit_code = ref 0

let get_migration_end_slot_for_state_hash ~query_mainnet_db state_hash =
  let open Deferred.Let_syntax in
  let%bind maybe_slot =
    query_mainnet_db ~f:(fun db ->
        Sql.Mainnet.global_slot_since_genesis_at_state_hash db state_hash )
  in
  Deferred.return
    (Option.value_exn maybe_slot
       ~message:
         (Printf.sprintf "Cannot find slot has for state hash: %s" state_hash) )

let assert_migrated_db_contains_only_canonical_blocks query_migrated_db =
  let%bind pending_blocks =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.count_orphaned_blocks db)
  in
  let%bind orphaned_blocks =
    query_migrated_db ~f:(fun db -> Sql.Berkeley.count_pending_blocks db)
  in
  match orphaned_blocks + pending_blocks with
  | 0 ->
      Deferred.return None
  | _ ->
      Deferred.return
        (Some
           (sprintf
              "Expected to have at only canonical block while having %d \
               orphaned and %d pending"
              orphaned_blocks pending_blocks ) )

let printout_errors_or_success error_messages ~check_name =
  let print_errors error_messages =
    if List.length error_messages > 10 then (
      Async.printf " - Details (truncated to only 10 errors): " ;
      List.iter (List.take error_messages 10) ~f:(fun error_message ->
          printf "\t%s\n" error_message ) )
    else printf " - Details : " ;
    List.iter error_messages ~f:(fun error_message ->
        printf "\t%s\n" error_message )
  in
  if List.length error_messages > 1 then (
    exit_code := !exit_code + 1 ;
    printf "%s check ... ❌ \n" check_name ;
    print_errors error_messages )
  else printf "%s check ... ✅ \n" check_name

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
      failwith " Failed to create Caqti pools for Postgresql ❌. Exiting \n"
  | Ok mainnet_pool, Ok migrated_pool ->
      printf "[1/9] Connection to orignal and migrated schema succesful ✅ \n" ;

      let query_mainnet_db = Mina_caqti.query mainnet_pool in
      let query_migrated_db = Mina_caqti.query migrated_pool in
      let%bind end_global_slot =
        get_migration_end_slot_for_state_hash ~query_mainnet_db fork_state_hash
      in
      let compare_hashes ~fetch_data_sql ~find_element_sql ~name =
        let%bind expected_hashes = query_mainnet_db ~f:fetch_data_sql in
        Deferred.List.filter_map expected_hashes ~f:(fun hash ->
            let%bind element_id = find_element_sql hash in
            if element_id |> Option.is_none then
              return
                (Some
                   (sprintf "Cannot find %s hash ('%s') in migrated database"
                      name hash ) )
            else return None )
      in

      let%bind error_messages =
        compare_hashes
          ~fetch_data_sql:(fun db ->
            Sql.Mainnet.user_commands_hashes db end_global_slot )
          ~find_element_sql:(fun hash ->
            query_migrated_db ~f:(fun db ->
                Sql.Berkeley.find_user_command_id_by_hash db hash ) )
          ~name:"user_commands"
      in
      printout_errors_or_success error_messages
        ~check_name:"[2/9] No missing user commands" ;

      let%bind error_messages =
        compare_hashes
          ~fetch_data_sql:(fun db ->
            Sql.Mainnet.internal_commands_hashes db end_global_slot )
          ~find_element_sql:(fun hash ->
            query_migrated_db ~f:(fun db ->
                Sql.Berkeley.find_internal_command_id_by_hash db hash ) )
          ~name:"internal_commands"
      in
      printout_errors_or_success error_messages
        ~check_name:"[3/9] No missing internal commands" ;
      let%bind error_message =
        assert_migrated_db_contains_only_canonical_blocks query_migrated_db
      in
      printout_errors_or_success
        (List.filter_map [ error_message ] ~f:(fun x -> x))
        ~check_name:"[4/9] Only canonical blocks in migrated archive" ;
      let%bind error_messages =
        compare_hashes
          ~fetch_data_sql:(fun db ->
            Sql.Mainnet.block_hashes_only_canonical db end_global_slot )
          ~find_element_sql:(fun hash ->
            query_migrated_db ~f:(fun db ->
                Sql.Berkeley.find_block_by_state_hash db hash ) )
          ~name:"block_state_hashes"
      in
      printout_errors_or_success error_messages
        ~check_name:"[5/9] No missing block state hashes " ;
      let%bind _ =
        compare_hashes
          ~fetch_data_sql:(fun db ->
            Sql.Mainnet.block_parent_hashes_no_orphaned db end_global_slot )
          ~find_element_sql:(fun hash ->
            query_migrated_db ~f:(fun db ->
                Sql.Berkeley.find_block_by_parent_hash db hash ) )
          ~name:"orphaned block"
      in
      printout_errors_or_success error_messages
        ~check_name:"[6/9] No orphaned blocks in migrated schema" ;
      let%bind _ =
        compare_hashes
          ~fetch_data_sql:(fun db ->
            Sql.Mainnet.ledger_hashes_no_orphaned db end_global_slot )
          ~find_element_sql:(fun hash ->
            query_migrated_db ~f:(fun db ->
                Sql.Berkeley.find_block_by_ledger_hash db hash ) )
          ~name:"ledger_hashes"
      in
      printout_errors_or_success error_messages
        ~check_name:"[7/9] No orphaned ledger hashes in migrated schema" ;
      let%bind expected_hashes =
        query_mainnet_db ~f:(fun db ->
            Sql.Common.block_state_hashes db end_global_slot )
      in
      let%bind actual_hashes =
        query_migrated_db ~f:(fun db ->
            Sql.Common.block_state_hashes db end_global_slot )
      in
      let error_messages =
        List.filter_map expected_hashes
          ~f:(fun (expected_child, expected_parent) ->
            if
              List.exists actual_hashes ~f:(fun (actual_child, actual_parent) ->
                  String.equal expected_child actual_child
                  && String.equal expected_parent actual_parent )
            then None
            else
              Some
                (sprintf
                   "Relation between blocks is skewed. Cannot find original \
                    subchain '%s' -> '%s' in migrated database"
                   expected_child expected_parent ) )
      in
      printout_errors_or_success error_messages
        ~check_name:"[8/9] Block relation parent -> child preserved" ;
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
      Async.printf
        "[9/9] Fork state hash does not exist. Skipping check ... ⚠️ \n" ;
      Deferred.unit
  | [ _fork_point ] ->
      Async.printf "[9/9] Forked blockchain is empty. Skipping check ... ⚠️ \n" ;
      Deferred.unit
  | fork_point :: fork_chain ->
      List.mapi fork_chain ~f:(fun idx block ->
          let idx_64 = Int64.of_int idx in
          let protocol_version_check =
            if Int.( <> ) block.protocol_version_id 2 then
              Some
                (sprintf "block with id (%d) has unexpected protocol version"
                   block.id )
            else None
          in
          let global_slot_since_hardfork_check =
            if Int64.( = ) block.global_slot_since_hard_fork idx_64 then
              Some
                (sprintf
                   "block with id (%d) has unexpected \
                    global_slot_since_hard_fork"
                   block.id )
            else None
          in
          let global_slot_since_genesis_check =
            if
              Int64.( > ) block.global_slot_since_genesis
                (Int64.( + ) fork_point.global_slot_since_genesis
                   (Int64.( + ) idx_64 Int64.one) )
            then
              Some
                (sprintf
                   "block with id (%d) has unexpected global_slot_since_genesis"
                   block.id )
            else None
          in
          let block_height_check =
            if Int.( > ) block.height (fork_point.height + idx + 1) then
              Some
                (sprintf
                   "block with id (%d) has unexpected global_slot_since_genesis"
                   block.id )
            else None
          in

          List.filter_map
            [ protocol_version_check
            ; global_slot_since_genesis_check
            ; global_slot_since_hardfork_check
            ; block_height_check
            ] ~f:(fun check -> check) )
      |> List.join
      |> printout_errors_or_success ~check_name:"[2/9] Consistency of new fork" ;
      Deferred.unit

  let compare_replayer_outputs expected actual ~compare_receipt_chain_hashes =
    let expected_output = ReplayerOutput.of_json_file_exn expected in
    let actual_output = ReplayerOutput.of_json_file_exn actual in

    let get_accounts (output : ReplayerOutput.t) file =
      match output.target_genesis_ledger.base with
      | Named _ ->
          failwithf "%s file does not have any account" file ()
      | Accounts accounts ->
          accounts
      | Hash _ ->
          failwithf "%s file does not have any account" file ()
    in

    let expected_accounts = get_accounts expected_output expected in
    let actual_accounts = get_accounts actual_output actual in

    List.iter expected_accounts ~f:(fun expected_account ->
        let get_value_or_none option = Option.value option ~default:"None" in
        let compare_balances (actual_account : Runtime_config.Accounts.Single.t)
            (expected_account : Runtime_config.Accounts.Single.t) =
          if
            Currency.Balance.( = ) expected_account.balance
              actual_account.balance
          then ()
          else
            failwithf
              "Incorrect balance for account %s when comparing replayer \
               outputs expected:(%s) vs actual(%s)"
              expected_account.pk expected actual ()
        in
        let compare_receipt (actual_account : Runtime_config.Accounts.Single.t)
            (expected_account : Runtime_config.Accounts.Single.t) =
          let expected_receipt_chain_hash =
            get_value_or_none expected_account.receipt_chain_hash
          in
          let actual_account_receipt_chain_hash =
            get_value_or_none actual_account.receipt_chain_hash
          in
          if
            String.( = ) expected_receipt_chain_hash
              actual_account_receipt_chain_hash
          then ()
          else
            failwithf
              "Incorrect receipt chain hash for account %s when comparing \
               replayer outputs expected:(%s) vs actual(%s)"
              expected_account.pk expected_receipt_chain_hash
              actual_account_receipt_chain_hash ()
        in
        let compare_delegation
            (actual_account : Runtime_config.Accounts.Single.t)
            (expected_account : Runtime_config.Accounts.Single.t) =
          let expected_delegation =
            get_value_or_none expected_account.delegate
          in
          let actual_delegation = get_value_or_none actual_account.delegate in
          if String.( = ) expected_delegation actual_delegation then ()
          else
            failwithf
              "Incorrect delegation for account %s when comparing replayer \
               outputs expected:(%s) vs actual(%s)"
              expected_account.pk expected_delegation actual_delegation ()
        in

        match
          List.find actual_accounts ~f:(fun actual_account ->
              String.( = ) expected_account.pk actual_account.pk )
        with
        | Some actual_account ->
            compare_balances actual_account expected_account ;
            if compare_receipt_chain_hashes then
              compare_receipt actual_account expected_account ;
            compare_delegation actual_account expected_account
        | None ->
            failwithf
              "Cannot find account in actual file %s when comparing replayer \
               outputs expected:(%s) vs actual(%s)"
              expected_account.pk expected actual () )

let main ~mainnet_archive_uri ~migrated_archive_uri ~fork_state_hash () =
  let%bind _ =
    compare_db_content ~mainnet_archive_uri ~migrated_archive_uri
      ~fork_state_hash ()
  in
  let%bind _ = check_forked_chain ~migrated_archive_uri ~fork_state_hash in
  if Int.equal !exit_code 1 then
    Deferred.Or_error.error_string
      (sprintf
         "\n ❌ %d checks failed. Please refer to output above for more details"
         !exit_code )
  else Deferred.Or_error.ok_unit

let () =
  Async_command.(
    run
      (let open Let_syntax in
      Async_command.async_or_error
        ~summary:"Verifye migrated mainnet archive with original one"
        (let%map mainnet_archive_uri =
           Param.flag "--mainnet-archive-uri"
             ~doc:"URI URI for connecting to the mainnet archive database"
             Param.(required string)
         and migrated_archive_uri =
           Param.flag "--migrated-archive-uri"
             ~doc:"URI URI for connecting to the migrated archive database"
             Param.(required string)
         and fork_state_hash =
           Param.flag "--fork-state-hash" ~aliases:[ "-fork-state-hash" ]
             Param.(required string)
             ~doc:"String state hash of the fork for the migration"
         and migrated_replayer_output =
          Param.flag "--migrated-replayer-output" ~aliases:[ "-migrated-replayer-output" ]
            Param.(required string)
            ~doc:"Path Path to migrated replayer output"
         and mainnet_replayer_output =
           Param.flag "--mainnet-replayer-output" ~aliases:[ "-mainnet-replayer-output" ]
             Param.(required string)
             ~doc:"String Path to mainnet replayer output"
         in

         main ~mainnet_archive_uri ~migrated_archive_uri ~fork_state_hash ~migrated_replayer_output ~mainnet_replayer_output )))
