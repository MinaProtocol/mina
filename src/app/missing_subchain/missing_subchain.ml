(* missing_subchain.ml -- report available missing subchain from archive db *)

open Core_kernel
open Async
open Mina_base
open Signature_lib
open Archive_lib

let query_db pool ~f ~item =
  match%bind Caqti_async.Pool.use f pool with
  | Ok v ->
      return v
  | Error msg ->
      failwithf "Error getting %s from db, error: %s" item
        (Caqti_error.show msg) ()

let fill_in_block pool (block : Archive_lib.Processor.Block.t) :
    Extensional.Block.t Deferred.t =
  let query_db ~item ~f = query_db pool ~item ~f in
  let state_hash = State_hash.of_base58_check_exn block.state_hash in
  let parent_hash = State_hash.of_base58_check_exn block.parent_hash in
  let open Deferred.Let_syntax in
  let%bind creator_str =
    query_db
      ~f:(fun db -> Sql.Public_key.run db block.creator_id)
      ~item:"creator public key"
  in
  let creator = Public_key.Compressed.of_base58_check_exn creator_str in
  let%bind block_winner_str =
    query_db
      ~f:(fun db -> Sql.Public_key.run db block.creator_id)
      ~item:"block winner public key"
  in
  let block_winner =
    Public_key.Compressed.of_base58_check_exn block_winner_str
  in
  let%bind snarked_ledger_hash_str =
    query_db
      ~f:(fun db ->
        Sql.Snarked_ledger_hashes.run db block.snarked_ledger_hash_id )
      ~item:"snarked ledger hash"
  in
  let snarked_ledger_hash =
    Frozen_ledger_hash.of_base58_check_exn snarked_ledger_hash_str
  in
  let%bind staking_epoch_seed_str, staking_epoch_ledger_hash_id =
    query_db
      ~f:(fun db -> Sql.Epoch_data.run db block.staking_epoch_data_id)
      ~item:"staking epoch data"
  in
  let staking_epoch_seed =
    Epoch_seed.of_base58_check_exn staking_epoch_seed_str
  in
  let%bind staking_epoch_ledger_hash_str =
    query_db
      ~f:(fun db ->
        Sql.Snarked_ledger_hashes.run db staking_epoch_ledger_hash_id )
      ~item:"staking epoch ledger hash"
  in
  let staking_epoch_ledger_hash =
    Frozen_ledger_hash.of_base58_check_exn staking_epoch_ledger_hash_str
  in
  let%bind next_epoch_seed_str, next_epoch_ledger_hash_id =
    query_db
      ~f:(fun db -> Sql.Epoch_data.run db block.next_epoch_data_id)
      ~item:"staking epoch data"
  in
  let next_epoch_seed = Epoch_seed.of_base58_check_exn next_epoch_seed_str in
  let%bind next_epoch_ledger_hash_str =
    query_db
      ~f:(fun db -> Sql.Snarked_ledger_hashes.run db next_epoch_ledger_hash_id)
      ~item:"next epoch ledger hash"
  in
  let next_epoch_ledger_hash =
    Frozen_ledger_hash.of_base58_check_exn next_epoch_ledger_hash_str
  in
  let ledger_hash = Ledger_hash.of_base58_check_exn block.ledger_hash in
  let height = Unsigned.UInt32.of_int64 block.height in
  let global_slot = Unsigned.UInt32.of_int64 block.global_slot in
  let global_slot_since_genesis =
    Unsigned.UInt32.of_int64 block.global_slot_since_genesis
  in
  let timestamp = Block_time.of_int64 block.timestamp in
  (* commands to be filled in later *)
  return
    { Extensional.Block.state_hash
    ; parent_hash
    ; creator
    ; block_winner
    ; snarked_ledger_hash
    ; staking_epoch_seed
    ; staking_epoch_ledger_hash
    ; next_epoch_seed
    ; next_epoch_ledger_hash
    ; ledger_hash
    ; height
    ; global_slot
    ; global_slot_since_genesis
    ; timestamp
    ; user_cmds= []
    ; internal_cmds= [] }

