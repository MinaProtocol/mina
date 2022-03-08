(* replayer.ml -- replay transactions from archive node database *)

open Core
open Async
open Mina_base
module Ledger = Mina_ledger.Ledger
module Processor = Archive_lib.Processor

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

type command_type = [ `Internal_command | `User_command | `Snapp_command ]

module type Get_command_ids = sig
  val run :
       Caqti_async.connection
    -> string
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
  List.map (Ledger.to_list ledger) ~f:(fun acc ->
      Genesis_ledger_helper.Accounts.Single.of_account acc None)

let create_output ~target_fork_state_hash ~target_epoch_ledgers_state_hash
    ~ledger ~staking_epoch_ledger ~staking_seed ~next_epoch_ledger ~next_seed
    (input_genesis_ledger : Runtime_config.Ledger.t) =
  let genesis_ledger_as_list = create_ledger_as_list ledger in
  let target_genesis_ledger =
    { input_genesis_ledger with base = Accounts genesis_ledger_as_list }
  in
  let staking_epoch_ledger_as_list =
    create_ledger_as_list staking_epoch_ledger
  in
  let next_epoch_ledger_as_list = create_ledger_as_list next_epoch_ledger in
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

let create_replayer_checkpoint ~ledger ~start_slot_since_genesis : input =
  let accounts = create_ledger_as_list ledger in
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

(* the starting slot may not have a block, so there may not be an entry in the table
    of hashes
   look at the predecessor slots until we find an entry
   this search should only happen on the start slot, all other slots
    come from commands in blocks, for which we have an entry in the table
*)
let get_slot_hashes ~logger slot =
  let rec go curr_slot =
    if Int64.is_negative curr_slot then (
      [%log fatal]
        "Could not find state and ledger hashes for slot %Ld, despite trying \
         all predecessor slots"
        slot ;
      Core.exit 1 ) ;
    match Hashtbl.find global_slot_hashes_tbl curr_slot with
    | None ->
        [%log info]
          "State and ledger hashes not available at slot since genesis %Ld, \
           will try predecessor slot"
          curr_slot ;
        go (Int64.pred curr_slot)
    | Some hashes ->
        hashes
  in
  go slot

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

let process_block_infos_of_state_hash ~logger pool state_hash ~f =
  match%bind
    Caqti_async.Pool.use (fun db -> Sql.Block_info.run db state_hash) pool
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
    let accounts = Ledger.to_list ledger in
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
            |> Error.raise) ;
    epoch_ledger )
  else epoch_ledger

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
  let%map { epoch_ledger_hash; epoch_data_seed } =
    query_db pool
      ~f:(fun db -> Sql.Epoch_data.get_epoch_data db staking_epoch_id)
      ~item:"staking epoch data"
  in
  let ledger =
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
  let%map { epoch_ledger_hash; epoch_data_seed } =
    query_db pool
      ~f:(fun db -> Sql.Epoch_data.get_epoch_data db next_epoch_id)
      ~item:"next epoch data"
  in
  let ledger =
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

(* balance_block_data come from a loaded internal or user command, which
    includes data from the blocks table and
   - for internal commands, the tables internal_commands and blocks_internals_commands
   - for user commands, the tables user_commands and blocks_user_commands
     we compare those against the same-named values in the balances row
*)
let verify_balance ~logger ~pool ~ledger ~who ~balance_id ~pk_id ~token_int64
    ~balance_block_data ~set_nonces ~repair_nonces ~continue_on_error :
    unit Deferred.t =
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
        query_db pool
          ~f:(fun db -> Sql.Balances.insert_nonce db ~id:balance_id ~nonce)
          ~item:"chain from state hash" )
      else (
        [%log error] "Missing nonce in archive db"
          ~metadata:
            [ ("balance_id", `Int balance_id)
            ; ("nonce", `String (Account.Nonce.to_string ledger_nonce))
            ] ;
        return
        @@ if continue_on_error then incr error_count else Core_kernel.exit 1 )
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
          query_db pool
            ~f:(fun db ->
              Sql.Balances.insert_nonce db ~id:balance_id ~nonce:correct_nonce)
            ~item:"repairing nonce" )
        else (
          [%log error] "Ledger nonce does not match nonce in balances table"
            ~metadata:
              [ ("who", `String who)
              ; ("ledger_nonce", Account.Nonce.to_yojson ledger_nonce)
              ; ("database_nonce", Account.Nonce.to_yojson db_nonce)
              ] ;
          return
          @@ if continue_on_error then incr error_count else Core_kernel.exit 1
          )
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
                 ]) ;
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
                   ]) ;
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
                 ]) ;
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
               ]) ;
        if continue_on_error then incr error_count else Core_kernel.exit 1

let run_internal_command ~logger ~pool ~ledger (cmd : Sql.Internal_command.t)
    ~set_nonces ~repair_nonces ~continue_on_error =
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
  let balance_id = cmd.receiver_balance_id in
  let token_int64 = cmd.token in
  let receiver_account_creation_fee = cmd.receiver_account_creation_fee_paid in
  let balance_block_data = internal_command_to_balance_block_data cmd in
  let open Ledger in
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
            ~repair_nonces ~continue_on_error
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
            ~repair_nonces ~continue_on_error
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
          ~continue_on_error
      in
      (* the actual application is in the "coinbase" case *)
      Deferred.unit
  | _ ->
      failwithf "Unknown internal command \"%s\"" cmd.type_ ()

let apply_combined_fee_transfer ~logger ~pool ~ledger ~set_nonces ~repair_nonces
    ~continue_on_error (cmd1 : Sql.Internal_command.t)
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
          ~balance_id:cmd1.receiver_balance_id ~pk_id:cmd1.receiver_id
          ~token_int64:cmd1.token ~balance_block_data ~set_nonces ~repair_nonces
          ~continue_on_error
      in
      let balance_block_data = internal_command_to_balance_block_data cmd2 in
      verify_balance ~logger ~pool ~ledger ~who:"combined fee transfer (2)"
        ~balance_id:cmd2.receiver_balance_id ~pk_id:cmd2.receiver_id
        ~token_int64:cmd2.token ~balance_block_data ~set_nonces ~repair_nonces
        ~continue_on_error
  | Error err ->
      Error.tag_arg err "Error applying combined fee transfer"
        ("sequence number", cmd1.sequence_no)
        [%sexp_of: string * int]
      |> Error.raise

