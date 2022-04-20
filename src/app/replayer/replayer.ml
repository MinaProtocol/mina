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

type command_type = [ `Internal_command | `User_command | `Zkapp_command ]

module type Get_command_ids = sig
  val run :
       Caqti_async.connection
    -> state_hash:string
    -> start_slot:int64
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

(* cache of tokens *)
let token_tbl : (int, Token_id.t) Hashtbl.t = Int.Table.create ()

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
  | None ->
      let%map pk =
        Archive_lib.Load_data.pk_of_id ~item:"a public key" pool pk_id
      in
      Hashtbl.add_exn pk_tbl ~key:pk_id ~data:pk ;
      pk

let token_of_token_id pool token_id : Token_id.t Deferred.t =
  let open Deferred.Let_syntax in
  match Hashtbl.find token_tbl token_id with
  | Some token ->
      return token
  | None ->
      let%map token =
        Archive_lib.Load_data.token_of_id ~item:"a token" pool token_id
      in
      Hashtbl.add_exn token_tbl ~key:token_id ~data:token ;
      token

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

let account_creation_fee_uint64 =
  Currency.Fee.to_uint64 constraint_constants.account_creation_fee

let account_creation_fee_int64 =
  Currency.Fee.to_int constraint_constants.account_creation_fee |> Int64.of_int

let run_internal_command ~logger ~pool ~ledger (cmd : Sql.Internal_command.t)
    ~continue_on_error:_ =
  [%log info]
    "Applying internal command (%s) with global slot since genesis %Ld, \
     sequence number %d, and secondary sequence number %d"
    cmd.type_ cmd.global_slot_since_genesis cmd.sequence_no
    cmd.secondary_sequence_no ;
  let%bind receiver_pk = pk_of_pk_id pool cmd.receiver_id in
  let fee = Currency.Fee.of_uint64 (Unsigned.UInt64.of_int64 cmd.fee) in
  let get_token id =
    Archive_lib.Load_data.token_of_id ~item:"internal command token" pool id
  in
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
  let open Ledger in
  match cmd.type_ with
  | "fee_transfer" -> (
      let%bind fee_token = get_token cmd.token_id in
      let fee_transfer =
        Fee_transfer.create_single ~receiver_pk ~fee ~fee_token
      in
      let undo_or_error =
        Ledger.apply_fee_transfer ~constraint_constants ~txn_global_slot ledger
          fee_transfer
      in
      match undo_or_error with
      | Ok _undo ->
          Deferred.unit
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
      let undo_or_error =
        apply_coinbase ~constraint_constants ~txn_global_slot ledger coinbase
      in
      match undo_or_error with
      | Ok _undo ->
          Deferred.unit
      | Error err ->
          fail_on_error err )
  | "fee_transfer_via_coinbase" ->
      (* the actual application is in the "coinbase" case *)
      Deferred.unit
  | _ ->
      failwithf "Unknown internal command \"%s\"" cmd.type_ ()

let apply_combined_fee_transfer ~logger ~pool ~ledger ~continue_on_error:_
    (cmd1 : Sql.Internal_command.t) (cmd2 : Sql.Internal_command.t) =
  [%log info] "Applying combined fee transfers with sequence number %d"
    cmd1.sequence_no ;
  let fee_transfer_of_cmd (cmd : Sql.Internal_command.t) =
    if not (String.equal cmd.type_ "fee_transfer") then
      failwithf "Expected fee transfer, got: %s" cmd.type_ () ;
    let%bind receiver_pk = pk_of_pk_id pool cmd.receiver_id in
    let fee = Currency.Fee.of_uint64 (Unsigned.UInt64.of_int64 cmd.fee) in
    let%map fee_token =
      Archive_lib.Load_data.token_of_id ~item:"combined fee transfer token" pool
        cmd.token_id
    in
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
      Deferred.unit
  | Error err ->
      Error.tag_arg err "Error applying combined fee transfer"
        ("sequence number", cmd1.sequence_no)
        [%sexp_of: string * int]
      |> Error.raise

module User_command_helpers = struct
  let body_of_sql_user_cmd pool
      ({ type_; source_id; receiver_id; amount; global_slot_since_genesis; _ } :
        Sql.User_command.t) : Signed_command_payload.Body.t Deferred.t =
    let open Signed_command_payload.Body in
    let open Deferred.Let_syntax in
    let%bind source_pk = pk_of_pk_id pool source_id in
    let%map receiver_pk = pk_of_pk_id pool receiver_id in
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
        Payment Payment_payload.Poly.{ source_pk; receiver_pk; amount }
    | "delegation" ->
        Stake_delegation
          (Stake_delegation.Set_delegate
             { delegator = source_pk; new_delegate = receiver_pk })
    | _ ->
        failwithf "Invalid user command type: %s" type_ ()
end

let run_user_command ~logger ~pool ~ledger (cmd : Sql.User_command.t)
    ~continue_on_error:_ =
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
      Deferred.unit
  | Error err ->
      Error.tag_arg err "User command failed on replay"
        ( ("global slot_since_genesis", cmd.global_slot_since_genesis)
        , ("sequence number", cmd.sequence_no) )
        [%sexp_of: (string * int64) * (string * int)]
      |> Error.raise

module Zkapp_helpers = struct
  open Zkapp_basic

  let get_parent_state_view ~pool block_id :
      Zkapp_precondition.Protocol_state.View.t Deferred.t =
    (* when a zkAppp is applied, use the protocol state associated with the parent block
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
      { Zkapp_precondition.Protocol_state.Poly.snarked_ledger_hash
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
            ~f:(fun db -> Processor.Zkapp_state_data_array.load db array_id)
            ~item:"Zkapp state data array"
        in
        let element_ids = Array.to_list element_id_array in
        let%bind field_strs =
          Deferred.List.map element_ids ~f:(fun elt_id ->
              query_db pool ~item:"Zkapp field element" ~f:(fun db ->
                  Processor.Zkapp_state_data.load db elt_id))
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
                ~f:(fun db -> Processor.Zkapp_state_data.load db id)
                ~item:"Zkapp state data"
            in
            Some (Snark_params.Tick.Field.of_string field_str))

  let party_body_of_id ~pool body_id =
    let%bind (body_data : Processor.Zkapp_party_body.t) =
      query_db pool
        ~f:(fun db -> Processor.Zkapp_party_body.load db body_id)
        ~item:"Zkapp party body"
    in
    let%bind public_key = pk_of_pk_id pool body_data.public_key_id in
    let%bind update_data =
      query_db pool
        ~f:(fun db -> Processor.Zkapp_updates.load db body_data.update_id)
        ~item:"Zkapp updates"
    in
    let%bind app_state_data_ids =
      query_db pool
        ~f:(fun db -> Processor.Zkapp_states.load db update_data.app_state_id)
        ~item:"zkApp app state ids"
    in
    let%bind app_state_data = state_data_of_ids ~pool app_state_data_ids in
    let app_state =
      Array.map app_state_data ~f:Zkapp_basic.Set_or_keep.of_option
      |> Array.to_list |> Pickles_types.Vector.Vector_8.of_list_exn
    in
    let%bind delegate =
      match update_data.delegate_id with
      | Some id ->
          let%map pk = pk_of_pk_id pool id in
          Zkapp_basic.Set_or_keep.Set pk
      | None ->
          return Zkapp_basic.Set_or_keep.Keep
    in
    let%bind verification_key =
      match update_data.verification_key_id with
      | Some id ->
          let%map ({ verification_key; hash }
                    : Processor.Zkapp_verification_keys.t) =
            query_db pool
              ~f:(fun db -> Processor.Zkapp_verification_keys.load db id)
              ~item:"zkApp verification key"
          in
          let data =
            Pickles.Side_loaded.Verification_key.of_base58_check_exn
              verification_key
          in
          let hash = Snark_params.Tick.Field.of_string hash in
          Zkapp_basic.Set_or_keep.Set { With_hash.data; hash }
      | None ->
          return Zkapp_basic.Set_or_keep.Keep
    in
    let%bind permissions =
      match update_data.permissions_id with
      | Some id ->
          let%map perms_data =
            query_db pool
              ~f:(fun db -> Processor.Zkapp_permissions.load db id)
              ~item:"zkApp verification key"
          in
          let perms : Mina_base.Permissions.t =
            { edit_state = perms_data.edit_state
            ; send = perms_data.send
            ; receive = perms_data.receive
            ; set_delegate = perms_data.set_delegate
            ; set_permissions = perms_data.set_permissions
            ; set_verification_key = perms_data.set_verification_key
            ; set_zkapp_uri = perms_data.set_zkapp_uri
            ; edit_sequence_state = perms_data.edit_sequence_state
            ; set_token_symbol = perms_data.set_token_symbol
            ; increment_nonce = perms_data.increment_nonce
            ; set_voting_for = perms_data.set_voting_for
            }
          in
          Zkapp_basic.Set_or_keep.Set perms
      | None ->
          return Zkapp_basic.Set_or_keep.Keep
    in
    let%bind zkapp_uri =
      let%map uri_opt =
        Option.value_map update_data.zkapp_uri_id ~default:(return None)
          ~f:(fun id ->
            let%map uri =
              query_db pool ~item:"zkapp uri" ~f:(fun db ->
                  Processor.Zkapp_uri.load db id)
            in
            Some uri)
      in
      Zkapp_basic.Set_or_keep.of_option uri_opt
    in
    let token_symbol =
      update_data.token_symbol |> Zkapp_basic.Set_or_keep.of_option
    in
    let voting_for =
      update_data.voting_for
      |> Option.map ~f:State_hash.of_base58_check_exn
      |> Zkapp_basic.Set_or_keep.of_option
    in
    let%bind timing =
      match update_data.timing_id with
      | None ->
          return Zkapp_basic.Set_or_keep.Keep
      | Some id ->
          let%map tm_info =
            query_db pool
              ~f:(fun db -> Processor.Zkapp_timing_info.load db id)
              ~item:"zkApp timing info"
          in
          Zkapp_basic.Set_or_keep.Set
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
      ; zkapp_uri
      ; token_symbol
      ; timing
      ; voting_for
      }
    in
    let%bind token_id =
      let%map token_str =
        query_db pool ~item:"token" ~f:(fun db ->
            Processor.Token.find_by_id db body_data.token_id)
      in
      Token_id.of_string token_str
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
    let load_events id =
      let%map fields_list =
        (* each id refers to an item in 'zkapp_state_data_array' *)
        let%bind field_array_ids =
          query_db pool ~item:"events arrays" ~f:(fun db ->
              Processor.Zkapp_events.load db id)
        in
        Deferred.List.map (Array.to_list field_array_ids) ~f:(fun array_id ->
            let%bind field_ids =
              query_db pool ~item:"events array" ~f:(fun db ->
                  Processor.Zkapp_state_data_array.load db array_id)
            in
            Deferred.List.map (Array.to_list field_ids) ~f:(fun field_id ->
                let%map field_str =
                  query_db pool ~item:"event field" ~f:(fun db ->
                      Processor.Zkapp_state_data.load db field_id)
                in
                Zkapp_basic.F.of_string field_str))
      in
      List.map fields_list ~f:Array.of_list
    in
    let%bind events = load_events body_data.events_id in
    let%bind sequence_events = load_events body_data.sequence_events_id in
    let%bind call_data_str =
      query_db pool
        ~f:(fun db -> Processor.Zkapp_state_data.load db body_data.call_data_id)
        ~item:"zkApp call data"
    in
    let call_data = Snark_params.Tick.Field.of_string call_data_str in
    let call_depth = body_data.call_depth in
    let%bind protocol_state_data =
      query_db pool
        ~f:(fun db ->
          Processor.Zkapp_precondition_protocol_state.load db
            body_data.zkapp_protocol_state_precondition_id)
        ~item:"zkApp account_precondition protocol state"
    in
    let%bind snarked_ledger_hash =
      match protocol_state_data.snarked_ledger_hash_id with
      | None ->
          return Zkapp_precondition.Hash.Ignore
      | Some id ->
          let%map hash_str =
            query_db pool ~item:"snarked ledger hash" ~f:(fun db ->
                Processor.Snarked_ledger_hash.load db id)
          in
          Zkapp_precondition.Hash.Check
            (Frozen_ledger_hash.of_base58_check_exn hash_str)
    in
    let%bind timestamp =
      match protocol_state_data.timestamp_id with
      | None ->
          return Zkapp_basic.Or_ignore.Ignore
      | Some id ->
          let%map bounds =
            query_db pool ~item:"zkApp timestamp bounds" ~f:(fun db ->
                Processor.Zkapp_timestamp_bounds.load db id)
          in
          let to_timestamp i64 = i64 |> Block_time.of_int64 in
          let lower = to_timestamp bounds.timestamp_lower_bound in
          let upper = to_timestamp bounds.timestamp_upper_bound in
          Zkapp_basic.Or_ignore.Check
            ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t)
    in
    let length_bounds_of_id = function
      | None ->
          return Zkapp_basic.Or_ignore.Ignore
      | Some id ->
          let%map bounds =
            query_db pool ~item:"zkApp length bounds" ~f:(fun db ->
                Processor.Zkapp_length_bounds.load db id)
          in
          let to_length i64 =
            i64 |> Unsigned.UInt32.of_int64 |> Mina_numbers.Length.of_uint32
          in
          let lower = to_length bounds.length_lower_bound in
          let upper = to_length bounds.length_upper_bound in
          Zkapp_basic.Or_ignore.Check
            ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t)
    in
    let%bind blockchain_length =
      length_bounds_of_id protocol_state_data.blockchain_length_id
    in
    let%bind min_window_density =
      length_bounds_of_id protocol_state_data.min_window_density_id
    in
    let total_currency_of_id = function
      | None ->
          return Zkapp_basic.Or_ignore.Ignore
      | Some id ->
          let%map bounds =
            query_db pool ~item:"zkApp currency bounds" ~f:(fun db ->
                Processor.Zkapp_amount_bounds.load db id)
          in
          let to_amount i64 =
            i64 |> Unsigned.UInt64.of_int64 |> Currency.Amount.of_uint64
          in
          let lower = to_amount bounds.amount_lower_bound in
          let upper = to_amount bounds.amount_upper_bound in
          Zkapp_basic.Or_ignore.Check
            ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t)
    in
    (* TODO: this will change *)
    let last_vrf_output = () in
    let%bind total_currency =
      total_currency_of_id protocol_state_data.total_currency_id
    in
    let global_slot_of_id = function
      | None ->
          return Zkapp_basic.Or_ignore.Ignore
      | Some id ->
          let%map bounds =
            query_db pool ~item:"zkApp global slot bounds" ~f:(fun db ->
                Processor.Zkapp_global_slot_bounds.load db id)
          in
          let to_slot i64 =
            i64 |> Unsigned.UInt32.of_int64
            |> Mina_numbers.Global_slot.of_uint32
          in
          let lower = to_slot bounds.global_slot_lower_bound in
          let upper = to_slot bounds.global_slot_upper_bound in
          Zkapp_basic.Or_ignore.Check
            ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t)
    in
    let%bind global_slot_since_hard_fork =
      global_slot_of_id protocol_state_data.curr_global_slot_since_hard_fork
    in
    let%bind global_slot_since_genesis =
      global_slot_of_id protocol_state_data.global_slot_since_genesis
    in
    let epoch_data_of_id id =
      let%bind epoch_data_raw =
        query_db pool ~item:"zkApp epoch data" ~f:(fun db ->
            Processor.Zkapp_epoch_data.load db id)
      in
      let%bind ledger =
        let%bind epoch_ledger_data =
          query_db pool ~item:"zkApp epoch ledger" ~f:(fun db ->
              Processor.Zkapp_epoch_ledger.load db id)
        in
        let%bind hash =
          Option.value_map epoch_ledger_data.hash_id
            ~default:(return Zkapp_basic.Or_ignore.Ignore) ~f:(fun id ->
              let%map hash_str =
                query_db pool ~item:"zkApp epoch ledger hash" ~f:(fun db ->
                    Processor.Snarked_ledger_hash.load db id)
              in
              Zkapp_basic.Or_ignore.Check
                (Frozen_ledger_hash.of_base58_check_exn hash_str))
        in
        let%map total_currency =
          total_currency_of_id epoch_ledger_data.total_currency_id
        in
        { Epoch_ledger.Poly.hash; total_currency }
      in
      let seed =
        Option.value_map epoch_data_raw.epoch_seed
          ~default:Zkapp_basic.Or_ignore.Ignore ~f:(fun s ->
            Zkapp_basic.Or_ignore.Check (Epoch_seed.of_base58_check_exn s))
      in
      let checkpoint_of_str str =
        Option.value_map str ~default:Zkapp_basic.Or_ignore.Ignore ~f:(fun s ->
            Zkapp_basic.Or_ignore.Check (State_hash.of_base58_check_exn s))
      in
      let start_checkpoint =
        checkpoint_of_str epoch_data_raw.start_checkpoint
      in
      let lock_checkpoint = checkpoint_of_str epoch_data_raw.lock_checkpoint in
      let%map epoch_length =
        length_bounds_of_id epoch_data_raw.epoch_length_id
      in
      { Zkapp_precondition.Protocol_state.Epoch_data.Poly.ledger
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
    let protocol_state_precondition : Zkapp_precondition.Protocol_state.t =
      { snarked_ledger_hash
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
    let%bind (account_precondition : Party.Account_precondition.t) =
      let%bind ({ kind; account_id; nonce }
                 : Processor.Zkapp_account_precondition.t) =
        query_db pool ~item:"account precondition" ~f:(fun db ->
            Processor.Zkapp_account_precondition.load db
              body_data.zkapp_account_precondition_id)
      in
      match kind with
      | Nonce -> (
          match nonce with
          | None ->
              failwith "Expected nonce for account precondition of kind Nonce"
          | Some nonce ->
              return
                (Party.Account_precondition.Nonce
                   (Mina_numbers.Account_nonce.of_uint32
                      (Unsigned.UInt32.of_int64 nonce))) )
      | Accept ->
          return Party.Account_precondition.Accept
      | Full ->
          assert (Option.is_some account_id) ;
          let%bind { balance_id
                   ; nonce_id
                   ; receipt_chain_hash
                   ; public_key_id
                   ; delegate_id
                   ; state_id
                   ; sequence_state_id
                   ; proved_state
                   } =
            query_db pool ~item:"precondition account" ~f:(fun db ->
                Processor.Zkapp_precondition_account.load db
                  (Option.value_exn account_id))
          in
          let%bind balance =
            let%map balance_opt =
              Option.value_map balance_id ~default:(return None) ~f:(fun id ->
                  let%map { balance_lower_bound; balance_upper_bound } =
                    query_db pool ~item:"balance bounds" ~f:(fun db ->
                        Processor.Zkapp_balance_bounds.load db id)
                  in
                  let balance_of_int64 int64 =
                    int64 |> Unsigned.UInt64.of_int64
                    |> Currency.Balance.of_uint64
                  in
                  let lower = balance_of_int64 balance_lower_bound in
                  let upper = balance_of_int64 balance_upper_bound in
                  Some
                    ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t))
            in
            Or_ignore.of_option balance_opt
          in
          let%bind nonce =
            let%map nonce_opt =
              Option.value_map nonce_id ~default:(return None) ~f:(fun id ->
                  let%map { nonce_lower_bound; nonce_upper_bound } =
                    query_db pool ~item:"nonce bounds" ~f:(fun db ->
                        Processor.Zkapp_nonce_bounds.load db id)
                  in
                  let balance_of_int64 int64 =
                    int64 |> Unsigned.UInt32.of_int64
                    |> Mina_numbers.Account_nonce.of_uint32
                  in
                  let lower = balance_of_int64 nonce_lower_bound in
                  let upper = balance_of_int64 nonce_upper_bound in
                  Some
                    ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t))
            in
            Or_ignore.of_option nonce_opt
          in
          let receipt_chain_hash =
            Option.map receipt_chain_hash
              ~f:Receipt.Chain_hash.of_base58_check_exn
            |> Or_ignore.of_option
          in
          let get_pk id =
            let%map pk_opt =
              Option.value_map id ~default:(return None) ~f:(fun id ->
                  let%map pk = pk_of_pk_id pool id in
                  Some pk)
            in
            Or_ignore.of_option pk_opt
          in
          let%bind public_key = get_pk public_key_id in
          let%bind delegate = get_pk delegate_id in
          let%bind state =
            let%bind field_ids =
              query_db pool ~item:"precondition account state" ~f:(fun db ->
                  Processor.Zkapp_states.load db state_id)
            in
            let%map fields =
              Deferred.List.map (Array.to_list field_ids) ~f:(fun id_opt ->
                  Option.value_map id_opt ~default:(return None) ~f:(fun id ->
                      let%map field_str =
                        query_db pool ~item:"precondition account state field"
                          ~f:(fun db -> Processor.Zkapp_state_data.load db id)
                      in
                      Some (Zkapp_basic.F.of_string field_str)))
            in
            List.map fields ~f:Or_ignore.of_option |> Zkapp_state.V.of_list_exn
          in
          let%bind sequence_state =
            let%map sequence_state_opt =
              Option.value_map sequence_state_id ~default:(return None)
                ~f:(fun id ->
                  let%map field_str =
                    query_db pool ~item:"precondition account sequence state"
                      ~f:(fun db -> Processor.Zkapp_state_data.load db id)
                  in
                  Some (Zkapp_basic.F.of_string field_str))
            in
            Or_ignore.of_option sequence_state_opt
          in
          let proved_state = Or_ignore.of_option proved_state in
          return
            (Party.Account_precondition.Full
               { balance
               ; nonce
               ; receipt_chain_hash
               ; public_key
               ; delegate
               ; state
               ; sequence_state
               ; proved_state
               })
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
        ; protocol_state_precondition
        ; account_precondition
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
    let fee_payer_account_precondition =
      match body.account_precondition with
      | Party.Account_precondition.Nonce n ->
          n
      | p ->
          failwith
            (sprintf
               "Expected Nonce for fee payer account precondition but received \
                %s"
               (Party.Account_precondition.to_yojson p |> Yojson.Safe.to_string))
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
      ; protocol_state_precondition = body.protocol_state_precondition
      ; account_precondition = fee_payer_account_precondition
      ; use_full_commitment = ()
      }
      : Party.Body.Fee_payer.t )
end

let parties_of_zkapp_command ~pool (cmd : Sql.Zkapp_command.t) :
    Parties.t Deferred.t =
  let%bind fee_payer_body_id =
    query_db pool
      ~f:(fun db -> Processor.Zkapp_fee_payers.load db cmd.fee_payer_id)
      ~item:"zkApp fee payer"
  in
  (* use dummy authorizations, memo *)
  let%bind (fee_payer : Party.Fee_payer.t) =
    let%bind (body : Party.Body.Fee_payer.t) =
      let%map raw_body =
        Archive_lib.Load_data.get_party_body ~pool fee_payer_body_id
      in
      Party.Body.to_fee_payer_exn raw_body
    in
    return ({ body; authorization = Signature.dummy } : Party.Fee_payer.t)
  in
  let%bind (other_parties : Party.t list) =
    Deferred.List.map (Array.to_list cmd.other_party_ids) ~f:(fun id ->
        let%map body = Archive_lib.Load_data.get_party_body ~pool id in
        let authorization = Control.None_given in
        ({ body; authorization } : Party.t))
  in
  let memo = Mina_base.Signed_command_memo.dummy in
  return ({ fee_payer; other_parties; memo } : Parties.t)

let run_zkapp_command ~logger ~pool ~ledger ~continue_on_error:_
    (cmd : Sql.Zkapp_command.t) =
  [%log info]
    "Applying zkApp command at global slot since genesis %Ld, and sequence \
     number %d"
    cmd.global_slot_since_genesis cmd.sequence_no ;
  let%bind state_view =
    Zkapp_helpers.get_parent_state_view ~pool cmd.block_id
  in
  let%bind parties = parties_of_zkapp_command ~pool cmd in
  match
    Ledger.apply_parties_unchecked ~constraint_constants ~state_view ledger
      parties
  with
  | Ok _ ->
      Deferred.unit
  | Error err ->
      Error.tag_arg err "zkApp command failed on replay"
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

let main ~input_file ~output_file_opt ~archive_uri ~continue_on_error () =
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
            (fun db ->
              Command_ids.run db ~state_hash:target_state_hash
                ~start_slot:input.start_slot_since_genesis)
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
      [%log info] "Loading zkApp command ids" ;
      let%bind zkapp_cmd_ids =
        get_command_ids (module Sql.Zkapp_command_ids) "zkApp"
      in
      [%log info]
        "Obtained %d user command ids, %d internal command ids, and %d zkApp \
         command ids"
        (List.length user_cmd_ids)
        (List.length internal_cmd_ids)
        (List.length zkapp_cmd_ids) ;
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
      (* filter out internal commands in blocks not along chain from target state hash *)
      let filtered_internal_cmds =
        List.filter unsorted_internal_cmds ~f:(fun cmd ->
            Int.Set.mem block_ids cmd.block_id)
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
      (* filter out user commands in blocks not along chain from target state hash *)
      let filtered_user_cmds =
        List.filter unsorted_user_cmds ~f:(fun cmd ->
            Int.Set.mem block_ids cmd.block_id)
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
      [%log info] "Loading zkApp commands" ;
      let%bind unsorted_zkapp_cmds_list =
        Deferred.List.map zkapp_cmd_ids ~f:(fun id ->
            let open Deferred.Let_syntax in
            match%map
              Caqti_async.Pool.use (fun db -> Sql.Zkapp_command.run db id) pool
            with
            | Ok [] ->
                failwithf "Expected at least one zkApp command with id %d" id ()
            | Ok zkapp_cmds ->
                zkapp_cmds
            | Error msg ->
                failwithf
                  "Error querying for zkApp commands with id %d, error %s" id
                  (Caqti_error.show msg) ())
      in
      let unsorted_zkapp_cmds = List.concat unsorted_zkapp_cmds_list in
      let filtered_zkapp_cmds =
        List.filter unsorted_zkapp_cmds ~f:(fun (cmd : Sql.Zkapp_command.t) ->
            Int64.( >= ) cmd.global_slot_since_genesis
              input.start_slot_since_genesis
            && Int.Set.mem block_ids cmd.block_id)
      in
      let sorted_zkapp_cmds =
        List.sort filtered_zkapp_cmds ~compare:(fun sc1 sc2 ->
            let tuple (sc : Sql.Zkapp_command.t) =
              (sc.global_slot_since_genesis, sc.sequence_no)
            in
            [%compare: int64 * int] (tuple sc1) (tuple sc2))
      in
      (* apply commands in global slot, sequence order *)
      let rec apply_commands (internal_cmds : Sql.Internal_command.t list)
          (user_cmds : Sql.User_command.t list)
          (zkapp_cmds : Sql.Zkapp_command.t list)
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
        let check_ledger_hash_after_last_slot () =
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
        let check_account_accessed () =
          let%bind accounts_accessed_db =
            query_db ~item:"accounts accessed"
              ~f:(fun db ->
                Processor.Accounts_accessed.all_from_block db last_block_id)
              pool
          in
          let%map accounts_accessed =
            Deferred.List.map accounts_accessed_db
              ~f:(Archive_lib.Load_data.get_account_accessed ~pool)
          in
          List.iter accounts_accessed
            ~f:(fun (index, { public_key; token_id; balance; nonce; _ }) ->
              let account_id = Account_id.create public_key token_id in
              let index_in_ledger =
                Ledger.index_of_account_exn ledger account_id
              in
              if index <> index_in_ledger then (
                [%log error]
                  "Index in ledger does not match index in account accessed"
                  ~metadata:
                    [ ("index_in_ledger", `Int index_in_ledger)
                    ; ("index_in_account_accessed", `Int index)
                    ] ;
                if continue_on_error then incr error_count
                else Core_kernel.exit 1 ) ;
              match Ledger.location_of_account ledger account_id with
              | None ->
                  [%log error]
                    "After applying all commands at global slot since genesis \
                     %Ld, accessed account not in ledger"
                    last_global_slot_since_genesis ;
                  if continue_on_error then incr error_count
                  else Core_kernel.exit 1
              | Some loc ->
                  let account_in_ledger =
                    match Ledger.get ledger loc with
                    | Some acct ->
                        acct
                    | None ->
                        (* should be unreachable *)
                        failwith
                          "Account not in ledger, even though there's a \
                           location for it"
                  in
                  let balance_in_ledger = account_in_ledger.balance in
                  if not (Currency.Balance.equal balance balance_in_ledger) then (
                    [%log error]
                      "Balance in ledger does not match balance in account \
                       accessed"
                      ~metadata:
                        [ ( "balance_in_ledger"
                          , Currency.Balance.to_yojson balance_in_ledger )
                        ; ( "balance_in_account_accessed"
                          , Currency.Balance.to_yojson balance )
                        ] ;
                    if continue_on_error then incr error_count
                    else Core_kernel.exit 1 ) ;
                  let nonce_in_ledger = account_in_ledger.nonce in
                  if
                    not (Mina_numbers.Account_nonce.equal nonce nonce_in_ledger)
                  then (
                    [%log error]
                      "Nonce in ledger does not match nonce in account accessed"
                      ~metadata:
                        [ ( "balance_in_ledger"
                          , Mina_numbers.Account_nonce.to_yojson nonce_in_ledger
                          )
                        ; ( "balance_in_account_accessed"
                          , Mina_numbers.Account_nonce.to_yojson nonce )
                        ] ;
                    if continue_on_error then incr error_count
                    else Core_kernel.exit 1 ))
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
        let run_checks_on_slot_change curr_global_slot_since_genesis =
          if
            Int64.( > ) curr_global_slot_since_genesis
              last_global_slot_since_genesis
          then (
            check_ledger_hash_after_last_slot () ;
            let%map () = check_account_accessed () in
            log_state_hash_on_next_slot curr_global_slot_since_genesis )
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
                run_checks_on_slot_change ic.global_slot_since_genesis
              in
              let%bind () =
                apply_combined_fee_transfer ~logger ~pool ~ledger
                  ~continue_on_error ic ic2
              in
              apply_commands ics2 user_cmds zkapp_cmds
                ~last_global_slot_since_genesis:ic.global_slot_since_genesis
                ~last_block_id:ic.block_id ~staking_epoch_ledger
                ~next_epoch_ledger
          | _ ->
              let%bind () =
                run_checks_on_slot_change ic.global_slot_since_genesis
              in
              let%bind () =
                run_internal_command ~logger ~pool ~ledger ~continue_on_error ic
              in
              apply_commands ics user_cmds zkapp_cmds
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
        let get_zkapp_cmd_sequence (sc : Sql.Zkapp_command.t) =
          (`Zkapp_command, sc.global_slot_since_genesis, sc.sequence_no)
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
          let%bind () =
            run_checks_on_slot_change uc.global_slot_since_genesis
          in
          let%bind () =
            run_user_command ~logger ~pool ~ledger ~continue_on_error uc
          in
          apply_commands internal_cmds ucs zkapp_cmds
            ~last_global_slot_since_genesis:uc.global_slot_since_genesis
            ~last_block_id:uc.block_id ~staking_epoch_ledger ~next_epoch_ledger
        in
        let run_zkapp_commands (sc : Sql.Zkapp_command.t) scs =
          let%bind () =
            run_checks_on_slot_change sc.global_slot_since_genesis
          in
          let%bind () =
            run_zkapp_command ~logger ~pool ~ledger ~continue_on_error sc
          in
          apply_commands internal_cmds user_cmds scs
            ~last_global_slot_since_genesis:sc.global_slot_since_genesis
            ~last_block_id:sc.block_id ~staking_epoch_ledger ~next_epoch_ledger
        in
        match (internal_cmds, user_cmds, zkapp_cmds) with
        | [], [], [] ->
            (* all done *)
            check_ledger_hash_after_last_slot () ;
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
            (* only zkApp commands *)
            run_zkapp_commands sc scs
        | [], uc :: ucs, sc :: scs -> (
            (* no internal commands *)
            let seqs =
              [ get_user_cmd_sequence uc; get_zkapp_cmd_sequence sc ]
            in
            match command_type_of_sequences seqs with
            | `User_command ->
                run_user_commands uc ucs
            | `Zkapp_command ->
                run_zkapp_commands sc scs )
        | ic :: ics, [], sc :: scs -> (
            (* no user commands *)
            let seqs =
              [ get_internal_cmd_sequence ic; get_zkapp_cmd_sequence sc ]
            in
            match command_type_of_sequences seqs with
            | `Internal_command ->
                combine_or_run_internal_cmds ic ics
            | `Zkapp_command ->
                run_zkapp_commands sc scs )
        | ic :: ics, uc :: ucs, [] -> (
            (* no zkApp commands *)
            let seqs =
              [ get_internal_cmd_sequence ic; get_user_cmd_sequence uc ]
            in
            match command_type_of_sequences seqs with
            | `Internal_command ->
                combine_or_run_internal_cmds ic ics
            | `User_command ->
                run_user_commands uc ucs )
        | ic :: ics, uc :: ucs, sc :: scs -> (
            (* internal, user, and zkApp commands *)
            let seqs =
              [ get_internal_cmd_sequence ic
              ; get_user_cmd_sequence uc
              ; get_zkapp_cmd_sequence sc
              ]
            in
            match command_type_of_sequences seqs with
            | `Internal_command ->
                combine_or_run_internal_cmds ic ics
            | `User_command ->
                let%bind () =
                  run_checks_on_slot_change uc.global_slot_since_genesis
                in
                let%bind () =
                  run_user_command ~logger ~pool ~ledger ~continue_on_error uc
                in
                apply_commands internal_cmds ucs scs
                  ~last_global_slot_since_genesis:uc.global_slot_since_genesis
                  ~last_block_id:uc.block_id ~staking_epoch_ledger
                  ~next_epoch_ledger
            | `Zkapp_command ->
                let%bind () =
                  run_zkapp_command ~logger ~pool ~ledger ~continue_on_error sc
                in
                apply_commands internal_cmds ucs scs
                  ~last_global_slot_since_genesis:uc.global_slot_since_genesis
                  ~last_block_id:uc.block_id ~staking_epoch_ledger
                  ~next_epoch_ledger )
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
        apply_commands sorted_internal_cmds sorted_user_cmds sorted_zkapp_cmds
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
      Command.async ~summary:"Replay transactions from Mina archive database"
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
         and continue_on_error =
           Param.flag "--continue-on-error"
             ~doc:"Continue processing after errors" Param.no_arg
         in
         main ~input_file ~output_file_opt ~archive_uri ~continue_on_error)))
