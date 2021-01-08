(* block.ml -- block for json output *)

(* use dummy values where the archive db does not have corresponding data
   these values are marked DUMMY in comments below
*)

open Core_kernel
open Mina_base
open Signature_lib
open Archive_lib

type t = Mina_transition.External_transition.Precomputed_block.t
[@@deriving yojson]

module Fee_transfer_via_coinbase = struct
  (* table of fee transfer via coinbase at given global slot, seq no, secondary seq no *)
  module T = struct
    type t = int64 * int * int
    [@@deriving bin_io_unversioned, hash, compare, sexp]
  end

  include T
  include Hashable.Make_binable (T)
end

let fee_transfer_tbl :
    Extensional.Internal_command.t Fee_transfer_via_coinbase.Table.t =
  Fee_transfer_via_coinbase.Table.create ()

let dummy_coinbase = Or_error.ok_exn @@ Pending_coinbase.create ~depth:6 ()

let staged_ledger_hash_of_extensional_block (block : Extensional.Block.t) =
  let aux_hash = Staged_ledger_hash.Aux_hash.dummy (* DUMMY *) in
  let ledger_hash = block.ledger_hash in
  let coinbase = dummy_coinbase (* DUMMY *) in
  Staged_ledger_hash.of_aux_ledger_and_coinbase_hash aux_hash ledger_hash
    coinbase

let blockchain_state_of_extensional_block (block : Extensional.Block.t) =
  let staged_ledger_hash = staged_ledger_hash_of_extensional_block block in
  let snarked_ledger_hash = Frozen_ledger_hash.empty_hash (* DUMMY *) in
  let genesis_ledger_hash = Frozen_ledger_hash.empty_hash (* DUMMY *) in
  let snarked_next_available_token = Token_id.default (* DUMMY *) in
  let timestamp = block.timestamp in
  Mina_state.Blockchain_state.create_value ~staged_ledger_hash
    ~snarked_ledger_hash ~genesis_ledger_hash ~snarked_next_available_token
    ~timestamp

let mk_ledger hash : Mina_base.Epoch_ledger.Value.t =
  (* hash is valid; total_currency is a DUMMY *)
  {hash; total_currency= Currency.Amount.zero}

let mk_epoch_data seed hash : Mina_base.Epoch_data.Value.t =
  { Mina_base.Epoch_data.Poly.ledger= mk_ledger hash
  ; seed
  ; start_checkpoint= State_hash.dummy (* DUMMY *)
  ; lock_checkpoint= State_hash.dummy (* DUMMY *)
  ; epoch_length= Mina_numbers.Length.zero (* DUMMY *) }

let consensus_constants = Lazy.force Consensus.Constants.for_unit_tests