module User_command_helpers = struct
  let body_of_sql_user_cmd pool
      ({ type_
       ; source_id
       ; receiver_id
       ; token = tok
       ; amount
       ; global_slot_since_genesis
       ; _
       } :
        Sql.User_command.t) : Signed_command_payload.Body.t Deferred.t =
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
    match type_ with
    | "payment" ->
        if Option.is_none amount then
          failwithf "Payment at global slot since genesis %Ld has NULL amount"
            global_slot_since_genesis () ;
        let amount = Option.value_exn amount in
        Payment
          Payment_payload.Poly.{ source_pk; receiver_pk; token_id; amount }
    | "delegation" ->
        Stake_delegation
          (Stake_delegation.Set_delegate
             { delegator = source_pk; new_delegate = receiver_pk })
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
          failwithf
            "Mint token at global slot since genesis %Ld has NULL amount"
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
end

let run_user_command ~logger ~pool ~ledger (cmd : Sql.User_command.t)
    ~set_nonces ~repair_nonces ~continue_on_error =
  [%log info]
    "Applying user command (%s) with nonce %Ld, global slot since genesis %Ld, \
     and sequence number %d"
    cmd.type_ cmd.nonce cmd.global_slot_since_genesis cmd.sequence_no ;
  let%bind body = User_command_helpers.body_of_sql_user_cmd pool cmd in
  let%bind fee_payer_pk = pk_of_pk_id pool cmd.fee_payer_id in
  let memo = Signed_command_memo.of_base58_check_exn cmd.memo in
  let valid_until =
    Option.map cmd.valid_until ~f:(fun slot ->
        Mina_numbers.Global_slot.of_uint32 @@ Unsigned.UInt32.of_int64 slot)
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
        match cmd.source_balance_id with
        | Some balance_id ->
            verify_balance ~logger ~pool ~ledger ~who:"source" ~balance_id
              ~pk_id:cmd.source_id ~token_int64 ~balance_block_data ~set_nonces
              ~repair_nonces ~continue_on_error
        | None ->
            return ()
      in
      let%bind () =
        match cmd.receiver_balance_id with
        | Some balance_id ->
            verify_balance ~logger ~pool ~ledger ~who:"receiver" ~balance_id
              ~pk_id:cmd.receiver_id ~token_int64 ~balance_block_data
              ~set_nonces ~repair_nonces ~continue_on_error
        | None ->
            return ()
      in
      verify_balance ~logger ~pool ~ledger ~who:"fee payer"
        ~balance_id:cmd.fee_payer_balance_id ~pk_id:cmd.fee_payer_id
        ~token_int64:cmd.fee_token ~balance_block_data ~set_nonces
        ~repair_nonces ~continue_on_error
  | Error err ->
      Error.tag_arg err "User command failed on replay"
        ( ("global slot_since_genesis", cmd.global_slot_since_genesis)
        , ("sequence number", cmd.sequence_no) )
        [%sexp_of: (string * int64) * (string * int)]
      |> Error.raise

