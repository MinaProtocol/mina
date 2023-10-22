(* berkeley_migration.ml -- migrate archive db from original Mina mainnet to berkeley schema *)

open Core_kernel
open Async

(* before running this program for the first time, import the berkeley schema to the
   migrated database name
*)

(* TODO: table of old, new txn hashes *)

let mainnet_transaction_failure_of_string s :
    Mina_base.Transaction_status.Failure.t =
  match s with
  | "Predicate" ->
      Predicate
  | "Source_not_present" ->
      Source_not_present
  | "Receiver_not_present" ->
      Receiver_not_present
  | "Amount_insufficient_to_create_account" ->
      Amount_insufficient_to_create_account
  | "Cannot_pay_creation_fee_in_token" ->
      Cannot_pay_creation_fee_in_token
  | "Source_insufficient_balance" ->
      Source_insufficient_balance
  | "Source_minimum_balance_violation" ->
      Source_minimum_balance_violation
  | "Receiver_already_exists" ->
      Receiver_already_exists
  | "Overflow" ->
      Overflow
  | "Incorrect_nonce" ->
      Incorrect_nonce
  (* these should never have occurred *)
  | "Signed_command_on_snapp_account"
  | "Not_token_owner"
  | "Snapp_account_not_present"
  | "Update_not_permitted" ->
      failwith "Transaction failure unrepresentable in Berkeley"
  | _ ->
      failwith "No such transaction failure"

let get_created paid pk =
  match paid with
  | None ->
      []
  | Some fee ->
      let acct_id = Mina_base.Account_id.create pk Mina_base.Token_id.default in
      [ (acct_id, Unsigned.UInt64.of_int64 fee |> Currency.Fee.of_uint64) ]

let internal_commands_from_block_id ~mainnet_pool block_id =
  let query_mainnet_db ~f = Mina_caqti.query ~f mainnet_pool in
  let pk_of_id id =
    let%map pk_str =
      query_mainnet_db ~f:(fun db -> Sql.Mainnet.Public_key.find_by_id db id)
    in
    Signature_lib.Public_key.Compressed.of_base58_check_exn pk_str
  in
  let%bind block_internal_cmds =
    query_mainnet_db ~f:(fun db ->
        Sql.Mainnet.Block_internal_command.load_block db ~block_id )
  in
  Deferred.List.fold block_internal_cmds ~init:([], [])
    ~f:(fun (created, cmds) block_internal_cmd ->
      let%bind internal_cmd =
        query_mainnet_db ~f:(fun db ->
            Sql.Mainnet.Internal_command.load db
              ~id:block_internal_cmd.internal_command_id )
      in
      (* some fields come from blocks_internal_commands, others from user_commands *)
      let sequence_no = block_internal_cmd.sequence_no in
      let secondary_sequence_no = block_internal_cmd.secondary_sequence_no in
      let command_type = internal_cmd.typ in
      let%bind receiver = pk_of_id internal_cmd.receiver_id in
      let fee =
        internal_cmd.fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
      in
      let hash =
        match command_type with
        | "coinbase" ->
            let coinbase =
              (* always valid, since fee transfer is None *)
              let amount = Currency.Amount.of_fee fee in
              Mina_base.Coinbase.create ~amount ~receiver ~fee_transfer:None
              |> Or_error.ok_exn
            in
            Mina_transaction.Transaction_hash.hash_coinbase coinbase
        | "fee_transfer" | "fee_transfer_via_coinbase" -> (
            let fee_transfer =
              Mina_base.Fee_transfer.create_single ~receiver_pk:receiver ~fee
                ~fee_token:Mina_base.Token_id.default
            in
            match Mina_base.Fee_transfer.to_singles fee_transfer with
            | `One single ->
                Mina_transaction.Transaction_hash.hash_fee_transfer single
            | `Two _ ->
                failwith "Expected one single in fee transfer" )
        | s ->
            failwithf "Unknown command type %s" s ()
      in
      let status = "applied" in
      let failure_reason = None in
      let cmd : Archive_lib.Extensional.Internal_command.t =
        { sequence_no
        ; secondary_sequence_no
        ; command_type
        ; receiver
        ; fee
        ; hash
        ; status
        ; failure_reason
        }
      in
      let created_by_cmd =
        get_created block_internal_cmd.receiver_account_creation_fee_paid
          receiver
      in
      return (created_by_cmd @ created, cmd :: cmds) )

