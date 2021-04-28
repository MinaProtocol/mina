(* delegation_compliance.ml *)

(* check whether a block producer delegated to from Mina Foundation or
   O(1) Labs follows requirements at
   https://docs.minaprotocol.com/en/advanced/foundation-delegation-program
*)

open Core
open Async
open Mina_base
open Signature_lib

type input =
  {target_state_hash: State_hash.t; genesis_ledger: Runtime_config.Ledger.t}
[@@deriving yojson]

type delegation_source = O1 | Mina_foundation [@@deriving yojson]

type payout_information =
  { payout_pk: Public_key.Compressed.t
  ; payout_id: int
  ; delegation_source: delegation_source
  ; delegatee: Public_key.Compressed.t
  ; delegatee_id: int
  ; payments: Sql.User_command.t list
  ; mutable unmet_obligation: float
  ; mutable to_3500_allocation_opt: float option }
[@@deriving yojson]

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let proof_level = Genesis_constants.Proof_level.Full

let json_ledger_hash_of_ledger ledger =
  Ledger_hash.to_yojson @@ Ledger.merkle_root ledger

(* map from global slots to state hash, ledger hash pairs *)
let global_slot_hashes_tbl : (Int64.t, State_hash.t * Ledger_hash.t) Hashtbl.t
    =
  Int64.Table.create ()

(* cache of account keys *)
let pk_tbl : (int, Account.key) Hashtbl.t = Int.Table.create ()

let query_db pool ~f ~item =
  match%bind Caqti_async.Pool.use f pool with
  | Ok v ->
      return v
  | Error msg ->
      failwithf "Error getting %s from db, error: %s" item
        (Caqti_error.show msg) ()

let slots_per_epoch =
  Genesis_constants.slots_per_epoch |> Unsigned.UInt32.of_int

(* offset is slot within epoch, starting from 0 *)
let epoch_and_offset_of_global_slot global_slot =
  let open Unsigned.UInt32 in
  let global_slot_uint32 = global_slot |> Int64.to_string |> of_string in
  let epoch = div global_slot_uint32 slots_per_epoch in
  let epoch_start_slot = mul epoch slots_per_epoch in
  let offset = Unsigned.UInt32.sub global_slot_uint32 epoch_start_slot in
  (epoch, offset)

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

let pk_id_of_pk pool pk : int Deferred.t =
  let open Deferred.Let_syntax in
  match%map
    Caqti_async.Pool.use (fun db -> Sql.Public_key.run_for_id db pk) pool
  with
  | Ok (Some id) ->
      id
  | Ok None ->
      failwithf "Could not find id for public key %s" pk ()
  | Error msg ->
      failwithf "Error retrieving id for public key %s, error: %s" pk
        (Caqti_error.show msg) ()

let balance_of_id_and_pk_id pool ~id ~pk_id : Currency.Balance.t Deferred.t =
  let open Deferred.Let_syntax in
  match%map
    Caqti_async.Pool.use (fun db -> Sql.Balance.run db ~id ~pk_id) pool
  with
  | Ok (Some balance) ->
      balance |> Unsigned.UInt64.of_int64 |> Currency.Balance.of_uint64
  | Ok None ->
      failwithf "Could not find balance with id %d and public key %d" id pk_id
        ()
  | Error msg ->
      failwithf
        "Error retrieving balance with id %d and public key %d, error: %s" id
        pk_id (Caqti_error.show msg) ()

let state_hash_of_epoch_ledgers_state_hash ~logger pool
    epoch_ledgers_state_hash =
  match%map
    Caqti_async.Pool.use
      (fun db -> Sql.Fork_block.get_state_hash db epoch_ledgers_state_hash)
      pool
  with
  | Ok state_hash ->
      [%log info]
        "Given epoch ledgers state hash %s, found state hash %s for fork block"
        epoch_ledgers_state_hash state_hash ;
      state_hash
  | Error msg ->
      failwithf
        "Error retrieving state hash for fork block, given epoch ledgers \
         state hash %s, error: %s"
        epoch_ledgers_state_hash (Caqti_error.show msg) ()

let epoch_staking_id_of_state_hash ~logger pool state_hash =
  match%map
    Caqti_async.Pool.use
      (fun db -> Sql.Epoch_data.get_staking_epoch_data_id db state_hash)
      pool
  with
  | Ok staking_epoch_data_id ->
      [%log info] "Found staking epoch data id for state hash %s" state_hash ;
      staking_epoch_data_id
  | Error msg ->
      failwithf
        "Error retrieving staking epoch data id for state hash %s, error: %s"
        state_hash (Caqti_error.show msg) ()

let epoch_next_id_of_state_hash ~logger pool state_hash =
  match%map
    Caqti_async.Pool.use
      (fun db -> Sql.Epoch_data.get_next_epoch_data_id db state_hash)
      pool
  with
  | Ok next_epoch_data_id ->
      [%log info] "Found next epoch data id for state hash %s" state_hash ;
      next_epoch_data_id
  | Error msg ->
      failwithf
        "Error retrieving next epoch data id for state hash %s, error: %s"
        state_hash (Caqti_error.show msg) ()