module Snapp_helpers = struct
  let get_parent_state_view ~pool block_id :
      Snapp_predicate.Protocol_state.View.t Deferred.t =
    (* when a Snapp is applied, use the protocol state associated with the parent block
       of the block containing the transaction
    *)
    let%bind parent_id =
      query_db pool
        ~f:(fun db -> Sql.Block.get_parent_id db block_id)
        ~item:"block parent id"
    in
    let%bind parent_block =
      query_db pool
        ~f:(fun db -> Processor.Block.load db ~id:parent_id)
        ~item:"parent block"
    in
    let%bind snarked_ledger_hash_str =
      query_db pool
        ~f:(fun db ->
          Sql.Snarked_ledger_hashes.run db parent_block.snarked_ledger_hash_id)
        ~item:"parent block snarked ledger hash"
    in
    let snarked_ledger_hash =
      Frozen_ledger_hash.of_base58_check_exn snarked_ledger_hash_str
    in
    let snarked_next_available_token =
      parent_block.next_available_token |> Unsigned.UInt64.of_int64
      |> Token_id.of_uint64
    in
    let timestamp = parent_block.timestamp |> Block_time.of_int64 in
    let blockchain_length =
      parent_block.height |> Unsigned.UInt32.of_int64
      |> Mina_numbers.Length.of_uint32
    in
    let min_window_density =
      parent_block.min_window_density |> Unsigned.UInt32.of_int64
      |> Mina_numbers.Length.of_uint32
    in
    (* TODO : this will change *)
    let last_vrf_output = () in
    let total_currency =
      parent_block.total_currency |> Unsigned.UInt64.of_int64
      |> Currency.Amount.of_uint64
    in
    let global_slot_since_hard_fork =
      parent_block.global_slot_since_hard_fork |> Unsigned.UInt32.of_int64
      |> Mina_numbers.Global_slot.of_uint32
    in
    let global_slot_since_genesis =
      parent_block.global_slot_since_genesis |> Unsigned.UInt32.of_int64
      |> Mina_numbers.Global_slot.of_uint32
    in
    let epoch_data_of_raw_epoch_data (raw_epoch_data : Processor.Epoch_data.t) :
        Mina_base.Epoch_data.Value.t Deferred.t =
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
    in
    let%bind staking_epoch_raw =
      query_db pool
        ~f:(fun db ->
          Processor.Epoch_data.load db parent_block.staking_epoch_data_id)
        ~item:"staking epoch data"
    in
    let%bind (staking_epoch_data : Mina_base.Epoch_data.Value.t) =
      epoch_data_of_raw_epoch_data staking_epoch_raw
    in
    let%bind next_epoch_raw =
      query_db pool
        ~f:(fun db ->
          Processor.Epoch_data.load db parent_block.staking_epoch_data_id)
        ~item:"staking epoch data"
    in
    let%bind next_epoch_data = epoch_data_of_raw_epoch_data next_epoch_raw in
    return
      { Snapp_predicate.Protocol_state.Poly.snarked_ledger_hash
      ; snarked_next_available_token
      ; timestamp
      ; blockchain_length
      ; min_window_density
      ; last_vrf_output
      ; total_currency
      ; global_slot_since_hard_fork
      ; global_slot_since_genesis
      ; staking_epoch_data
      ; next_epoch_data
      }

  let get_field_arrays ~pool array_id_arrays =
    let array_ids = Array.to_list array_id_arrays in
    Deferred.List.map array_ids ~f:(fun array_id ->
        let%bind element_id_array =
          query_db pool
            ~f:(fun db -> Processor.Snapp_state_data_array.load db array_id)
            ~item:"Snapp state data array"
        in
        let element_ids = Array.to_list element_id_array in
        let%bind field_strs =
          Deferred.List.map element_ids ~f:(fun elt_id ->
              query_db pool ~item:"Snapp field element" ~f:(fun db ->
                  Processor.Snapp_state_data.load db elt_id))
        in
        let fields =
          List.map field_strs ~f:(fun field_str ->
              Snark_params.Tick.Field.of_string field_str)
        in
        return (Array.of_list fields))

  let state_data_of_ids ~pool ids =
    Deferred.Array.map ids ~f:(fun state_data_id ->
        match state_data_id with
        | None ->
            return None
        | Some id ->
            let%map field_str =
              query_db pool
                ~f:(fun db -> Processor.Snapp_state_data.load db id)
                ~item:"Snapp state data"
            in
            Some (Snark_params.Tick.Field.of_string field_str))

  let party_body_of_id ~pool body_id =
    let%bind (body_data : Processor.Snapp_party_body.t) =
      query_db pool
        ~f:(fun db -> Processor.Snapp_party_body.load db body_id)
        ~item:"Snapp party body"
    in
    let%bind public_key = pk_of_pk_id pool body_data.public_key_id in
    let%bind update_data =
      query_db pool
        ~f:(fun db -> Processor.Snapp_updates.load db body_data.update_id)
        ~item:"snapp updates"
    in
    let%bind app_state_data_ids =
      query_db pool
        ~f:(fun db -> Processor.Snapp_states.load db update_data.app_state_id)
        ~item:"snapp app state ids"
    in
    let%bind app_state_data = state_data_of_ids ~pool app_state_data_ids in
    let app_state =
      Array.map app_state_data ~f:Snapp_basic.Set_or_keep.of_option
      |> Array.to_list |> Pickles_types.Vector.Vector_8.of_list_exn
    in
    let%bind delegate =
      match update_data.delegate_id with
      | Some id ->
          let%map pk = pk_of_pk_id pool id in
          Snapp_basic.Set_or_keep.Set pk
      | None ->
          return Snapp_basic.Set_or_keep.Keep
    in
    let%bind verification_key =
      match update_data.verification_key_id with
      | Some id ->
          let%map ({ verification_key; hash }
                    : Processor.Snapp_verification_keys.t) =
            query_db pool
              ~f:(fun db -> Processor.Snapp_verification_keys.load db id)
              ~item:"snapp verification key"
          in
          let data =
            Pickles.Side_loaded.Verification_key.of_base58_check_exn
              verification_key
          in
          let hash = Snark_params.Tick.Field.of_string hash in
          Snapp_basic.Set_or_keep.Set { With_hash.data; hash }
      | None ->
          return Snapp_basic.Set_or_keep.Keep
    in
    let%bind permissions =
      match update_data.permissions_id with
      | Some id ->
          let%map perms_data =
            query_db pool
              ~f:(fun db -> Processor.Snapp_permissions.load db id)
              ~item:"snapp verification key"
          in
          let perms : Mina_base.Permissions.t =
            { edit_state = perms_data.edit_state
            ; send = perms_data.send
            ; receive = perms_data.receive
            ; set_delegate = perms_data.set_delegate
            ; set_permissions = perms_data.set_permissions
            ; set_verification_key = perms_data.set_verification_key
            ; set_snapp_uri = perms_data.set_snapp_uri
            ; edit_sequence_state = perms_data.edit_sequence_state
            ; set_token_symbol = perms_data.set_token_symbol
            ; increment_nonce = perms_data.increment_nonce
            ; set_voting_for = perms_data.set_voting_for
            }
          in
          Snapp_basic.Set_or_keep.Set perms
      | None ->
          return Snapp_basic.Set_or_keep.Keep
    in
    let snapp_uri =
      update_data.snapp_uri |> Snapp_basic.Set_or_keep.of_option
    in
    let token_symbol =
      update_data.token_symbol |> Snapp_basic.Set_or_keep.of_option
    in
    let voting_for =
      update_data.voting_for
      |> Option.map ~f:State_hash.of_base58_check_exn
      |> Snapp_basic.Set_or_keep.of_option
    in
    let%bind timing =
      match update_data.timing_id with
      | None ->
          return Snapp_basic.Set_or_keep.Keep
      | Some id ->
          let%map tm_info =
            query_db pool
              ~f:(fun db -> Processor.Snapp_timing_info.load db id)
              ~item:"snapp timing info"
          in
          Snapp_basic.Set_or_keep.Set
            { Party.Update.Timing_info.initial_minimum_balance =
                tm_info.initial_minimum_balance |> Unsigned.UInt64.of_int64
                |> Currency.Balance.of_uint64
            ; cliff_time =
                tm_info.cliff_time |> Unsigned.UInt32.of_int64
                |> Mina_numbers.Global_slot.of_uint32
            ; cliff_amount =
                tm_info.cliff_amount |> Unsigned.UInt64.of_int64
                |> Currency.Amount.of_uint64
            ; vesting_period =
                tm_info.vesting_period |> Unsigned.UInt32.of_int64
                |> Mina_numbers.Global_slot.of_uint32
            ; vesting_increment =
                tm_info.vesting_increment |> Unsigned.UInt64.of_int64
                |> Currency.Amount.of_uint64
            }
    in
    let update : Party.Update.t =
      { app_state
      ; delegate
      ; verification_key
      ; permissions
      ; snapp_uri
      ; token_symbol
      ; timing
      ; voting_for
      }
    in
    let token_id =
      body_data.token_id |> Unsigned.UInt64.of_int64 |> Token_id.of_uint64
    in
    let balance_change =
      let magnitude =
        body_data.balance_change |> Int64.abs |> Unsigned.UInt64.of_int64
        |> Currency.Amount.of_uint64
      in
      let sgn =
        if Int64.is_negative body_data.balance_change then Sgn.Neg else Sgn.Pos
      in
      ({ magnitude; sgn } : _ Currency.Signed_poly.t)
    in
    let increment_nonce = body_data.increment_nonce in
    let%bind events = get_field_arrays ~pool body_data.events_ids in
    let%bind sequence_events =
      get_field_arrays ~pool body_data.sequence_events_ids
    in
    let%bind call_data_str =
      query_db pool
        ~f:(fun db -> Processor.Snapp_state_data.load db body_data.call_data_id)
        ~item:"Snapp call data"
    in
    let call_data = Snark_params.Tick.Field.of_string call_data_str in
    let call_depth = body_data.call_depth in
    let%bind protocol_state_data =
      query_db pool
        ~f:(fun db ->
          Processor.Snapp_predicate_protocol_states.load db
            body_data.snapp_predicate_protocol_state_id)
        ~item:"Snapp predicate protocol state"
    in
    let%bind snarked_ledger_hash =
      match protocol_state_data.snarked_ledger_hash_id with
      | None ->
          return Snapp_predicate.Hash.Ignore
      | Some id ->
          let%map hash_str =
            query_db pool ~item:"snarked ledger hash" ~f:(fun db ->
                Processor.Snarked_ledger_hash.load db id)
          in
          Snapp_predicate.Hash.Check
            (Frozen_ledger_hash.of_base58_check_exn hash_str)
    in
    let%bind snarked_next_available_token =
      match protocol_state_data.snarked_next_available_token_id with
      | None ->
          return Snapp_basic.Or_ignore.Ignore
      | Some id ->
          let%map bounds =
            query_db pool ~item:"Snapp token id bounds" ~f:(fun db ->
                Processor.Snapp_token_id_bounds.load db id)
          in
          let to_token_id i64 =
            i64 |> Unsigned.UInt64.of_int64 |> Token_id.of_uint64
          in
          let lower = to_token_id bounds.token_id_lower_bound in
          let upper = to_token_id bounds.token_id_upper_bound in
          Snapp_basic.Or_ignore.Check
            ({ lower; upper } : _ Snapp_predicate.Closed_interval.t)
    in
    let%bind timestamp =
      match protocol_state_data.timestamp_id with
      | None ->
          return Snapp_basic.Or_ignore.Ignore
      | Some id ->
          let%map bounds =
            query_db pool ~item:"Snapp timestamp bounds" ~f:(fun db ->
                Processor.Snapp_timestamp_bounds.load db id)
          in
          let to_timestamp i64 = i64 |> Block_time.of_int64 in
          let lower = to_timestamp bounds.timestamp_lower_bound in
          let upper = to_timestamp bounds.timestamp_upper_bound in
          Snapp_basic.Or_ignore.Check
            ({ lower; upper } : _ Snapp_predicate.Closed_interval.t)
    in
    let length_bounds_of_id = function
      | None ->
          return Snapp_basic.Or_ignore.Ignore
      | Some id ->
          let%map bounds =
            query_db pool ~item:"Snapp length bounds" ~f:(fun db ->
                Processor.Snapp_length_bounds.load db id)
          in
          let to_length i64 =
            i64 |> Unsigned.UInt32.of_int64 |> Mina_numbers.Length.of_uint32
          in
          let lower = to_length bounds.length_lower_bound in
          let upper = to_length bounds.length_upper_bound in
          Snapp_basic.Or_ignore.Check
            ({ lower; upper } : _ Snapp_predicate.Closed_interval.t)
    in
    let%bind blockchain_length =
      length_bounds_of_id protocol_state_data.blockchain_length_id
    in
    let%bind min_window_density =
      length_bounds_of_id protocol_state_data.min_window_density_id
    in
    let total_currency_of_id = function
      | None ->
          return Snapp_basic.Or_ignore.Ignore
      | Some id ->
          let%map bounds =
            query_db pool ~item:"Snapp currency bounds" ~f:(fun db ->
                Processor.Snapp_amount_bounds.load db id)
          in
          let to_amount i64 =
            i64 |> Unsigned.UInt64.of_int64 |> Currency.Amount.of_uint64
          in
          let lower = to_amount bounds.amount_lower_bound in
          let upper = to_amount bounds.amount_upper_bound in
          Snapp_basic.Or_ignore.Check
            ({ lower; upper } : _ Snapp_predicate.Closed_interval.t)
    in
    (* TODO: this will change *)
    let last_vrf_output = () in
    let%bind total_currency =
      total_currency_of_id protocol_state_data.total_currency_id
    in
    let global_slot_of_id = function
      | None ->
          return Snapp_basic.Or_ignore.Ignore
      | Some id ->
          let%map bounds =
            query_db pool ~item:"Snapp global slot bounds" ~f:(fun db ->
                Processor.Snapp_global_slot_bounds.load db id)
          in
          let to_slot i64 =
            i64 |> Unsigned.UInt32.of_int64
            |> Mina_numbers.Global_slot.of_uint32
          in
          let lower = to_slot bounds.global_slot_lower_bound in
          let upper = to_slot bounds.global_slot_upper_bound in
          Snapp_basic.Or_ignore.Check
            ({ lower; upper } : _ Snapp_predicate.Closed_interval.t)
    in
    let%bind global_slot_since_hard_fork =
      global_slot_of_id protocol_state_data.curr_global_slot_since_hard_fork
    in
    let%bind global_slot_since_genesis =
      global_slot_of_id protocol_state_data.global_slot_since_genesis
    in
    let epoch_data_of_id id =
      let%bind epoch_data_raw =
        query_db pool ~item:"Snapp epoch data" ~f:(fun db ->
            Processor.Snapp_epoch_data.load db id)
      in
      let%bind ledger =
        let%bind epoch_ledger_data =
          query_db pool ~item:"Snapp epoch ledger" ~f:(fun db ->
              Processor.Snapp_epoch_ledger.load db id)
        in
        let%bind hash =
          Option.value_map epoch_ledger_data.hash_id
            ~default:(return Snapp_basic.Or_ignore.Ignore) ~f:(fun id ->
              let%map hash_str =
                query_db pool ~item:"Snapp epoch ledger hash" ~f:(fun db ->
                    Processor.Snarked_ledger_hash.load db id)
              in
              Snapp_basic.Or_ignore.Check
                (Frozen_ledger_hash.of_base58_check_exn hash_str))
        in
        let%map total_currency =
          total_currency_of_id epoch_ledger_data.total_currency_id
        in
        { Epoch_ledger.Poly.hash; total_currency }
      in
      let seed =
        Option.value_map epoch_data_raw.epoch_seed
          ~default:Snapp_basic.Or_ignore.Ignore ~f:(fun s ->
            Snapp_basic.Or_ignore.Check (Epoch_seed.of_base58_check_exn s))
      in
      let checkpoint_of_str str =
        Option.value_map str ~default:Snapp_basic.Or_ignore.Ignore ~f:(fun s ->
            Snapp_basic.Or_ignore.Check (State_hash.of_base58_check_exn s))
      in
      let start_checkpoint =
        checkpoint_of_str epoch_data_raw.start_checkpoint
      in
      let lock_checkpoint = checkpoint_of_str epoch_data_raw.lock_checkpoint in
      let%map epoch_length =
        length_bounds_of_id epoch_data_raw.epoch_length_id
      in
      { Snapp_predicate.Protocol_state.Epoch_data.Poly.ledger
      ; seed
      ; start_checkpoint
      ; lock_checkpoint
      ; epoch_length
      }
    in
    let%bind staking_epoch_data =
      epoch_data_of_id protocol_state_data.staking_epoch_data_id
    in
    let%bind next_epoch_data =
      epoch_data_of_id protocol_state_data.next_epoch_data_id
    in
    let protocol_state : Snapp_predicate.Protocol_state.t =
      { snarked_ledger_hash
      ; snarked_next_available_token
      ; timestamp
      ; blockchain_length
      ; min_window_density
      ; last_vrf_output
      ; total_currency
      ; global_slot_since_hard_fork
      ; global_slot_since_genesis
      ; staking_epoch_data
      ; next_epoch_data
      }
    in
    let use_full_commitment = body_data.use_full_commitment in
    return
      ( { public_key
        ; update
        ; token_id
        ; balance_change
        ; increment_nonce
        ; events
        ; sequence_events
        ; call_data
        ; call_depth
        ; protocol_state
        ; use_full_commitment
        }
        : Party.Body.t )

  (* fee payer body is like a party body, except the balance change is a fee, not signed,
     and some fields are placeholders with the unit value
  *)
  let fee_payer_body_of_id ~pool body_id =
    let%map body = party_body_of_id ~pool body_id in
    let balance_change =
      match body.balance_change with
      | { magnitude; sgn = Sgn.Pos } ->
          Currency.Amount.to_uint64 magnitude |> Currency.Fee.of_uint64
      | _ ->
          failwith
            "fee_payer_body_of_id: expected positive balance change for fee \
             payer"
    in
    ( { public_key = body.public_key
      ; update = body.update
      ; token_id = ()
      ; balance_change
      ; increment_nonce = ()
      ; events = body.events
      ; sequence_events = body.sequence_events
      ; call_data = body.call_data
      ; call_depth = body.call_depth
      ; protocol_state = body.protocol_state
      ; use_full_commitment = ()
      }
      : Party.Body.Fee_payer.t )
