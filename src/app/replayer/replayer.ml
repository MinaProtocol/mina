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
  { target_epoch_ledgers_state_hash: State_hash.t
  ; genesis_ledger: Runtime_config.Ledger.t }
[@@deriving yojson]

type output =
  { target_epoch_ledgers_state_hash: State_hash.t
  ; target_fork_state_hash: State_hash.t
  ; target_genesis_ledger: Runtime_config.Ledger.t
  ; target_epoch_data: Runtime_config.Epoch_data.t }
[@@deriving yojson]

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let proof_level = Genesis_constants.Proof_level.Full

let json_ledger_hash_of_ledger ledger =
  Ledger_hash.to_yojson @@ Ledger.merkle_root ledger

let create_output ~target_fork_state_hash ~target_epoch_ledgers_state_hash
    ~ledger ~staking_epoch_ledger ~staking_seed ~next_epoch_ledger ~next_seed
    (input_genesis_ledger : Runtime_config.Ledger.t) =
  let create_ledger_as_list ledger =
    List.map (Ledger.to_list ledger) ~f:(fun acc ->
        Genesis_ledger_helper.Accounts.Single.of_account acc None )
  in
  let genesis_ledger_as_list = create_ledger_as_list ledger in
  let target_genesis_ledger =
    {input_genesis_ledger with base= Accounts genesis_ledger_as_list}
  in
  let staking_epoch_ledger_as_list =
    create_ledger_as_list staking_epoch_ledger
  in
  let next_epoch_ledger_as_list = create_ledger_as_list next_epoch_ledger in
  let target_staking_epoch_data : Runtime_config.Epoch_data.Data.t =
    let ledger =
      {input_genesis_ledger with base= Accounts staking_epoch_ledger_as_list}
    in
    {ledger; seed= staking_seed}
  in
  let target_next_epoch_data : Runtime_config.Epoch_data.Data.t =
    let ledger =
      {input_genesis_ledger with base= Accounts next_epoch_ledger_as_list}
    in
    {ledger; seed= next_seed}
  in
  let target_epoch_data : Runtime_config.Epoch_data.t =
    {staking= target_staking_epoch_data; next= Some target_next_epoch_data}
  in
  { target_fork_state_hash
  ; target_epoch_ledgers_state_hash
  ; target_genesis_ledger
  ; target_epoch_data }

(* map from global slots to expected ledger hashes *)
let global_slot_ledger_hash_tbl : (Int64.t, Ledger_hash.t) Hashtbl.t =
  Int64.Table.create ()

(* cache of account keys *)
let pk_tbl : (int, Account.key) Hashtbl.t = Int.Table.create ()

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

let process_block_info_of_state_hash ~logger pool state_hash ~f =
  match%bind
    Caqti_async.Pool.use (fun db -> Sql.Block_info.run db state_hash) pool
  with
  | Ok block_info ->
      f block_info
  | Error msg ->
      [%log error] "Error getting block information for state hash"
        ~metadata:
          [ ("error", `String (Caqti_error.show msg))
          ; ("state_hash", `String state_hash) ] ;
      exit 1