let epoch_data_of_id ~logger pool epoch_data_id =
  match%map
    Caqti_async.Pool.use
      (fun db -> Sql.Epoch_data.get_epoch_data db epoch_data_id)
      pool
  with
  | Ok {epoch_ledger_hash; epoch_data_seed} ->
      [%log info] "Found epoch data for id %d" epoch_data_id ;
      ({epoch_ledger_hash; epoch_data_seed} : Sql.Epoch_data.epoch_data)
  | Error msg ->
      failwithf "Error retrieving epoch data for epoch data id %d, error: %s"
        epoch_data_id (Caqti_error.show msg) ()

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
          ; ("state_hash", `String state_hash) ] ;
      exit 1

let update_epoch_ledger ~logger ~name ~ledger ~epoch_ledger epoch_ledger_hash =
  let epoch_ledger_hash = Ledger_hash.of_string epoch_ledger_hash in
  let curr_ledger_hash = Ledger.merkle_root ledger in
  if Frozen_ledger_hash.equal epoch_ledger_hash curr_ledger_hash then (
    [%log info]
      "Creating %s epoch ledger from ledger with Merkle root matching epoch \
       ledger hash %s"
      name
      (Ledger_hash.to_string epoch_ledger_hash) ;
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
            |> Error.raise ) ;
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
  let%map {epoch_ledger_hash; epoch_data_seed} =
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
  let%map {epoch_ledger_hash; epoch_data_seed} =
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

let fee_transfer_tbl : (Fee_transfer_key.t, Coinbase_fee_transfer.t) Hashtbl.t
    =
  Fee_transfer_key.Table.create ()

let cache_fee_transfer_via_coinbase pool
    (internal_cmd : Sql.Internal_command.t) =
  match internal_cmd.type_ with
  | "fee_transfer_via_coinbase" ->
      let%map receiver_pk = pk_of_pk_id pool internal_cmd.receiver_id in
      let fee =
        Currency.Fee.of_uint64 (Unsigned.UInt64.of_int64 internal_cmd.fee)
      in
      let fee_transfer = Coinbase_fee_transfer.create ~receiver_pk ~fee in
      Hashtbl.add_exn fee_transfer_tbl
        ~key:
          ( internal_cmd.global_slot
          , internal_cmd.sequence_no
          , internal_cmd.secondary_sequence_no )
        ~data:fee_transfer
  | _ ->
      Deferred.unit

let verify_balance ~logger ~pool ~ledger ~who ~balance_id ~pk_id ~token_int64 =
  let%bind pk = pk_of_pk_id pool pk_id in
  let%map claimed_balance =
    balance_of_id_and_pk_id pool ~id:balance_id ~pk_id
  in
  let token = token_int64 |> Unsigned.UInt64.of_int64 |> Token_id.of_uint64 in
  let account_id = Account_id.create pk token in
  let actual_balance =
    match Ledger.location_of_account ledger account_id with
    | Some loc -> (
      match Ledger.get ledger loc with
      | Some account ->
          account.balance
      | None ->
          failwithf
            "Could not find account in ledger for public key %s and token id %s"
            (Signature_lib.Public_key.Compressed.to_base58_check pk)
            (Token_id.to_string token) () )
    | None ->
        failwithf
          "Could not get location of account for public key %s and token id %s"
          (Signature_lib.Public_key.Compressed.to_base58_check pk)
          (Token_id.to_string token) ()
  in
  if not (Currency.Balance.equal actual_balance claimed_balance) then (
    [%log error] "Claimed balance does not match actual balance in ledger"
      ~metadata:
        [ ("who", `String who)
        ; ("claimed_balance", Currency.Balance.to_yojson claimed_balance)
        ; ("actual_balance", Currency.Balance.to_yojson actual_balance) ] ;
    Core_kernel.exit 1 )

let run_internal_command ~logger ~pool ~ledger (cmd : Sql.Internal_command.t) =
  [%log info]
    "Applying internal command (%s) with global slot %Ld, sequence number %d, \
     and secondary sequence number %d"
    cmd.type_ cmd.global_slot cmd.sequence_no cmd.secondary_sequence_no ;
  let%bind receiver_pk = pk_of_pk_id pool cmd.receiver_id in
  let fee = Currency.Fee.of_uint64 (Unsigned.UInt64.of_int64 cmd.fee) in
  let fee_token = Token_id.of_uint64 (Unsigned.UInt64.of_int64 cmd.token) in
  let txn_global_slot =
    cmd.txn_global_slot |> Unsigned.UInt32.of_int64
    |> Mina_numbers.Global_slot.of_uint32
  in
  let fail_on_error err =
    Error.tag_arg err "Could not apply internal command"
      (("global slot", cmd.global_slot), ("sequence number", cmd.sequence_no))
      [%sexp_of: (string * int64) * (string * int)]
    |> Error.raise
  in
  let pk_id = cmd.receiver_id in
  let balance_id = cmd.receiver_balance in
  let token_int64 = cmd.token in
  let open Mina_base.Ledger in
  match cmd.type_ with
  | "fee_transfer" -> (
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
            ~balance_id ~pk_id ~token_int64
      | Error err ->
          fail_on_error err )
  | "coinbase" -> (
      let amount = Currency.Fee.to_uint64 fee |> Currency.Amount.of_uint64 in
      (* combining situation 1: add cached coinbase fee transfer, if it exists *)
      let fee_transfer =
        Hashtbl.find fee_transfer_tbl
          (cmd.global_slot, cmd.sequence_no, cmd.secondary_sequence_no)
      in
      let coinbase =
        match Coinbase.create ~amount ~receiver:receiver_pk ~fee_transfer with
        | Ok cb ->
            cb
        | Error err ->
            Error.tag err ~tag:"Error creating coinbase for internal command"
            |> Error.raise
      in
      let undo_or_error =
        apply_coinbase ~constraint_constants ~txn_global_slot ledger coinbase
      in
      match undo_or_error with
      | Ok _undo ->
          verify_balance ~logger ~pool ~ledger ~who:"coinbase receiver"
            ~balance_id ~pk_id ~token_int64
      | Error err ->
          fail_on_error err )
  | "fee_transfer_via_coinbase" ->
      (* these are combined in the "coinbase" case *)
      Deferred.unit
  | _ ->
      failwithf "Unknown internal command \"%s\"" cmd.type_ ()