let user_commands_from_block_id ~mainnet_pool block_id =
  let query_mainnet_db ~f = Mina_caqti.query ~f mainnet_pool in
  let%bind block_user_cmds =
    query_mainnet_db ~f:(fun db ->
        Sql.Mainnet.Block_user_command.load_block db ~block_id )
  in
  let pk_of_id id =
    let%map pk_str =
      query_mainnet_db ~f:(fun db -> Sql.Mainnet.Public_key.find_by_id db id)
    in
    Signature_lib.Public_key.Compressed.of_base58_check_exn pk_str
  in
  Deferred.List.fold block_user_cmds ~init:([], [])
    ~f:(fun (created, cmds) block_user_cmd ->
      let%bind user_cmd =
        query_mainnet_db ~f:(fun db ->
            Sql.Mainnet.User_command.load db ~id:block_user_cmd.user_command_id )
      in
      (* some fields come from blocks_user_commands, others from user_commands *)
      let sequence_no = block_user_cmd.sequence_no in
      let command_type = user_cmd.typ in
      let%bind fee_payer = pk_of_id user_cmd.fee_payer_id in
      let%bind source = pk_of_id user_cmd.source_id in
      let%bind receiver = pk_of_id user_cmd.receiver_id in
      let nonce = Mina_numbers.Account_nonce.of_int user_cmd.nonce in
      let amount =
        Option.map user_cmd.amount ~f:(fun amount ->
            Unsigned.UInt64.of_int64 amount |> Currency.Amount.of_uint64 )
      in
      let fee =
        user_cmd.fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
      in
      let valid_until =
        Option.map user_cmd.valid_until ~f:(fun valid_until ->
            Unsigned.UInt32.of_int64 valid_until
            |> Mina_numbers.Global_slot_since_genesis.of_uint32 )
      in
      let memo =
        Mina_base.Signed_command_memo.of_base58_check_exn user_cmd.memo
      in
      let status = block_user_cmd.status in
      let failure_reason =
        Option.map block_user_cmd.failure_reason
          ~f:mainnet_transaction_failure_of_string
      in
      (* a V2 signed command *)
      let signed_cmd =
        let payload =
          let body =
            match command_type with
            | "payment" ->
                let amount = Option.value_exn amount in
                Mina_base.Signed_command_payload.Body.Payment
                  { receiver_pk = receiver; amount }
            | "delegation" ->
                let set_delegate =
                  Mina_base.Stake_delegation.Set_delegate
                    { new_delegate = receiver }
                in
                Mina_base.Signed_command_payload.Body.Stake_delegation
                  set_delegate
            | s ->
                failwithf "Unknown command type: %s" s ()
          in
          Mina_base.Signed_command_payload.create ~fee ~fee_payer_pk:fee_payer
            ~nonce ~valid_until ~memo ~body
        in
        let signer = Signature_lib.Public_key.decompress_exn source in
        let signature = Mina_base.Signature.dummy in
        ({ payload; signer; signature } : Mina_base.Signed_command.t)
      in
      let hash =
        Mina_transaction.Transaction_hash.hash_signed_command signed_cmd
      in
      let cmd : Archive_lib.Extensional.User_command.t =
        { sequence_no
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
        }
      in
      let created_by_cmd =
        let fee_payer_created =
          get_created block_user_cmd.fee_payer_account_creation_fee_paid
            fee_payer
        in
        let receiver_created =
          get_created block_user_cmd.receiver_account_creation_fee_paid receiver
        in
        fee_payer_created @ receiver_created
      in
      return (created_by_cmd @ created, cmd :: cmds) )

let first_batch = ref true

let mainnet_protocol_version =
  Protocol_version.create ~transaction:2 ~network:1 ~patch:0

