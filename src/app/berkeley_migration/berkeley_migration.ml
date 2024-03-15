(* TODO: cleanup partial writes to blocks table introduced by bulk approach *)

(* berkeley_migration.ml -- migrate archive db from original Mina mainnet to berkeley schema *)

open Core_kernel
open Async
open Caqti_async

(* before running this program for the first time, import the berkeley schema to the
   migrated database name
*)

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
      (* some fields come from blocks_internal_commands, others from internal_commands *)
      let sequence_no = block_internal_cmd.sequence_no in
      let secondary_sequence_no = block_internal_cmd.secondary_sequence_no in
      let command_type = internal_cmd.typ in
      let%bind receiver = pk_of_id internal_cmd.receiver_id in
      let fee =
        internal_cmd.fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
      in
      let hash =
        Mina_transaction.Transaction_hash.of_base58_check_exn_v1
          internal_cmd.hash
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
      let hash =
        Mina_transaction.Transaction_hash.of_base58_check_exn_v1 user_cmd.hash
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
  (* It would be more accurate to posit distinct patches for each
     mainnet release, but it's sufficient to have a protocol version
     earlier than the berkeley hard fork protocol version. After the
     hard fork, the replayer won't check ledger hashes for blocks with
     an earlier protocol version.
  *)
  Protocol_version.create ~transaction:1 ~network:0 ~patch:0

let compare_user_cmd_seq (a : Archive_lib.Extensional.User_command.t) (b : Archive_lib.Extensional.User_command.t) : int =
  Int.compare a.sequence_no b.sequence_no

let compare_internal_cmd_seq (a : Archive_lib.Extensional.Internal_command.t) (b : Archive_lib.Extensional.Internal_command.t) : int =
  Tuple2.compare ~cmp1:Int.compare ~cmp2:Int.compare (a.sequence_no, a.secondary_sequence_no) (b.sequence_no, b.secondary_sequence_no)