let apply_combined_fee_transfer ~logger ~pool ~ledger
    (cmd1 : Sql.Internal_command.t) (cmd2 : Sql.Internal_command.t) =
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
    cmd2.txn_global_slot |> Unsigned.UInt32.of_int64
    |> Mina_numbers.Global_slot.of_uint32
  in
  let applied_or_error =
    Ledger.apply_fee_transfer ~constraint_constants ~txn_global_slot ledger
      fee_transfer
  in
  match applied_or_error with
  | Ok _ ->
      let%bind () =
        verify_balance ~logger ~pool ~ledger ~who:"combined fee transfer (1)"
          ~balance_id:cmd1.receiver_balance ~pk_id:cmd1.receiver_id
          ~token_int64:cmd1.token
      in
      verify_balance ~logger ~pool ~ledger ~who:"combined fee transfer (2)"
        ~balance_id:cmd2.receiver_balance ~pk_id:cmd2.receiver_id
        ~token_int64:cmd2.token
  | Error err ->
      Error.tag_arg err "Error applying combined fee transfer"
        ("sequence number", cmd1.sequence_no)
        [%sexp_of: string * int]
      |> Error.raise

let body_of_sql_user_cmd pool
    ({type_; source_id; receiver_id; token= tok; amount; global_slot; _} :
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
  (* TODO: handle "snapp" user commands *)
  match type_ with
  | "payment" ->
      if Option.is_none amount then
        failwithf "Payment at global slot %Ld has NULL amount" global_slot () ;
      let amount = Option.value_exn amount in
      Payment Payment_payload.Poly.{source_pk; receiver_pk; token_id; amount}
  | "delegation" ->
      Stake_delegation
        (Stake_delegation.Set_delegate
           {delegator= source_pk; new_delegate= receiver_pk})
  | "create_token" ->
      Create_new_token
        { New_token_payload.token_owner_pk= source_pk
        ; disable_new_accounts= false }
  | "create_account" ->
      Create_token_account
        { New_account_payload.token_id
        ; token_owner_pk= source_pk
        ; receiver_pk
        ; account_disabled= false }
  | "mint_tokens" ->
      if Option.is_none amount then
        failwithf "Mint token at global slot %Ld has NULL amount" global_slot
          () ;
      let amount = Option.value_exn amount in
      Mint_tokens
        { Minting_payload.token_id
        ; token_owner_pk= source_pk
        ; receiver_pk
        ; amount }
  | _ ->
      failwithf "Invalid user command type: %s" type_ ()

let run_user_command ~logger ~pool ~ledger (cmd : Sql.User_command.t) =
  [%log info]
    "Applying user command (%s) with nonce %Ld, global slot %Ld, and sequence \
     number %d"
    cmd.type_ cmd.nonce cmd.global_slot cmd.sequence_no ;
  let%bind body = body_of_sql_user_cmd pool cmd in
  let%bind fee_payer_pk = pk_of_pk_id pool cmd.fee_payer_id in
  let memo = Signed_command_memo.of_string cmd.memo in
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
    Signed_command.Poly.{payload; signer; signature= Signature.dummy}
  in
  (* the signature isn't checked when applying, the real signature was checked in the
     transaction SNARK, so deem the signature to be valid here
  *)
  let (`If_this_is_used_it_should_have_a_comment_justifying_it
        valid_signed_cmd) =
    Signed_command.to_valid_unsafe signed_cmd
  in
  let txn_global_slot = Unsigned.UInt32.of_int64 cmd.txn_global_slot in
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
            failwithf "New token %Ld in user command with nonzero token %Ld" n
              m ()
        | _, None ->
            cmd.token
      in
      let%bind () =
        match cmd.source_balance with
        | Some balance_id ->
            verify_balance ~logger ~pool ~ledger ~who:"source" ~balance_id
              ~pk_id:cmd.source_id ~token_int64
        | None ->
            return ()
      in
      let%bind () =
        match cmd.receiver_balance with
        | Some balance_id ->
            verify_balance ~logger ~pool ~ledger ~who:"receiver" ~balance_id
              ~pk_id:cmd.receiver_id ~token_int64
        | None ->
            return ()
      in
      verify_balance ~logger ~pool ~ledger ~who:"fee payer"
        ~balance_id:cmd.fee_payer_balance ~pk_id:cmd.fee_payer_id
        ~token_int64:cmd.fee_token
  | Error err ->
      Error.tag_arg err "User command failed on replay"
        (("global slot", cmd.global_slot), ("sequence number", cmd.sequence_no))
        [%sexp_of: (string * int64) * (string * int)]
      |> Error.raise

let compute_delegated_stake staking_ledger delegatee =
  let open Currency in
  Ledger.foldi staking_ledger ~init:Amount.zero
    ~f:(fun _addr accum (account : Account.t) ->
      match account.delegate with
      | Some delegate ->
          if Public_key.Compressed.equal delegate delegatee then
            let balance_as_amount =
              Currency.Balance.to_amount account.balance
            in
            match Amount.add balance_as_amount accum with
            | Some sum ->
                sum
            | None ->
                failwith "Error summing delegated stake"
          else accum
      | None ->
          accum )

let get_account_balance_as_amount ledger pk =
  let account_id = Account_id.create pk Token_id.default in
  match Ledger.location_of_account ledger account_id with
  | Some location -> (
    match Ledger.get ledger location with
    | Some account ->
        Currency.Balance.to_amount account.balance
    | None ->
        failwith
          "get_account_balance_as_amount: Could not find account for public key"
    )
  | None ->
      failwith
        "get_account_balance_as_amount: Could not find location for account"

let slot_bounds_for_epoch epoch =
  let open Unsigned.UInt32 in
  let low_slot = mul epoch slots_per_epoch |> to_int64 in
  let high_slot = pred (mul (succ epoch) slots_per_epoch) |> to_int64 in
  (low_slot, high_slot)

let num_blocks_produced_in_epoch pool delegatee_id epoch =
  let low_slot, high_slot = slot_bounds_for_epoch epoch in
  query_db pool
    ~f:(fun db ->
      Sql.Block.get_creator_count_in_slot_bounds db ~creator:delegatee_id
        ~low_slot ~high_slot )
    ~item:"blocks count for delegatee in epoch"

let get_payment_total_in_bounds ~low_slot ~high_slot
    (payments : Sql.User_command.t list) =
  List.fold payments ~init:0L ~f:(fun accum uc ->
      if uc.global_slot >= low_slot && uc.global_slot <= high_slot then
        match uc.amount with
        | Some amount ->
            Int64.( + ) amount accum
        | None ->
            failwith "get_payment_total_in_epoch: No amount in payment"
      else accum )

let get_payment_total_in_epoch epoch payments =
  let low_slot, high_slot = slot_bounds_for_epoch epoch in
  get_payment_total_in_bounds ~low_slot ~high_slot payments

let get_payment_total_to_3500_in_epoch epoch payments =
  let low_slot, _hi = slot_bounds_for_epoch epoch in
  let high_slot = Int64.( + ) low_slot 3501L in
  get_payment_total_in_bounds ~low_slot ~high_slot payments

let get_payment_total_past_3500_in_epoch epoch payments =
  let low_slot, high_slot = slot_bounds_for_epoch epoch in
  let low_slot = Int64.( + ) low_slot 3501L in
  get_payment_total_in_bounds ~low_slot ~high_slot payments

let unquoted_string_of_yojson json =
  (* Yojson.Safe.to_string produces double-quoted strings
     remove those quotes for SQL queries
  *)
  let s = Yojson.Safe.to_string json in
  String.sub s ~pos:1 ~len:(String.length s - 2)

let main ~input_file ~archive_uri ~payout_addresses () =
  let logger = Logger.create () in
  if List.is_empty payout_addresses then (
    [%log error]
      "Please provide at least one payout address on the command line" ;
    Core.exit 1 ) ;
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
        ~metadata:[("error", `String (Caqti_error.show e))]
        "Failed to create a Caqti pool for Postgresql" ;
      exit 1
  | Ok pool ->
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
            [%log fatal] "Could not load accounts from input staking ledger" ;
            exit 1
        | Some accounts ->
            return accounts
      in
      let packed_ledger =
        Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts
          ~depth:constraint_constants.ledger_depth padded_accounts
      in
      let ledger = Lazy.force @@ Genesis_ledger.Packed.t packed_ledger in
      let target_state_hash = State_hash.to_string input.target_state_hash in
      [%log info] "Loading block information using target state hash" ;
      let%bind block_ids =
        process_block_infos_of_state_hash ~logger pool target_state_hash
          ~f:(fun block_infos ->
            let ids = List.map block_infos ~f:(fun {id; _} -> id) in
            (* build mapping from global slots to state and ledger hashes *)
            List.iter block_infos
              ~f:(fun {global_slot; state_hash; ledger_hash; _} ->
                Hashtbl.add_exn global_slot_hashes_tbl ~key:global_slot
                  ~data:
                    ( State_hash.of_string state_hash
                    , Ledger_hash.of_string ledger_hash ) ) ;
            return (Int.Set.of_list ids) )
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
      [%log info] "Building delegatee table " ;
      (* table of account public keys to delegatee public keys *)
      let delegatee_tbl = Public_key.Compressed.Table.create () in
      Ledger.iteri ledger ~f:(fun _ndx acct ->
          ignore
            (Option.map acct.delegate ~f:(fun delegate ->
                 match
                   Public_key.Compressed.Table.add delegatee_tbl
                     ~key:acct.public_key ~data:delegate
                 with
                 | `Ok ->
                     ()
                 | `Duplicate ->
                     failwith "Duplicate account in initial staking ledger" ))
      ) ;
      [%log info] "Computing delegation information for payout addresses" ;
      let%bind payout_infos =
        (* sets for quick lookups *)
        let foundation_addresses =
          String.Set.of_list Payout_addresses.foundation_addresses
        in
        let o1_addresses = String.Set.of_list Payout_addresses.o1_addresses in
        Deferred.List.map payout_addresses ~f:(fun addr ->
            let%bind payout_id = pk_id_of_pk pool addr in
            let delegation_source =
              if String.Set.mem foundation_addresses addr then Mina_foundation
              else if String.Set.mem o1_addresses addr then O1
              else
                failwithf
                  "Payout address %s is neither a Foundation nor O1 delegator"
                  addr ()
            in
            let payout_pk = Public_key.Compressed.of_base58_check_exn addr in
            let delegatee =
              match
                Public_key.Compressed.Table.find delegatee_tbl payout_pk
              with
              | Some pk ->
                  pk
              | None ->
                  failwithf "No delegatee for payout address %s" addr ()
            in
            let delegatee_str =
              Public_key.Compressed.to_base58_check delegatee
            in
            let%bind delegatee_id = pk_id_of_pk pool delegatee_str in
            let%bind payments_from_delegatee =
              query_db pool
                ~f:(fun db ->
                  Sql.User_command.run_payments_by_source_and_receiver db
                    ~source_id:delegatee_id ~receiver_id:payout_id )
                ~item:"payments from delegatee"
            in
            let%bind coinbase_receiver_ids =
              match%map
                Caqti_async.Pool.use
                  (fun db ->
                    Sql.Coinbase_receivers_for_block_creator.run db
                      ~block_creator_id:delegatee_id )
                  pool
              with
              | Ok ids ->
                  ids
              | Error err ->
                  failwithf
                    "Error getting coinbase receiver ids from blocks where \
                     the delegatee %s is the block creator, %s"
                    delegatee_str (Caqti_error.show err) ()
            in
            let%map payments_from_coinbase_receivers =
              match%map
                Archive_lib.Processor.deferred_result_list_fold
                  coinbase_receiver_ids ~init:[]
                  ~f:(fun accum coinbase_receiver_id ->
                    let%map payments =
                      query_db pool
                        ~f:(fun db ->
                          Sql.User_command.run_payments_by_source_and_receiver
                            db ~source_id:coinbase_receiver_id
                            ~receiver_id:payout_id )
                        ~item:
                          (sprintf
                             "payments from coinbase receiver with id %d to \
                              payment address"
                             coinbase_receiver_id)
                    in
                    Ok (payments @ accum) )
              with
              | Ok payments ->
                  payments
              | Error err ->
                  failwithf
                    "Error getting payments from coinbase receivers: %s"
                    (Caqti_error.show err) ()
            in
            let all_payments =
              payments_from_delegatee @ payments_from_coinbase_receivers
            in
            (* discard payments not in canonical chain *)
            let payments =
              List.filter all_payments ~f:(fun uc ->
                  Int.Set.mem block_ids uc.block_id )
            in
            { payout_pk
            ; payout_id
            ; delegation_source
            ; delegatee
            ; delegatee_id
            ; payments
            ; unmet_obligation= Float.zero
            ; to_3500_allocation_opt= None } )
      in
      [%log info] "Loading user command ids" ;
      let%bind user_cmd_ids =
        match%bind
          Caqti_async.Pool.use
            (fun db -> Sql.User_command_ids.run db target_state_hash)
            pool
        with
        | Ok ids ->
            return ids
        | Error msg ->
            [%log error] "Error getting user command ids"
              ~metadata:[("error", `String (Caqti_error.show msg))] ;
            exit 1
      in
      [%log info] "Loading internal command ids" ;
      let%bind internal_cmd_ids =
        match%bind
          Caqti_async.Pool.use
            (fun db -> Sql.Internal_command_ids.run db target_state_hash)
            pool
        with
        | Ok ids ->
            return ids
        | Error msg ->
            [%log error] "Error getting user command ids"
              ~metadata:[("error", `String (Caqti_error.show msg))] ;
            exit 1
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
                  "Error querying for internal commands with id %d, error %s"
                  id (Caqti_error.show msg) () )
      in
      let unsorted_internal_cmds = List.concat unsorted_internal_cmds_list in
      (* filter out internal commands in blocks not along chain from target state hash *)
      let filtered_internal_cmds =
        List.filter unsorted_internal_cmds ~f:(fun cmd ->
            Int.Set.mem block_ids cmd.block_id )
      in
      let sorted_internal_cmds =
        List.sort filtered_internal_cmds ~compare:(fun ic1 ic2 ->
            let tuple (ic : Sql.Internal_command.t) =
              (ic.global_slot, ic.sequence_no, ic.secondary_sequence_no)
            in
            [%compare: int64 * int * int] (tuple ic1) (tuple ic2) )
      in
      (* populate cache of fee transfer via coinbase items *)
      [%log info] "Populating fee transfer via coinbase cache" ;
      let%bind () =
        Deferred.List.iter sorted_internal_cmds
          ~f:(cache_fee_transfer_via_coinbase pool)
      in
      [%log info] "Loading user commands" ;
      let%bind unsorted_user_cmds_list =
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
      let sorted_user_cmds =
        List.sort filtered_user_cmds ~compare:(fun uc1 uc2 ->
            let tuple (uc : Sql.User_command.t) =
              (uc.global_slot, uc.sequence_no)
            in
            [%compare: int64 * int] (tuple uc1) (tuple uc2) )
      in
      [%log info] "Applying %d user commands and %d internal commands"
        (List.length sorted_user_cmds)
        (List.length sorted_internal_cmds) ;
      let update_to_3500_allocation_opt ~last_global_slot ~payout_info =
        (* at or past slot 3500, check any unmet obligation from previous epoch
         error if we can't meet the obligation, and zero to_3500 allocation
         if unmet obligation was 0, zero to_3500 allocation
         if nonzero. take what we need to meet the obligation, allocate rest to to_3500 allocation
      *)
        let epoch, _slot = epoch_and_offset_of_global_slot last_global_slot in
        let json_of_float float = `String (Float.to_string float) in
        let new_allocation_opt =
          if Float.equal payout_info.unmet_obligation 0.0 then (
            [%log info]
              "At slot 3500 in current epoch, no unmet obligation from \
               delegatee to payout address from previous epoch"
              ~metadata:
                [ ( "delegatee"
                  , Public_key.Compressed.to_yojson payout_info.delegatee )
                ; ( "payout_addr"
                  , Public_key.Compressed.to_yojson payout_info.payout_pk )
                ; ("epoch", Unsigned_extended.UInt32.to_yojson epoch) ] ;
            (* all payments in epoch can be used to satisfy obligations *)
            None )
          else
            let total_to_3500 =
              get_payment_total_to_3500_in_epoch epoch payout_info.payments
              |> Int64.to_float
            in
            let base_metadata =
              [ ( "delegatee"
                , Public_key.Compressed.to_yojson payout_info.delegatee )
              ; ( "payout_addr"
                , Public_key.Compressed.to_yojson payout_info.payout_pk )
              ; ("unmet_obligation", json_of_float payout_info.unmet_obligation)
              ; ("epoch", Unsigned_extended.UInt32.to_yojson epoch)
              ; ("total_to_slot_3500", json_of_float total_to_3500) ]
            in
            if Float.( < ) total_to_3500 payout_info.unmet_obligation then (
              [%log error]
                "DELINQUENCY (reward specification): Delegatee $delegatee has \
                 not met obligations to payout address $payout_addr"
                ~metadata:base_metadata ;
              (* can't satisfy unmet obligation, nothing to contribute to current epoch obligation *)
              Some Float.zero )
            else if Float.equal payout_info.unmet_obligation total_to_3500 then (
              [%log info]
                "Payments to slot 3500 in this epoch equal to unmet \
                 obligation from previous epoch"
                ~metadata:base_metadata ;
              Some Float.zero )
            else
              let new_allocation =
                Float.( - ) total_to_3500 payout_info.unmet_obligation
              in
              [%log info]
                "Allocating some amount to slot 3500 to unmet obligation from \
                 previous epoch"
                ~metadata:
                  ( ("allocation_from_total", json_of_float new_allocation)
                  :: base_metadata ) ;
              Some new_allocation
        in
        payout_info.to_3500_allocation_opt <- new_allocation_opt ;
        payout_info
      in
      let update_unmet_obligation ~epoch ~staking_epoch_ledger ~payout_info =
        let prev_epoch = Unsigned.UInt32.pred epoch in
        let delegated_stake =
          compute_delegated_stake staking_epoch_ledger payout_info.delegatee
        in
        let delegated_amount =
          get_account_balance_as_amount ledger payout_info.payout_pk
        in
        let fraction_of_stake =
          Float.round_decimal ~decimal_digits:5
            (Float.( / )
               (Currency.Amount.to_string delegated_amount |> Float.of_string)
               (Currency.Amount.to_string delegated_stake |> Float.of_string))
        in
        let coinbase_amount = Float.( * ) 0.95 720.0 in
        let payout_obligation_per_block =
          Float.( * ) fraction_of_stake coinbase_amount
        in
        let%bind num_blocks_produced =
          (* blocks produced in previous epoch *)
          num_blocks_produced_in_epoch pool payout_info.delegatee_id prev_epoch
        in
        let payout_obligation =
          Float.( * )
            (Float.of_int num_blocks_produced)
            payout_obligation_per_block
        in
        let payout_in_prev_epoch =
          match payout_info.to_3500_allocation_opt with
          | None ->
              (* all payments in previous epoch *)
              let total =
                get_payment_total_in_epoch prev_epoch payout_info.payments
                |> Float.of_int64
              in
              if
                Float.( > ) payout_obligation Float.zero
                && Float.equal Float.zero total
              then
                [%log error]
                  "DELINQUENCY (payment frequency): Delegatee $delegatee made \
                   no payments to payout address $payout_addr in epoch $epoch"
                  ~metadata:
                    [ ("epoch", Unsigned_extended.UInt32.to_yojson prev_epoch)
                    ; ( "delegatee"
                      , Public_key.Compressed.to_yojson payout_info.delegatee
                      )
                    ; ( "payout_addr"
                      , Public_key.Compressed.to_yojson payout_info.payout_pk
                      ) ] ;
              total
          | Some amount ->
              (* some/all of the payments to slot 3500 allocated to earlier obligation,
             remaining amount we can use here, and any payments after slot 3500
          *)
              Float.( + ) amount
                ( get_payment_total_past_3500_in_epoch prev_epoch
                    payout_info.payments
                |> Float.of_int64 )
        in
        let unmet_obligation =
          Float.max 0.0 (Float.( - ) payout_obligation payout_in_prev_epoch)
        in
        [%log info]
          "Delegation information for payout address $payout_addr in epoch \
           $epoch"
          ~metadata:
            [ ("epoch", Unsigned_extended.UInt32.to_yojson prev_epoch)
            ; ( "delegatee"
              , Public_key.Compressed.to_yojson payout_info.delegatee )
            ; ( "payout_addr"
              , Public_key.Compressed.to_yojson payout_info.payout_pk )
            ; ( "delegatee_delegated_stake"
              , Currency.Amount.to_yojson delegated_stake )
            ; ("delegator_fraction_of_stake", `Float fraction_of_stake)
            ; ("payout_obligation", `Float payout_obligation)
            ; ("payout_in_prev_epoch", `Float payout_in_prev_epoch)
            ; ("unmet_obligation", `Float unmet_obligation) ] ;
        payout_info.unmet_obligation <- unmet_obligation ;
        return payout_info
      in
      (* apply commands in global slot, sequence order *)
      let rec apply_commands (internal_cmds : Sql.Internal_command.t list)
          (user_cmds : Sql.User_command.t list) ~last_global_slot ~last_epoch
          ~staking_epoch_ledger ~next_epoch_ledger ~last_block_id
          ~updated_at_3500 ~payout_infos =
        (* we don't necessarily see commands at slot 0 and 3500 of this epoch
         track last epoch, detect when we're in a new epoch
      *)
        let epoch, offset = epoch_and_offset_of_global_slot last_global_slot in
        let%bind payout_infos, updated_at_3500 =
          let is_new_epoch =
            Int.( > ) (Unsigned.UInt32.compare epoch last_epoch) 0
          in
          if is_new_epoch then
            (* on new epoch, check unmet obligations from previous epoch, reset `updated_at_3500` *)
            let%map infos =
              Deferred.List.map payout_infos ~f:(fun payout_info ->
                  update_unmet_obligation ~epoch ~staking_epoch_ledger
                    ~payout_info )
            in
            (infos, false)
          else
            let at_or_past_3500 =
              Int.( >= )
                (Unsigned.UInt32.compare offset (Unsigned.UInt32.of_int 3500))
                0
            in
            (* when passing slot 3500 of this epoch, check unmet obligations from previous epoch *)
            if at_or_past_3500 && not updated_at_3500 then
              let infos =
                List.map payout_infos ~f:(fun payout_info ->
                    update_to_3500_allocation_opt ~last_global_slot
                      ~payout_info )
              in
              return (infos, true)
            else return (payout_infos, updated_at_3500)
        in
        let%bind staking_epoch_ledger, _staking_seed =
          update_staking_epoch_data ~logger pool ~last_block_id ~ledger
            ~staking_epoch_ledger
        in
        let%bind next_epoch_ledger, _next_seed =
          update_next_epoch_data ~logger pool ~last_block_id ~ledger
            ~next_epoch_ledger
        in
        let log_ledger_hash_after_last_slot () =
          let _state_hash, expected_ledger_hash =
            Hashtbl.find_exn global_slot_hashes_tbl last_global_slot
          in
          if Ledger_hash.equal (Ledger.merkle_root ledger) expected_ledger_hash
          then
            [%log info]
              "Applied all commands at global slot %Ld, got expected ledger \
               hash"
              ~metadata:[("ledger_hash", json_ledger_hash_of_ledger ledger)]
              last_global_slot
          else (
            [%log error]
              "Applied all commands at global slot %Ld, ledger hash differs \
               from expected ledger hash"
              ~metadata:
                [ ("ledger_hash", json_ledger_hash_of_ledger ledger)
                ; ( "expected_ledger_hash"
                  , Ledger_hash.to_yojson expected_ledger_hash ) ]
              last_global_slot ;
            Core_kernel.exit 1 )
        in
        let log_state_hash_on_next_slot curr_global_slot =
          let state_hash, _ledger_hash =
            Hashtbl.find_exn global_slot_hashes_tbl curr_global_slot
          in
          [%log info]
            ~metadata:
              [("state_hash", `String (State_hash.to_base58_check state_hash))]
            "Starting processing of commands in block with state_hash \
             $state_hash at global slot %Ld"
            curr_global_slot
        in
        let log_on_slot_change curr_global_slot =
          if Int64.( > ) curr_global_slot last_global_slot then (
            log_ledger_hash_after_last_slot () ;
            log_state_hash_on_next_slot curr_global_slot )
        in
        let combine_or_run_internal_cmds (ic : Sql.Internal_command.t)
            (ics : Sql.Internal_command.t list) =
          match ics with
          | ic2 :: ics2
            when Int64.equal ic.global_slot ic2.global_slot
                 && Int.equal ic.sequence_no ic2.sequence_no
                 && String.equal ic.type_ "fee_transfer"
                 && String.equal ic.type_ ic2.type_ ->
              (* combining situation 2
             two fee transfer commands with same global slot, sequence number
          *)
              log_on_slot_change ic.global_slot ;
              let%bind () =
                apply_combined_fee_transfer ~logger ~pool ~ledger ic ic2
              in
              apply_commands ics2 user_cmds ~last_global_slot:ic.global_slot
                ~last_epoch:epoch ~last_block_id:ic.block_id
                ~staking_epoch_ledger ~next_epoch_ledger ~payout_infos
                ~updated_at_3500
          | _ ->
              log_on_slot_change ic.global_slot ;
              let%bind () = run_internal_command ~logger ~pool ~ledger ic in
              apply_commands ics user_cmds ~last_global_slot:ic.global_slot
                ~last_epoch:epoch ~last_block_id:ic.block_id
                ~staking_epoch_ledger ~next_epoch_ledger ~payout_infos
                ~updated_at_3500
        in
        (* choose command with least global slot, sequence number *)
        let cmp_ic_uc (ic : Sql.Internal_command.t) (uc : Sql.User_command.t) =
          [%compare: int64 * int]
            (ic.global_slot, ic.sequence_no)
            (uc.global_slot, uc.sequence_no)
        in
        match (internal_cmds, user_cmds) with
        | [], [] ->
            log_ledger_hash_after_last_slot () ;
            Deferred.return (updated_at_3500, epoch)
        | [], uc :: ucs ->
            log_on_slot_change uc.global_slot ;
            let%bind () = run_user_command ~logger ~pool ~ledger uc in
            apply_commands [] ucs ~last_global_slot:uc.global_slot
              ~last_epoch:epoch ~last_block_id:uc.block_id
              ~staking_epoch_ledger ~next_epoch_ledger ~payout_infos
              ~updated_at_3500
        | ic :: _, uc :: ucs when cmp_ic_uc ic uc > 0 ->
            log_on_slot_change uc.global_slot ;
            let%bind () = run_user_command ~logger ~pool ~ledger uc in
            apply_commands internal_cmds ucs ~last_global_slot:uc.global_slot
              ~last_epoch:epoch ~last_block_id:uc.block_id
              ~staking_epoch_ledger ~next_epoch_ledger ~payout_infos
              ~updated_at_3500
        | ic :: ics, [] ->
            combine_or_run_internal_cmds ic ics
        | ic :: ics, uc :: _ when cmp_ic_uc ic uc < 0 ->
            combine_or_run_internal_cmds ic ics
        | ic :: _, _ :: __ ->
            failwithf
              "An internal command and a user command have the same global \
               slot %Ld and sequence number %d"
              ic.global_slot ic.sequence_no ()
      in
      [%log info] "At genesis, ledger hash"
        ~metadata:[("ledger_hash", json_ledger_hash_of_ledger ledger)] ;
      let%bind unparented_ids =
        query_db pool
          ~f:(fun db -> Sql.Block.get_unparented db ())
          ~item:"unparented ids"
      in
      let genesis_block_id =
        match List.filter unparented_ids ~f:(Int.Set.mem block_ids) with
        | [id] ->
            id
        | _ ->
            failwith "Expected only the genesis block to have an unparented id"
      in
      let%bind updated_at_3500, epoch =
        apply_commands sorted_internal_cmds sorted_user_cmds
          ~last_global_slot:0L ~last_epoch:Unsigned.UInt32.zero
          ~last_block_id:genesis_block_id ~staking_epoch_ledger:ledger
          ~next_epoch_ledger:ledger ~updated_at_3500:false ~payout_infos
      in
      if not updated_at_3500 then
        [%log warn]
          "Did not update payouts at slot 3500 in epoch $epoch, some \
           delinquencies may not have been logged"
          ~metadata:[("epoch", Unsigned_extended.UInt32.to_yojson epoch)] ;
      [%log info] "Done" ;
      Deferred.unit

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async
        ~summary:
          "Check compliance for Mina Foundation and O(1) Labs delegations"
        (let%map input_file =
           Param.flag "--input-file"
             ~doc:"file File containing the starting staking ledger"
             Param.(required string)
         and archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER@localhost:5432/archiver)"
             Param.(required string)
         and payout_addresses =
           Param.anon Anons.(sequence ("PAYOUT ADDRESSES" %: Param.string))
         in
         main ~input_file ~archive_uri ~payout_addresses)))