let fill_in_user_command pool block_state_hash =
  let query_db ~item ~f = query_db pool ~item ~f in
  let pk_of_id id ~item =
    let%map pk_str = query_db ~f:(fun db -> Sql.Public_key.run db id) ~item in
    Public_key.Compressed.of_base58_check_exn pk_str
  in
  let balance_of_id id ~item =
    let%map _pk_id, balance =
      query_db ~f:(fun db -> Processor.Balance.load db ~id) ~item
    in
    balance |> Unsigned.UInt64.of_int64 |> Currency.Balance.of_uint64
  in
  let balance_of_id_opt id_opt ~item =
    Option.value_map id_opt ~default:(Deferred.return None) ~f:(fun id ->
        let%map balance = balance_of_id id ~item in
        Some balance )
  in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~item:"blocks" ~f:(fun db ->
        Processor.Block.find db ~state_hash:block_state_hash )
  in
  let%bind user_command_ids_and_sequence_nos =
    query_db ~item:"user command id, sequence no" ~f:(fun db ->
        Sql.Blocks_and_user_commands.run db ~block_id )
  in
  (* create extensional user command for each id, seq no *)
  Deferred.List.map user_command_ids_and_sequence_nos
    ~f:(fun (user_command_id, sequence_no) ->
      let%bind user_cmd =
        query_db ~item:"user commands" ~f:(fun db ->
            Processor.User_command.Signed_command.load db ~id:user_command_id
        )
      in
      let typ = user_cmd.typ in
      let%bind fee_payer = pk_of_id ~item:"fee payer" user_cmd.fee_payer_id in
      let%bind source = pk_of_id ~item:"source" user_cmd.source_id in
      let%bind receiver = pk_of_id ~item:"receiver" user_cmd.receiver_id in
      let fee_token =
        user_cmd.fee_token |> Unsigned.UInt64.of_int64 |> Token_id.of_uint64
      in
      let token =
        user_cmd.token |> Unsigned.UInt64.of_int64 |> Token_id.of_uint64
      in
      let nonce = user_cmd.nonce |> Account.Nonce.of_int in
      let amount =
        Option.map user_cmd.amount ~f:(fun amt ->
            Unsigned.UInt64.of_int64 amt |> Currency.Amount.of_uint64 )
      in
      let fee =
        user_cmd.fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
      in
      let valid_until =
        Option.map user_cmd.valid_until ~f:(fun valid ->
            Unsigned.UInt32.of_int64 valid
            |> Mina_numbers.Global_slot.of_uint32 )
      in
      let memo = user_cmd.memo |> Signed_command_memo.of_string in
      let hash = user_cmd.hash |> Transaction_hash.of_base58_check_exn in
      let%bind block_user_cmd =
        query_db ~item:"block user commands" ~f:(fun db ->
            Processor.Block_and_signed_command.load db ~block_id
              ~user_command_id )
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
      let%bind source_balance =
        balance_of_id_opt block_user_cmd.source_balance_id
          ~item:"source balance"
      in
      let fee_payer_account_creation_fee_paid =
        Option.map block_user_cmd.fee_payer_account_creation_fee_paid
          ~f:(fun amt ->
            Unsigned.UInt64.of_int64 amt |> Currency.Amount.of_uint64 )
      in
      let%bind fee_payer_balance =
        balance_of_id block_user_cmd.fee_payer_balance_id
          ~item:"fee payer balance"
      in
      let receiver_account_creation_fee_paid =
        Option.map block_user_cmd.receiver_account_creation_fee_paid
          ~f:(fun amt ->
            Unsigned.UInt64.of_int64 amt |> Currency.Amount.of_uint64 )
      in
      let%bind receiver_balance =
        balance_of_id_opt block_user_cmd.receiver_balance_id
          ~item:"receiver balance"
      in
      let created_token =
        Option.map block_user_cmd.created_token ~f:(fun tok ->
            Unsigned.UInt64.of_int64 tok |> Token_id.of_uint64 )
      in
      return
        { Extensional.User_command.sequence_no
        ; typ
        ; fee_payer
        ; source
        ; receiver
        ; fee_token
        ; token
        ; nonce
        ; amount
        ; fee
        ; valid_until
        ; memo
        ; hash
        ; status
        ; failure_reason
        ; source_balance
        ; fee_payer_account_creation_fee_paid
        ; fee_payer_balance
        ; receiver_account_creation_fee_paid
        ; receiver_balance
        ; created_token } )

