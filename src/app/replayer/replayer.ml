(* replayer.ml -- replay transactions from archive node database *)

open Core
open Async
open Mina_base

(* identify a target block B containing staking and next epoch ledgers
   to be used in a hard fork, by giving its state hash

   from B, we choose a predecessor block B_fork, which is the block to
   fork from

   we replay all commands, one by one, from the genesis block through
   B_fork

   when the Merkle root of the replay ledger matches one of the
   epoch ledger hashes, we make a copy of the replay ledger to
   become that target epoch ledger

   when all commands from a block have been replayed, we verify
   that the Merkle root of the replay ledger matches the stored
   ledger hash in the archive database
*)

type input =
  { target_epoch_ledgers_state_hash : State_hash.t option [@default None]
  ; start_slot_since_genesis : int64 [@default 0L]
  ; genesis_ledger : Runtime_config.Ledger.t
  }
[@@deriving yojson]

type output =
  { target_epoch_ledgers_state_hash : State_hash.t
  ; target_fork_state_hash : State_hash.t
  ; target_genesis_ledger : Runtime_config.Ledger.t
  ; target_epoch_data : Runtime_config.Epoch_data.t
  }
[@@deriving yojson]

module type Get_command_ids = sig
  val run :
       Caqti_async.connection
    -> state_hash:string
    -> (int list, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t
end

type balance_block_data =
  { block_id : int
  ; block_height : int64
  ; sequence_no : int
  ; secondary_sequence_no : int
  }

let error_count = ref 0

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let proof_level = Genesis_constants.Proof_level.Full

let json_ledger_hash_of_ledger ledger =
  Ledger_hash.to_yojson @@ Ledger.merkle_root ledger

let create_ledger_as_list ledger =
  let%map accounts = Ledger.to_list ledger in
  List.map accounts ~f:(fun acc ->
      Genesis_ledger_helper.Accounts.Single.of_account acc None )

let create_output ~target_fork_state_hash ~target_epoch_ledgers_state_hash
    ~ledger ~staking_epoch_ledger ~staking_seed ~next_epoch_ledger ~next_seed
    (input_genesis_ledger : Runtime_config.Ledger.t) =
  let%bind genesis_ledger_as_list = create_ledger_as_list ledger in
  let target_genesis_ledger =
    { input_genesis_ledger with base = Accounts genesis_ledger_as_list }
  in
  let%bind staking_epoch_ledger_as_list =
    create_ledger_as_list staking_epoch_ledger
  in
  let%map next_epoch_ledger_as_list = create_ledger_as_list next_epoch_ledger in
  let target_staking_epoch_data : Runtime_config.Epoch_data.Data.t =
    let ledger =
      { input_genesis_ledger with base = Accounts staking_epoch_ledger_as_list }
    in
    { ledger; seed = staking_seed }
  in
  let target_next_epoch_data : Runtime_config.Epoch_data.Data.t =
    let ledger =
      { input_genesis_ledger with base = Accounts next_epoch_ledger_as_list }
    in
    { ledger; seed = next_seed }
  in
  let target_epoch_data : Runtime_config.Epoch_data.t =
    { staking = target_staking_epoch_data; next = Some target_next_epoch_data }
  in
  { target_fork_state_hash
  ; target_epoch_ledgers_state_hash
  ; target_genesis_ledger
  ; target_epoch_data
  }

let create_replayer_checkpoint ~ledger ~start_slot_since_genesis :
    input Deferred.t =
  let%map accounts = create_ledger_as_list ledger in
  let genesis_ledger : Runtime_config.Ledger.t =
    { base = Accounts accounts
    ; num_accounts = None
    ; balances = []
    ; hash = None
    ; name = None
    ; add_genesis_winner = Some true
    }
  in
  { target_epoch_ledgers_state_hash = None
  ; start_slot_since_genesis
  ; genesis_ledger
  }

(* map from global slots (since genesis) to state hash, ledger hash pairs *)
let global_slot_hashes_tbl : (Int64.t, State_hash.t * Ledger_hash.t) Hashtbl.t =
  Int64.Table.create ()

let get_slot_hashes slot = Hashtbl.find global_slot_hashes_tbl slot

(* cache of account keys *)
let pk_tbl : (int, Account.key) Hashtbl.t = Int.Table.create ()

let query_db pool ~f ~item =
  match%bind Caqti_async.Pool.use f pool with
  | Ok v ->
      return v
  | Error msg ->
      failwithf "Error getting %s from db, error: %s" item
        (Caqti_error.show msg) ()

let pk_of_pk_id pool pk_id : Account.key Deferred.t =
  let open Deferred.Let_syntax in
  match Hashtbl.find pk_tbl pk_id with
  | Some pk ->
      return pk
  | None -> (
      (* not in cache, consult database *)
      match%map
        Caqti_async.Pool.use (fun db -> Sql.Public_key.run db pk_id) pool
      with
      | Ok (Some pk) -> (
          match Signature_lib.Public_key.Compressed.of_base58_check pk with
          | Ok pk ->
              Hashtbl.add_exn pk_tbl ~key:pk_id ~data:pk ;
              pk
          | Error err ->
              Error.tag_arg err "Error decoding public key"
                (("public_key", pk), ("id", pk_id))
                [%sexp_of: (string * string) * (string * int)]
              |> Error.raise )
      | Ok None ->
          failwithf "Could not find public key with id %d" pk_id ()
      | Error msg ->
          failwithf "Error retrieving public key with id %d, error: %s" pk_id
            (Caqti_error.show msg) () )

let balance_info_of_id pool ~id =
  query_db pool
    ~f:(fun db -> Archive_lib.Processor.Balance.load db ~id)
    ~item:"balance info of id"

let internal_command_to_balance_block_data
    (internal_cmd : Sql.Internal_command.t) =
  { block_id = internal_cmd.block_id
  ; block_height = internal_cmd.block_height
  ; sequence_no = internal_cmd.sequence_no
  ; secondary_sequence_no = internal_cmd.secondary_sequence_no
  }

let user_command_to_balance_block_data (user_cmd : Sql.User_command.t) =
  { block_id = user_cmd.block_id
  ; block_height = user_cmd.block_height
  ; sequence_no = user_cmd.sequence_no
  ; secondary_sequence_no = 0
  }

let process_block_infos_of_state_hash ~logger pool ~state_hash ~start_slot ~f =
  match%bind
    Caqti_async.Pool.use
      (fun db -> Sql.Block_info.run db ~state_hash ~start_slot)
      pool
  with
  | Ok block_infos ->
      f block_infos
  | Error msg ->
      [%log error] "Error getting block information for state hash"
        ~metadata:
          [ ("error", `String (Caqti_error.show msg))
          ; ("state_hash", `String state_hash)
          ] ;
      exit 1

let update_epoch_ledger ~logger ~name ~ledger ~epoch_ledger epoch_ledger_hash =
  let epoch_ledger_hash = Ledger_hash.of_base58_check_exn epoch_ledger_hash in
  let curr_ledger_hash = Ledger.merkle_root ledger in
  if Frozen_ledger_hash.equal epoch_ledger_hash curr_ledger_hash then (
    [%log info]
      "Creating %s epoch ledger from ledger with Merkle root matching epoch \
       ledger hash %s"
      name
      (Ledger_hash.to_base58_check epoch_ledger_hash) ;
    (* Ledger.copy doesn't actually copy, roll our own here *)
    let%map accounts = Ledger.to_list ledger in
    let epoch_ledger = Ledger.create ~depth:(Ledger.depth ledger) () in
    List.iter accounts ~f:(fun account ->
        let pk = Account.public_key account in
        let token = Account.token account in
        let account_id = Account_id.create pk token in
        match Ledger.get_or_create_account epoch_ledger account_id account with
        | Ok (`Added, _loc) ->
            ()
        | Ok (`Existed, _loc) ->
            failwithf
              "When creating epoch ledger, account with public key %s and \
               token %s already existed"
              (Signature_lib.Public_key.Compressed.to_string pk)
              (Token_id.to_string token) ()
        | Error err ->
            Error.tag_arg err
              "When creating epoch ledger, error when adding account"
              (("public_key", pk), ("token", token))
              [%sexp_of:
                (string * Signature_lib.Public_key.Compressed.t)
                * (string * Token_id.t)]
            |> Error.raise ) ;
    epoch_ledger )
  else return epoch_ledger

let update_staking_epoch_data ~logger pool ~ledger ~last_block_id
    ~staking_epoch_ledger =
  let%bind state_hash =
    query_db pool
      ~f:(fun db -> Sql.Block.get_state_hash db last_block_id)
      ~item:"block state hash for staking epoch data"
  in
  let%bind staking_epoch_id =
    query_db pool
      ~f:(fun db -> Sql.Epoch_data.get_staking_epoch_data_id db state_hash)
      ~item:"staking epoch id"
  in
  let%bind { epoch_ledger_hash; epoch_data_seed } =
    query_db pool
      ~f:(fun db -> Sql.Epoch_data.get_epoch_data db staking_epoch_id)
      ~item:"staking epoch data"
  in
  let%map ledger =
    update_epoch_ledger ~logger ~name:"staking" ~ledger
      ~epoch_ledger:staking_epoch_ledger epoch_ledger_hash
  in
  (ledger, epoch_data_seed)

let update_next_epoch_data ~logger pool ~ledger ~last_block_id
    ~next_epoch_ledger =
  let%bind state_hash =
    query_db pool
      ~f:(fun db -> Sql.Block.get_state_hash db last_block_id)
      ~item:"block state hash for next epoch data"
  in
  let%bind next_epoch_id =
    query_db pool
      ~f:(fun db -> Sql.Epoch_data.get_next_epoch_data_id db state_hash)
      ~item:"next epoch id"
  in
  let%bind { epoch_ledger_hash; epoch_data_seed } =
    query_db pool
      ~f:(fun db -> Sql.Epoch_data.get_epoch_data db next_epoch_id)
      ~item:"next epoch data"
  in
  let%map ledger =
    update_epoch_ledger ~logger ~name:"next" ~ledger
      ~epoch_ledger:next_epoch_ledger epoch_ledger_hash
  in
  (ledger, epoch_data_seed)

(* cache of fee transfers for coinbases *)
module Fee_transfer_key = struct
  module T = struct
    type t = int64 * int * int [@@deriving hash, sexp, compare]
  end

  type t = T.t

  include Hashable.Make (T)
end

let fee_transfer_tbl : (Fee_transfer_key.t, Coinbase_fee_transfer.t) Hashtbl.t =
  Fee_transfer_key.Table.create ()

let cache_fee_transfer_via_coinbase pool (internal_cmd : Sql.Internal_command.t)
    =
  match internal_cmd.type_ with
  | "fee_transfer_via_coinbase" ->
      let%map receiver_pk = pk_of_pk_id pool internal_cmd.receiver_id in
      let fee =
        Currency.Fee.of_uint64 (Unsigned.UInt64.of_int64 internal_cmd.fee)
      in
      let fee_transfer = Coinbase_fee_transfer.create ~receiver_pk ~fee in
      Hashtbl.add_exn fee_transfer_tbl
        ~key:
          ( internal_cmd.global_slot_since_genesis
          , internal_cmd.sequence_no
          , internal_cmd.secondary_sequence_no )
        ~data:fee_transfer
  | _ ->
      Deferred.unit

let create_or_append_repair_script ~logger ~output_repair_script_opt
    ~(balance_info : Archive_lib.Processor.Balance.t) nonce =
  match output_repair_script_opt with
  | None ->
      ()
  | Some output_repair_script_opt ->
      [%log debug] "Persisting nonce repair to repair script" ;

      let sql =
        sprintf
          "UPDATE balances SET nonce = %Ld\n\
          \      WHERE balance = %Ld\n\
          \      AND block_height = %Ld\n\
          \      AND block_sequence_no = %d\n\
          \      AND block_secondary_sequence_no = %d;" nonce
          balance_info.balance balance_info.block_height
          balance_info.block_sequence_no
          balance_info.block_secondary_sequence_no
      in

      Out_channel.with_file ~append:true output_repair_script_opt
        ~f:(fun outc ->
          Out_channel.output_string outc sql ;
          Out_channel.newline outc )

(* balance_block_data come from a loaded internal or user command, which
    includes data from the blocks table and
    - for internal commands, the tables internal_commands and blocks_internals_commands
    - for user commands, the tables user_commands and blocks_user_commands
   we compare those against the same-named values in the balances row
*)
let verify_balance ~logger ~pool ~ledger ~who ~balance_id ~pk_id ~token_int64
    ~balance_block_data ~set_nonces ~repair_nonces ~continue_on_error
    ~output_repair_script_opt : unit Deferred.t =
  let%bind pk = pk_of_pk_id pool pk_id in
  let%bind balance_info = balance_info_of_id pool ~id:balance_id in
  let token = token_int64 |> Unsigned.UInt64.of_int64 |> Token_id.of_uint64 in
  let account_id = Account_id.create pk token in
  let account =
    match Ledger.location_of_account ledger account_id with
    | Some loc -> (
        match Ledger.get ledger loc with
        | Some account ->
            account
        | None ->
            failwithf
              "Could not find account in ledger for public key %s and token id \
               %s"
              (Signature_lib.Public_key.Compressed.to_base58_check pk)
              (Token_id.to_string token) () )
    | None ->
        failwithf
          "Could not get location of account for public key %s and token id %s"
          (Signature_lib.Public_key.Compressed.to_base58_check pk)
          (Token_id.to_string token) ()
  in
  let actual_balance = account.balance in
  let claimed_balance =
    balance_info.balance |> Unsigned.UInt64.of_int64
    |> Currency.Balance.of_uint64
  in
  if not (Currency.Balance.equal actual_balance claimed_balance) then (
    [%log error] "Claimed balance does not match actual balance in ledger"
      ~metadata:
        [ ("who", `String who)
        ; ("claimed_balance", Currency.Balance.to_yojson claimed_balance)
        ; ("actual_balance", Currency.Balance.to_yojson actual_balance)
        ] ;
    if continue_on_error then incr error_count else Core_kernel.exit 1 ) ;
  let { block_id; block_height; sequence_no; secondary_sequence_no } =
    balance_block_data
  in
  if not (block_id = balance_info.block_id) then (
    [%log error]
      "Block id from command does not match block id in balances table"
      ~metadata:
        [ ("who", `String who)
        ; ("block_id_command", `Int block_id)
        ; ("block_id_balances", `Int balance_info.block_id)
        ] ;
    if continue_on_error then incr error_count else Core_kernel.exit 1 ) ;
  if not (Int64.equal block_height balance_info.block_height) then (
    [%log error]
      "Block height from command does not match block height in balances table"
      ~metadata:
        [ ("who", `String who)
        ; ("block_height_command", `String (Int64.to_string block_height))
        ; ( "block_height_balances"
          , `String (Int64.to_string balance_info.block_height) )
        ] ;
    if continue_on_error then incr error_count else Core_kernel.exit 1 ) ;
  if not (sequence_no = balance_info.block_sequence_no) then (
    [%log error]
      "Sequence no from command does not match sequence no in balances table"
      ~metadata:
        [ ("who", `String who)
        ; ("block_sequence_no_command", `Int sequence_no)
        ; ("block_sequence_no_balances", `Int balance_info.block_sequence_no)
        ] ;
    if continue_on_error then incr error_count else Core_kernel.exit 1 ) ;
  if not (secondary_sequence_no = balance_info.block_secondary_sequence_no) then (
    [%log error]
      "Secondary sequence no from command does not match secondary sequence no \
       in balances table"
      ~metadata:
        [ ("who", `String who)
        ; ("block_secondary_sequence_no_command", `Int secondary_sequence_no)
        ; ( "block_secondary_sequence_no_balances"
          , `Int balance_info.block_secondary_sequence_no )
        ] ;
    if continue_on_error then incr error_count else Core_kernel.exit 1 ) ;
  let ledger_nonce = account.nonce in
  match balance_info.nonce with
  | None ->
      if set_nonces then (
        [%log info] "Inserting missing nonce into archive db"
          ~metadata:
            [ ("balance_id", `Int balance_id)
            ; ("nonce", `String (Account.Nonce.to_string ledger_nonce))
            ] ;
        let nonce =
          Account.Nonce.to_uint32 ledger_nonce |> Unsigned.UInt32.to_int64
        in

        create_or_append_repair_script ~logger ~output_repair_script_opt
          ~balance_info nonce ;

        query_db pool
          ~f:(fun db -> Sql.Balances.insert_nonce db ~id:balance_id ~nonce)
          ~item:"chain from state hash" )
      else (
        [%log error] "Missing nonce in archive db"
          ~metadata:
            [ ("balance_id", `Int balance_id)
            ; ("nonce", `String (Account.Nonce.to_string ledger_nonce))
            ] ;
        Deferred.unit )
  | Some nonce ->
      let db_nonce =
        nonce |> Unsigned.UInt32.of_int64 |> Account.Nonce.of_uint32
      in
      if not (Account.Nonce.equal ledger_nonce db_nonce) then
        if repair_nonces then (
          [%log info] "Repairing incorrect nonce in balances table"
            ~metadata:
              [ ("who", `String who)
              ; ("balance_id", `Int balance_id)
              ; ("ledger_nonce", Account.Nonce.to_yojson ledger_nonce)
              ; ("database_nonce", Account.Nonce.to_yojson db_nonce)
              ] ;
          let correct_nonce =
            ledger_nonce |> Account.Nonce.to_uint32 |> Unsigned.UInt32.to_int64
          in

          create_or_append_repair_script ~logger ~output_repair_script_opt
            ~balance_info correct_nonce ;

          query_db pool
            ~f:(fun db ->
              Sql.Balances.insert_nonce db ~id:balance_id ~nonce:correct_nonce
              )
            ~item:"repairing nonce" )
        else (
          [%log error] "Ledger nonce does not match nonce in balances table"
            ~metadata:
              [ ("who", `String who)
              ; ("ledger_nonce", Account.Nonce.to_yojson ledger_nonce)
              ; ("database_nonce", Account.Nonce.to_yojson db_nonce)
              ; ("balance_id", `Int balance_id)
              ] ;
          Deferred.unit )
      else Deferred.unit

let account_creation_fee_uint64 =
  Currency.Fee.to_uint64 constraint_constants.account_creation_fee

let account_creation_fee_int64 =
  Currency.Fee.to_int constraint_constants.account_creation_fee |> Int64.of_int

let verify_account_creation_fee ~logger ~pool ~receiver_account_creation_fee
    ~balance_id ~fee ?additional_fee ~continue_on_error () =
  let%map balance_info = balance_info_of_id pool ~id:balance_id in
  let claimed_balance =
    balance_info.balance |> Unsigned.UInt64.of_int64
    |> Currency.Balance.of_uint64
  in
  let balance_uint64 = Currency.Balance.to_uint64 claimed_balance in
  (* for coinbases, an additional fee may be deducted from the amount
     given to the receiver beyond the account creation fee *)
  let total_creation_deduction_uint64 =
    match additional_fee with
    | None ->
        account_creation_fee_uint64
    | Some fee' ->
        Unsigned.UInt64.add account_creation_fee_uint64
          (Currency.Fee.to_uint64 fee')
  in
  let fee_uint64 = Currency.Fee.to_uint64 fee in
  let add_additional_fee_to_metadata metadata =
    match additional_fee with
    | None ->
        metadata
    | Some fee ->
        metadata @ [ ("fee_transfer_fee", Currency.Fee.to_yojson fee) ]
  in
  if Unsigned_extended.UInt64.( >= ) fee_uint64 total_creation_deduction_uint64
  then (
    (* account may have been created *)
    let fee_less_total_creation_deduction_uint64 =
      Unsigned.UInt64.sub fee_uint64 total_creation_deduction_uint64
    in
    if
      Unsigned.UInt64.equal balance_uint64
        fee_less_total_creation_deduction_uint64
    then
      match receiver_account_creation_fee with
      | None ->
          [%log error]
            "In the archive database, the account balance equals the internal \
             command fee minus the account creation fee (and for coinbases, \
             also less any fee transfer fee), but the receiver account \
             creation fee is NULL"
            ~metadata:
              (add_additional_fee_to_metadata
                 [ ( "account_balance"
                   , Currency.Balance.to_yojson claimed_balance )
                 ; ("fee", Currency.Fee.to_yojson fee)
                 ; ( "constraint_constants.account_creation_fee"
                   , Currency.Fee.to_yojson
                       constraint_constants.account_creation_fee )
                 ] ) ;
          if continue_on_error then incr error_count else Core_kernel.exit 1
      | Some amount_int64 ->
          if Int64.equal amount_int64 account_creation_fee_int64 then
            (* account creation fee in db has the expected value *)
            ()
          else (
            [%log error]
              "In the archive database, the account balance equals the \
               internal command fee minus the account creation fee (and for \
               coinbases, also less any fee transfer fee), but the receiver \
               account creation fee differs from the account creation fee"
              ~metadata:
                (add_additional_fee_to_metadata
                   [ ( "account_balance"
                     , Currency.Balance.to_yojson claimed_balance )
                   ; ("fee", Currency.Fee.to_yojson fee)
                   ; ( "constraint_constants.account_creation_fee"
                     , Currency.Fee.to_yojson
                         constraint_constants.account_creation_fee )
                   ; ( "receiver_account_creation_fee"
                     , `String (Int64.to_string amount_int64) )
                   ] ) ;
            if continue_on_error then incr error_count else Core_kernel.exit 1 )
    else
      match receiver_account_creation_fee with
      | None ->
          ()
      | Some amount_int64 ->
          [%log error]
            "In the archive database, the account balance is different than \
             the internal command fee minus the account creation fee (and for \
             coinbases, also less any fee transfer fee), but the receiver \
             account creation fee is not NULL"
            ~metadata:
              (add_additional_fee_to_metadata
                 [ ( "account_balance"
                   , Currency.Balance.to_yojson claimed_balance )
                 ; ("fee", Currency.Fee.to_yojson fee)
                 ; ( "constraint_constants.account_creation_fee"
                   , Currency.Fee.to_yojson
                       constraint_constants.account_creation_fee )
                 ; ( "receiver_account_creation_fee"
                   , `String (Int64.to_string amount_int64) )
                 ] ) ;
          if continue_on_error then incr error_count else Core_kernel.exit 1 )
  else
    (* fee less than account creation fee *)
    match receiver_account_creation_fee with
    | None ->
        ()
    | Some amount_int64 ->
        [%log error]
          "The internal command fee is less than the account creation fee (for \
           coinbases the creation fee plus any fee transfer fee), so no \
           account should have been created, but in the archive database, the \
           receiver account creation fee is not NULL"
          ~metadata:
            (add_additional_fee_to_metadata
               [ ("account_balance", Currency.Balance.to_yojson claimed_balance)
               ; ("fee", Currency.Fee.to_yojson fee)
               ; ( "constraint_constants.account_creation_fee"
                 , Currency.Fee.to_yojson
                     constraint_constants.account_creation_fee )
               ; ( "receiver_account_creation_fee"
                 , `String (Int64.to_string amount_int64) )
               ] ) ;
        if continue_on_error then incr error_count else Core_kernel.exit 1

let run_internal_command ~logger ~pool ~ledger (cmd : Sql.Internal_command.t)
    ~set_nonces ~repair_nonces ~continue_on_error ~output_repair_script_opt =
  [%log info]
    "Applying internal command (%s) with global slot since genesis %Ld, \
     sequence number %d, and secondary sequence number %d"
    cmd.type_ cmd.global_slot_since_genesis cmd.sequence_no
    cmd.secondary_sequence_no ;
  let%bind receiver_pk = pk_of_pk_id pool cmd.receiver_id in
  let fee = Currency.Fee.of_uint64 (Unsigned.UInt64.of_int64 cmd.fee) in
  let fee_token = Token_id.of_uint64 (Unsigned.UInt64.of_int64 cmd.token) in
  let txn_global_slot =
    cmd.txn_global_slot_since_genesis |> Unsigned.UInt32.of_int64
    |> Mina_numbers.Global_slot.of_uint32
  in
  let fail_on_error err =
    Error.tag_arg err "Could not apply internal command"
      ( ("global slot_since_genesis", cmd.global_slot_since_genesis)
      , ("sequence number", cmd.sequence_no) )
      [%sexp_of: (string * int64) * (string * int)]
    |> Error.raise
  in
  let pk_id = cmd.receiver_id in
  let balance_id = cmd.receiver_balance in
  let token_int64 = cmd.token in
  let receiver_account_creation_fee = cmd.receiver_account_creation_fee_paid in
  let balance_block_data = internal_command_to_balance_block_data cmd in
  let open Mina_base.Ledger in
  match cmd.type_ with
  | "fee_transfer" -> (
      let%bind () =
        verify_account_creation_fee ~logger ~pool ~receiver_account_creation_fee
          ~balance_id ~fee ~continue_on_error ()
      in
      let fee_transfer =
        Fee_transfer.create_single ~receiver_pk ~fee ~fee_token
      in
      let undo_or_error =
        Ledger.apply_fee_transfer ~constraint_constants ~txn_global_slot ledger
          fee_transfer
      in
      match undo_or_error with
      | Ok _undo ->
          verify_balance ~logger ~pool ~ledger ~who:"fee transfer receiver"
            ~balance_id ~pk_id ~token_int64 ~balance_block_data ~set_nonces
            ~repair_nonces ~continue_on_error ~output_repair_script_opt
      | Error err ->
          fail_on_error err )
  | "coinbase" -> (
      let amount = Currency.Fee.to_uint64 fee |> Currency.Amount.of_uint64 in
      (* combining situation 1: add cached coinbase fee transfer, if it exists *)
      let fee_transfer =
        Hashtbl.find fee_transfer_tbl
          ( cmd.global_slot_since_genesis
          , cmd.sequence_no
          , cmd.secondary_sequence_no )
      in
      if Option.is_some fee_transfer then
        [%log info]
          "Coinbase transaction at global slot since genesis %Ld, sequence \
           number %d, and secondary sequence number %d contains a fee transfer"
          cmd.global_slot_since_genesis cmd.sequence_no
          cmd.secondary_sequence_no ;
      let coinbase =
        match Coinbase.create ~amount ~receiver:receiver_pk ~fee_transfer with
        | Ok cb ->
            cb
        | Error err ->
            Error.tag err ~tag:"Error creating coinbase for internal command"
            |> Error.raise
      in
      let additional_fee = Option.map fee_transfer ~f:(fun { fee; _ } -> fee) in
      let%bind () =
        verify_account_creation_fee ~logger ~pool ~receiver_account_creation_fee
          ~balance_id ~fee ?additional_fee ~continue_on_error ()
      in
      let undo_or_error =
        apply_coinbase ~constraint_constants ~txn_global_slot ledger coinbase
      in
      match undo_or_error with
      | Ok _undo ->
          verify_balance ~logger ~pool ~ledger ~who:"coinbase receiver"
            ~balance_id ~pk_id ~token_int64 ~balance_block_data ~set_nonces
            ~repair_nonces ~continue_on_error ~output_repair_script_opt
      | Error err ->
          fail_on_error err )
  | "fee_transfer_via_coinbase" ->
      let%bind () =
        verify_account_creation_fee ~logger ~pool ~receiver_account_creation_fee
          ~balance_id ~fee ~continue_on_error ()
      in
      let%bind () =
        verify_balance ~logger ~pool ~ledger
          ~who:"fee_transfer_via_coinbase receiver" ~balance_id ~pk_id
          ~token_int64 ~balance_block_data ~set_nonces ~repair_nonces
          ~continue_on_error ~output_repair_script_opt
      in
      (* the actual application is in the "coinbase" case *)
      Deferred.unit
  | _ ->
      failwithf "Unknown internal command \"%s\"" cmd.type_ ()

let apply_combined_fee_transfer ~logger ~pool ~ledger ~set_nonces ~repair_nonces
    ~output_repair_script_opt ~continue_on_error (cmd1 : Sql.Internal_command.t)
    (cmd2 : Sql.Internal_command.t) =
  [%log info] "Applying combined fee transfers with sequence number %d"
    cmd1.sequence_no ;
  let fee_transfer_of_cmd (cmd : Sql.Internal_command.t) =
    if not (String.equal cmd.type_ "fee_transfer") then
      failwithf "Expected fee transfer, got: %s" cmd.type_ () ;
    let%map receiver_pk = pk_of_pk_id pool cmd.receiver_id in
    let fee = Currency.Fee.of_uint64 (Unsigned.UInt64.of_int64 cmd.fee) in
    let fee_token = Token_id.of_uint64 (Unsigned.UInt64.of_int64 cmd.token) in
    Fee_transfer.Single.create ~receiver_pk ~fee ~fee_token
  in
  let%bind fee_transfer1 = fee_transfer_of_cmd cmd1 in
  let%bind fee_transfer2 = fee_transfer_of_cmd cmd2 in
  let fee_transfer =
    match Fee_transfer.create fee_transfer1 (Some fee_transfer2) with
    | Ok ft ->
        ft
    | Error err ->
        Error.tag err ~tag:"Could not create combined fee transfer"
        |> Error.raise
  in
  let txn_global_slot =
    cmd2.txn_global_slot_since_genesis |> Unsigned.UInt32.of_int64
    |> Mina_numbers.Global_slot.of_uint32
  in
  let applied_or_error =
    Ledger.apply_fee_transfer ~constraint_constants ~txn_global_slot ledger
      fee_transfer
  in
  match applied_or_error with
  | Ok _ ->
      let balance_block_data = internal_command_to_balance_block_data cmd1 in
      let%bind () =
        verify_balance ~logger ~pool ~ledger ~who:"combined fee transfer (1)"
          ~balance_id:cmd1.receiver_balance ~pk_id:cmd1.receiver_id
          ~token_int64:cmd1.token ~balance_block_data ~set_nonces ~repair_nonces
          ~continue_on_error ~output_repair_script_opt
      in
      let balance_block_data = internal_command_to_balance_block_data cmd2 in
      verify_balance ~logger ~pool ~ledger ~who:"combined fee transfer (2)"
        ~balance_id:cmd2.receiver_balance ~pk_id:cmd2.receiver_id
        ~token_int64:cmd2.token ~balance_block_data ~set_nonces ~repair_nonces
        ~continue_on_error ~output_repair_script_opt
  | Error err ->
      Error.tag_arg err "Error applying combined fee transfer"
        ("sequence number", cmd1.sequence_no)
        [%sexp_of: string * int]
      |> Error.raise

let body_of_sql_user_cmd pool
    ({ type_
     ; source_id
     ; receiver_id
     ; token = tok
     ; amount
     ; global_slot_since_genesis
     ; _
     } :
      Sql.User_command.t ) : Signed_command_payload.Body.t Deferred.t =
  let open Signed_command_payload.Body in
  let open Deferred.Let_syntax in
  let%bind source_pk = pk_of_pk_id pool source_id in
  let%map receiver_pk = pk_of_pk_id pool receiver_id in
  let token_id = Token_id.of_uint64 (Unsigned.UInt64.of_int64 tok) in
  let amount =
    Option.map amount
      ~f:(Fn.compose Currency.Amount.of_uint64 Unsigned.UInt64.of_int64)
  in
  (* possibilities from user_command_type enum in SQL schema *)
  (* TODO: handle "snapp" user commands *)
  match type_ with
  | "payment" ->
      if Option.is_none amount then
        failwithf "Payment at global slot since genesis %Ld has NULL amount"
          global_slot_since_genesis () ;
      let amount = Option.value_exn amount in
      Payment Payment_payload.Poly.{ source_pk; receiver_pk; token_id; amount }
  | "delegation" ->
      Stake_delegation
        (Stake_delegation.Set_delegate
           { delegator = source_pk; new_delegate = receiver_pk } )
  | "create_token" ->
      Create_new_token
        { New_token_payload.token_owner_pk = source_pk
        ; disable_new_accounts = false
        }
  | "create_account" ->
      Create_token_account
        { New_account_payload.token_id
        ; token_owner_pk = source_pk
        ; receiver_pk
        ; account_disabled = false
        }
  | "mint_tokens" ->
      if Option.is_none amount then
        failwithf "Mint token at global slot since genesis %Ld has NULL amount"
          global_slot_since_genesis () ;
      let amount = Option.value_exn amount in
      Mint_tokens
        { Minting_payload.token_id
        ; token_owner_pk = source_pk
        ; receiver_pk
        ; amount
        }
  | _ ->
      failwithf "Invalid user command type: %s" type_ ()

let run_user_command ~logger ~pool ~ledger (cmd : Sql.User_command.t)
    ~set_nonces ~repair_nonces ~continue_on_error ~output_repair_script_opt =
  [%log info]
    "Applying user command (%s) with nonce %Ld, global slot since genesis %Ld, \
     and sequence number %d"
    cmd.type_ cmd.nonce cmd.global_slot_since_genesis cmd.sequence_no ;
  let%bind body = body_of_sql_user_cmd pool cmd in
  let%bind fee_payer_pk = pk_of_pk_id pool cmd.fee_payer_id in
  let memo = Signed_command_memo.of_base58_check_exn cmd.memo in
  let valid_until =
    Option.map cmd.valid_until ~f:(fun slot ->
        Mina_numbers.Global_slot.of_uint32 @@ Unsigned.UInt32.of_int64 slot )
  in
  let payload =
    Signed_command_payload.create
      ~fee:(Currency.Fee.of_uint64 @@ Unsigned.UInt64.of_int64 cmd.fee)
      ~fee_token:(Token_id.of_uint64 @@ Unsigned.UInt64.of_int64 cmd.fee_token)
      ~fee_payer_pk
      ~nonce:(Unsigned.UInt32.of_int64 cmd.nonce)
      ~valid_until ~memo ~body
  in
  (* when applying the transaction, there's a check that the fee payer and
     signer keys are the same; since this transaction was accepted, we know
     those keys are the same
  *)
  let signer = Signature_lib.Public_key.decompress_exn fee_payer_pk in
  let signed_cmd =
    Signed_command.Poly.{ payload; signer; signature = Signature.dummy }
  in
  (* the signature isn't checked when applying, the real signature was checked in the
     transaction SNARK, so deem the signature to be valid here
  *)
  let (`If_this_is_used_it_should_have_a_comment_justifying_it valid_signed_cmd)
      =
    Signed_command.to_valid_unsafe signed_cmd
  in
  let txn_global_slot =
    Unsigned.UInt32.of_int64 cmd.txn_global_slot_since_genesis
  in
  match
    Ledger.apply_user_command ~constraint_constants ~txn_global_slot ledger
      valid_signed_cmd
  with
  | Ok _undo ->
      (* verify balances in database against current ledger *)
      let token_int64 =
        (* if the command is "create token", the token for the command is 0 (meaning unused),
           and the balance is for source/receiver account using the new token
        *)
        match (cmd.token, cmd.created_token) with
        | 0L, Some token ->
            token
        | n, Some m ->
            failwithf "New token %Ld in user command with nonzero token %Ld" n m
              ()
        | _, None ->
            cmd.token
      in
      let balance_block_data = user_command_to_balance_block_data cmd in
      let%bind () =
        match cmd.source_balance with
        | Some balance_id ->
            verify_balance ~logger ~pool ~ledger ~who:"source" ~balance_id
              ~pk_id:cmd.source_id ~token_int64 ~balance_block_data ~set_nonces
              ~repair_nonces ~continue_on_error ~output_repair_script_opt
        | None ->
            return ()
      in
      let%bind () =
        match cmd.receiver_balance with
        | Some balance_id ->
            verify_balance ~logger ~pool ~ledger ~who:"receiver" ~balance_id
              ~pk_id:cmd.receiver_id ~token_int64 ~balance_block_data
              ~set_nonces ~repair_nonces ~continue_on_error
              ~output_repair_script_opt
        | None ->
            return ()
      in
      verify_balance ~logger ~pool ~ledger ~who:"fee payer"
        ~balance_id:cmd.fee_payer_balance ~pk_id:cmd.fee_payer_id
        ~token_int64:cmd.fee_token ~balance_block_data ~set_nonces
        ~repair_nonces ~continue_on_error ~output_repair_script_opt
  | Error err ->
      Error.tag_arg err "User command failed on replay"
        ( ("global slot_since_genesis", cmd.global_slot_since_genesis)
        , ("sequence number", cmd.sequence_no) )
        [%sexp_of: (string * int64) * (string * int)]
      |> Error.raise

let find_canonical_chain ~logger pool slot =
  (* find longest canonical chain
     a slot may represent several blocks, only one of which can be on canonical chain
     starting with max slot, look for chain, decrementing slot until chain found
  *)
  let find_state_hash_chain state_hash =
    match%map
      query_db pool
        ~f:(fun db -> Sql.Block.get_chain db state_hash)
        ~item:"chain from state hash"
    with
    | [] ->
        [%log info] "Block with state hash %s is not along canonical chain"
          state_hash ;
        None
    | _ ->
        Some state_hash
  in
  let%bind state_hashes =
    query_db pool
      ~f:(fun db -> Sql.Block.get_state_hashes_by_slot db slot)
      ~item:"ids by slot"
  in
  Deferred.List.find_map state_hashes ~f:find_state_hash_chain

let try_slot ~logger pool slot =
  let num_tries = 5 in
  let rec go ~slot ~tries_left =
    if tries_left <= 0 then (
      [%log fatal] "Could not find canonical chain after trying %d slots"
        num_tries ;
      Core_kernel.exit 1 ) ;
    match%bind find_canonical_chain ~logger pool slot with
    | None ->
        go ~slot:(Int64.pred slot) ~tries_left:(tries_left - 1)
    | Some state_hash ->
        [%log info]
          "Found possible canonical chain to target state hash %s at slot %Ld"
          state_hash slot ;
        return state_hash
  in
  go ~slot ~tries_left:num_tries

let write_replayer_checkpoint ~logger ~ledger ~last_global_slot_since_genesis
    ~max_canonical_slot =
  if Int64.( <= ) last_global_slot_since_genesis max_canonical_slot then (
    (* start replaying at the slot after the one we've just finished with *)
    let start_slot_since_genesis = Int64.succ last_global_slot_since_genesis in
    let%map replayer_checkpoint =
      let%map input =
        create_replayer_checkpoint ~ledger ~start_slot_since_genesis
      in
      input_to_yojson input |> Yojson.Safe.pretty_to_string
    in
    let checkpoint_file =
      sprintf "replayer-checkpoint-%Ld.json" start_slot_since_genesis
    in
    [%log info] "Writing checkpoint file"
      ~metadata:[ ("checkpoint_file", `String checkpoint_file) ] ;
    Out_channel.with_file checkpoint_file ~f:(fun oc ->
        Out_channel.output_string oc replayer_checkpoint ) )
  else (
    [%log info] "Not writing checkpoint file at slot %Ld, because not canonical"
      last_global_slot_since_genesis
      ~metadata:
        [ ("max_canonical_slot", `String (Int64.to_string max_canonical_slot)) ] ;
    Deferred.unit )

let main ~input_file ~output_file_opt ~archive_uri ~set_nonces ~repair_nonces
    ~checkpoint_interval ~continue_on_error ~output_repair_script_opt () =
  let logger = Logger.create () in
  let json = Yojson.Safe.from_file input_file in
  let input =
    match input_of_yojson json with
    | Ok inp ->
        inp
    | Error msg ->
        failwith
          (sprintf "Could not parse JSON in input file \"%s\": %s" input_file
             msg )
  in
  let archive_uri = Uri.of_string archive_uri in
  match Caqti_async.connect_pool ~max_size:128 archive_uri with
  | Error e ->
      [%log fatal]
        ~metadata:[ ("error", `String (Caqti_error.show e)) ]
        "Failed to create a Caqti pool for Postgresql" ;
      exit 1
  | Ok pool -> (
      [%log info] "Successfully created Caqti pool for Postgresql" ;
      (* load from runtime config in same way as daemon
         except that we don't consider loading from a tar file
      *)
      let%bind padded_accounts =
        match
          Genesis_ledger_helper.Ledger.padded_accounts_from_runtime_config_opt
            ~logger ~proof_level input.genesis_ledger
            ~ledger_name_prefix:"genesis_ledger"
        with
        | None ->
            [%log fatal]
              "Could not load accounts from input runtime genesis ledger" ;
            exit 1
        | Some accounts ->
            return accounts
      in
      let packed_ledger =
        Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts
          ~depth:constraint_constants.ledger_depth padded_accounts
      in
      let ledger = Lazy.force @@ Genesis_ledger.Packed.t packed_ledger in
      let epoch_ledgers_state_hash_opt =
        Option.map input.target_epoch_ledgers_state_hash
          ~f:State_hash.to_base58_check
      in
      let%bind target_state_hash =
        match epoch_ledgers_state_hash_opt with
        | Some epoch_ledgers_state_hash ->
            [%log info] "Retrieving fork block state_hash" ;
            query_db pool
              ~f:(fun db ->
                Sql.Parent_block.get_parent_state_hash db
                  epoch_ledgers_state_hash )
              ~item:"parent state hash of state hash"
        | None ->
            [%log info]
              "Searching for block with greatest height on canonical chain" ;
            let%bind max_slot =
              query_db pool
                ~f:(fun db -> Sql.Block.get_max_slot db ())
                ~item:"max slot"
            in
            [%log info] "Maximum global slot since genesis in blocks is %Ldd"
              max_slot ;
            try_slot ~logger pool max_slot
      in
      [%log info]
        "Loading block information using target state hash and start slot" ;
      (* oldest block id is the id of the block with the earliest slot *)
      let%bind block_ids, oldest_block_id =
        process_block_infos_of_state_hash ~logger pool
          ~state_hash:target_state_hash
          ~start_slot:input.start_slot_since_genesis ~f:(fun block_infos ->
            let ({ id = oldest_block_id; _ } : Sql.Block_info.t) =
              Option.value_exn
                (List.min_elt block_infos ~compare:(fun bi1 bi2 ->
                     Int64.compare bi1.global_slot_since_genesis
                       bi2.global_slot_since_genesis ) )
            in
            let ids = List.map block_infos ~f:(fun { id; _ } -> id) in
            (* build mapping from global slots to state and ledger hashes *)
            List.iter block_infos
              ~f:(fun { global_slot_since_genesis; state_hash; ledger_hash; _ }
                 ->
                Hashtbl.add_exn global_slot_hashes_tbl
                  ~key:global_slot_since_genesis
                  ~data:
                    ( State_hash.of_base58_check_exn state_hash
                    , Ledger_hash.of_base58_check_exn ledger_hash ) ) ;
            return (Int.Set.of_list ids, oldest_block_id) )
      in
      if Int64.equal input.start_slot_since_genesis 0L then
        (* check that genesis block is in chain to target hash
           assumption: genesis block occupies global slot 0

           if nonzero start slot, can't assume there's a block at that slot
        *)
        if Int64.Table.mem global_slot_hashes_tbl Int64.zero then
          [%log info]
            "Block chain leading to target state hash includes genesis block, \
             length = %d"
            (Int.Set.length block_ids)
        else (
          [%log fatal]
            "Block chain leading to target state hash does not include genesis \
             block" ;
          Core_kernel.exit 1 )
      else
        [%log info]
          "Block chain from non-genesis start slot to target state hash has \
           length = %d"
          (Int.Set.length block_ids) ;
      let get_command_ids (module Command_ids : Get_command_ids) name =
        match%bind
          Caqti_async.Pool.use
            (fun db -> Command_ids.run db ~state_hash:target_state_hash)
            pool
        with
        | Ok ids ->
            return ids
        | Error msg ->
            [%log error] "Error getting %s command ids" name
              ~metadata:[ ("error", `String (Caqti_error.show msg)) ] ;
            exit 1
      in
      [%log info] "Loading internal command ids" ;
      let%bind internal_cmd_ids =
        get_command_ids (module Sql.Internal_command_ids) "internal"
      in
      [%log info] "Loading user command ids" ;
      let%bind user_cmd_ids =
        get_command_ids (module Sql.User_command_ids) "user"
      in
      [%log info] "Obtained %d user command ids and %d internal command ids"
        (List.length user_cmd_ids)
        (List.length internal_cmd_ids) ;
      [%log info] "Loading internal commands" ;
      let%bind unsorted_internal_cmds_list =
        Deferred.List.map internal_cmd_ids ~f:(fun id ->
            let open Deferred.Let_syntax in
            match%map
              Caqti_async.Pool.use
                (fun db ->
                  Sql.Internal_command.run db
                    ~start_slot:input.start_slot_since_genesis
                    ~internal_cmd_id:id )
                pool
            with
            | Ok internal_cmds ->
                internal_cmds
            | Error msg ->
                failwithf
                  "Error querying for internal commands with id %d, error %s" id
                  (Caqti_error.show msg) () )
      in
      let unsorted_internal_cmds = List.concat unsorted_internal_cmds_list in
      (* filter out internal commands in blocks not along chain from target state hash *)
      let filtered_internal_cmds =
        List.filter unsorted_internal_cmds ~f:(fun cmd ->
            Int.Set.mem block_ids cmd.block_id )
      in
      [%log info] "Will replay %d internal commands"
        (List.length filtered_internal_cmds) ;
      let sorted_internal_cmds =
        List.sort filtered_internal_cmds ~compare:(fun ic1 ic2 ->
            let tuple (ic : Sql.Internal_command.t) =
              ( ic.global_slot_since_genesis
              , ic.sequence_no
              , ic.secondary_sequence_no )
            in
            let cmp = [%compare: int64 * int * int] (tuple ic1) (tuple ic2) in
            if cmp = 0 then
              match (ic1.type_, ic2.type_) with
              | "coinbase", "fee_transfer_via_coinbase" ->
                  -1
              | "fee_transfer_via_coinbase", "coinbase" ->
                  1
              | s1, s2 ->
                  failwithf
                    "Two internal commands have the same global slot since \
                     genesis %Ld, sequence no %d, and secondary sequence no \
                     %d, but are not a coinbase and fee transfer via coinbase \
                     (%s and %s)"
                    ic1.global_slot_since_genesis ic1.sequence_no
                    ic1.secondary_sequence_no s1 s2 ()
            else cmp )
      in
      (* populate cache of fee transfer via coinbase items *)
      [%log info] "Populating fee transfer via coinbase cache" ;
      let%bind () =
        Deferred.List.iter sorted_internal_cmds
          ~f:(cache_fee_transfer_via_coinbase pool)
      in
      [%log info] "Loading user commands" ;
      let%bind (unsorted_user_cmds_list : Sql.User_command.t list list) =
        Deferred.List.map user_cmd_ids ~f:(fun id ->
            let open Deferred.Let_syntax in
            match%map
              Caqti_async.Pool.use (fun db -> Sql.User_command.run db id) pool
            with
            | Ok [] ->
                failwithf "Expected at least one user command with id %d" id ()
            | Ok user_cmds ->
                user_cmds
            | Error msg ->
                failwithf
                  "Error querying for user commands with id %d, error %s" id
                  (Caqti_error.show msg) () )
      in
      let unsorted_user_cmds = List.concat unsorted_user_cmds_list in
      (* filter out user commands in blocks not along chain from target state hash *)
      let filtered_user_cmds =
        List.filter unsorted_user_cmds ~f:(fun cmd ->
            Int.Set.mem block_ids cmd.block_id )
      in
      [%log info] "Will replay %d user commands"
        (List.length filtered_user_cmds) ;
      let sorted_user_cmds =
        List.sort filtered_user_cmds ~compare:(fun uc1 uc2 ->
            let tuple (uc : Sql.User_command.t) =
              (uc.global_slot_since_genesis, uc.sequence_no)
            in
            [%compare: int64 * int] (tuple uc1) (tuple uc2) )
      in
      let checkpoint_interval_i64 =
        Option.map checkpoint_interval ~f:Int64.of_int
      in
      let checkpoint_target =
        ref
          (Option.map checkpoint_interval_i64 ~f:(fun interval ->
               Int64.(input.start_slot_since_genesis + interval) ) )
      in
      let%bind max_canonical_slot =
        query_db pool
          ~f:(fun db -> Sql.Block.get_max_canonical_slot db ())
          ~item:"max canonical slot"
      in
      let incr_checkpoint_target () =
        Option.iter !checkpoint_target ~f:(fun target ->
            match checkpoint_interval_i64 with
            | Some interval ->
                let new_target = Int64.(target + interval) in
                if Int64.( <= ) new_target max_canonical_slot then (
                  [%log info] "Checkpoint target was %Ld, setting to %Ld" target
                    new_target ;
                  checkpoint_target := Some new_target )
                else (
                  (* set target so it can't be reached *)
                  [%log info]
                    "Checkpoint target was %Ld, new target would be at \
                     noncanonical slot, set target to unreachable value"
                    target ;
                  checkpoint_target := Some Int64.max_value )
            | None ->
                failwith "Expected a checkpoint interval" )
      in
      (* apply commands in global slot, sequence order *)
      let rec apply_commands (internal_cmds : Sql.Internal_command.t list)
          (user_cmds : Sql.User_command.t list) ~last_global_slot_since_genesis
          ~last_block_id ~staking_epoch_ledger ~next_epoch_ledger =
        let%bind staking_epoch_ledger, staking_seed =
          update_staking_epoch_data ~logger pool ~last_block_id ~ledger
            ~staking_epoch_ledger
        in
        let%bind next_epoch_ledger, next_seed =
          update_next_epoch_data ~logger pool ~last_block_id ~ledger
            ~next_epoch_ledger
        in
        let log_ledger_hash_after_last_slot () =
          (* See PR #9782. *)
          let state_hashes_to_avoid =
            (* devnet *)
            [ "3NKNU4WceYUjnQbxaUAmcHQzhGhC8ZxkYKqDKojKMpVjoj9WQZM6"
            ; "3NKvaxewhJ9e1GWvFFT83p4MA2MPFChFoQTmdJ2zeBNX9rLorGFH"
            ; "3NKNDWt8f1vVeFdBN8FCyHnAwnc5oXR18UvqriW2tQtHABTgX2tu"
            ; "3NLR1VaGKs36byogm4atXtiNVre3TtWrrg1Btt3HxGZ2mEBEN5hg"
            ; "3NL3fHu5bAqBNMmQ1Jh3HPZq7xX67WKFyAEUs2FFHJeiYxbEiq69"
            ; "3NLuEU1bJ462uzkJpQXDCo2DcpkkJLbK9kXgwpCYHDuofXo7Smrr"
            ; "3NK9ZYikzJDzXK7CPjyr7jo1S4ZGfKUKa18uTZd96X7YVcQihW1W"
            ; "3NK6PXGHsrRo8iYzWx43rtnyN2ynmZ7enWU7CMWH6oTUi5CRck7c"
            ; "3NKNrQG3DvyxDAuhudq7UhYRQ4GL7suKHcfQ3q7nUDXS1NjHyuZE"
            ; "3NKcbRVyPHeBoWiK8AHXVVYxswv5c4kpmECRS3LTbAVCHzrxbzuH"
            ; "3NKoxfcbnSkFSkFaMpmpgfVFqQmrwR6xkfpCHePLPh5uYKQLdpJt"
            ; "3NKVfBD1kXDJ8ZM3xhR5TFZXBRAs5UanSewxQRpXFmoxGxDddkP5"
            ; "3NKuotwHEdKRBK1yuDNkVUXqCnz5dPpS1xL4UJWghrAUB3t9pRQg"
            ; "3NKou5o9gJpcKBp8LnkUQgFBBQFZB6z7GD88pWDdwgVkfV8HmQTW"
            ; "3NKaqDsxAAFMvvxw22PLDkFaQyeHqioxhvb6BcpzbB3i8uaQdta7"
            ; "3NKCDffYzX5VMH3eH3G8CU6Ba6FndrevGBaJ9NCU7U6nv3iv2bpN"
            ; "3NL9sVkyZLLHFEvGPzr4ihYPzzZ3W3GixxjofeZib8qbe8hE4jUg"
            ; "3NLWggBpXBZxaV2R1DaJrL51uS6NshyDejbPn1gpWhp4E9t1cvPU"
            ; "3NL2cRDQkXEwnv33jTY5UKxLpyUpxKhcnwq7hQcfdDwc9QqXg5K9"
            ; "3NKvh8kXNtaJAhuC6Eqa8K4r2whzLuN5G7F8M14GTB1tcFKERp3z"
            ; "3NKVo2E1TGfb2pQ3jv84m7tVid4d6AHnKbDMZLWcrPxWwQJTYiQg"
            ; "3NL8d9RgUbDXjy92eH6ZVFc1ozn3darQx8u9EViMiCqrv5Ywe42x"
            ; "3NLGBF3yXbnQQxophx4YZfdXGcTt11KjC7jv8qaf3b8B8tZdrCBh"
            ; "3NKAbgwCDsdW6m18FSj8mBE2SpdMd7gopc5NMqGHxkqqLykMZrCR"
            ; "3NKFtTCSqVqKdbm6unoCiQWnKnozwYsiey5aPegV5xMR2MNR9kjZ"
            ; "3NKEyaQdmFtYWx2swLjkcpBeQGsfo8riNH6Kbdr9myWUQrZkbqjV"
            ; "3NK7jasQXuACjzJ5mBPNr13Y6Yt8vD6piLc1waFBU4Jte8WzEZ4h"
            ; "3NLPbRNQi6JFbh7DW9ibPgRhUnExwGaMpiuGJdEQ6Na47kWcP3PW"
            ; "3NK4EUku6d9fmU3P1t7NnoxsN4sg699JSskJZ4nJs1mWSHs1CL4v"
            ; "3NLDE8xKUvKMiSpLSd9uvnQaRiXYW6MWw7UXpFD2wbq4WeKRAnKM"
            ; "3NLZYyohgxGFE3hw6o6tfvXnZLoG6gyzr67WNGPFfpugHtoXaFGq" (*mainnet*)
            ; "3NKCedb2xxrgiaBFKVpxAJ9Kp7Tu1JG4qCUppJmt3c1RULQYQtrZ"
            ; "3NKjb8G3Sc4Z5hLckDy2Wg8soZmdghenyAYDuHVF5uNV36Td9DZt"
            ; "3NKKrhT3QX5tUS18kyGkYnjfNCCppgjy9zcZrmtMeNynEce47zpj"
            ; "3NKzdd7UjWLygUvgKfJwd3MVj3PD1GnXDHHGoTLyXinVvSoFRyX5"
            ; "3NKpPvE3NfGnbqRU4U6fDCMdUi9c54kphuDY4jniJuHZ62MyPWmr"
            ; "3NLP9qXSUAo9b8XjLZ8YpvdvEJ1g4TUdeznBH5kDAFv6kYYCGY51"
            ; "3NLLEfqqPdWHDtM7nw4S27uejcLZQ5D7N3BzmCNR5acYSaGuJ4pH"
            ; "3NKJoVQRihbwMUTDJKv4patDDMF8xGrvAaxQ9d2QJovJFegSuEQV"
            ; "3NKQ8W6L77xjPbz9sPNp357gfJ6a5LMD8K8kwGnW5jyULcCbd5Su"
            ; "3NLYL2dmLyGd889rwF5EmdjWE2BBGCZcHAwJA8MotiPVDiXLvktw"
            ; "3NLhmVdQvxpQLNvyehAXZKDsVrkgjb812VfpbgKqBRWSLa9c1kAA"
            ; "3NKX71ifBPJCZFDLdeLmhY97Zc8Y3xt2JZTFLgqtTnv53JvRcbzx"
            ; "3NLUhVLiWav4kBszLKZ6oDNC2BkbeX2cftsUGb6egeixjvqu3qqt"
            ; "3NKtmu2j6UJ9oggDJbtY6UDzZrMgDF8CH5A5xs3GyQUqMq4nS1ZN"
            ; "3NKJbfqrRzsjDC3FkSv5tsKQ7yp1xxYsXcs6arsoj18MKhcMVNeA"
            ; "3NKy6JUgC8r6ZGCKcQxPmKu9pN8xv5mGqVEiC1z1dLuVYhc2KEvV"
            ; "3NLi5AWq9YCT2XrB5vxkC5Psxrjv3JjHmK5DX87duztbCcL2oJkD"
            ; "3NKm5VGDQXtekWf3erWfjcHciGzjAWB4u7WNE7gAHGYjvkFbF5xj"
            ; "3NLnTnSMFayzpAahTgyL9mY1og2HDJjcg9kpKsQT5iQcPJ7FtJtJ"
            ; "3NKGm1K6T9pV7ygFqtScugMQB7EhDozsiz8Fe9LAYG2yx8yYie6p"
            ; "3NKj4YqZq1RCMDK3YM1gRtFZ2fspR1sNbRjQw4GA6Ut2Ar16jEYF"
            ; "3NLC7zugGno2Emt3w2DRJx6LdRzmoiW4F9PuAYurLQFmWFqEer1V"
            ; "3NKAKrhJrvFJtgMvr72ZXTaWPFisgDaND3AxZoPR6gAff5qDuKcq"
            ; "3NKDaz4DVLp4bQ5FJiXjEQPWmwgzvXAfCLY3w8d5NjzJZNVXnF6Q"
            ; "3NLKV4BUZwzpYvqcByRhJoKyME6Q5KEcrHPVY21XPfXsbPp486eu"
            ; "3NLbwy3BrF7gxEPF9WPoJPeED9NUC2RXdDnoJf6GvRwzksJThnM9"
            ; "3NKfHZ5DJkL3jjzstrfTCjHczMrPzvBsgPQ66trR9yqkE9dHJ7AD"
            ; "3NKUaab3R1mcG9caqyUUntpjvYD7VYUJ7rWjTCbgxzob3miG3WHK"
            ; "3NL2aQWNi6JadvfmwkyJVCtd9MjVwDCbvY1bfHbwCm1nJrDwSV2A"
            ; "3NK7ANsW4LQ62Hk8DJNEF36yyccoECJKmdeAyaf96WmksR2TyM3C"
            ; "3NKa82y8gNUe8ePYjq7jEh38vyWVLEteHynK686D8qaebeHpmfsS"
            ; "3NLcmRzkBdmFKqhpKEbw33A7GAd1EG7dg6CVwUhC4RKDTBZGnYDQ"
            ; "3NLHTdvTPXxUn8YFy4z59NxDcX9DYhthFtv8aPNMmpm2pYuA6Tf6"
            ]
          in

          match get_slot_hashes last_global_slot_since_genesis with
          | None ->
              if
                Int64.equal last_global_slot_since_genesis
                  input.start_slot_since_genesis
              then
                [%log info]
                  "No ledger hash information at start slot, not checking \
                   against ledger"
              else (
                [%log fatal]
                  "Missing ledger hash information for last global slot, which \
                   is not the start slot" ;
                Core.exit 1 )
          | Some (state_hash, expected_ledger_hash) ->
              if
                Ledger_hash.equal
                  (Ledger.merkle_root ledger)
                  expected_ledger_hash
              then
                [%log info]
                  "Applied all commands at global slot since genesis %Ld, got \
                   expected ledger hash"
                  ~metadata:
                    [ ("ledger_hash", json_ledger_hash_of_ledger ledger) ]
                  last_global_slot_since_genesis
              else if
                List.mem state_hashes_to_avoid
                  (State_hash.to_base58_check state_hash)
                  ~equal:String.equal
              then
                [%log info]
                  ~metadata:
                    [ ( "state_hash"
                      , `String (State_hash.to_base58_check state_hash) )
                    ]
                  "This block has an inconsistent ledger hash due to a known \
                   historical issue."
              else (
                [%log error]
                  "Applied all commands at global slot since genesis %Ld, \
                   ledger hash differs from expected ledger hash"
                  ~metadata:
                    [ ("ledger_hash", json_ledger_hash_of_ledger ledger)
                    ; ( "expected_ledger_hash"
                      , Ledger_hash.to_yojson expected_ledger_hash )
                    ]
                  last_global_slot_since_genesis ;
                if continue_on_error then incr error_count
                else Core_kernel.exit 1 )
        in
        let log_state_hash_on_next_slot curr_global_slot_since_genesis =
          match get_slot_hashes curr_global_slot_since_genesis with
          | None ->
              [%log fatal]
                "Missing state hash information for current global slot" ;
              Core.exit 1
          | Some (state_hash, _ledger_hash) ->
              [%log info]
                ~metadata:
                  [ ( "state_hash"
                    , `String (State_hash.to_base58_check state_hash) )
                  ]
                "Starting processing of commands in block with state_hash \
                 $state_hash at global slot since genesis %Ld"
                curr_global_slot_since_genesis
        in
        let write_checkpoint_file () =
          match !checkpoint_target with
          | None ->
              Deferred.unit
          | Some target ->
              if Int64.(last_global_slot_since_genesis >= target) then (
                incr_checkpoint_target () ;
                write_replayer_checkpoint ~logger ~ledger
                  ~last_global_slot_since_genesis ~max_canonical_slot )
              else Deferred.unit
        in
        let run_actions_on_slot_change curr_global_slot_since_genesis =
          if
            Int64.( > ) curr_global_slot_since_genesis
              last_global_slot_since_genesis
          then (
            log_ledger_hash_after_last_slot () ;
            log_state_hash_on_next_slot curr_global_slot_since_genesis ;
            write_checkpoint_file () )
          else Deferred.unit
        in
        let combine_or_run_internal_cmds (ic : Sql.Internal_command.t)
            (ics : Sql.Internal_command.t list) =
          match ics with
          | ic2 :: ics2
            when Int64.equal ic.global_slot_since_genesis
                   ic2.global_slot_since_genesis
                 && Int.equal ic.sequence_no ic2.sequence_no
                 && String.equal ic.type_ "fee_transfer"
                 && String.equal ic.type_ ic2.type_ ->
              (* combining situation 2
                 two fee transfer commands with same global slot since genesis, sequence number
              *)
              let%bind () =
                run_actions_on_slot_change ic.global_slot_since_genesis
              in
              let%bind () =
                apply_combined_fee_transfer ~logger ~pool ~ledger ~set_nonces
                  ~repair_nonces ~continue_on_error ic ic2
                  ~output_repair_script_opt
              in
              apply_commands ics2 user_cmds
                ~last_global_slot_since_genesis:ic.global_slot_since_genesis
                ~last_block_id:ic.block_id ~staking_epoch_ledger
                ~next_epoch_ledger
          | _ ->
              let%bind () =
                run_actions_on_slot_change ic.global_slot_since_genesis
              in
              let%bind () =
                run_internal_command ~logger ~pool ~ledger ~set_nonces
                  ~repair_nonces ~continue_on_error ic ~output_repair_script_opt
              in
              apply_commands ics user_cmds
                ~last_global_slot_since_genesis:ic.global_slot_since_genesis
                ~last_block_id:ic.block_id ~staking_epoch_ledger
                ~next_epoch_ledger
        in
        (* choose command with least global slot since genesis, sequence number *)
        let cmp_ic_uc (ic : Sql.Internal_command.t) (uc : Sql.User_command.t) =
          [%compare: int64 * int]
            (ic.global_slot_since_genesis, ic.sequence_no)
            (uc.global_slot_since_genesis, uc.sequence_no)
        in
        match (internal_cmds, user_cmds) with
        | [], [] ->
            log_ledger_hash_after_last_slot () ;
            let%map () =
              write_replayer_checkpoint ~logger ~ledger
                ~last_global_slot_since_genesis ~max_canonical_slot
            in
            (staking_epoch_ledger, staking_seed, next_epoch_ledger, next_seed)
        | [], uc :: ucs ->
            let%bind () =
              run_actions_on_slot_change uc.global_slot_since_genesis
            in
            let%bind () =
              run_user_command ~logger ~pool ~ledger ~set_nonces ~repair_nonces
                ~continue_on_error uc ~output_repair_script_opt
            in
            apply_commands [] ucs
              ~last_global_slot_since_genesis:uc.global_slot_since_genesis
              ~last_block_id:uc.block_id ~staking_epoch_ledger
              ~next_epoch_ledger
        | ic :: _, uc :: ucs when cmp_ic_uc ic uc > 0 ->
            let%bind () =
              run_actions_on_slot_change uc.global_slot_since_genesis
            in
            let%bind () =
              run_user_command ~logger ~pool ~ledger ~set_nonces ~repair_nonces
                ~continue_on_error uc ~output_repair_script_opt
            in
            apply_commands internal_cmds ucs
              ~last_global_slot_since_genesis:uc.global_slot_since_genesis
              ~last_block_id:uc.block_id ~staking_epoch_ledger
              ~next_epoch_ledger
        | ic :: ics, [] ->
            combine_or_run_internal_cmds ic ics
        | ic :: ics, uc :: _ when cmp_ic_uc ic uc < 0 ->
            combine_or_run_internal_cmds ic ics
        | ic :: _, _ :: __ ->
            failwithf
              "An internal command and a user command have the same global \
               slot since_genesis %Ld and sequence number %d"
              ic.global_slot_since_genesis ic.sequence_no ()
      in
      let%bind start_slot_since_genesis =
        let%map slot_opt =
          query_db pool
            ~f:(fun db ->
              Sql.Block.get_next_slot db input.start_slot_since_genesis )
            ~item:"Start slot"
        in
        match slot_opt with
        | Some slot ->
            slot
        | None ->
            failwithf
              "There is no slot in the database greater than equal to the \
               start slot %Ld given in the input file"
              input.start_slot_since_genesis ()
      in
      if
        not
          (Int64.equal start_slot_since_genesis input.start_slot_since_genesis)
      then
        [%log info]
          "Starting with next available global slot in the archive database"
          ~metadata:
            [ ( "input_start_slot"
              , `String (Int64.to_string input.start_slot_since_genesis) )
            ; ( "available_start_slot"
              , `String (Int64.to_string start_slot_since_genesis) )
            ] ;
      [%log info] "At start global slot %Ld, ledger hash"
        start_slot_since_genesis
        ~metadata:[ ("ledger_hash", json_ledger_hash_of_ledger ledger) ] ;
      let%bind staking_epoch_ledger, staking_seed, next_epoch_ledger, next_seed
          =
        apply_commands sorted_internal_cmds sorted_user_cmds
          ~last_global_slot_since_genesis:start_slot_since_genesis
          ~last_block_id:oldest_block_id ~staking_epoch_ledger:ledger
          ~next_epoch_ledger:ledger
      in
      match input.target_epoch_ledgers_state_hash with
      | None ->
          [%log info] "No target epoch ledger hash supplied, not writing output" ;
          Deferred.unit
      | Some target_epoch_ledgers_state_hash -> (
          match output_file_opt with
          | None ->
              [%log info] "Output file not supplied, not writing output" ;
              return ()
          | Some output_file ->
              if Int.equal !error_count 0 then (
                [%log info] "Writing output to $output_file"
                  ~metadata:[ ("output_file", `String output_file) ] ;
                let%bind output =
                  let%map output =
                    create_output ~target_epoch_ledgers_state_hash
                      ~target_fork_state_hash:
                        (State_hash.of_base58_check_exn target_state_hash)
                      ~ledger ~staking_epoch_ledger ~staking_seed
                      ~next_epoch_ledger ~next_seed input.genesis_ledger
                  in
                  output_to_yojson output |> Yojson.Safe.pretty_to_string
                in
                return
                @@ Out_channel.with_file output_file ~f:(fun oc ->
                       Out_channel.output_string oc output ) )
              else (
                [%log error] "There were %d errors, not writing output"
                  !error_count ;
                exit 1 ) ) )

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async ~summary:"Replay transactions from Mina archive"
        (let%map input_file =
           Param.flag "--input-file"
             ~doc:"file File containing the genesis ledger"
             Param.(required string)
         and output_file_opt =
           Param.flag "--output-file"
             ~doc:"file File containing the resulting ledger"
             Param.(optional string)
         and archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER@localhost:5432/archiver)"
             Param.(required string)
         and set_nonces =
           Param.flag "--set-nonces"
             ~doc:"Set missing nonces in archive database" Param.no_arg
         and repair_nonces =
           Param.flag "--repair-nonces"
             ~doc:"Repair incorrect nonces in archive database" Param.no_arg
         and output_repair_script_opt =
           Param.flag "--dump-repair-script"
             ~doc:
               "file Output sql script which will contain all updates to \
                nonces made during replayer run. Works only when using \
                --repair-nonces or --set-nonces args"
             Param.(optional string)
         and continue_on_error =
           Param.flag "--continue-on-error"
             ~doc:"Continue processing after errors" Param.no_arg
         and checkpoint_interval =
           Param.flag "--checkpoint-interval"
             ~doc:"NN Write checkpoint file every NN slots"
             Param.(optional int)
         in
         if
           Option.is_some output_repair_script_opt
           && not (repair_nonces || set_nonces)
         then (
           eprintf
             "--dump-repair-script requires --repair-nonces or --set-nonces" ;
           exit 1 ) ;
         main ~input_file ~output_file_opt ~archive_uri ~set_nonces
           ~repair_nonces ~checkpoint_interval ~continue_on_error
           ~output_repair_script_opt )))
