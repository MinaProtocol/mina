(* extract_blocks.ml -- dump extensional blocks from archive db *)

open Core_kernel
open Async
open Mina_base
open Mina_transaction
open Signature_lib
open Archive_lib

let query_db pool ~f ~item =
  match%bind Caqti_async.Pool.use f pool with
  | Ok v ->
      return v
  | Error msg ->
      failwithf "Error getting %s from db, error: %s" item
        (Caqti_error.show msg) ()

let epoch_data_of_raw_epoch_data ~pool (raw_epoch_data : Processor.Epoch_data.t)
    =
  let%bind hash_str =
    query_db pool
      ~f:(fun db ->
        Sql.Snarked_ledger_hashes.run db raw_epoch_data.ledger_hash_id)
      ~item:"epoch ledger hash"
  in
  let hash = Frozen_ledger_hash.of_base58_check_exn hash_str in
  let total_currency =
    raw_epoch_data.total_currency |> Unsigned.UInt64.of_int64
    |> Currency.Amount.of_uint64
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
      ~f:(fun db -> Sql.Public_key.run db block.block_winner_id)
      ~item:"block winner public key"
  in
  let block_winner =
    Public_key.Compressed.of_base58_check_exn block_winner_str
  in
  let%bind snarked_ledger_hash_str =
    query_db
      ~f:(fun db ->
        Sql.Snarked_ledger_hashes.run db block.snarked_ledger_hash_id)
      ~item:"snarked ledger hash"
  in
  let snarked_ledger_hash =
    Frozen_ledger_hash.of_base58_check_exn snarked_ledger_hash_str
  in
  let%bind staking_epoch_data_raw =
    query_db
      ~f:(fun db -> Processor.Epoch_data.load db block.staking_epoch_data_id)
      ~item:"staking epoch data"
  in
  let%bind staking_epoch_data =
    epoch_data_of_raw_epoch_data ~pool staking_epoch_data_raw
  in
  let%bind next_epoch_data_raw =
    query_db
      ~f:(fun db -> Processor.Epoch_data.load db block.next_epoch_data_id)
      ~item:"staking epoch data"
  in
  let%bind next_epoch_data =
    epoch_data_of_raw_epoch_data ~pool next_epoch_data_raw
  in
  let min_window_density =
    block.min_window_density |> Unsigned.UInt32.of_int64
    |> Mina_numbers.Length.of_uint32
  in
  let total_currency =
    Unsigned.UInt64.of_int64 block.total_currency |> Currency.Amount.of_uint64
  in
  let ledger_hash = Ledger_hash.of_base58_check_exn block.ledger_hash in
  let height = Unsigned.UInt32.of_int64 block.height in
  let global_slot_since_hard_fork =
    Unsigned.UInt32.of_int64 block.global_slot_since_hard_fork
  in
  let global_slot_since_genesis =
    Unsigned.UInt32.of_int64 block.global_slot_since_genesis
  in
  let timestamp = Block_time.of_int64 block.timestamp in
  let chain_status = Chain_status.of_string block.chain_status in
  (* commands, accounts_accessed, accounts_created to be filled in later *)
  return
    { Extensional.Block.state_hash
    ; parent_hash
    ; creator
    ; block_winner
    ; snarked_ledger_hash
    ; staking_epoch_data
    ; next_epoch_data
    ; min_window_density
    ; total_currency
    ; ledger_hash
    ; height
    ; global_slot_since_hard_fork
    ; global_slot_since_genesis
    ; timestamp
    ; user_cmds = []
    ; internal_cmds = []
    ; zkapp_cmds = []
    ; chain_status
    ; accounts_accessed = []
    ; accounts_created = []
    }

let fill_in_user_commands pool block_state_hash =
  let query_db ~item ~f = query_db pool ~item ~f in
  let pk_of_id id ~item =
    let%map pk_str = query_db ~f:(fun db -> Sql.Public_key.run db id) ~item in
    Public_key.Compressed.of_base58_check_exn pk_str
  in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~item:"blocks" ~f:(fun db ->
        Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind user_command_ids_and_sequence_nos =
    query_db ~item:"user command id, sequence no" ~f:(fun db ->
        Sql.Blocks_and_user_commands.run db ~block_id)
  in
  (* create extensional user command for each id, seq no *)
  Deferred.List.map user_command_ids_and_sequence_nos
    ~f:(fun (user_command_id, sequence_no) ->
      let%bind user_cmd =
        query_db ~item:"user commands" ~f:(fun db ->
            Processor.User_command.Signed_command.load db ~id:user_command_id)
      in
      let typ = user_cmd.typ in
      let%bind fee_payer = pk_of_id ~item:"fee payer" user_cmd.fee_payer_id in
      let%bind source = pk_of_id ~item:"source" user_cmd.source_id in
      let%bind receiver = pk_of_id ~item:"receiver" user_cmd.receiver_id in
      let fee_token = user_cmd.fee_token |> Token_id.of_string in
      let token = user_cmd.token |> Token_id.of_string in
      let nonce = user_cmd.nonce |> Account.Nonce.of_int in
      let amount =
        Option.map user_cmd.amount ~f:(fun amt ->
            Unsigned.UInt64.of_int64 amt |> Currency.Amount.of_uint64)
      in
      let fee =
        user_cmd.fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
      in
      let valid_until =
        Option.map user_cmd.valid_until ~f:(fun valid ->
            Unsigned.UInt32.of_int64 valid |> Mina_numbers.Global_slot.of_uint32)
      in
      let memo = user_cmd.memo |> Signed_command_memo.of_base58_check_exn in
      let hash = user_cmd.hash |> Transaction_hash.of_base58_check_exn in
      let%bind block_user_cmd =
        query_db ~item:"block user commands" ~f:(fun db ->
            Processor.Block_and_signed_command.load db ~block_id
              ~user_command_id ~sequence_no)
      in
      let status = block_user_cmd.status in
      let failure_reason =
        Option.map block_user_cmd.failure_reason ~f:(fun s ->
            match Transaction_status.Failure.of_string s with
            | Ok s ->
                s
            | Error err ->
                failwithf "Not a transaction status failure: %s, error: %s" s
                  err ())
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
        })

