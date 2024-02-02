open Async
open Integration_test_lib
open Core
open Settings
open Yojson.Basic.Util
open Mina_automation

module HardForkSteps = struct
  type t =
    { env : Settings.t
    ; working_dir : string
    ; docker_api : Docker.Client.t
    ; test_name : string
    }

  let create (env : Settings.t) working_dir test_name =
    { env; working_dir; docker_api = Docker.Client.default; test_name }

  let run_context t : Executor.context =
    match t.env.executor with Dune -> Dune | Bash -> Debian

  let unpack_random_data archive output =
    Unix.mkdir output ;
    Utils.untar ~archive ~output

  let to_connection t =
    Psql.Credentials
      { Psql.Credentials.user = Some t.env.db.user
      ; password = t.env.db.password
      ; host = Some t.env.db.host
      ; port = Some t.env.db.port
      ; db = None
      }

  let create_random_output_db t =
    let open Deferred.Let_syntax in
    let%bind db_name =
      Psql.create_new_random_archive ~connection:(to_connection t)
        ~prefix:t.test_name ~script:t.env.paths.create_schema_script
    in
    Deferred.return (Settings.connection_str_to t.env db_name)

  let create_random_mainnet_db t =
    let open Deferred.Let_syntax in
    let%bind db_name =
      Psql.create_random_mainnet_db ~connection:(to_connection t)
        ~prefix:t.test_name ~working_dir:t.working_dir
    in
    Deferred.return (Settings.connection_str_to t.env db_name)

  let perform_berkeley_migration t ~batch_size ~genesis_ledger
      ~source_archive_uri ~source_blocks_bucket ~target_archive_uri
      ~end_global_slot =
    Berkeley_migration.of_context (run_context t)
    |> Berkeley_migration.run ~batch_size ~genesis_ledger ~source_archive_uri
         ~source_blocks_bucket ~target_archive_uri ~end_global_slot

  let run_migration_replayer t ~archive_uri ~input_config ~interval_checkpoint
      ~output_ledger =
    Replayer.of_context (run_context t)
    |> Replayer.run ~archive_uri ~input_config ~interval_checkpoint
         ~output_ledger ~migration_mode:true
         ~checkpoint_output_folder:t.working_dir
         ~checkpoint_file_prefix:"migration"

  let gather_files_with_prefix root ~substring =
    Sys.readdir root |> Array.to_list
    |> List.filter ~f:(fun x -> String.is_substring x ~substring)
    |> List.map ~f:(fun file -> Filename.concat root file)

  let gather_replayer_migration_checkpoint_files root =
    let substring = "migration-checkpoint" in
    gather_files_with_prefix root ~substring
    |> List.sort ~compare:String.compare

  let gather_extensional_block_files root =
    let get_blockchain_length extensional_block_file =
      Yojson.Basic.from_file extensional_block_file
      |> member "height" |> to_string |> Int.of_string
    in
    let full_path file = Printf.sprintf "%s/%s" root file in

    gather_files_with_prefix root ~substring:"3N"
    |> List.map ~f:(fun extensional_block_file ->
           let full_path = full_path extensional_block_file in
           let height = get_blockchain_length full_path in
           let new_name =
             Printf.sprintf "mainnet_%d_%s" height extensional_block_file
           in
           let full_new_name = Printf.sprintf "%s/%s" root new_name in
           Sys.rename full_path full_new_name ;
           new_name )
    |> List.sort ~compare:(fun left right ->
           let left = get_blockchain_length (full_path left) in
           let right = get_blockchain_length (full_path right) in
           left - right )

  let get_max_length uri =
    match Caqti_async.connect_pool ~max_size:128 uri with
    | Error _ ->
        failwithf "Failed to create Caqti pools for Postgresql to %s"
          (Uri.to_string uri) ()
    | Ok pool ->
        let query_db = Mina_caqti.query pool in
        query_db ~f:(fun db -> Sql.Mainnet.max_length db)

  let get_max_state_hash uri =
    match Caqti_async.connect_pool ~max_size:128 uri with
    | Error _ ->
        failwithf "Failed to create Caqti pools for Postgresql to %s"
          (Uri.to_string uri) ()
    | Ok pool ->
        let query_db = Mina_caqti.query pool in
        query_db ~f:(fun db -> Sql.Mainnet.max_state_hash db)

  let get_latest_state_hash uri =
    let open Deferred.Let_syntax in
    let mainnet_pool = Caqti_async.connect_pool ~max_size:128 uri in

    match mainnet_pool with
    | Error _ ->
        failwithf "Failed to create Caqti pools for Postgresql to %s"
          (Uri.to_string uri) ()
    | Ok mainnet_pool ->
        let query_mainnet_db = Mina_caqti.query mainnet_pool in
        let%bind maybe_slot =
          query_mainnet_db ~f:(fun db -> Sql.Mainnet.latest_state_hash db)
        in
        Deferred.return maybe_slot

  let get_latest_state_hash_at_slot uri migration_end_slot =
    let open Deferred.Let_syntax in
    let mainnet_pool = Caqti_async.connect_pool ~max_size:128 uri in

    match mainnet_pool with
    | Error _ ->
        failwithf "Failed to create Caqti pools for Postgresql to %s"
          (Uri.to_string uri) ()
    | Ok mainnet_pool ->
        let query_mainnet_db = Mina_caqti.query mainnet_pool in
        let%bind maybe_slot =
          query_mainnet_db ~f:(fun db ->
              Sql.Mainnet.latest_state_hash_before_slot db migration_end_slot )
        in
        Deferred.return
          (Option.value_exn maybe_slot
             ~message:
               (Printf.sprintf "Cannot find latest state has for slot: %d"
                  migration_end_slot ) )

  let get_migration_end_slot_for_state_hash conn_str state_hash =
    let open Deferred.Let_syntax in
    let uri = Uri.of_string conn_str in
    let mainnet_pool = Caqti_async.connect_pool ~max_size:128 uri in
    match mainnet_pool with
    | Error _ ->
        failwithf "Failed to create Caqti pools for Postgresql to %s"
          (Uri.to_string uri) ()
    | Ok mainnet_pool ->
        let query_mainnet_db = Mina_caqti.query mainnet_pool in
        let%bind maybe_slot =
          query_mainnet_db ~f:(fun db ->
              Sql.Mainnet.global_slot_since_genesis_at_state_hash db state_hash )
        in
        Deferred.return
          (Option.value_exn maybe_slot
             ~message:
               (Printf.sprintf "Cannot find slot has for state hash: %s"
                  state_hash ) )

  let assert_migrated_db_contains_only_canonical_blocks query_migrated_db =
    let%bind pending_blocks =
      query_migrated_db ~f:(fun db -> Sql.Berkeley.count_orphaned_blocks db)
    in
    let%bind orphaned_blocks =
      query_migrated_db ~f:(fun db -> Sql.Berkeley.count_pending_blocks db)
    in
    match orphaned_blocks + pending_blocks with
    | 0 ->
        Deferred.unit
    | _ ->
        failwithf
          "Expected to have at only canonical block while having %d orphaned \
           and %d pending"
          orphaned_blocks pending_blocks ()

  let assert_migrated_db_contains_no_orphaned_blocks query_migrated_db =
    let%bind orphaned_blocks =
      query_migrated_db ~f:(fun db -> Sql.Berkeley.count_orphaned_blocks db)
    in
    match orphaned_blocks with
    | 0 ->
        Deferred.unit
    | _ ->
        failwith "Expected to have none orphaned blocks"

  let assert_migrated_db_contains_pending_blocks query_migrated_db =
    let%bind pending_blocks =
      query_migrated_db ~f:(fun db -> Sql.Berkeley.count_pending_blocks db)
    in
    match pending_blocks with
    | 0 ->
        failwith "Expected to have at least one pending block"
    | _ ->
        Deferred.unit

  let compare_hashes mainnet_archive_conn_str migrated_archive_conn_str
      end_global_slot ~should_contain_pending_blocks =
    let mainnet_archive_uri = Uri.of_string mainnet_archive_conn_str in
    let migrated_archive_uri = Uri.of_string migrated_archive_conn_str in
    let mainnet_pool =
      Caqti_async.connect_pool ~max_size:128 mainnet_archive_uri
    in
    let migrated_pool =
      Caqti_async.connect_pool ~max_size:128 migrated_archive_uri
    in
    match (mainnet_pool, migrated_pool) with
    | Error _e, _ | _, Error _e ->
        failwith "Failed to create Caqti pools for Postgresql"
    | Ok mainnet_pool, Ok migrated_pool ->
        let query_mainnet_db = Mina_caqti.query mainnet_pool in
        let query_migrated_db = Mina_caqti.query migrated_pool in
        let compare_hashes ~fetch_data_sql ~find_element_sql name =
          let%bind expected_hashes = query_mainnet_db ~f:fetch_data_sql in
          Deferred.List.iter expected_hashes ~f:(fun hash ->
              let%bind element_id = find_element_sql hash in
              if element_id |> Option.is_none then
                failwithf "Cannot find %s hash ('%s') in migrated database" name
                  hash ()
              else Deferred.unit )
        in
        let%bind _ =
          compare_hashes
            ~fetch_data_sql:(fun db ->
              Sql.Mainnet.user_commands_hashes db end_global_slot )
            ~find_element_sql:(fun hash ->
              query_migrated_db ~f:(fun db ->
                  Sql.Berkeley.find_user_command_id_by_hash db hash ) )
            "user_commands"
        in
        let%bind _ =
          compare_hashes
            ~fetch_data_sql:(fun db ->
              Sql.Mainnet.internal_commands_hashes db end_global_slot )
            ~find_element_sql:(fun hash ->
              query_migrated_db ~f:(fun db ->
                  Sql.Berkeley.find_internal_command_id_by_hash db hash ) )
            "internal_commands"
        in
        let%bind _ =
          assert_migrated_db_contains_no_orphaned_blocks query_migrated_db
        in
        let%bind _ =
          match should_contain_pending_blocks with
          | true ->
              assert_migrated_db_contains_pending_blocks query_migrated_db
          | false ->
              assert_migrated_db_contains_only_canonical_blocks
                query_migrated_db
        in
        let%bind _ =
          compare_hashes
            ~fetch_data_sql:(fun db ->
              match should_contain_pending_blocks with
              | true ->
                  Sql.Mainnet.block_hashes_only_canonical db end_global_slot
              | false ->
                  Sql.Mainnet.block_hashes_no_orphaned db end_global_slot )
            ~find_element_sql:(fun hash ->
              query_migrated_db ~f:(fun db ->
                  Sql.Berkeley.find_block_by_state_hash db hash ) )
            "block_state_hashes"
        in
        let%bind _ =
          compare_hashes
            ~fetch_data_sql:(fun db ->
              match should_contain_pending_blocks with
              | true ->
                  Sql.Mainnet.block_parent_hashes_only_canonical db
                    end_global_slot
              | false ->
                  Sql.Mainnet.block_parent_hashes_no_orphaned db end_global_slot
              )
            ~find_element_sql:(fun hash ->
              query_migrated_db ~f:(fun db ->
                  Sql.Berkeley.find_block_by_parent_hash db hash ) )
            "block_parent_state_hashes"
        in
        let%bind _ =
          compare_hashes
            ~fetch_data_sql:(fun db ->
              match should_contain_pending_blocks with
              | true ->
                  Sql.Mainnet.ledger_hashes_only_canonical db end_global_slot
              | false ->
                  Sql.Mainnet.ledger_hashes_no_orphaned db end_global_slot )
            ~find_element_sql:(fun hash ->
              query_migrated_db ~f:(fun db ->
                  Sql.Berkeley.find_block_by_ledger_hash db hash ) )
            "ledger_hashes"
        in

        let%bind expected_hashes =
          query_mainnet_db ~f:(fun db ->
              Sql.Common.block_state_hashes db end_global_slot )
        in
        let%bind actual_hashes =
          query_migrated_db ~f:(fun db ->
              Sql.Common.block_state_hashes db end_global_slot )
        in
        List.iter expected_hashes ~f:(fun (expected_child, expected_parent) ->
            if
              List.exists actual_hashes ~f:(fun (actual_child, actual_parent) ->
                  String.equal expected_child actual_child
                  && String.equal expected_parent actual_parent )
            then ()
            else
              failwithf
                "Relation between blocks skew. Cannot find original subchain \
                 '%s' -> '%s' in migrated database"
                expected_child expected_parent () ) ;
        Deferred.unit

  let import_mainnet_dump t date =
    let%bind archive =
      Archive_dumps.download_via_public_url ~prefix:"mainnet" ~date
        ~target:t.working_dir
    in
    let sql =
      Printf.sprintf "%s/mainnet-archive-dump-%s_0000.sql" t.working_dir date
    in
    let%bind _ = Utils.untar ~archive ~output:t.working_dir in
    let db_name =
      Printf.sprintf "%s_%d" t.test_name (Random.int 1000000 + 1000)
    in
    let%bind _ =
      Utils.sed ~search:"archive_balances_migrated" ~replacement:db_name
        ~input:sql
    in

    let%bind _ =
      Psql.create_new_mina_archive ~connection:(to_connection t) ~db:db_name
        ~script:sql
    in

    Deferred.return (Settings.connection_str_to t.env db_name)

  let import_dump t ~script =
    let open Deferred.Let_syntax in
    let prefix = Printf.sprintf "%s_input" t.test_name in
    let%bind db_name =
      Psql.create_new_random_archive ~connection:(to_connection t) ~prefix
        ~script
    in
    Deferred.return (Settings.connection_str_to t.env db_name)

  let import_random_data_dump t =
    import_dump t ~script:t.env.paths.random_data_dump

  let import_genesis_mainnet_dump t =
    import_dump t ~script:t.env.paths.mainnet_genesis_block

  let recreate_working_dir t =
    let open Deferred.Let_syntax in
    let%bind _ = Util.run_cmd_exn "." "rm" [ "-rf"; t.working_dir ] in
    Unix.mkdir_p t.working_dir ; Deferred.return ()

  let clear_checkpoint_files prefix t =
    Util.run_cmd_exn "." "rm"
      [ "-f"; Printf.sprintf "%s/%s-checkpoint*.json" t.working_dir prefix ]

  let compare_replayer_outputs expected actual ~compare_receipt_chain_hashes =
    let expected_output = Replayer.Output.of_json_file_exn expected in
    let actual_output = Replayer.Output.of_json_file_exn actual in

    let get_accounts (output : Replayer.Output.t) file =
      let ledger =
        match output.target_genesis_ledger with
        | None ->
            failwithf
              "replayer output file (%s) does not have any target ledger " file
              ()
        | Some ledger ->
            ledger
      in
      match ledger.base with
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

  let get_expected_ledger folder name =
    let expected_ledger_path = Printf.sprintf "%s/%s" folder name in
    let expected_ledger =
      Yojson.Safe.from_file expected_ledger_path
      |> Replayer.Output.of_yojson |> Result.ok_or_failwith
    in
    let end_migration_ledger_hash =
      expected_ledger.target_epoch_ledgers_state_hash
    in
    return (expected_ledger_path, end_migration_ledger_hash)

  let assert_no_replayer_migration_checkpoint_on_pending_blocks root =
    let len = gather_replayer_migration_checkpoint_files root |> List.length in
    if len > 0 then
      failwithf
        "Expected no checkpoint generated on fixing account tables on pending \
         blocks (size: %d)"
        len ()
    else ()

  let archive_mainnet_precomputed_blocks t blocks conn_str =
    let workdir = "/workdir" in
    let blocks_in_docker =
      List.map blocks ~f:(fun block ->
          Filename.concat workdir (Filename.basename block) )
    in

    let archive_blocks =
      Archive_blocks.of_context Docker
        { image = t.env.reference.docker
        ; workdir
        ; volume =
            Printf.sprintf "%s:%s" (Filename.realpath t.working_dir) workdir
        ; network = "hardfork"
        }
    in

    Archive_blocks.run archive_blocks ~archive_uri ~blocks:blocks_in_docker

  let run_compatible_replayer t ~archive_uri ?(clear_checkpoints = false)
      ~input_config ~output_ledger =
    let workdir = "/workdir" in
    let host_volume =
      match t.env.reference.volume_bind with
      | Some volume ->
          Filename.concat volume t.test_name
      | None ->
          Core.Filename.realpath t.working_dir
    in

    let replayer_app =
      Replayer.of_context
        (Docker
           { image = t.env.reference.docker
           ; workdir
           ; volume = Printf.sprintf "%s:%s" host_volume workdir
           ; network = "hardfork"
           } )
    in

    let%bind _ =
      Replayer.run replayer_app ~archive_uri
        ~input_config:(Filename.concat workdir input_config)
        ~interval_checkpoint:10
        ~output_ledger:(Filename.concat workdir output_ledger)
        ?checkpoint_output_folder:None ?checkpoint_file_prefix:None
        ~migration_mode:false
    in

    if clear_checkpoints then clear_checkpoint_files "replayer" t >>| ignore
    else Deferred.unit

  let download_mainnet_precomputed_blocks steps ~from ~num_blocks =
    let output_folder = steps.working_dir in
    let%bind _ =
      Precomputed_blocks.fetch_batch ~height:(Int64.of_int from)
        ~num_blocks:(Int64.of_int num_blocks) ~bucket:"mina_network_block_data"
        ~output_folder
    in
    Deferred.return
      ( gather_files_with_prefix output_folder ~substring:"mainnet"
      |> List.sort ~compare:(fun left right ->
             let get_length file =
               Scanf.sscanf (Filename.basename file) "mainnet-%d-%s"
                 (fun d _s -> d)
             in
             let left = get_length left in
             let right = get_length right in
             left - right ) )
end
