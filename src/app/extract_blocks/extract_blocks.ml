(* extract_blocks.ml -- dump extensional blocks from archive db *)
[@@@coverage exclude_file]

open Core_kernel
open Async
open Mina_base
open Mina_transaction
open Archive_lib

let epoch_data_of_raw_epoch_data ~pool (raw_epoch_data : Processor.Epoch_data.t)
    =
  let query_db = Mina_caqti.query pool in
  let%bind hash_str =
    query_db ~f:(fun db ->
        Processor.Snarked_ledger_hash.find_by_id db
          raw_epoch_data.ledger_hash_id )
  in
  let hash = Frozen_ledger_hash.of_base58_check_exn hash_str in
  let total_currency =
    Currency.Amount.of_string raw_epoch_data.total_currency
  in
  let ledger = { Mina_base.Epoch_ledger.Poly.hash; total_currency } in
  let seed = raw_epoch_data.seed |> Epoch_seed.of_base58_check_exn in
  let start_checkpoint =
    raw_epoch_data.start_checkpoint |> State_hash.of_base58_check_exn
  in
  let lock_checkpoint =
    raw_epoch_data.lock_checkpoint |> State_hash.of_base58_check_exn
  in
  let epoch_length =
    raw_epoch_data.epoch_length |> Unsigned.UInt32.of_int64
    |> Mina_numbers.Length.of_uint32
  in
  return
    { Mina_base.Epoch_data.Poly.ledger
    ; seed
    ; start_checkpoint
    ; lock_checkpoint
    ; epoch_length
    }

let fill_in_block pool (block : Archive_lib.Processor.Block.t) :
    Extensional.Block.t Deferred.t =
  let query_db = Mina_caqti.query pool in
  let state_hash = State_hash.of_base58_check_exn block.state_hash in
  let parent_hash = State_hash.of_base58_check_exn block.parent_hash in
  let pk_of_id = Load_data.pk_of_id pool in
  let open Deferred.Let_syntax in
  let%bind creator = pk_of_id block.creator_id in
  let%bind block_winner = pk_of_id block.block_winner_id in
  let last_vrf_output =
    (* keep hex encoding *)
    block.last_vrf_output
  in
  let%bind snarked_ledger_hash_str =
    query_db ~f:(fun db ->
        Processor.Snarked_ledger_hash.find_by_id db block.snarked_ledger_hash_id )
  in
  let snarked_ledger_hash =
    Frozen_ledger_hash.of_base58_check_exn snarked_ledger_hash_str
  in
  let%bind staking_epoch_data_raw =
    query_db ~f:(fun db ->
        Processor.Epoch_data.load db block.staking_epoch_data_id )
  in
  let%bind staking_epoch_data =
    epoch_data_of_raw_epoch_data ~pool staking_epoch_data_raw
  in
  let%bind next_epoch_data_raw =
    query_db ~f:(fun db ->
        Processor.Epoch_data.load db block.next_epoch_data_id )
  in
  let%bind next_epoch_data =
    epoch_data_of_raw_epoch_data ~pool next_epoch_data_raw
  in
  let min_window_density =
    block.min_window_density |> Unsigned.UInt32.of_int64
    |> Mina_numbers.Length.of_uint32
  in
  let sub_window_densities =
    block.sub_window_densities
    |> Array.map ~f:(fun length ->
           Unsigned.UInt32.of_int64 length |> Mina_numbers.Length.of_uint32 )
    |> Array.to_list
  in
  let total_currency = Currency.Amount.of_string block.total_currency in
  let ledger_hash = Ledger_hash.of_base58_check_exn block.ledger_hash in
  let height = Unsigned.UInt32.of_int64 block.height in
  let global_slot_since_hard_fork =
    Unsigned.UInt32.of_int64 block.global_slot_since_hard_fork
    |> Mina_numbers.Global_slot_since_hard_fork.of_uint32
  in
  let global_slot_since_genesis =
    Unsigned.UInt32.of_int64 block.global_slot_since_genesis
    |> Mina_numbers.Global_slot_since_genesis.of_uint32
  in
  let timestamp = Block_time.of_string_exn block.timestamp in
  let chain_status = Chain_status.of_string block.chain_status in
  let%bind protocol_version =
    let%map { major; minor; patch } =
      query_db ~f:(fun db ->
          Processor.Protocol_versions.load db block.protocol_version_id )
    in
    Protocol_version.create_exn ~major ~minor ~patch
  in
  let%bind proposed_protocol_version =
    Option.value_map block.proposed_protocol_version_id ~default:(return None)
      ~f:(fun id ->
        let%map { major; minor; patch } =
          query_db ~f:(fun db -> Processor.Protocol_versions.load db id)
        in
        Some (Protocol_version.create_exn ~major ~minor ~patch) )
  in
  (* commands, accounts_accessed, accounts_created, tokens_used to be filled in later *)
  return
    { Extensional.Block.state_hash
    ; parent_hash
    ; creator
    ; block_winner
    ; last_vrf_output
    ; snarked_ledger_hash
    ; staking_epoch_data
    ; next_epoch_data
    ; min_window_density
    ; sub_window_densities
    ; total_currency
    ; ledger_hash
    ; height
    ; global_slot_since_hard_fork
    ; global_slot_since_genesis
    ; timestamp
    ; user_cmds = []
    ; internal_cmds = []
    ; zkapp_cmds = []
    ; proposed_protocol_version
    ; protocol_version
    ; chain_status
    ; accounts_accessed = []
    ; accounts_created = []
    ; tokens_used = []
    }