let fill_in_internal_commands pool block_state_hash =
  let query_db ~item ~f = query_db pool ~item ~f in
  let pk_of_id id ~item =
    let%map pk_str = query_db ~f:(fun db -> Sql.Public_key.run db id) ~item in
    Public_key.Compressed.of_base58_check_exn pk_str
  in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~item:"blocks" ~f:(fun db ->
        Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind internal_cmd_info =
    query_db
      ~item:
        "internal command id, global_slot, sequence no, secondary sequence no, \
         receiver_balance_id" ~f:(fun db ->
        Sql.Blocks_and_internal_commands.run db ~block_id)
  in
  Deferred.List.map internal_cmd_info
    ~f:(fun { internal_command_id; sequence_no; secondary_sequence_no } ->
      (* pieces from the internal_commands table *)
      let%bind internal_cmd =
        query_db ~item:"blocks internal commands" ~f:(fun db ->
            Processor.Internal_command.load db ~id:internal_command_id)
      in
      let typ = internal_cmd.typ in
      let%bind receiver = pk_of_id ~item:"receiver" internal_cmd.receiver_id in
      let fee =
        internal_cmd.fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
      in
      let token = internal_cmd.token |> Token_id.of_string in
      let hash = internal_cmd.hash |> Transaction_hash.of_base58_check_exn in
      let cmd =
        { Extensional.Internal_command.sequence_no
        ; secondary_sequence_no
        ; typ
        ; receiver
        ; fee
        ; token
        ; hash
        }
      in
      return cmd)

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
      [%log info] "Successfully created Caqti pool for Postgresql" ;
      let%bind blocks =
        if all_blocks then (
          [%log info] "Querying for all blocks" ;
          query_db pool
            ~f:(fun db -> Sql.Subchain.all_blocks db)
            ~item:"all blocks" )
        else
          match (start_state_hash_opt, end_state_hash_opt) with
          | None, Some end_state_hash ->
              [%log info]
                "Querying for subchain to end block with given state hash" ;
              let%map blocks =
                query_db pool
                  ~f:(fun db ->
                    Sql.Subchain.start_from_unparented db ~end_state_hash)
                  ~item:"blocks starting from unparented"
              in
              let end_block_found =
                List.exists blocks ~f:(fun block ->
                    String.equal block.state_hash end_state_hash)
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
                query_db pool
                  ~f:(fun db ->
                    Sql.Subchain.start_from_specified db ~start_state_hash
                      ~end_state_hash)
                  ~item:"blocks starting from specified"
              in
              let start_block_found =
                List.exists blocks ~f:(fun block ->
                    String.equal block.state_hash start_state_hash)
              in
              let end_block_found =
                List.exists blocks ~f:(fun block ->
                    String.equal block.state_hash end_state_hash)
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
                  Int.compare cmd1.sequence_no cmd2.sequence_no)
            in
            { block with user_cmds })
      in
      [%log info] "Querying for internal commands in blocks" ;
      let%bind blocks_with_all_cmds =
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
                    (cmd2.sequence_no, cmd2.secondary_sequence_no))
            in
            { block with internal_cmds })
      in
      [%log info] "Writing blocks" ;
      let%map () =
        Deferred.List.iter blocks_with_all_cmds ~f:(fun block ->
            [%log info] "Writing block with $state_hash"
              ~metadata:
                [ ("state_hash", State_hash.to_yojson block.state_hash) ] ;
            let output_file =
              State_hash.to_base58_check block.state_hash ^ ".json"
            in
            Async_unix.Writer.with_file output_file ~f:(fun writer ->
                return
                  (Async.fprintf writer "%s\n%!"
                     ( Extensional.Block.to_yojson block
                     |> Yojson.Safe.pretty_to_string ))))
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
         main ~archive_uri ~start_state_hash_opt ~end_state_hash_opt ~all_blocks)))