let update_epoch_ledger ~logger ~name ledger epoch_ledger_opt epoch_ledger_hash
    =
  match epoch_ledger_opt with
  | Some _ ->
      (* already have this epoch ledger *)
      epoch_ledger_opt
  | None ->
      let curr_ledger_hash = Ledger.merkle_root ledger in
      if Frozen_ledger_hash.equal epoch_ledger_hash curr_ledger_hash then (
        [%log info]
          "Creating %s epoch ledger from ledger with Merkle root matching \
           epoch ledger hash %s"
          name
          (Ledger_hash.to_string epoch_ledger_hash) ;
        (* Ledger.copy doesn't actually copy, roll our own here *)
        let accounts = Ledger.to_list ledger in
        let epoch_ledger = Ledger.create ~depth:(Ledger.depth ledger) () in
        List.iter accounts ~f:(fun account ->
            let pk = Account.public_key account in
            let token = Account.token account in
            let account_id = Account_id.create pk token in
            match
              Ledger.get_or_create_account epoch_ledger account_id account
            with
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
        Some epoch_ledger )
      else None

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
  let undo_or_error =
    Ledger.apply_fee_transfer ~constraint_constants ~txn_global_slot ledger
      fee_transfer
  in
  match undo_or_error with
  | Ok _undo ->
      (* in Transaction_log.process_transfer_fee, when the fee transfer has two components,
       as here, the balance depends only on the first transfer if the receiver is the same
       in both components
    *)
      let cmd =
        if Int.equal cmd1.receiver_id cmd2.receiver_id then cmd1 else cmd2
      in
      verify_balance ~logger ~pool ~ledger ~who:"combined fee transfer"
        ~balance_id:cmd.receiver_balance ~pk_id:cmd.receiver_id
        ~token_int64:cmd.token
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

let unquoted_string_of_yojson json =
  (* Yojson.Safe.to_string produces double-quoted strings
     remove those quotes for SQL queries
  *)
  let s = Yojson.Safe.to_string json in
  String.sub s ~pos:1 ~len:(String.length s - 2)

let main ~input_file ~output_file ~archive_uri () =
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
      let epoch_ledgers_state_hash =
        State_hash.to_string input.target_epoch_ledgers_state_hash
      in
      [%log info] "Retrieving fork block state_hash" ;
      let%bind fork_state_hash =
        state_hash_of_epoch_ledgers_state_hash ~logger pool
          epoch_ledgers_state_hash
      in
      [%log info] "Loading epoch ledger data" ;
      let%bind staking_id_from_epoch_ledgers_state_hash =
        epoch_staking_id_of_state_hash ~logger pool epoch_ledgers_state_hash
      in
      let%bind next_id_from_epoch_ledgers_state_hash =
        epoch_next_id_of_state_hash ~logger pool epoch_ledgers_state_hash
      in
      let%bind next_id_from_fork_state_hash =
        epoch_next_id_of_state_hash ~logger pool fork_state_hash
      in
      let%bind { epoch_ledger_hash= staking_epoch_ledger_hash_str
               ; epoch_data_seed= staking_seed_str } =
        epoch_data_of_id ~logger pool staking_id_from_epoch_ledgers_state_hash
      in
      let%bind { epoch_ledger_hash= next_epoch_ledger_hash_str
               ; epoch_data_seed= _ } =
        epoch_data_of_id ~logger pool next_id_from_epoch_ledgers_state_hash
      in
      let%bind {epoch_ledger_hash= _; epoch_data_seed= next_seed_str} =
        epoch_data_of_id ~logger pool next_id_from_fork_state_hash
      in
      let staking_epoch_ledger_hash =
        Frozen_ledger_hash.of_string staking_epoch_ledger_hash_str
      in
      let staking_seed = Epoch_seed.of_string staking_seed_str in
      let next_epoch_ledger_hash =
        Frozen_ledger_hash.of_string next_epoch_ledger_hash_str
      in
      let next_seed = Epoch_seed.of_string next_seed_str in
      [%log info] "Loading block information using target state hash" ;
      let%bind block_ids =
        process_block_info_of_state_hash ~logger pool fork_state_hash
          ~f:(fun block_info ->
            let ids =
              List.map block_info ~f:(fun (id, _global_slot, _hash) -> id)
            in
            (* build mapping from global slots to ledger hashes *)
            List.iter block_info ~f:(fun (_id, global_slot, hash) ->
                Hashtbl.add_exn global_slot_ledger_hash_tbl ~key:global_slot
                  ~data:(Ledger_hash.of_string hash) ) ;
            return (Int.Set.of_list ids) )
      in
      (* check that genesis block is in chain to target hash
         assumption: genesis block occupies global slot 0
      *)
      if Int64.Table.mem global_slot_ledger_hash_tbl Int64.zero then
        [%log info]
          "Block chain leading to target state hash includes genesis block"
      else (
        [%log fatal]
          "Block chain leading to target state hash does not include genesis \
           block" ;
        Core_kernel.exit 1 ) ;
      [%log info] "Loading user command ids" ;
      let%bind user_cmd_ids =
        match%bind
          Caqti_async.Pool.use
            (fun db -> Sql.User_command_ids.run db fork_state_hash)
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
            (fun db -> Sql.Internal_command_ids.run db fork_state_hash)
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
      (* apply commands in global slot, sequence order *)
      let rec apply_commands (internal_cmds : Sql.Internal_command.t list)
          (user_cmds : Sql.User_command.t list) ~last_global_slot
          ~staking_epoch_ledger_opt ~next_epoch_ledger_opt =
        let staking_epoch_ledger_opt =
          update_epoch_ledger ~logger ~name:"staking" ledger
            staking_epoch_ledger_opt staking_epoch_ledger_hash
        in
        let next_epoch_ledger_opt =
          update_epoch_ledger ~logger ~name:"next" ledger next_epoch_ledger_opt
            next_epoch_ledger_hash
        in
        let log_ledger_hash_after_last_slot () =
          let expected_ledger_hash =
            Hashtbl.find_exn global_slot_ledger_hash_tbl last_global_slot
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
        let log_on_slot_change curr_global_slot =
          if Int64.( > ) curr_global_slot last_global_slot then
            log_ledger_hash_after_last_slot ()
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
                ~staking_epoch_ledger_opt ~next_epoch_ledger_opt
          | _ ->
              log_on_slot_change ic.global_slot ;
              let%bind () = run_internal_command ~logger ~pool ~ledger ic in
              apply_commands ics user_cmds ~last_global_slot:ic.global_slot
                ~staking_epoch_ledger_opt ~next_epoch_ledger_opt
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
            let found_staking = Option.is_some staking_epoch_ledger_opt in
            let found_next = Option.is_some next_epoch_ledger_opt in
            ( match (found_staking, found_next) with
            | false, false ->
                [%log error]
                  "Replayed all commands, found neither staking epoch ledger \
                   nor next epoch ledger" ;
                Core_kernel.exit 1
            | false, true ->
                [%log error]
                  "Replayed all commands, did not find staking epoch ledger" ;
                Core_kernel.exit 1
            | true, false ->
                [%log error]
                  "Replayed all commands, did not find next epoch ledger" ;
                Core_kernel.exit 1
            | true, true ->
                () ) ;
            Deferred.return
              ( Option.value_exn staking_epoch_ledger_opt
              , Option.value_exn next_epoch_ledger_opt )
        | [], uc :: ucs ->
            log_on_slot_change uc.global_slot ;
            let%bind () = run_user_command ~logger ~pool ~ledger uc in
            apply_commands [] ucs ~last_global_slot:uc.global_slot
              ~staking_epoch_ledger_opt ~next_epoch_ledger_opt
        | ic :: _, uc :: ucs when cmp_ic_uc ic uc > 0 ->
            log_on_slot_change uc.global_slot ;
            let%bind () = run_user_command ~logger ~pool ~ledger uc in
            apply_commands internal_cmds ucs ~last_global_slot:uc.global_slot
              ~staking_epoch_ledger_opt ~next_epoch_ledger_opt
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
      let%bind staking_epoch_ledger, next_epoch_ledger =
        apply_commands sorted_internal_cmds sorted_user_cmds
          ~last_global_slot:0L ~staking_epoch_ledger_opt:None
          ~next_epoch_ledger_opt:None
      in
      [%log info] "Writing output to $output_file"
        ~metadata:[("output_file", `String output_file)] ;
      let output =
        create_output
          ~target_epoch_ledgers_state_hash:
            input.target_epoch_ledgers_state_hash
          ~target_fork_state_hash:(State_hash.of_string fork_state_hash)
          ~ledger ~staking_epoch_ledger
          ~staking_seed:(Epoch_seed.to_string staking_seed)
          ~next_epoch_ledger
          ~next_seed:(Epoch_seed.to_string next_seed)
          input.genesis_ledger
        |> output_to_yojson |> Yojson.Safe.to_string
      in
      let%map writer = Async_unix.Writer.open_file output_file in
      Async.fprintf writer "%s\n" output ;
      ()

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async ~summary:"Replay transactions from Coda archive"
        (let%map input_file =
           Param.flag "--input-file"
             ~doc:"file File containing the genesis ledger"
             Param.(required string)
         and output_file =
           Param.flag "--output-file"
             ~doc:"file File containing the resulting ledger"
             Param.(required string)
         and archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER:$USER@localhost:5432/archiver)"
             Param.(required string)
         in
         main ~input_file ~output_file ~archive_uri)))