end

let parties_of_snapp_command ~pool (cmd : Sql.Snapp_command.t) :
    Parties.t Deferred.t =
  let%bind fee_payer_data =
    query_db pool
      ~f:(fun db -> Processor.Snapp_fee_payers.load db cmd.fee_payer_id)
      ~item:"Snapp fee payer"
  in
  let%bind (fee_payer : Party.Fee_payer.t) =
    let%bind (data : Party.Predicated.Fee_payer.t) =
      let%bind (body : Party.Body.Fee_payer.t) =
        Snapp_helpers.fee_payer_body_of_id ~pool fee_payer_data.body_id
      in
      let predicate =
        fee_payer_data.nonce |> Unsigned.UInt32.of_int64
        |> Mina_numbers.Account_nonce.of_uint32
      in
      return { Party.Predicated.Poly.body; predicate }
    in
    return { Party.Fee_payer.data; authorization = Signature.dummy }
  in
  let%bind (other_parties : Party.t list) =
    Deferred.List.map (Array.to_list cmd.other_party_ids) ~f:(fun id ->
        let%bind snapp_party_data =
          query_db pool
            ~f:(fun db -> Processor.Snapp_party.load db id)
            ~item:"Snapp party"
        in
        let%bind (data : Party.Predicated.t) =
          let%bind (body : Party.Body.t) =
            Snapp_helpers.party_body_of_id ~pool snapp_party_data.body_id
          in
          let%bind (predicate : Party.Predicate.t) =
            let%bind predicate_data =
              query_db pool ~item:"Snapp predicate" ~f:(fun db ->
                  Processor.Snapp_predicate.load db
                    snapp_party_data.predicate_id)
            in
            match predicate_data.kind with
            | Full ->
                let%bind snapp_account_data =
                  match predicate_data.account_id with
                  | None ->
                      failwith "Expected account id for predicate of kind Full"
                  | Some account_id ->
                      query_db pool ~item:"Snapp account" ~f:(fun db ->
                          Processor.Snapp_account.load db account_id)
                in
                let%map snapp_account =
                  let%bind balance =
                    match snapp_account_data.balance_id with
                    | None ->
                        return Snapp_basic.Or_ignore.Ignore
                    | Some balance_id ->
                        let%map bounds =
                          query_db pool ~item:"Snapp balance" ~f:(fun db ->
                              Processor.Snapp_balance_bounds.load db balance_id)
                        in
                        let to_balance i64 =
                          i64 |> Unsigned.UInt64.of_int64
                          |> Currency.Balance.of_uint64
                        in
                        let lower = to_balance bounds.balance_lower_bound in
                        let upper = to_balance bounds.balance_upper_bound in
                        Snapp_basic.Or_ignore.Check
                          ( { lower; upper }
                            : _ Snapp_predicate.Closed_interval.t )
                  in
                  let%bind nonce =
                    match snapp_account_data.nonce_id with
                    | None ->
                        return Snapp_basic.Or_ignore.Ignore
                    | Some balance_id ->
                        let%map bounds =
                          query_db pool ~item:"Snapp nonce" ~f:(fun db ->
                              Processor.Snapp_nonce_bounds.load db balance_id)
                        in
                        let to_nonce i64 =
                          i64 |> Unsigned.UInt32.of_int64
                          |> Mina_numbers.Account_nonce.of_uint32
                        in
                        let lower = to_nonce bounds.nonce_lower_bound in
                        let upper = to_nonce bounds.nonce_upper_bound in
                        Snapp_basic.Or_ignore.Check
                          ( { lower; upper }
                            : _ Snapp_predicate.Closed_interval.t )
                  in
                  let receipt_chain_hash =
                    Option.value_map snapp_account_data.receipt_chain_hash
                      ~default:Snapp_basic.Or_ignore.Ignore ~f:(fun s ->
                        Snapp_basic.Or_ignore.Check
                          (Receipt.Chain_hash.of_base58_check_exn s))
                  in
                  let pk_check_or_ignore_of_id id =
                    Option.value_map id
                      ~default:(return Snapp_basic.Or_ignore.Ignore)
                      ~f:(fun pk_id ->
                        let%map pk = pk_of_pk_id pool pk_id in
                        Snapp_basic.Or_ignore.Check pk)
                  in
                  let%bind public_key =
                    pk_check_or_ignore_of_id snapp_account_data.public_key_id
                  in
                  let%bind delegate =
                    pk_check_or_ignore_of_id snapp_account_data.delegate_id
                  in
                  let%bind state =
                    let%bind snapp_state_ids =
                      query_db pool ~item:"Snapp state id" ~f:(fun db ->
                          Processor.Snapp_states.load db
                            snapp_account_data.state_id)
                    in
                    let%map state_data =
                      Snapp_helpers.state_data_of_ids ~pool snapp_state_ids
                    in
                    Array.map state_data ~f:Snapp_basic.Or_ignore.of_option
                    |> Array.to_list
                    |> Pickles_types.Vector.Vector_8.of_list_exn
                  in
                  let%bind sequence_state =
                    Option.value_map snapp_account_data.sequence_state_id
                      ~default:(return Snapp_basic.Or_ignore.Ignore)
                      ~f:(fun state_id ->
                        let%map state_data_str =
                          query_db pool ~item:"Snapp state data" ~f:(fun db ->
                              Processor.Snapp_state_data.load db state_id)
                        in
                        let state_data =
                          Pickles.Backend.Tick.Field.of_string state_data_str
                        in
                        Snapp_basic.Or_ignore.Check state_data)
                  in
                  let proved_state =
                    Option.value_map snapp_account_data.proved_state
                      ~default:Snapp_basic.Or_ignore.Ignore ~f:(fun b ->
                        Snapp_basic.Or_ignore.Check b)
                  in
                  return
                    ( { balance
                      ; nonce
                      ; receipt_chain_hash
                      ; public_key
                      ; delegate
                      ; state
                      ; sequence_state
                      ; proved_state
                      }
                      : Snapp_predicate.Account.t )
                in
                Party.Predicate.Full snapp_account
            | Nonce -> (
                match predicate_data.nonce with
                | None ->
                    failwith "Expected nonce for predicate of kind Nonce"
                | Some nonce ->
                    return
                      (Party.Predicate.Nonce
                         (Mina_numbers.Account_nonce.of_uint32
                            (Unsigned.UInt32.of_int64 nonce))) )
            | Accept ->
                return Party.Predicate.Accept
          in
          return ({ body; predicate } : Party.Predicated.t)
        in
        let authorization =
          (* dummy proof, signature, don't affect replay *)
          match snapp_party_data.authorization_kind with
          | Control.Tag.Proof ->
              let n2 = Pickles_types.Nat.N2.n in
              let proof = Pickles.Proof.dummy n2 n2 n2 in
              Control.Proof proof
          | Control.Tag.Signature ->
              Control.Signature Signature.dummy
          | Control.Tag.None_given ->
              Control.None_given
        in
        return ({ data; authorization } : Party.t))
  in
  (* memo contents don't affect ability to replay snapp *)
  let memo = Mina_base.Signed_command_memo.dummy in
  return ({ fee_payer; other_parties; memo } : Parties.t)

let run_snapp_command ~logger ~pool ~ledger ~continue_on_error:_
    (cmd : Sql.Snapp_command.t) =
  [%log info]
    "Applying Snapp command at global slot since genesis %Ld, and sequence \
     number %d"
    cmd.global_slot_since_genesis cmd.sequence_no ;
  let%bind state_view =
    Snapp_helpers.get_parent_state_view ~pool cmd.block_id
  in
  let%bind parties = parties_of_snapp_command ~pool cmd in
  match
    Ledger.apply_parties_unchecked ~constraint_constants ~state_view ledger
      parties
  with
  | Ok _ ->
      Deferred.unit
  | Error err ->
      Error.tag_arg err "Snapp command failed on replay"
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
        go ~slot:(slot - 1) ~tries_left:(tries_left - 1)
    | Some state_hash ->
        [%log info]
          "Found possible canonical chain to target state hash %s at slot %d"
          state_hash slot ;
        return state_hash
  in
  go ~slot ~tries_left:num_tries

let unquoted_string_of_yojson json =
  (* Yojson.Safe.to_string produces double-quoted strings
     remove those quotes for SQL queries
  *)
  let s = Yojson.Safe.to_string json in
  String.sub s ~pos:1 ~len:(String.length s - 2)

let main ~input_file ~output_file_opt ~archive_uri ~set_nonces ~repair_nonces
    ~continue_on_error () =
  let logger = Logger.create () in
  let json = Yojson.Safe.from_file input_file in
  let input =
    match input_of_yojson json with
    | Ok inp ->
        inp
    | Error msg ->
        failwith
          (sprintf "Could not parse JSON in input file \"%s\": %s" input_file
             msg)
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
                  epoch_ledgers_state_hash)
              ~item:"parent state hash of state hash"
        | None ->
            [%log info]
              "Searching for block with greatest height on canonical chain" ;
            let%bind max_slot =
              query_db pool
                ~f:(fun db -> Sql.Block.get_max_slot db ())
                ~item:"max slot"
            in
            [%log info] "Maximum global slot since genesis in blocks is %d"
              max_slot ;
            try_slot ~logger pool max_slot
      in
      [%log info] "Loading block information using target state hash" ;
      let%bind block_ids =
        process_block_infos_of_state_hash ~logger pool target_state_hash
          ~f:(fun block_infos ->
            let ids = List.map block_infos ~f:(fun { id; _ } -> id) in
            (* build mapping from global slots to state and ledger hashes *)
            List.iter block_infos
              ~f:(fun { global_slot_since_genesis; state_hash; ledger_hash; _ }
                 ->
                Hashtbl.add_exn global_slot_hashes_tbl
                  ~key:global_slot_since_genesis
                  ~data:
                    ( State_hash.of_base58_check_exn state_hash
                    , Ledger_hash.of_base58_check_exn ledger_hash )) ;
            return (Int.Set.of_list ids))
      in
      (* check that genesis block is in chain to target hash
         assumption: genesis block occupies global slot 0
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
        Core_kernel.exit 1 ) ;
      let get_command_ids (module Command_ids : Get_command_ids) name =
        match%bind
          Caqti_async.Pool.use
            (fun db -> Command_ids.run db target_state_hash)
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
      [%log info] "Loading Snapp command ids" ;
      let%bind snapp_cmd_ids =
        get_command_ids (module Sql.Snapp_command_ids) "Snapp"
      in
      [%log info]
        "Obtained %d user command ids, %d internal command ids, and %d Snapp \
         command ids"
        (List.length user_cmd_ids)
        (List.length internal_cmd_ids)
        (List.length snapp_cmd_ids) ;
      [%log info] "Loading internal commands" ;
      let%bind unsorted_internal_cmds_list =
        Deferred.List.map internal_cmd_ids ~f:(fun id ->
            let open Deferred.Let_syntax in
            match%map
              Caqti_async.Pool.use
                (fun db -> Sql.Internal_command.run db id)
                pool
            with
            | Ok [] ->
                failwithf "Could not find any internal commands with id: %d" id
                  ()
            | Ok internal_cmds ->
                internal_cmds
            | Error msg ->
                failwithf
                  "Error querying for internal commands with id %d, error %s" id
                  (Caqti_error.show msg) ())
      in
      let unsorted_internal_cmds = List.concat unsorted_internal_cmds_list in
      (* filter out internal commands in blocks not along chain from target state hash
         or before start slot
      *)
      let filtered_internal_cmds =
        List.filter unsorted_internal_cmds ~f:(fun cmd ->
            Int64.( >= ) cmd.global_slot_since_genesis
              input.start_slot_since_genesis
            && Int.Set.mem block_ids cmd.block_id)
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
              | _ ->
                  failwith
                    "Two internal commands have the same global slot since \
                     genesis %Ld, sequence no %d, and secondary sequence no \
                     %d, but are not a coinbase and fee transfer via coinbase"
            else cmp)
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
                  (Caqti_error.show msg) ())
      in
      let unsorted_user_cmds = List.concat unsorted_user_cmds_list in
      (* filter out user commands in blocks not along chain from target state hash
         or before start slot
      *)
      let filtered_user_cmds =
        List.filter unsorted_user_cmds ~f:(fun cmd ->
            Int64.( >= ) cmd.global_slot_since_genesis
              input.start_slot_since_genesis
            && Int.Set.mem block_ids cmd.block_id)
      in
      [%log info] "Will replay %d user commands"
        (List.length filtered_user_cmds) ;
      let sorted_user_cmds =
        List.sort filtered_user_cmds ~compare:(fun uc1 uc2 ->
            let tuple (uc : Sql.User_command.t) =
              (uc.global_slot_since_genesis, uc.sequence_no)
            in
            [%compare: int64 * int] (tuple uc1) (tuple uc2))
      in
      [%log info] "Loading Snapp commands" ;
      let%bind unsorted_snapp_cmds_list =
        Deferred.List.map snapp_cmd_ids ~f:(fun id ->
            let open Deferred.Let_syntax in
            match%map
              Caqti_async.Pool.use (fun db -> Sql.Snapp_command.run db id) pool
            with
            | Ok [] ->
                failwithf "Expected at least one Snapp command with id %d" id ()
            | Ok snapp_cmds ->
                snapp_cmds
            | Error msg ->
                failwithf
                  "Error querying for Snapp commands with id %d, error %s" id
                  (Caqti_error.show msg) ())
      in
      let unsorted_snapp_cmds = List.concat unsorted_snapp_cmds_list in
      let filtered_snapp_cmds =
        List.filter unsorted_snapp_cmds ~f:(fun (cmd : Sql.Snapp_command.t) ->
            Int64.( >= ) cmd.global_slot_since_genesis
              input.start_slot_since_genesis
            && Int.Set.mem block_ids cmd.block_id)
      in
      let sorted_snapp_cmds =
        List.sort filtered_snapp_cmds ~compare:(fun sc1 sc2 ->
            let tuple (sc : Sql.Snapp_command.t) =
              (sc.global_slot_since_genesis, sc.sequence_no)
            in
            [%compare: int64 * int] (tuple sc1) (tuple sc2))
      in
      (* apply commands in global slot, sequence order *)
      let rec apply_commands (internal_cmds : Sql.Internal_command.t list)
          (user_cmds : Sql.User_command.t list)
          (snapp_cmds : Sql.Snapp_command.t list)
          ~last_global_slot_since_genesis ~last_block_id ~staking_epoch_ledger
          ~next_epoch_ledger =
        let%bind staking_epoch_ledger, staking_seed =
          update_staking_epoch_data ~logger pool ~last_block_id ~ledger
            ~staking_epoch_ledger
        in
        let%bind next_epoch_ledger, next_seed =
          update_next_epoch_data ~logger pool ~last_block_id ~ledger
            ~next_epoch_ledger
        in
        let log_ledger_hash_after_last_slot () =
          let _state_hash, expected_ledger_hash =
            get_slot_hashes ~logger last_global_slot_since_genesis
          in
          if Ledger_hash.equal (Ledger.merkle_root ledger) expected_ledger_hash
          then
            [%log info]
              "Applied all commands at global slot since genesis %Ld, got \
               expected ledger hash"
              ~metadata:[ ("ledger_hash", json_ledger_hash_of_ledger ledger) ]
              last_global_slot_since_genesis
          else (
            [%log error]
              "Applied all commands at global slot since genesis %Ld, ledger \
               hash differs from expected ledger hash"
              ~metadata:
                [ ("ledger_hash", json_ledger_hash_of_ledger ledger)
                ; ( "expected_ledger_hash"
                  , Ledger_hash.to_yojson expected_ledger_hash )
                ]
              last_global_slot_since_genesis ;
            if continue_on_error then incr error_count else Core_kernel.exit 1 )
        in
        let log_state_hash_on_next_slot curr_global_slot_since_genesis =
          let state_hash, _ledger_hash =
            get_slot_hashes ~logger curr_global_slot_since_genesis
          in
          [%log info]
            ~metadata:
              [ ("state_hash", `String (State_hash.to_base58_check state_hash))
              ]
            "Starting processing of commands in block with state_hash \
             $state_hash at global slot since genesis %Ld"
            curr_global_slot_since_genesis
        in
        let log_on_slot_change curr_global_slot_since_genesis =
          if
            Int64.( > ) curr_global_slot_since_genesis
              last_global_slot_since_genesis
          then (
            log_ledger_hash_after_last_slot () ;
            log_state_hash_on_next_slot curr_global_slot_since_genesis )
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
              log_on_slot_change ic.global_slot_since_genesis ;
              let%bind () =
                apply_combined_fee_transfer ~logger ~pool ~ledger ~set_nonces
                  ~repair_nonces ~continue_on_error ic ic2
              in
              apply_commands ics2 user_cmds snapp_cmds
                ~last_global_slot_since_genesis:ic.global_slot_since_genesis
                ~last_block_id:ic.block_id ~staking_epoch_ledger
                ~next_epoch_ledger
          | _ ->
              log_on_slot_change ic.global_slot_since_genesis ;
              let%bind () =
                run_internal_command ~logger ~pool ~ledger ~set_nonces
                  ~repair_nonces ~continue_on_error ic
              in
              apply_commands ics user_cmds snapp_cmds
                ~last_global_slot_since_genesis:ic.global_slot_since_genesis
                ~last_block_id:ic.block_id ~staking_epoch_ledger
                ~next_epoch_ledger
        in
        (* a sequence is a command type, slot, sequence number triple *)
        let get_internal_cmd_sequence (ic : Sql.Internal_command.t) =
          (`Internal_command, ic.global_slot_since_genesis, ic.sequence_no)
        in
        let get_user_cmd_sequence (uc : Sql.User_command.t) =
          (`User_command, uc.global_slot_since_genesis, uc.sequence_no)
        in
        let get_snapp_cmd_sequence (sc : Sql.Snapp_command.t) =
          (`Snapp_command, sc.global_slot_since_genesis, sc.sequence_no)
        in
        let command_type_of_sequences seqs =
          let compare (_cmd_ty1, slot1, seq_no1) (_cmd_ty2, slot2, seq_no2) =
            [%compare: int64 * int] (slot1, seq_no1) (slot2, seq_no2)
          in
          let sorted_seqs = List.sort seqs ~compare in
          let cmd_ty, _slot, _seq_no = List.hd_exn sorted_seqs in
          cmd_ty
        in
        let run_user_commands (uc : Sql.User_command.t) ucs =
          log_on_slot_change uc.global_slot_since_genesis ;
          let%bind () =
            run_user_command ~logger ~pool ~ledger ~continue_on_error
              ~repair_nonces ~set_nonces uc
          in
          apply_commands internal_cmds ucs snapp_cmds
            ~last_global_slot_since_genesis:uc.global_slot_since_genesis
            ~last_block_id:uc.block_id ~staking_epoch_ledger ~next_epoch_ledger
        in
        let run_snapp_commands (sc : Sql.Snapp_command.t) scs =
          log_on_slot_change sc.global_slot_since_genesis ;
          let%bind () =
            run_snapp_command ~logger ~pool ~ledger ~continue_on_error sc
          in
          apply_commands internal_cmds user_cmds scs
            ~last_global_slot_since_genesis:sc.global_slot_since_genesis
            ~last_block_id:sc.block_id ~staking_epoch_ledger ~next_epoch_ledger
        in
        match (internal_cmds, user_cmds, snapp_cmds) with
        | [], [], [] ->
            (* all done *)
            log_ledger_hash_after_last_slot () ;
            Deferred.return
              ( last_global_slot_since_genesis
              , staking_epoch_ledger
              , staking_seed
              , next_epoch_ledger
              , next_seed )
        | ic :: ics, [], [] ->
            (* only internal commands *)
            combine_or_run_internal_cmds ic ics
        | [], uc :: ucs, [] ->
            (* only user commands *)
            run_user_commands uc ucs
        | [], [], sc :: scs ->
            (* only Snapp commands *)
            run_snapp_commands sc scs
        | [], uc :: ucs, sc :: scs -> (
            (* no internal commands *)
            let seqs =
              [ get_user_cmd_sequence uc; get_snapp_cmd_sequence sc ]
            in
            match command_type_of_sequences seqs with
            | `User_command ->
                run_user_commands uc ucs
            | `Snapp_command ->
                run_snapp_commands sc scs )
        | ic :: ics, [], sc :: scs -> (
            (* no user commands *)
            let seqs =
              [ get_internal_cmd_sequence ic; get_snapp_cmd_sequence sc ]
            in
            match command_type_of_sequences seqs with
            | `Internal_command ->
                combine_or_run_internal_cmds ic ics
            | `Snapp_command ->
                run_snapp_commands sc scs )
        | ic :: ics, uc :: ucs, [] -> (
            (* no Snapp commands *)
            let seqs =
              [ get_internal_cmd_sequence ic; get_user_cmd_sequence uc ]
            in
            match command_type_of_sequences seqs with
            | `Internal_command ->
                combine_or_run_internal_cmds ic ics
            | `User_command ->
                run_user_commands uc ucs )
        | ic :: ics, uc :: ucs, sc :: scs -> (
            (* internal, user, and Snapp commands *)
            let seqs =
              [ get_internal_cmd_sequence ic
              ; get_user_cmd_sequence uc
              ; get_snapp_cmd_sequence sc
              ]
            in
            match command_type_of_sequences seqs with
            | `Internal_command ->
                combine_or_run_internal_cmds ic ics
            | `User_command ->
                log_on_slot_change uc.global_slot_since_genesis ;
                let%bind () =
                  run_user_command ~logger ~pool ~ledger ~continue_on_error
                    ~set_nonces ~repair_nonces uc
                in
                apply_commands internal_cmds ucs scs
                  ~last_global_slot_since_genesis:uc.global_slot_since_genesis
                  ~last_block_id:uc.block_id ~staking_epoch_ledger
                  ~next_epoch_ledger
            | `Snapp_command ->
                run_snapp_commands sc scs )
      in
      let%bind unparented_ids =
        query_db pool
          ~f:(fun db -> Sql.Block.get_unparented db ())
          ~item:"unparented ids"
      in
      let genesis_block_id =
        match List.filter unparented_ids ~f:(Int.Set.mem block_ids) with
        | [ id ] ->
            id
        | _ ->
            failwith "Expected only the genesis block to have an unparented id"
      in
      let%bind start_slot_since_genesis =
        let%map slot_opt =
          query_db pool
            ~f:(fun db ->
              Sql.Block.get_next_slot db input.start_slot_since_genesis)
            ~item:"Next slot"
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
      let%bind ( last_global_slot_since_genesis
               , staking_epoch_ledger
               , staking_seed
               , next_epoch_ledger
               , next_seed ) =
        apply_commands sorted_internal_cmds sorted_user_cmds sorted_snapp_cmds
          ~last_global_slot_since_genesis:start_slot_since_genesis
          ~last_block_id:genesis_block_id ~staking_epoch_ledger:ledger
          ~next_epoch_ledger:ledger
      in
      match input.target_epoch_ledgers_state_hash with
      | None ->
          (* start replaying at the slot after the one we've just finished with *)
          let start_slot_since_genesis =
            Int64.succ last_global_slot_since_genesis
          in
          let replayer_checkpoint =
            create_replayer_checkpoint ~ledger ~start_slot_since_genesis
            |> input_to_yojson |> Yojson.Safe.pretty_to_string
          in
          let checkpoint_file =
            sprintf "replayer-checkpoint-%Ld.json" start_slot_since_genesis
          in
          [%log info] "Writing checkpoint file"
            ~metadata:[ ("checkpoint_file", `String checkpoint_file) ] ;
          return
          @@ Out_channel.with_file checkpoint_file ~f:(fun oc ->
                 Out_channel.output_string oc replayer_checkpoint)
      | Some target_epoch_ledgers_state_hash -> (
          match output_file_opt with
          | None ->
              [%log info] "Output file not supplied, not writing output" ;
              return ()
          | Some output_file ->
              if Int.equal !error_count 0 then (
                [%log info] "Writing output to $output_file"
                  ~metadata:[ ("output_file", `String output_file) ] ;
                let output =
                  create_output ~target_epoch_ledgers_state_hash
                    ~target_fork_state_hash:
                      (State_hash.of_base58_check_exn target_state_hash)
                    ~ledger ~staking_epoch_ledger ~staking_seed
                    ~next_epoch_ledger ~next_seed input.genesis_ledger
                  |> output_to_yojson |> Yojson.Safe.pretty_to_string
                in
                return
                @@ Out_channel.with_file output_file ~f:(fun oc ->
                       Out_channel.output_string oc output) )
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
         and continue_on_error =
           Param.flag "--continue-on-error"
             ~doc:"Continue processing after errors" Param.no_arg
         in
         main ~input_file ~output_file_opt ~archive_uri ~set_nonces
           ~repair_nonces ~continue_on_error)))