let mainnet_block_to_extensional_batch ~logger ~mainnet_pool ~precomputed_blocks
    ~(genesis_block : Mina_block.t) (blocks : Sql.Mainnet.Block.t list)
    : Archive_lib.Extensional.Block.t list Deferred.t =
  let module Blockchain_state = Mina_state.Blockchain_state in
  let module Consensus_state = Consensus.Data.Consensus_state in

  let query_mainnet_db ~f = Mina_caqti.query ~f mainnet_pool in

  (*
  [%log info] "Deleting all precomputed blocks" ;
  let%bind () = Precomputed_block.delete_fetched ~network in
  *)

  (*
  [%log info] "Fetching batch of precomputed blocks" ;
  let%bind precomputed_blocks =
    List.filter blocks ~f:(fun block -> Int64.(block.height > 1L))
    |> List.map ~f:(fun block -> (block.height, block.state_hash))
    |> Precomputed_block.concrete_fetch_batch ~network ~bucket
  in
  [%log info] "Done fetching batch of precomputed blocks" ;
  *)

  [%log info] "Fetching transaction sequence from prior database" ;
  let%bind block_user_cmds =
    query_mainnet_db ~f:(fun (module Conn : CONNECTION) ->
      Conn.collect_list
        (Caqti_request.collect Caqti_type.unit (Caqti_type.tup2 Sql.Mainnet.User_command.typ Sql.Mainnet.Block_user_command.typ)
          (sprintf "SELECT %s, %s FROM %s AS c JOIN %s AS j ON c.id = j.user_command_id AND j.block_id IN (%s)"
            (String.concat ~sep:"," Sql.Mainnet.User_command.field_names)
            (String.concat ~sep:"," Sql.Mainnet.Block_user_command.Fields.names)
            Sql.Mainnet.User_command.table_name
            Sql.Mainnet.Block_user_command.table_name
            (String.concat ~sep:"," @@ List.map blocks ~f:(fun block -> Int.to_string block.id))))
        ())
  in
  let%bind block_internal_cmds =
    query_mainnet_db ~f:(fun (module Conn : CONNECTION) ->
      Conn.collect_list
        (Caqti_request.collect Caqti_type.unit (Caqti_type.tup2 Sql.Mainnet.Internal_command.typ Sql.Mainnet.Block_internal_command.typ)
          (sprintf "SELECT %s, %s FROM %s AS c JOIN %s AS j ON c.id = j.internal_command_id AND j.block_id IN (%s)"
            (String.concat ~sep:"," Sql.Mainnet.Internal_command.field_names)
            (String.concat ~sep:"," Sql.Mainnet.Block_internal_command.Fields.names)
            Sql.Mainnet.Internal_command.table_name
            Sql.Mainnet.Block_internal_command.table_name
            (String.concat ~sep:"," @@ List.map blocks ~f:(fun block -> Int.to_string block.id))))
        ())
  in
  let required_public_key_ids =
    let user_cmd_reqs = List.bind block_user_cmds ~f:(fun (cmd, _join) -> [cmd.fee_payer_id; cmd.source_id; cmd.receiver_id]) in
    let internal_cmd_reqs = List.map block_internal_cmds ~f:(fun (cmd, _join) -> cmd.receiver_id) in
    Staged.unstage (List.stable_dedup_staged ~compare:Int.compare) (user_cmd_reqs @ internal_cmd_reqs)
  in
  let%bind public_keys =
    query_mainnet_db ~f:(fun (module Conn : CONNECTION) ->
      Conn.collect_list
        (Caqti_request.collect Caqti_type.unit Caqti_type.(tup2 int Sql.Mainnet.Public_key.typ)
          (sprintf "SELECT id, value FROM %s WHERE id IN (%s)"
            Sql.Mainnet.Public_key.table_name
            (String.concat ~sep:"," @@ List.map required_public_key_ids ~f:Int.to_string)
          ))
        ())
    >>| Int.Map.of_alist_exn
  in
  let user_cmds =
    List.fold_left block_user_cmds ~init:Int.Map.empty ~f:(fun acc (cmd, join) ->
        let ext_cmd : Archive_lib.Extensional.User_command.t =
          { sequence_no = join.sequence_no
          ; command_type = cmd.typ
          ; fee_payer = Map.find_exn public_keys cmd.fee_payer_id
          ; source = Map.find_exn public_keys cmd.source_id
          ; receiver = Map.find_exn public_keys cmd.receiver_id
          ; nonce = Mina_numbers.Account_nonce.of_int cmd.nonce
          ; amount = Option.map cmd.amount ~f:(fun amount -> Unsigned.UInt64.of_int64 amount |> Currency.Amount.of_uint64)
          ; fee = cmd.fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
          ; valid_until =
              Option.map cmd.valid_until ~f:(fun valid_until ->
                  Unsigned.UInt32.of_int64 valid_until
                  |> Mina_numbers.Global_slot_since_genesis.of_uint32 )
          ; memo = Mina_base.Signed_command_memo.of_base58_check_exn cmd.memo
          ; hash = Mina_transaction.Transaction_hash.of_base58_check_exn_v1 cmd.hash
          ; status = join.status
          ; failure_reason = Option.map join.failure_reason ~f:mainnet_transaction_failure_of_string
          }
        in
        Map.add_multi acc ~key:join.block_id ~data:ext_cmd)
  in
  let internal_cmds =
    List.fold_left block_internal_cmds ~init:Int.Map.empty ~f:(fun acc (cmd, join) ->
      let ext_cmd : Archive_lib.Extensional.Internal_command.t =
        { sequence_no = join.sequence_no
        ; secondary_sequence_no = join.secondary_sequence_no
        ; command_type = cmd.typ
        ; receiver = Map.find_exn public_keys cmd.receiver_id
        ; fee = cmd.fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
        ; hash = Mina_transaction.Transaction_hash.of_base58_check_exn_v1 cmd.hash
        ; status = "applied"
        ; failure_reason = None
        }
      in
      Map.add_multi acc ~key:join.block_id ~data:ext_cmd)
  in
  [%log info] "Done fetching transaction sequence from prior database" ;

  return (List.map blocks ~f:(fun block ->
    let state_hash = Mina_base.State_hash.of_base58_check_exn block.state_hash in
    let is_genesis_block = Int64.equal block.height Int64.one in
    let precomputed =
      if is_genesis_block then
        Precomputed_block.of_block_header (Mina_block.header genesis_block)
      else
        Map.find_exn precomputed_blocks state_hash
    in
    (* NB: command indices do not contain entries for blocks that have no commands associated with them in the database *)
    let user_cmds = List.sort ~compare:compare_user_cmd_seq @@ Option.value ~default:[] @@ Map.find user_cmds block.id in
    let internal_cmds = List.sort ~compare:compare_internal_cmd_seq @@ Option.value ~default:[] @@ Map.find internal_cmds block.id in
    let consensus_state = precomputed.protocol_state.body.consensus_state in
    { Archive_lib.Extensional.Block.state_hash
    ; parent_hash = Mina_base.State_hash.of_base58_check_exn block.parent_hash
    ; creator = (* Map.find_exn public_keys block.creator_id *) consensus_state.block_creator
    ; block_winner = (* Map.find_exn public_keys block.block_winner_id *) consensus_state.block_stake_winner
    ; last_vrf_output = consensus_state.last_vrf_output
    ; snarked_ledger_hash = (* Map.find_exn snarked_ledger_hashes block.snarked_ledger_hash_id *) precomputed.protocol_state.body.blockchain_state.snarked_ledger_hash
    ; staking_epoch_data = consensus_state.staking_epoch_data
    ; next_epoch_data = consensus_state.next_epoch_data
    ; min_window_density = consensus_state.min_window_density
    ; total_currency = consensus_state.total_currency
    ; sub_window_densities = consensus_state.sub_window_densities
    ; ledger_hash = Mina_base.Frozen_ledger_hash.of_base58_check_exn block.ledger_hash
    ; height = Unsigned.UInt32.of_int64 block.height
    ; global_slot_since_hard_fork = Mina_numbers.Global_slot_since_hard_fork.of_uint32 @@ Unsigned.UInt32.of_int64 block.global_slot_since_hard_fork
    ; global_slot_since_genesis = Mina_numbers.Global_slot_since_genesis.of_uint32 @@ Unsigned.UInt32.of_int64 block.global_slot_since_genesis
    ; timestamp = Block_time.of_int64 block.timestamp
    ; user_cmds
    ; internal_cmds
    ; zkapp_cmds = []
    ; protocol_version = mainnet_protocol_version
    ; proposed_protocol_version = None
    ; chain_status = Archive_lib.Chain_status.of_string block.chain_status
    (* TODO: ignoring these fields as they are unread when adding to the db, so they aren't needed to make the replayer happy, but we will need to add this back *)
    ; accounts_accessed = []
    ; accounts_created = []
    ; tokens_used = []
    }))

let _mainnet_block_to_extensional ~logger ~mainnet_pool ~network
    ~(genesis_block : Mina_block.t) (block : Sql.Mainnet.Block.t) ~bucket
    ~batch_size =
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
    (* TODO: only download the state hashes we need... *)
    (* we may try to be fetching more blocks than exist
       gsutil seems to get the ones that do exist, in that exist
    *)
    let batch_size = Int64.of_int batch_size in
    if is_genesis_block then Deferred.unit
    else if !first_batch then (
      let num_blocks = Int64.(batch_size - (block.height % batch_size)) in
      [%log info] "Fetching first batch of precomputed blocks"
        ~metadata:
          [ ("height", `Int (Int64.to_int_exn block.height))
          ; ("num_blocks", `Int (Int64.to_int_exn num_blocks))
          ] ;
      let%bind () =
        Precomputed_block.fetch_batch ~network ~height:block.height ~num_blocks
          ~bucket
      in
      [%log info] "Done fetching first batch of precomputed blocks" ;
      first_batch := false ;
      Deferred.unit )
    else if Int64.(equal (block.height % batch_size)) 0L then (
      [%log info] "Deleting all precomputed blocks" ;
      let%bind () = Precomputed_block.delete_fetched ~network in
      [%log info] "Fetching batch of precomputed blocks"
        ~metadata:
          [ ("height", `Int (Int64.to_int_exn block.height))
          ; ("num_blocks", `Int (Int64.to_int_exn batch_size))
          ] ;
      let%bind () =
        Precomputed_block.fetch_batch ~network ~height:block.height
          ~num_blocks:batch_size ~bucket
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
  [%log info] "Fetching block data from mainnet db..." ;
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
          ~height:block.height ~network
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
          ~height:block.height ~network
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
          ~height:block.height ~network
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
          ~height:block.height ~network
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
          ~height:block.height ~network
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
          ~height:block.height ~network
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
    ~fork_state_hash:_ ~mina_network_blocks_bucket ~batch_size ~network () =
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
      let With_hash.{ data = genesis_block; hash = genesis_state_hashes }, _validation =
        Mina_block.genesis ~precomputed_values
      in
      [%log info] "Querying mainnet canonical blocks" ;
      let%bind mainnet_blocks_unsorted =
        query_mainnet_db ~f:(fun db -> Sql.Mainnet.Block.full_canonical_blocks db ())
      in
      (* remove blocks we've already migrated *)
      [%log info] "Determining already migrated bocks" ;
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
      (* TODO: this ordering is actually already done by the sql query, so we can skip this here *)
      let mainnet_blocks_to_migrate =
        List.sort mainnet_blocks_unmigrated ~compare:(fun block1 block2 ->
            Int64.compare block1.height block2.height )
      in
      let required_precomputed_block_ids =
        List.map mainnet_blocks_to_migrate ~f:(fun {height; state_hash; _} -> (height, state_hash))
        |> List.filter ~f:(fun (height, _) -> Int64.(height > 1L))
      in
      let%bind precomputed_blocks = Precomputed_block.concrete_fetch_batch ~logger ~bucket:mina_network_blocks_bucket ~network required_precomputed_block_ids in
      [%log info] "Migrating mainnet blocks" ;
      let%bind () =
        List.chunks_of ~length:batch_size mainnet_blocks_to_migrate
        |> Deferred.List.iter ~f:(fun (blocks : Sql.Mainnet.Block.t list) ->
            (* TODO: state hash list in metadata *)
            [%log info]
              "Migrating %d blocks starting at height %Ld (%s..%s)"
              (List.length blocks)
              (List.hd_exn blocks).height
              (List.hd_exn blocks).state_hash
              (List.last_exn blocks).state_hash ;
            [%log info] "Converting blocks to extensional format..." ;
            let%bind extensional_blocks =
              mainnet_block_to_extensional_batch ~logger ~mainnet_pool ~genesis_block
                ~precomputed_blocks blocks
            in
            [%log info] "Adding blocks to migrated database..." ;
            query_migrated_db ~f:(fun db ->
                match%map
                  Archive_lib.Processor.Block.add_from_extensional_batch db
                    extensional_blocks ~v1_transaction_hash:true
                    ~genesis_block_hash:(Mina_base.State_hash.State_hashes.state_hash genesis_state_hashes)
                with
                | Ok _id ->
                    Ok ()
                | Error (`Congested _) ->
                    failwith "Could not archive extensional block batch: congested"
                | (Error (`Decode_rejected _ as err))
                | (Error (`Encode_failed _ as err))
                | (Error (`Encode_rejected _ as err))
                | (Error (`Request_failed _ as err))
                | (Error (`Request_rejected _ as err))
                | (Error (`Response_failed _ as err))
                | (Error (`Response_rejected _ as err)) ->
                    failwithf
                      "Could not archive extensional block batch: %s" (Caqti_error.show err) () ) )
      in
      (*
      (* if the migration was successfully, cleanup the precomputed blocks we downloaded *)
      [%log info] "Deleting all precomputed blocks" ;
      let%bind () = Precomputed_block.delete_fetched ~network in
      [%log info] "Done migrating mainnet blocks!" ;
      *)
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
         and fork_state_hash =
           Param.flag "--fork-state-hash" ~aliases:[ "-fork-state-hash" ]
             Param.(optional string)
             ~doc:
               "String state hash of the fork for the migration (if omitted, \
                only canonical blocks will be migrated)"
         and mina_network_blocks_bucket =
           Param.flag "--blocks-bucket" ~aliases:[ "-blocks-bucket" ]
             Param.(required string)
             ~doc:"Bucket with precomputed mainnet blocks"
         and batch_size =
           Param.flag "--batch-size" ~aliases:[ "-batch-size" ]
             Param.(required int)
             ~doc:"Batch size used when downloading precomputed blocks"
         and network =
           Param.flag "--network" ~aliases:[ "-network" ]
             Param.(required string)
             ~doc:"Network name used when downloading precomputed blocks"
         in
         main ~mainnet_archive_uri ~migrated_archive_uri ~runtime_config_file
           ~fork_state_hash ~mina_network_blocks_bucket ~batch_size ~network )))