let mainnet_block_to_extensional ~logger ~mainnet_pool
    ~(genesis_block : Mina_block.t) (block : Sql.Mainnet.Block.t) =
  let query_mainnet_db ~f = Mina_caqti.query ~f mainnet_pool in
  let is_genesis_block = Int64.equal block.height Int64.one in
  let genesis_consensus_state =
    lazy
      (let protocol_state =
         Mina_block.Header.protocol_state (Mina_block.header genesis_block)
       in
       let body = Mina_state.Protocol_state.body protocol_state in
       Mina_state.Protocol_state.Body.consensus_state body )
  in
  let%bind () =
    (* we may try to be fetching more blocks than exist
       gsutil seems to get the ones that do exist, in that exist
    *)
    let batch_size = 1000L in
    if is_genesis_block then Deferred.unit
    else if !first_batch then (
      let num_blocks = Int64.(batch_size - (block.height % batch_size)) in
      [%log info] "Fetching first batch of precomputed blocks"
        ~metadata:
          [ ("height", `Int (Int64.to_int_exn block.height))
          ; ("num_blocks", `Int (Int64.to_int_exn num_blocks))
          ] ;
      let%bind () =
        Precomputed_block.fetch_batch ~height:block.height ~num_blocks
      in
      [%log info] "Done fetching first batch of precomputed blocks" ;
      first_batch := false ;
      Deferred.unit )
    else if Int64.(equal (block.height % batch_size)) 0L then (
      [%log info] "Deleting all precomputed blocks" ;
      let%bind () = Precomputed_block.delete_fetched () in
      [%log info] "Fetching batch of precomputed blocks"
        ~metadata:
          [ ("height", `Int (Int64.to_int_exn block.height))
          ; ("num_blocks", `Int (Int64.to_int_exn batch_size))
          ] ;
      let%bind () =
        Precomputed_block.fetch_batch ~height:block.height
          ~num_blocks:batch_size
      in
      [%log info] "Done fetching batch of precomputed blocks" ;
      Deferred.unit )
    else Deferred.unit
  in
  let pk_of_id id =
    let%map pk_str =
      query_mainnet_db ~f:(fun db -> Sql.Mainnet.Public_key.find_by_id db id)
    in
    Signature_lib.Public_key.Compressed.of_base58_check_exn pk_str
  in
  let state_hash = Mina_base.State_hash.of_base58_check_exn block.state_hash in
  let parent_hash =
    Mina_base.State_hash.of_base58_check_exn block.parent_hash
  in
  let%bind creator = pk_of_id block.creator_id in
  let%bind block_winner = pk_of_id block.block_winner_id in
  let%bind last_vrf_output =
    (* the unencoded string, not base64 *)
    if is_genesis_block then
      let consensus = Lazy.force genesis_consensus_state in
      return @@ Consensus.Data.Consensus_state.last_vrf_output consensus
    else
      let%map json =
        Precomputed_block.last_vrf_output ~state_hash:block.state_hash
          ~height:block.height
      in
      Consensus_vrf.Output.Truncated.of_yojson json |> Result.ok_or_failwith
  in
  let%bind snarked_ledger_hash =
    let%map hash_str =
      query_mainnet_db ~f:(fun db ->
          Sql.Mainnet.Snarked_ledger_hash.find_by_id db
            block.snarked_ledger_hash_id )
    in
    Mina_base.Frozen_ledger_hash.of_base58_check_exn hash_str
  in
  (* TODO: confirm these match mainnet db ? *)
  let%bind staking_epoch_data =
    if is_genesis_block then
      let consensus = Lazy.force genesis_consensus_state in
      return @@ Consensus.Data.Consensus_state.staking_epoch_data consensus
    else
      let%map json =
        Precomputed_block.staking_epoch_data ~state_hash:block.state_hash
          ~height:block.height
      in
      match Mina_base.Epoch_data.Value.of_yojson json with
      | Ok epoch_data ->
          epoch_data
      | Error err ->
          failwithf "Could not get staking epoch data, error: %s" err ()
  in
  let%bind next_epoch_data =
    if is_genesis_block then
      let consensus = Lazy.force genesis_consensus_state in
      return @@ Consensus.Data.Consensus_state.next_epoch_data consensus
    else
      let%map json =
        Precomputed_block.next_epoch_data ~state_hash:block.state_hash
          ~height:block.height
      in
      match Mina_base.Epoch_data.Value.of_yojson json with
      | Ok epoch_data ->
          epoch_data
      | Error err ->
          failwithf "Could not get next epoch data, error: %s" err ()
  in
  let%bind min_window_density =
    if is_genesis_block then
      let consensus = Lazy.force genesis_consensus_state in
      return @@ Consensus.Data.Consensus_state.min_window_density consensus
    else
      match%map
        Precomputed_block.min_window_density ~state_hash:block.state_hash
          ~height:block.height
      with
      | `String s ->
          Mina_numbers.Length.of_string s
      | _ ->
          failwith "min_window_density: unexpected JSON"
  in
  let%bind total_currency =
    if is_genesis_block then
      let consensus = Lazy.force genesis_consensus_state in
      return @@ Consensus.Data.Consensus_state.total_currency consensus
    else
      match%map
        Precomputed_block.total_currency ~state_hash:block.state_hash
          ~height:block.height
      with
      | `String s ->
          Currency.Amount.of_string s
      | _ ->
          failwith "total currency: unexpected JSON"
  in
  let%bind sub_window_densities =
    if is_genesis_block then
      let consensus = Lazy.force genesis_consensus_state in
      return @@ Consensus.Data.Consensus_state.sub_window_densities consensus
    else
      match%map
        Precomputed_block.subwindow_densities ~state_hash:block.state_hash
          ~height:block.height
      with
      | `List items ->
          List.map items ~f:(function
            | `String s ->
                Mina_numbers.Length.of_string s
            | _ ->
                failwith "Expected string for subwindow density" )
      | _ ->
          failwith "sub_window_densities: unexpected JSON"
  in
  let ledger_hash =
    Mina_base.Frozen_ledger_hash.of_base58_check_exn block.ledger_hash
  in
  let height = Unsigned.UInt32.of_int64 block.height in
  let global_slot_since_hard_fork =
    block.global_slot_since_hard_fork |> Unsigned.UInt32.of_int64
    |> Mina_numbers.Global_slot_since_hard_fork.of_uint32
  in
  let global_slot_since_genesis =
    block.global_slot_since_genesis |> Unsigned.UInt32.of_int64
    |> Mina_numbers.Global_slot_since_genesis.of_uint32
  in
  let timestamp = Block_time.of_int64 block.timestamp in
  let%bind block_id =
    query_mainnet_db ~f:(fun db ->
        Sql.Mainnet.Block.id_from_state_hash db block.state_hash )
  in
  let%bind user_accounts_created, user_cmds_rev =
    user_commands_from_block_id ~mainnet_pool block_id
  in
  let user_cmds = List.rev user_cmds_rev in
  let%bind internal_accounts_created, internal_cmds_rev =
    internal_commands_from_block_id ~mainnet_pool block_id
  in
  let internal_cmds = List.rev internal_cmds_rev in
  let accounts_created = user_accounts_created @ internal_accounts_created in
  let zkapp_cmds = [] in
  let protocol_version = mainnet_protocol_version in
  let proposed_protocol_version = None in
  let chain_status = Archive_lib.Chain_status.of_string block.chain_status in
  (* always the default token *)
  let tokens_used =
    if is_genesis_block then [] else [ (Mina_base.Token_id.default, None) ]
  in
  return
    ( { state_hash
      ; parent_hash
      ; creator
      ; block_winner
      ; last_vrf_output
      ; snarked_ledger_hash
      ; staking_epoch_data
      ; next_epoch_data
      ; min_window_density
      ; total_currency
      ; sub_window_densities
      ; ledger_hash
      ; height
      ; global_slot_since_hard_fork
      ; global_slot_since_genesis
      ; timestamp
      ; user_cmds
      ; internal_cmds
      ; zkapp_cmds
      ; protocol_version
      ; proposed_protocol_version
      ; chain_status
      ; accounts_accessed = []
      ; accounts_created
      ; tokens_used
      }
      : Archive_lib.Extensional.Block.t )