let fill_in_accounts_accessed pool block_state_hash =
  let query_db = Mina_caqti.query pool in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~f:(fun db -> Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind accounts_accessed =
    query_db ~f:(fun db ->
        Processor.Accounts_accessed.all_from_block db block_id )
  in
  Deferred.List.map accounts_accessed ~f:(Load_data.get_account_accessed ~pool)

let fill_in_accounts_created pool block_state_hash =
  let query_db = Mina_caqti.query pool in
  let pk_of_id = Load_data.pk_of_id pool in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~f:(fun db -> Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind accounts_created =
    query_db ~f:(fun db ->
        Processor.Accounts_created.all_from_block db block_id )
  in
  Deferred.List.map accounts_created ~f:(fun acct_created ->
      let ({ block_id = _; account_identifier_id; creation_fee }
            : Processor.Accounts_created.t ) =
        acct_created
      in
      let%bind ({ public_key_id; token_id; _ } : Processor.Account_identifiers.t)
          =
        query_db ~f:(fun db ->
            Processor.Account_identifiers.load db account_identifier_id )
      in
      let%bind pk = pk_of_id public_key_id in
      let%bind token_id =
        let%map { value; _ } =
          query_db ~f:(fun db -> Processor.Token.find_by_id db token_id)
        in
        Token_id.of_string value
      in
      let account_id = Account_id.create pk token_id in
      let fee = Currency.Fee.of_string creation_fee in
      return (account_id, fee) )

let fill_in_tokens_used pool block_state_hash =
  let query_db = Mina_caqti.query pool in
  let pk_of_id = Load_data.pk_of_id pool in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~f:(fun db -> Processor.Block.find db ~state_hash:block_state_hash)
  in
  let get_token_owner
      ({ value; owner_public_key_id; owner_token_id } : Processor.Token.t) =
    let token_id = Token_id.of_string value in
    match (owner_public_key_id, owner_token_id) with
    | None, None ->
        return (token_id, None)
    | Some owner_pk_id, Some owner_tok_id ->
        let%bind owner_pk = pk_of_id owner_pk_id in
        let%bind owner_token_id =
          let%map owner_token =
            query_db ~f:(fun db -> Processor.Token.find_by_id db owner_tok_id)
          in
          Token_id.of_string owner_token.value
        in
        return (token_id, Some (Account_id.create owner_pk owner_token_id))
    | _ ->
        failwith "Owner public key and token must both be Some or both None"
  in
  let%bind internal_cmd_tokens =
    query_db ~f:(fun db -> Sql.Block_internal_command_tokens.run db ~block_id)
  in
  let%bind internal_cmd_tokens_used =
    Deferred.List.map internal_cmd_tokens ~f:get_token_owner
  in
  let%bind user_cmd_tokens =
    query_db ~f:(fun db -> Sql.Block_user_command_tokens.run db ~block_id)
  in
  let%bind user_cmd_tokens_used =
    Deferred.List.map user_cmd_tokens ~f:get_token_owner
  in
  let%bind zkapps_in_block =
    query_db ~f:(fun db ->
        Processor.Block_and_zkapp_command.all_from_block db ~block_id )
  in
  let%bind zkapp_cmd_tokens =
    let%bind zkapp_cmds =
      Deferred.List.map zkapps_in_block ~f:(fun { zkapp_command_id; _ } ->
          query_db ~f:(fun db ->
              Processor.User_command.Zkapp_command.load db zkapp_command_id ) )
    in
    let%bind fee_payer_token =
      let%bind default_id =
        query_db ~f:(fun db -> Processor.Token.find db Token_id.default)
      in
      query_db ~f:(fun db -> Processor.Token.find_by_id db default_id)
    in
    let%map account_updates_tokenss =
      Deferred.List.map zkapp_cmds ~f:(fun { zkapp_account_updates_ids; _ } ->
          let%bind account_update_bodies =
            Deferred.List.map (Array.to_list zkapp_account_updates_ids)
              ~f:(fun account_update_id ->
                let%bind { body_id; _ } =
                  query_db ~f:(fun db ->
                      Processor.Zkapp_account_update.load db account_update_id )
                in
                query_db ~f:(fun db ->
                    Processor.Zkapp_account_update_body.load db body_id ) )
          in
          Deferred.List.map account_update_bodies
            ~f:(fun { account_identifier_id; _ } ->
              let%bind { token_id; _ } =
                query_db ~f:(fun db ->
                    Processor.Account_identifiers.load db account_identifier_id )
              in
              query_db ~f:(fun db -> Processor.Token.find_by_id db token_id) ) )
    in
    fee_payer_token :: List.concat account_updates_tokenss
  in
  let%bind zkapp_cmd_tokens_used =
    Deferred.List.map zkapp_cmd_tokens ~f:get_token_owner
  in
  let tokens_used =
    internal_cmd_tokens_used @ user_cmd_tokens_used @ zkapp_cmd_tokens_used
    |> List.dedup_and_sort ~compare:[%compare: Token_id.t * Account_id.t option]
  in
  return tokens_used

let fill_in_user_commands pool block_state_hash =
  let query_db = Mina_caqti.query pool in
  let pk_of_id = Load_data.pk_of_id pool in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~f:(fun db -> Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind user_command_ids_and_sequence_nos =
    query_db ~f:(fun db -> Sql.Blocks_and_user_commands.run db ~block_id)
  in
  (* create extensional user command for each id, seq no *)
  Deferred.List.map user_command_ids_and_sequence_nos
    ~f:(fun (user_command_id, sequence_no) ->
      let%bind user_cmd =
        query_db ~f:(fun db ->
            Processor.User_command.Signed_command.load db ~id:user_command_id )
      in
      let command_type = user_cmd.command_type in
      let%bind fee_payer = pk_of_id user_cmd.fee_payer_id in
      let%bind source = pk_of_id user_cmd.source_id in
      let%bind receiver = pk_of_id user_cmd.receiver_id in
      let nonce =
        user_cmd.nonce |> Unsigned.UInt32.of_int64 |> Account.Nonce.of_uint32
      in
      let amount = Option.map user_cmd.amount ~f:Currency.Amount.of_string in
      let fee = Currency.Fee.of_string user_cmd.fee in
      let valid_until =
        Option.map user_cmd.valid_until ~f:(fun valid ->
            Unsigned.UInt32.of_int64 valid
            |> Mina_numbers.Global_slot_since_genesis.of_uint32 )
      in
      let memo = user_cmd.memo |> Signed_command_memo.of_base58_check_exn in
      let hash = user_cmd.hash |> Transaction_hash.of_base58_check_exn in
      let%bind block_user_cmd =
        query_db ~f:(fun db ->
            Processor.Block_and_signed_command.load db ~block_id
              ~user_command_id ~sequence_no )
      in
      let status = block_user_cmd.status in
      let failure_reason =
        Option.map block_user_cmd.failure_reason ~f:(fun s ->
            match Transaction_status.Failure.of_string s with
            | Ok s ->
                s
            | Error err ->
                failwithf "Not a transaction status failure: %s, error: %s" s
                  err () )
      in
      return
        { Extensional.User_command.sequence_no
        ; command_type
        ; fee_payer
        ; source
        ; receiver
        ; nonce
        ; amount
        ; fee
        ; valid_until
        ; memo
        ; hash
        ; status
        ; failure_reason
        } )

let fill_in_internal_commands pool block_state_hash =
  let query_db = Mina_caqti.query pool in
  let pk_of_id = Load_data.pk_of_id pool in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~f:(fun db -> Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind internal_cmd_info =
    query_db ~f:(fun db -> Sql.Blocks_and_internal_commands.run db ~block_id)
  in
  Deferred.List.map internal_cmd_info
    ~f:(fun { internal_command_id; sequence_no; secondary_sequence_no } ->
      (* pieces from the internal_commands table *)
      let%bind internal_cmd =
        query_db ~f:(fun db ->
            Processor.Internal_command.load db ~id:internal_command_id )
      in
      let command_type = internal_cmd.command_type in
      let%bind receiver = pk_of_id internal_cmd.receiver_id in
      let fee = Currency.Fee.of_string internal_cmd.fee in
      let hash = internal_cmd.hash |> Transaction_hash.of_base58_check_exn in
      let%bind block_internal_cmd =
        query_db ~f:(fun db ->
            Processor.Block_and_internal_command.load db ~block_id
              ~internal_command_id ~sequence_no ~secondary_sequence_no )
      in
      let status = block_internal_cmd.status in
      let failure_reason =
        Option.map block_internal_cmd.failure_reason ~f:(fun s ->
            match Transaction_status.Failure.of_string s with
            | Ok s ->
                s
            | Error err ->
                failwithf "Not a transaction status failure: %s, error: %s" s
                  err () )
      in
      let cmd =
        { Extensional.Internal_command.sequence_no
        ; secondary_sequence_no
        ; command_type
        ; receiver
        ; fee
        ; hash
        ; status
        ; failure_reason
        }
      in
      return cmd )

let fill_in_zkapp_commands pool block_state_hash =
  let query_db = Mina_caqti.query pool in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~f:(fun db -> Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind zkapp_command_ids_and_sequence_nos =
    query_db ~f:(fun db -> Sql.Blocks_and_zkapp_commands.run db ~block_id)
  in
  (* create extensional zkapp command for each id, seq no *)
  Deferred.List.map zkapp_command_ids_and_sequence_nos
    ~f:(fun (zkapp_command_id, sequence_no) ->
      let%bind zkapp_cmd =
        query_db ~f:(fun db ->
            Processor.User_command.Zkapp_command.load db zkapp_command_id )
      in
      let%bind fee_payer =
        Load_data.get_fee_payer_body ~pool zkapp_cmd.zkapp_fee_payer_body_id
      in
      let%bind account_updates =
        Deferred.List.map
          (Array.to_list zkapp_cmd.zkapp_account_updates_ids)
          ~f:(Load_data.get_account_update_body ~pool)
      in
      let memo = zkapp_cmd.memo |> Signed_command_memo.of_base58_check_exn in
      let hash = zkapp_cmd.hash |> Transaction_hash.of_base58_check_exn in
      let%bind block_zkapp_cmd =
        query_db ~f:(fun db ->
            Processor.Block_and_zkapp_command.load db ~block_id
              ~zkapp_command_id ~sequence_no )
      in

      let status = block_zkapp_cmd.status in
      let%bind failure_reasons =
        Option.value_map block_zkapp_cmd.failure_reasons_ids
          ~default:(return None) ~f:(fun ids ->
            let%map display =
              Deferred.List.map (Array.to_list ids) ~f:(fun id ->
                  let%map { index; failures } =
                    query_db ~f:(fun db ->
                        Processor.Zkapp_account_update_failures.load db id )
                  in
                  ( index
                  , List.map (Array.to_list failures) ~f:(fun s ->
                        match Transaction_status.Failure.of_string s with
                        | Ok failure ->
                            failure
                        | Error err ->
                            failwithf
                              "Invalid account update transaction status, \
                               error: %s"
                              err () ) ) )
            in
            Some display )
      in

      return
        { Extensional.Zkapp_command.sequence_no
        ; fee_payer
        ; account_updates
        ; memo
        ; hash
        ; status
        ; failure_reasons
        } )

let check_state_hash ~logger state_hash_opt =
  match state_hash_opt with
  | None ->
      ()
  | Some state_hash -> (
      match State_hash.of_base58_check state_hash with
      | Ok _ ->
          ()
      | Error err ->
          [%log error] "Error decoding state hash"
            ~metadata:
              [ ("state_hash", `String state_hash)
              ; ("error", Error_json.error_to_yojson err)
              ] ;
          Core.exit 1 )

let main ~archive_uri ~start_state_hash_opt ~end_state_hash_opt ~all_blocks () =
  ( match (start_state_hash_opt, end_state_hash_opt, all_blocks) with
  | None, None, true | None, Some _, false | Some _, Some _, false ->
      ()
  | Some _, None, true ->
      failwith "If --all-blocks is given, do not also give --start-state-hash"
  | _, None, false | _, Some _, true ->
      failwith "Must specify exactly one of --end-state-hash and --all-blocks"
  ) ;
  let logger = Logger.create () in
  let archive_uri = Uri.of_string archive_uri in
  (* sanity-check input state hashes *)
  check_state_hash ~logger start_state_hash_opt ;
  check_state_hash ~logger end_state_hash_opt ;
  match Caqti_async.connect_pool ~max_size:128 archive_uri with
  | Error e ->
      [%log fatal]
        ~metadata:[ ("error", `String (Caqti_error.show e)) ]
        "Failed to create a Caqti pool for Postgresql" ;
      exit 1
  | Ok pool ->
      let query_db = Mina_caqti.query pool in

      [%log info] "Successfully created Caqti pool for Postgresql" ;
      let%bind blocks =
        if all_blocks then (
          [%log info] "Querying for all blocks" ;
          query_db ~f:(fun db -> Sql.Subchain.all_blocks db) )
        else
          match (start_state_hash_opt, end_state_hash_opt) with
          | None, Some end_state_hash ->
              [%log info]
                "Querying for subchain to end block with given state hash" ;
              let%map blocks =
                query_db ~f:(fun db ->
                    Sql.Subchain.start_from_unparented db ~end_state_hash )
              in
              let end_block_found =
                List.exists blocks ~f:(fun block ->
                    String.equal block.state_hash end_state_hash )
              in
              if not end_block_found then (
                [%log error]
                  "No subchain available from an unparented block (possibly \
                   the genesis block) to block with given end state hash" ;
                Core.exit 1 ) ;
              blocks
          | Some start_state_hash, Some end_state_hash ->
              [%log info]
                "Querying for subchain from start block to end block with \
                 given state hashes" ;
              let%map blocks =
                query_db ~f:(fun db ->
                    Sql.Subchain.start_from_specified db ~start_state_hash
                      ~end_state_hash )
              in
              let start_block_found =
                List.exists blocks ~f:(fun block ->
                    String.equal block.state_hash start_state_hash )
              in
              let end_block_found =
                List.exists blocks ~f:(fun block ->
                    String.equal block.state_hash end_state_hash )
              in
              if not (start_block_found && end_block_found) then (
                [%log error]
                  "No subchain with given start and end state hashes \
                   available; try omitting the start state hash, to get a \
                   chain from an unparented block to the block with the end \
                   state hash" ;
                Core.exit 1 ) ;
              blocks
          | _ ->
              (* unreachable *)
              failwith "Unexpected flag combination"
      in
      let%bind extensional_blocks =
        Deferred.List.map blocks ~f:(fill_in_block pool)
      in
      let num_blocks = List.length extensional_blocks in
      if all_blocks then [%log info] "Found %d blocks" num_blocks
      else [%log info] "Found a subchain of length %d" num_blocks ;
      [%log info] "Querying for user commands in blocks" ;
      let%bind blocks_with_user_cmds =
        Deferred.List.map extensional_blocks ~f:(fun block ->
            let%map unsorted_user_cmds =
              fill_in_user_commands pool block.state_hash
            in
            (* sort, to give block a canonical representation *)
            let user_cmds =
              List.sort unsorted_user_cmds
                ~compare:(fun (cmd1 : Extensional.User_command.t) cmd2 ->
                  Int.compare cmd1.sequence_no cmd2.sequence_no )
            in
            { block with user_cmds } )
      in
      [%log info] "Querying for internal commands in blocks" ;
      let%bind blocks_with_internal_cmds =
        Deferred.List.map blocks_with_user_cmds ~f:(fun block ->
            let%map unsorted_internal_cmds =
              fill_in_internal_commands pool block.state_hash
            in
            (* sort, to give block a canonical representation *)
            let internal_cmds =
              List.sort unsorted_internal_cmds
                ~compare:(fun (cmd1 : Extensional.Internal_command.t) cmd2 ->
                  [%compare: int * int]
                    (cmd1.sequence_no, cmd1.secondary_sequence_no)
                    (cmd2.sequence_no, cmd2.secondary_sequence_no) )
            in
            { block with internal_cmds } )
      in
      [%log info] "Querying for zkapp commands in blocks" ;
      let%bind blocks_with_zkapp_cmds =
        Deferred.List.map blocks_with_internal_cmds ~f:(fun block ->
            let%map unsorted_zkapp_cmds =
              fill_in_zkapp_commands pool block.state_hash
            in
            (* sort, to give block a canonical representation *)
            let zkapp_cmds =
              List.sort unsorted_zkapp_cmds
                ~compare:(fun (cmd1 : Extensional.Zkapp_command.t) cmd2 ->
                  Int.compare cmd1.sequence_no cmd2.sequence_no )
            in
            { block with zkapp_cmds } )
      in
      [%log info] "Querying for accounts accessed in blocks" ;
      let%bind blocks_with_accounts_accessed =
        Deferred.List.map blocks_with_zkapp_cmds ~f:(fun block ->
            let%map accounts_accessed =
              fill_in_accounts_accessed pool block.state_hash
            in
            { block with accounts_accessed } )
      in
      [%log info] "Querying for accounts created in blocks" ;
      let%bind blocks_with_accounts_created =
        Deferred.List.map blocks_with_accounts_accessed ~f:(fun block ->
            let%map accounts_created =
              fill_in_accounts_created pool block.state_hash
            in
            { block with accounts_created } )
      in
      [%log info] "Querying for tokens used in blocks" ;
      let%bind blocks_with_accounts_created =
        Deferred.List.map blocks_with_accounts_created ~f:(fun block ->
            let%map tokens_used = fill_in_tokens_used pool block.state_hash in
            { block with tokens_used } )
      in
      [%log info] "Writing blocks" ;
      let%map () =
        Deferred.List.iter blocks_with_accounts_created ~f:(fun block ->
            [%log info] "Writing block with $state_hash"
              ~metadata:
                [ ("state_hash", State_hash.to_yojson block.state_hash) ] ;
            let output_file =
              State_hash.to_base58_check block.state_hash ^ ".json"
            in
            (* use Latest.to_yojson to get versioned JSON *)
            Async_unix.Writer.with_file output_file ~f:(fun writer ->
                return
                  (Async.fprintf writer "%s\n%!"
                     ( Extensional.Block.Stable.Latest.to_yojson block
                     |> Yojson.Safe.pretty_to_string ) ) ) )
      in
      ()

let () =
  Command.(
    run
      (let open Let_syntax in
      async
        ~summary:
          "Extract blocks from an archive db, either all blocks, or from a \
           subchain"
        (let%map archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER@localhost:5432/archiver)"
             Param.(required string)
         and start_state_hash_opt =
           Param.flag "--start-state-hash"
             ~doc:
               "State hash of the block that begins a chain (default: start at \
                the block closest to the end block without a parent, possibly \
                the genesis block)"
             Param.(optional string)
         and end_state_hash_opt =
           Param.flag "--end-state-hash"
             ~doc:"State hash of the block that ends a chain"
             Param.(optional string)
         and all_blocks =
           Param.flag "--all-blocks" Param.no_arg
             ~doc:"Extract all blocks in the archive database"
         in
         main ~archive_uri ~start_state_hash_opt ~end_state_hash_opt ~all_blocks
        )))
