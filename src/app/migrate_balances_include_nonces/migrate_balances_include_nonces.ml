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
      let%bind () =
        query_db pool
          ~f:(fun db -> Sql.add_nonce_column db ())
          ~item:"ADD nonce COLUMN"
      in
      let%bind fee_payers_and_nonces =
        query_db pool
          ~f:(fun db -> Sql.fee_payers_and_nonces db ())
          ~item:"fee payers and nonces"
      in
      [%log info] "Updating nonce for fee payers in %d user commands"
        (List.length fee_payers_and_nonces) ;
      let%bind () =
        Deferred.List.iteri fee_payers_and_nonces
          ~f:(fun i (fee_payer, user_cmd_nonce) ->
            if i > 0 && (i + 1) % 1000 = 0 then
              [%log info] "Updating fee payer nonce no. %d" (i + 1) ;
            (* ledger nonce is 1 more than nonce in user command *)
            let nonce = Int64.succ user_cmd_nonce in
            query_db pool
              ~f:(fun db -> Sql.update_balance_nonce db ~id:fee_payer ~nonce)
              ~item:"update fee payer nonce")
      in
      [%log info] "Finding balances with NULL nonces" ;
      let%bind balances_with_null_nonces =
        query_db pool
          ~f:(fun db -> Sql.balances_with_null_nonces db ())
          ~item:"balances with null nonces"
      in
      [%log info] "Found %d balances with NULL nonces"
        (List.length balances_with_null_nonces) ;
      let%bind balances_with_nonces_to_update =
        Deferred.List.mapi balances_with_null_nonces ~f:(fun i bal ->
            if i > 0 && (i + 1) % 100 = 0 then
              [%log info] "Obtaining most recent nonce for balance no. %d"
                (i + 1) ;
            let%map nonce =
              let public_key_id = bal.public_key_id in
              let block_height = bal.block_height in
              let block_sequence_no = bal.block_sequence_no in
              let block_secondary_sequence_no =
                bal.block_secondary_sequence_no
              in
              query_db pool
                ~f:(fun db ->
                  Sql.most_recent_nonce db ~public_key_id ~block_height
                    ~block_sequence_no ~block_secondary_sequence_no)
                ~item:"most recent nonce"
            in
            (bal.id, nonce))
      in
      let%bind () =
        Deferred.List.iteri balances_with_nonces_to_update
          ~f:(fun i (id, nonce_opt) ->
            if i > 0 && (i + 1) % 1000 = 0 then
              [%log info] "Updating balance with NULL nonce no. %d" (i + 1) ;
            let nonce = Option.value_map nonce_opt ~default:0L ~f:Fn.id in
            query_db pool
              ~f:(fun db -> Sql.update_balance_nonce db ~id ~nonce)
              ~item:"update other nonces")
      in
      [%log info] "Migration successful" ;
      return ()

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async ~summary:"Migrate balances table to include nonces"
        (let%map archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER@localhost:5432/archiver)"
             Param.(required string)
         in
         main ~archive_uri)))