let consensus_state_of_extensional_block (block : Extensional.Block.t) :
    Consensus.Data.Consensus_state.Value.t =
  let blockchain_length = Mina_numbers.Length.zero (* DUMMY *) in
  let epoch_count = Mina_numbers.Length.zero (* DUMMY *) in
  let min_window_density = Mina_numbers.Length.zero (* DUMMY *) in
  let sub_window_densities = [] (* DUMMY *) in
  let last_vrf_output = "" (* DUMMY *) in
  let total_currency = Currency.Amount.zero (* DUMMY *) in
  (* the slot number is valid, the constants are a DUMMY *)
  let curr_global_slot =
    Consensus.Proof_of_stake.Exported.Global_slot.create_with_slot_number
      ~constants:consensus_constants ~slot_number:block.global_slot
  in
  let global_slot_since_genesis = block.global_slot_since_genesis in
  let staking_epoch_data =
    mk_epoch_data block.staking_epoch_seed block.staking_epoch_ledger_hash
  in
  let next_epoch_data =
    mk_epoch_data block.next_epoch_seed block.next_epoch_ledger_hash
  in
  let has_ancestor_in_same_checkpoint_window = false (* DUMMY *) in
  let block_stake_winner = block.block_winner in
  let block_creator = block.creator in
  let coinbase_receiver = Public_key.Compressed.empty (* DUMMY *) in
  let supercharge_coinbase = false (* DUMMY *) in
  Consensus.Proof_of_stake.Exported.Consensus_state.Unsafe.create_value
    `I_have_an_excellent_reason_to_call_this ~blockchain_length ~epoch_count
    ~min_window_density ~sub_window_densities ~last_vrf_output ~total_currency
    ~curr_global_slot ~global_slot_since_genesis ~staking_epoch_data
    ~next_epoch_data ~has_ancestor_in_same_checkpoint_window
    ~block_stake_winner ~block_creator ~coinbase_receiver ~supercharge_coinbase

let protocol_state_of_extensional_block block : Mina_state.Protocol_state.value
    =
  let previous_state_hash = State_hash.dummy (* DUMMY *) in
  let genesis_state_hash = State_hash.dummy (* DUMMY *) in
  let blockchain_state = blockchain_state_of_extensional_block block in
  let consensus_state = consensus_state_of_extensional_block block in
  let constants =
    Genesis_constants.compiled.protocol
    |> Protocol_constants_checked.value_of_t
  in
  Mina_state.Protocol_state.create_value ~previous_state_hash
    ~genesis_state_hash ~blockchain_state ~consensus_state ~constants

let body_of_user_cmd (user_cmd : Extensional.User_command.t) :
    Signed_command_payload.Body.t =
  match user_cmd.typ with
  | "payment" ->
      if Option.is_none user_cmd.amount then
        failwithf
          "Payment user command has a NULL amount; block state hash=%s, \
           sequence no=%d"
          (State_hash.to_string user_cmd.block_state_hash)
          user_cmd.sequence_no () ;
      let payload =
        { Payment_payload.Poly.source_pk= user_cmd.source
        ; receiver_pk= user_cmd.receiver
        ; token_id= user_cmd.token
        ; amount= Option.value_exn user_cmd.amount }
      in
      Payment payload
  | "delegation" ->
      let payload =
        Stake_delegation.Set_delegate
          {delegator= user_cmd.source; new_delegate= user_cmd.receiver}
      in
      Stake_delegation payload
  | "create_token" ->
      let payload =
        { New_token_payload.token_owner_pk= user_cmd.source
        ; disable_new_accounts= false (* DUMMY *) }
      in
      Create_new_token payload
  | "create_account" ->
      let payload =
        { New_account_payload.token_id= user_cmd.token
        ; token_owner_pk= user_cmd.source
        ; receiver_pk= user_cmd.receiver
        ; account_disabled= false (* DUMMY *) }
      in
      Create_token_account payload
  | "mint_tokens" ->
      if Option.is_none user_cmd.amount then
        failwithf
          "Mint_tokens user command has a NULL amount; block state hash=%s, \
           sequence no=%d"
          (State_hash.to_string user_cmd.block_state_hash)
          user_cmd.sequence_no () ;
      let payload =
        { Minting_payload.token_id= user_cmd.token
        ; token_owner_pk= user_cmd.source
        ; receiver_pk= user_cmd.receiver
        ; amount= Option.value_exn user_cmd.amount }
      in
      Mint_tokens payload
  | cmd ->
      failwithf "Unknown user command \"%s\"" cmd ()

let payload_of_user_cmd (user_cmd : Extensional.User_command.t) :
    Signed_command_payload.t =
  let fee = user_cmd.fee in
  let fee_token = user_cmd.fee_token in
  let fee_payer_pk = user_cmd.fee_payer in
  let nonce = user_cmd.nonce in
  let valid_until = user_cmd.valid_until in
  let memo = user_cmd.memo in
  Signed_command_payload.create ~fee ~fee_token ~fee_payer_pk ~nonce
    ~valid_until ~memo
    ~body:(body_of_user_cmd user_cmd)

let status_of_user_cmd (user_cmd : Extensional.User_command.t) =
  let open Transaction_status in
  (* TODO: use actual balance data instead of dummy value *)
  match user_cmd.status with
  | Some "applied" ->
      Applied
        ( { fee_payer_account_creation_fee_paid=
              user_cmd.fee_payer_account_creation_fee_paid
          ; receiver_account_creation_fee_paid=
              user_cmd.receiver_account_creation_fee_paid
          ; created_token= user_cmd.created_token }
        , Balance_data.empty )
  | Some "failed" -> (
    match user_cmd.failure_reason with
    | Some reason ->
        Failed (reason, Balance_data.empty)
    | None ->
        failwith "Failed user command status, no reason given" )
  | Some s ->
      failwithf "Unexpected user command status \"%s\"" s ()
  | None ->
      (* REVIEWER: is failure here reasonable?
       the status is NULLable in the archive db; should we expect NULLs, in fact?
    *)
      failwithf
        "User command is missing status; block state hash=%s, sequence no=%d"
        (State_hash.to_string user_cmd.block_state_hash)
        user_cmd.sequence_no ()

let dummy_signer = Quickcheck.random_value Public_key.gen

let signed_cmd_with_status_of_user_cmd (user_cmd : Extensional.User_command.t)
    : User_command.t With_status.t =
  { With_status.data=
      Signed_command
        { payload= payload_of_user_cmd user_cmd
        ; signer= dummy_signer (* DUMMY *)
        ; signature= Signature.dummy (* DUMMY *) }
  ; status= status_of_user_cmd user_cmd }

let user_commands_of_extensional_block user_cmds_tbl
    (block : Extensional.Block.t) : User_command.t With_status.t list =
  let user_cmds = State_hash.Table.find_exn user_cmds_tbl block.state_hash in
  List.map user_cmds ~f:signed_cmd_with_status_of_user_cmd

let internal_cmd_balance_data_of_internal_cmd
    (internal_cmd : Extensional.Internal_command.t) =
  let open Transaction_status.Internal_command_balance_data in
  match internal_cmd.typ with
  | "coinbase" ->
      (* TODO: add fee transfer via coinbase here, when balances available
         use Fee_transfer_via_coinbase.Table.find on global slot, seq no, secondary seq no
      *)
      (* TODO: add valid balances when they're available in archive db *)
      Some
        (Coinbase
           { coinbase_receiver_balance= Currency.Balance.zero
           ; fee_transfer_receiver_balance= None })
  | "fee_transfer" ->
      (* TODO: add valid balances when they're available in archive db *)
      Some
        (Fee_transfer
           {receiver1_balance= Currency.Balance.zero; receiver2_balance= None})
  | "fee_transfer_via_coinbase" ->
      (* these are combined into a coinbase *)
      None
  | cmd ->
      failwithf "Unknown internal command: %s" cmd ()

let internal_commands_of_extensional_block internal_cmds_tbl
    (block : Extensional.Block.t) =
  let internal_cmds =
    State_hash.Table.find_exn internal_cmds_tbl block.state_hash
  in
  List.map internal_cmds ~f:internal_cmd_balance_data_of_internal_cmd

let diff_commands_of_extensional_block user_cmds_tbl internal_cmds_tbl block :
    Staged_ledger_diff.Diff.t =
  let prediff_with_at_most_two_coinbase =
    { Staged_ledger_diff.Pre_diff_two.completed_works= [] (* DUMMY *)
    ; commands= user_commands_of_extensional_block user_cmds_tbl block
    ; coinbase= Zero (* DUMMY *)
    ; internal_command_balances=
        List.filter_opt
          (internal_commands_of_extensional_block internal_cmds_tbl block) }
    (* REVIEWER: does it make sense to put all the commands in the at-most-two part? *)
  in
  (prediff_with_at_most_two_coinbase, None)

let staged_ledger_diff_of_extensional_block user_cmds_tbl internal_cmds_tbl
    block : Staged_ledger_diff.t =
  { diff=
      diff_commands_of_extensional_block user_cmds_tbl internal_cmds_tbl block
  }

let precomputed_block_of_extensional_block user_cmds_tbl internal_cmds_tbl
    (block : Extensional.Block.t) : t =
  let scheduled_time = Block_time.zero (* DUMMY *) in
  let protocol_state = protocol_state_of_extensional_block block in
  let protocol_state_proof = Mina_base.Proof.blockchain_dummy (* DUMMY *) in
  let staged_ledger_diff =
    staged_ledger_diff_of_extensional_block user_cmds_tbl internal_cmds_tbl
      block
  in
  let delta_transition_chain_proof =
    (Frozen_ledger_hash.empty_hash, [])
    (* DUMMY *)
  in
  { scheduled_time
  ; protocol_state
  ; protocol_state_proof
  ; staged_ledger_diff
  ; delta_transition_chain_proof }
