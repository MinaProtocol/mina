(* migrate_balances_table.ml *)

open Core_kernel
open Async

let query_db pool ~f ~item =
  match%bind Caqti_async.Pool.use f pool with
  | Ok v ->
      return v
  | Error msg ->
      failwithf "Error getting %s from db, error: %s" item
        (Caqti_error.show msg) ()

let main ~archive_uri () =
  let logger = Logger.create () in
  let archive_uri = Uri.of_string archive_uri in
  match Caqti_async.connect_pool ~max_size:128 archive_uri with
  | Error e ->
      [%log fatal]
        ~metadata:[ ("error", `String (Caqti_error.show e)) ]
        "Failed to create a Caqti pool for Postgresql" ;
      exit 1
  | Ok pool ->
      [%log info] "Successfully created Caqti pool for Postgresql" ;
      let drop_and_rename_table table =
        [%log info] "DROP original %s table, overwrite with temp table" table ;
        let%bind () =
          query_db pool
            ~f:(fun db -> Sql.drop_table db table ())
            ~item:(sprintf "DROP %s table" table)
        in
        query_db pool
          ~f:(fun db -> Sql.rename_temp_table db table ())
          ~item:(sprintf "RENAME %s_temp table" table)
      in
      let mk_temp_table table =
        query_db pool
          ~f:(fun db -> Sql.copy_table_to_temp_table db table ())
          ~item:(sprintf "temp table: %s" table)
      in
      let get_balances_id ~public_key_id ~balance ~block_id ~block_height
          ~block_sequence_no ~block_secondary_sequence_no =
        match%bind
          query_db pool
            ~f:(fun db ->
              Sql.find_balance_entry db ~public_key_id ~balance ~block_id
                ~block_height ~block_sequence_no ~block_secondary_sequence_no )
            ~item:"find balance entry"
        with
        | None ->
            query_db pool
              ~f:(fun db ->
                Sql.insert_balance_entry db ~public_key_id ~balance ~block_id
                  ~block_height ~block_sequence_no ~block_secondary_sequence_no
                )
              ~item:"insert balance entry"
        | Some id ->
            return id
      in
      let read_cursor name =
        match%map
          query_db pool
            ~f:(fun db -> Sql.current_cursor db name ())
            ~item:(sprintf "read %s cursor" name)
        with
        | Some ndx ->
            ndx
        | None ->
            0
      in
      let update_cursor name ndx =
        query_db pool
          ~f:(fun db -> Sql.update_cursor db name ndx)
          ~item:(sprintf "update %s cursor" name)
      in
      [%log info] "Checking whether balances table is already migrated" ;
      let%bind num_balance_columns =
        query_db pool
          ~f:(fun db -> Sql.get_column_count db "balances")
          ~item:"balances column count"
      in
      if num_balance_columns = 7 then (
        [%log info] "Balances table has %d columns, already migrated"
          num_balance_columns ;
        Core_kernel.exit 0 ) ;
      [%log info] "Creating temporary balances table" ;
      let%bind () =
        query_db pool
          ~f:(fun db -> Sql.create_temp_balances_table db ())
          ~item:"balances temp table"
      in
      [%log info] "Creating indexes for temp balances table" ;
      let%bind () =
        Deferred.List.iter
          [ "id"
          ; "public_key_id"
          ; "block_id"
          ; "block_height"
          ; "block_sequence_no"
          ; "block_secondary_sequence_no"
          ] ~f:(fun col ->
            let table = "balances" in
            let%bind () =
              query_db pool
                ~f:(fun db -> Sql.drop_temp_table_index db table col ())
                ~item:"drop blocks internal commands index"
            in
            query_db pool
              ~f:(fun db -> Sql.create_temp_table_index db table col ())
              ~item:"balances index" )
      in
      let%bind () =
        query_db pool
          ~f:(fun db ->
            Sql.create_temp_table_named_index db "balances"
              "block_height,block_sequence_no,block_secondary_sequence_no"
              "height_seq_nos" () )
          ~item:"balances index"
      in
      [%log info] "Creating temporary blocks internal commands table" ;
      let%bind () = mk_temp_table "blocks_internal_commands" in
      [%log info]
        "Creating indexes for temporary blocks internal commands table" ;
      let%bind () =
        Deferred.List.iter
          [ "block_id"
          ; "internal_command_id"
          ; "sequence_no"
          ; "secondary_sequence_no"
          ; "receiver_balance"
          ] ~f:(fun col ->
            let table = "blocks_internal_commands" in
            let%bind () =
              query_db pool
                ~f:(fun db -> Sql.drop_temp_table_index db table col ())
                ~item:"drop blocks internal commands index"
            in
            query_db pool
              ~f:(fun db -> Sql.create_temp_table_index db table col ())
              ~item:"create blocks internal commands index" )
      in
      [%log info] "Creating temporary blocks user commands table" ;
      let%bind () = mk_temp_table "blocks_user_commands" in
      [%log info] "Creating indexes for temporary blocks user commands table" ;
      let%bind () =
        Deferred.List.iter [ "block_id"; "user_command_id"; "sequence_no" ]
          ~f:(fun col ->
            let table = "blocks_user_commands" in
            let%bind () =
              query_db pool
                ~f:(fun db -> Sql.drop_temp_table_index db table col ())
                ~item:"drop blocks internal commands index"
            in
            query_db pool
              ~f:(fun db -> Sql.create_temp_table_index db table col ())
              ~item:"blocks user commands index" )
      in
      let internal_cmds_cursor_name = "internal_cmds" in
      let fee_payer_cursor_name = "fee_payer" in
      let source_cursor_name = "source" in
      let receiver_cursor_name = "receiver" in
      [%log info] "Creating cursors" ;
      let%bind () =
        Deferred.List.iter
          [ internal_cmds_cursor_name
          ; fee_payer_cursor_name
          ; source_cursor_name
          ; receiver_cursor_name
          ] ~f:(fun cursor ->
            let%bind () =
              query_db pool
                ~f:(fun db -> Sql.create_cursor db cursor ())
                ~item:(sprintf "Create cursor %s" cursor)
            in
            match%bind
              query_db pool
                ~f:(fun db -> Sql.current_cursor db cursor ())
                ~item:(sprintf "Current cursor %s" cursor)
            with
            | None ->
                query_db pool
                  ~f:(fun db -> Sql.initialize_cursor db cursor ())
                  ~item:(sprintf "Initialize cursor %s" cursor)
            | Some _ ->
                return () )
      in
      [%log info] "Getting internal commands" ;
      let%bind internal_commands =
        query_db pool
          ~f:(fun db -> Sql.get_internal_commands db ())
          ~item:"Get internal commands"
      in
      [%log info] "Updating receiver balances in %d internal commands"
        (List.length internal_commands) ;
      let%bind internal_cmd_cursor = read_cursor internal_cmds_cursor_name in
      if internal_cmd_cursor > 0 then
        [%log info] "Skipping %d internal commands, already processed"
          internal_cmd_cursor ;
      let%bind () =
        Deferred.List.iteri internal_commands
          ~f:(fun
               ndx
               ( public_key_id
               , balance
               , ( block_id
                 , block_height
                 , block_sequence_no
                 , block_secondary_sequence_no )
               , internal_command_id )
             ->
            if ndx < internal_cmd_cursor then return ()
            else
              let%bind new_balance_id =
                get_balances_id ~public_key_id ~balance ~block_id ~block_height
                  ~block_sequence_no ~block_secondary_sequence_no
              in
              let%bind () =
                query_db pool
                  ~f:(fun db ->
                    Sql.update_internal_command_receiver_balance db
                      ~new_balance_id ~block_id ~internal_command_id
                      ~block_sequence_no ~block_secondary_sequence_no )
                  ~item:"update internal command receiver balance"
              in
              (* update cursor only periodically, otherwise too slow *)
              if ndx % 1000 = 0 then (
                [%log info] "Updated internal command receiver balance: %d" ndx ;
                update_cursor internal_cmds_cursor_name ndx )
              else return () )
      in
      [%log info] "Getting user command fee payer balance information" ;
      let%bind user_command_fee_payers =
        query_db pool
          ~f:(fun db -> Sql.get_user_command_fee_payers db ())
          ~item:"Get user commands with fee payer balances"
      in
      [%log info] "Updating fee payer balances in %d user commands"
        (List.length user_command_fee_payers) ;
      let%bind fee_payer_cursor = read_cursor fee_payer_cursor_name in
      if fee_payer_cursor > 0 then
        [%log info]
          "Skipping %d user commands for fee payers, already processed"
          fee_payer_cursor ;
      let%bind () =
        Deferred.List.iteri user_command_fee_payers
          ~f:(fun
               ndx
               ( (block_id, block_height, block_sequence_no, user_command_id)
               , (public_key_id, balance) )
             ->
            if ndx < fee_payer_cursor then return ()
            else
              let%bind new_balance_id =
                get_balances_id ~public_key_id ~balance ~block_id ~block_height
                  ~block_sequence_no ~block_secondary_sequence_no:0
              in
              let%bind () =
                query_db pool
                  ~f:(fun db ->
                    Sql.update_user_command_fee_payer_balance db ~new_balance_id
                      ~block_id ~user_command_id ~block_sequence_no )
                  ~item:"update user command fee payer balance"
              in
              if ndx % 1000 = 0 then (
                [%log info] "Updated user command fee payer balance: %d" ndx ;
                update_cursor fee_payer_cursor_name ndx )
              else return () )
      in
      [%log info] "Getting user command source balance information" ;
      let%bind user_command_sources =
        query_db pool
          ~f:(fun db -> Sql.get_user_command_sources db ())
          ~item:"Get user commands with source balances"
      in
      [%log info] "Updating source balances in %d user commands"
        (List.length user_command_sources) ;
      let%bind source_cursor = read_cursor source_cursor_name in
      if source_cursor > 0 then
        [%log info]
          "Skipping %d user commands for source payers, already processed"
          source_cursor ;
      let%bind () =
        Deferred.List.iteri user_command_sources
          ~f:(fun
               ndx
               ( (block_id, block_height, block_sequence_no, user_command_id)
               , (public_key_id, balance) )
             ->
            if ndx < source_cursor then return ()
            else
              let%bind new_balance_id =
                get_balances_id ~public_key_id ~balance ~block_id ~block_height
                  ~block_sequence_no ~block_secondary_sequence_no:0
              in
              let%bind () =
                query_db pool
                  ~f:(fun db ->
                    Sql.update_user_command_source_balance db ~new_balance_id
                      ~block_id ~user_command_id ~block_sequence_no )
                  ~item:"update user command source balance"
              in
              if ndx % 1000 = 0 then (
                [%log info] "Updated user command source balance: %d" ndx ;
                update_cursor source_cursor_name ndx )
              else return () )
      in
      [%log info] "Getting user command receiver balance information" ;
      let%bind user_command_receivers =
        query_db pool
          ~f:(fun db -> Sql.get_user_command_receivers db ())
          ~item:"Get user commands with receiver balances"
      in
      [%log info] "Updating receiver balances in %d user commands"
        (List.length user_command_receivers) ;
      let%bind receiver_cursor = read_cursor receiver_cursor_name in
      if receiver_cursor > 0 then
        [%log info]
          "Skipping %d user commands for source payers, already processed"
          receiver_cursor ;
      let%bind () =
        Deferred.List.iteri user_command_receivers
          ~f:(fun
               ndx
               ( (block_id, block_height, block_sequence_no, user_command_id)
               , (public_key_id, balance) )
             ->
            if ndx < receiver_cursor then return ()
            else
              let%bind new_balance_id =
                get_balances_id ~public_key_id ~balance ~block_id ~block_height
                  ~block_sequence_no ~block_secondary_sequence_no:0
              in
              let%bind () =
                query_db pool
                  ~f:(fun db ->
                    Sql.update_user_command_receiver_balance db ~new_balance_id
                      ~block_id ~user_command_id ~block_sequence_no )
                  ~item:"update user command receiver balance"
              in
              if ndx % 1000 = 0 then (
                [%log info] "Updated user command receiver balance: %d" ndx ;
                update_cursor receiver_cursor_name ndx )
              else return () )
      in
      [%log info]
        "DROP original blocks_internal_command table, overwrite with temp table" ;
      let%bind () = drop_and_rename_table "blocks_internal_commands" in
      [%log info]
        "DROP original blocks_user_command table, overwrite with temp table" ;
      let%bind () = drop_and_rename_table "blocks_user_commands" in
      [%log info] "DROP original balances table, overwrite with temp table" ;
      let%bind () = drop_and_rename_table "balances" in
      [%log info] "Adding back foreign key constraints" ;
      let%bind () =
        query_db pool
          ~f:(fun db ->
            Sql.add_balances_foreign_key_constraint db
              "blocks_internal_commands" "receiver_balance"
              "blocks_internal_commands_receiver_balance_fkey" () )
          ~item:
            "Blocks_internal_commands receiver balance foreign key constraint"
      in
      let%bind () =
        query_db pool
          ~f:(fun db ->
            Sql.add_balances_foreign_key_constraint db "blocks_user_commands"
              "fee_payer_balance" "blocks_user_commands_fee_payer_balance_fkey"
              () )
          ~item:"Blocks_user_commands fee payer balance foreign key constraint"
      in
      let%bind () =
        query_db pool
          ~f:(fun db ->
            Sql.add_balances_foreign_key_constraint db "blocks_user_commands"
              "source_balance" "blocks_user_commands_source_balance_fkey" () )
          ~item:"Blocks_user_commands source balance foreign key constraint"
      in
      let%bind () =
        query_db pool
          ~f:(fun db ->
            Sql.add_balances_foreign_key_constraint db "blocks_user_commands"
              "receiver_balance" "blocks_user_commands_receiver_balance_fkey" ()
            )
          ~item:"Blocks_user_commands receiver balance foreign key constraint"
      in
      let%bind () =
        query_db pool
          ~f:(fun db ->
            Sql.add_blocks_foreign_key_constraint db "blocks_internal_commands"
              "block_id" "blocks_internal_commands_block_id_fkey" () )
          ~item:"Blocks_internal_commands block id foreign key constraint"
      in
      let%bind () =
        query_db pool
          ~f:(fun db ->
            Sql.add_blocks_foreign_key_constraint db "blocks_user_commands"
              "block_id" "blocks_user_commands_block_id_fkey" () )
          ~item:"Blocks_user_commands block id foreign key constraint"
      in
      let%bind () =
        query_db pool
          ~f:(fun db ->
            Sql.add_blocks_foreign_key_constraint db "balances" "block_id"
              "balances_block_id_fkey" () )
          ~item:"Balances block id foreign key constraint"
      in
      [%log info] "Migration successful" ;
      return ()

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async ~summary:"Migrate balances table to extended balances table"
        (let%map archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER@localhost:5432/archiver)"
             Param.(required string)
         in
         main ~archive_uri )))