let fill_in_internal_command pool block_state_hash =
  let query_db ~item ~f = query_db pool ~item ~f in
  let pk_of_id id ~item =
    let%map pk_str = query_db ~f:(fun db -> Sql.Public_key.run db id) ~item in
    Public_key.Compressed.of_base58_check_exn pk_str
  in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~item:"blocks" ~f:(fun db ->
        Processor.Block.find db ~state_hash:block_state_hash )
  in
  let%bind internal_cmd_info =
    query_db
      ~item:
        "internal command id, global_slot, sequence no, secondary sequence \
         no, receiver_balance" ~f:(fun db ->
        Sql.Blocks_and_internal_commands.run db ~block_id )
  in
  Deferred.List.map internal_cmd_info
    ~f:(fun { internal_command_id
            ; global_slot
            ; sequence_no
            ; secondary_sequence_no
            ; receiver_balance }
       ->
      let receiver_balance =
        receiver_balance |> Unsigned.UInt64.of_int64
        |> Currency.Balance.of_uint64
      in
      (* pieces from the internal_commands table *)
      let%bind internal_cmd =
        query_db ~item:"blocks internal commands" ~f:(fun db ->
            Processor.Internal_command.load db ~id:internal_command_id )
      in
      let typ = internal_cmd.typ in
      let%bind receiver = pk_of_id ~item:"receiver" internal_cmd.receiver_id in
      let fee =
        internal_cmd.fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
      in
      let token =
        internal_cmd.token |> Unsigned.UInt64.of_int64 |> Token_id.of_uint64
      in
      let hash = internal_cmd.hash |> Transaction_hash.of_base58_check_exn in
      let cmd =
        { Extensional.Internal_command.sequence_no
        ; secondary_sequence_no
        ; typ
        ; receiver
        ; receiver_balance
        ; fee
        ; token
        ; hash }
      in
      ( if String.equal cmd.typ "fee_transfer_via_coinbase" then
        match
          Block.Fee_transfer_via_coinbase.Table.add Block.fee_transfer_tbl
            ~key:(global_slot, cmd.sequence_no, cmd.secondary_sequence_no)
            ~data:cmd
        with
        | `Ok ->
            ()
        | `Duplicate ->
            failwithf
              "Duplicate fee transfer via coinbase at global slot = %Ld, \
               sequence no = %d, secondary sequence no = %d"
              global_slot cmd.sequence_no cmd.secondary_sequence_no () ) ;
      return cmd )

let main ~archive_uri ~state_hash () =
  let logger = Logger.create () in
  let archive_uri = Uri.of_string archive_uri in
  (* sanity-check input state hash *)
  ( match State_hash.of_base58_check state_hash with
  | Ok _ ->
      ()
  | Error err ->
      [%log error] "Error decoding input state hash"
        ~metadata:[("error", Error_json.error_to_yojson err)] ;
      Core.exit 1 ) ;
  match Caqti_async.connect_pool ~max_size:128 archive_uri with
  | Error e ->
      [%log fatal]
        ~metadata:[("error", `String (Caqti_error.show e))]
        "Failed to create a Caqti pool for Postgresql" ;
      exit 1
  | Ok pool ->
      [%log info] "Successfully created Caqti pool for Postgresql" ;
      [%log info] "Querying for subchain to block with given state hash" ;
      let%bind blocks =
        query_db pool
          ~f:(fun db -> Sql.Subchain.run db state_hash)
          ~item:"blocks"
      in
      if List.is_empty blocks then (
        [%log error]
          "No subchain available from genesis block to block with given state \
           hash" ;
        Core.exit 1 ) ;
      let%bind extensional_blocks =
        Deferred.List.map blocks ~f:(fill_in_block pool)
      in
      [%log info] "Found a subchain of length %d"
        (List.length extensional_blocks) ;
      [%log info] "Querying for user commands in blocks" ;
      let%bind blocks_with_user_cmds =
        Deferred.List.map extensional_blocks ~f:(fun block ->
            let%map user_cmds = fill_in_user_command pool block.state_hash in
            {block with user_cmds} )
      in
      [%log info] "Querying for internal commands in blocks" ;
      let%bind blocks_with_all_cmds =
        Deferred.List.map blocks_with_user_cmds ~f:(fun block ->
            let%map internal_cmds =
              fill_in_internal_command pool block.state_hash
            in
            {block with internal_cmds} )
      in
      [%log info] "Writing blocks" ;
      let%map () =
        Deferred.List.iter blocks_with_all_cmds ~f:(fun block ->
            [%log info] "Writing block with $state_hash"
              ~metadata:[("state_hash", State_hash.to_yojson block.state_hash)] ;
            let output_file =
              State_hash.to_string block.state_hash ^ ".json"
            in
            Async_unix.Writer.with_file output_file ~f:(fun writer ->
                return
                  (Async.fprintf writer "%s\n%!"
                     ( Extensional.Block.to_yojson block
                     |> Yojson.Safe.pretty_to_string )) ) )
      in
      ()

let () =
  Command.(
    run
      (let open Let_syntax in
      async
        ~summary:
          "Report blocks in a subchain from the genesis block to a specific \
           block"
        (let%map archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER:$USER@localhost:5432/archiver)"
             Param.(required string)
         and state_hash =
           Param.flag "--state-hash"
             ~doc:
               "State hash of the block that ends a chain from the genesis \
                block"
             Param.(required string)
         in
         main ~archive_uri ~state_hash)))