let main ~mainnet_archive_uri ~migrated_archive_uri ~runtime_config_file
    ~end_global_slot () =
  let logger = Logger.create () in
  let mainnet_archive_uri = Uri.of_string mainnet_archive_uri in
  let migrated_archive_uri = Uri.of_string migrated_archive_uri in
  let mainnet_pool =
    Caqti_async.connect_pool ~max_size:128 mainnet_archive_uri
  in
  let migrated_pool =
    Caqti_async.connect_pool ~max_size:128 migrated_archive_uri
  in
  match (mainnet_pool, migrated_pool) with
  | Error e, _ | _, Error e ->
      [%log fatal]
        ~metadata:[ ("error", `String (Caqti_error.show e)) ]
        "Failed to create Caqti pools for Postgresql" ;
      exit 1
  | Ok mainnet_pool, Ok migrated_pool ->
      [%log info] "Successfully created Caqti pools for databases" ;
      (* use Processor to write to migrated db; separate code to read from mainnet db *)
      let query_mainnet_db ~f = Mina_caqti.query ~f mainnet_pool in
      let query_migrated_db ~f = Mina_caqti.query ~f migrated_pool in
      let runtime_config =
        Yojson.Safe.from_file runtime_config_file
        |> Runtime_config.of_yojson |> Result.ok_or_failwith
      in
      [%log info] "Getting precomputed values from runtime config" ;
      let proof_level = Genesis_constants.Proof_level.compiled in
      let%bind precomputed_values =
        match%map
          Genesis_ledger_helper.init_from_config_file ~logger
            ~proof_level:(Some proof_level) runtime_config
        with
        | Ok (precomputed_values, _) ->
            precomputed_values
        | Error err ->
            failwithf "Could not get precomputed values, error: %s"
              (Error.to_string_hum err) ()
      in
      [%log info] "Got precomputed values from runtime config" ;
      let With_hash.{ data = genesis_block; _ }, _validation =
        Mina_block.genesis ~precomputed_values
      in
      let%bind mainnet_block_ids =
        match end_global_slot with
        | None ->
            [%log info] "Querying mainnet canonical blocks" ;
            query_mainnet_db ~f:(fun db ->
                Sql.Mainnet.Block.canonical_blocks db () )
        | Some slot ->
            [%log info]
              "Querying mainnet blocks at or below global slot since genesis \
               %d (but not orphaned blocks)"
              slot ;
            query_mainnet_db ~f:(fun db ->
                Sql.Mainnet.Block.blocks_at_or_below db slot )
      in
      [%log info] "Found %d mainnet blocks" (List.length mainnet_block_ids) ;
      let%bind mainnet_blocks_unsorted =
        Deferred.List.map mainnet_block_ids ~f:(fun id ->
            query_mainnet_db ~f:(fun db -> Sql.Mainnet.Block.load db ~id) )
      in
      (* remove blocks we've already migrated *)
      let%bind greatest_migrated_height =
        let%bind count =
          query_migrated_db ~f:(fun db -> Sql.Berkeley.Block.count db ())
        in
        if count = 0 then return Int64.zero
        else
          query_migrated_db ~f:(fun db ->
              Sql.Berkeley.Block.greatest_block_height db () )
      in
      if Int64.is_positive greatest_migrated_height then
        [%log info]
          "Already migrated blocks through height %Ld, resuming migration"
          greatest_migrated_height ;
      let mainnet_blocks_unmigrated =
        if Int64.equal greatest_migrated_height Int64.zero then
          mainnet_blocks_unsorted
        else
          List.filter mainnet_blocks_unsorted ~f:(fun block ->
              Int64.( > ) block.height greatest_migrated_height )
      in
      [%log info] "Will migrate %d mainnet blocks"
        (List.length mainnet_blocks_unmigrated) ;
      (* blocks in height order *)
      let mainnet_blocks_to_migrate =
        List.sort mainnet_blocks_unmigrated ~compare:(fun block1 block2 ->
            Int64.compare block1.height block2.height )
      in
      [%log info] "Migrating mainnet blocks" ;
      let%bind () =
        Deferred.List.iter mainnet_blocks_to_migrate ~f:(fun block ->
            [%log info]
              "Migrating mainnet block at height %Ld with state hash %s"
              block.height block.state_hash ;
            let%bind extensional_block =
              mainnet_block_to_extensional ~logger ~mainnet_pool ~genesis_block
                block
            in
            query_migrated_db ~f:(fun db ->
                match%map
                  Archive_lib.Processor.Block.add_from_extensional db
                    extensional_block
                with
                | Ok _id ->
                    Ok ()
                | Error err ->
                    failwithf
                      "Could not archive extensional block from mainnet block \
                       with state hash %s, error: %s"
                      block.state_hash (Caqti_error.show err) () ) )
      in
      [%log info] "Deleting all precomputed blocks" ;
      let%bind () = Precomputed_block.delete_fetched () in
      [%log info] "Done migrating mainnet blocks!" ;
      Deferred.unit

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async
        ~summary:"Migrate mainnet archive database to Berkeley schema"
        (let%map mainnet_archive_uri =
           Param.flag "--mainnet-archive-uri"
             ~doc:"URI URI for connecting to the mainnet archive database"
             Param.(required string)
         and migrated_archive_uri =
           Param.flag "--migrated-archive-uri"
             ~doc:"URI URI for connecting to the migrated archive database"
             Param.(required string)
         and runtime_config_file =
           Param.flag "--config-file" ~aliases:[ "-config-file" ]
             Param.(required string)
             ~doc:
               "PATH to the configuration file containing the berkeley genesis \
                ledger"
         and end_global_slot =
           Param.flag "--end-global-slot" ~aliases:[ "-end-global-slot" ]
             Param.(optional int)
             ~doc:
               "NN Last global slot since genesis to include in the migration \
                (if omitted, only canonical blocks will be migrated)"
         in
         main ~mainnet_archive_uri ~migrated_archive_uri ~runtime_config_file
           ~end_global_slot )))
