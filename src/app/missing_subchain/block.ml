(* block.ml -- block for json output *)

open Core_kernel
open Mina_base
open Signature_lib
open Archive_lib

(* like With_status, but with an option
   why? the archive db has a NULLable column for user command status
*)
module With_opt_status = struct
  type 'a t = {data: 'a; status: Transaction_status.t option}
  [@@deriving yojson]
end

type curr_global_slot = {slot_number: Mina_numbers.Global_slot.t}
[@@deriving yojson]

type epoch_ledger_hash = {hash: Frozen_ledger_hash.t} [@@deriving yojson]

type epoch_data = {ledger: epoch_ledger_hash; seed: Epoch_seed.t}
[@@deriving yojson]

type non_snark = {ledger_hash: Ledger_hash.t} [@@deriving yojson]

type staged_ledger_hash = {non_snark: non_snark} [@@deriving yojson]

type blockchain_state =
  {staged_ledger_hash: staged_ledger_hash; timestamp: Block_time.t}
[@@deriving yojson]

type consensus_state =
  { curr_global_slot: curr_global_slot
  ; global_slot_since_genesis: Mina_numbers.Global_slot.t
  ; staking_epoch_data: epoch_data
  ; next_epoch_data: epoch_data
  ; block_stake_winner: Public_key.Compressed.t
  ; block_creator: Public_key.Compressed.t }
[@@deriving yojson]

type protocol_state_body =
  {blockchain_state: blockchain_state; consensus_state: consensus_state}
[@@deriving yojson]

type protocol_state = {body: protocol_state_body} [@@deriving yojson]

type user_cmd_common =
  { fee: Currency.Fee.t
  ; fee_token: Token_id.t
  ; fee_payer_pk: Public_key.Compressed.t
  ; nonce: Account.Nonce.t
  ; valid_until: Mina_numbers.Global_slot.t option
  ; memo: Signed_command_memo.t }
[@@deriving yojson]

type user_cmd_body_payload =
  { source_pk: Public_key.Compressed.t
  ; receiver_pk: Public_key.Compressed.t
  ; token_id: Token_id.t
  ; amount: Currency.Amount.t option }
[@@deriving yojson]

type user_cmd_body =
  | Payment of user_cmd_body_payload
  | Stake_delegation of user_cmd_body_payload
  | Create_new_token of user_cmd_body_payload
  | Create_token_account of user_cmd_body_payload
  | Mint_tokens of user_cmd_body_payload
[@@deriving yojson]

type payload = {common: user_cmd_common; body: user_cmd_body}
[@@deriving yojson]

(* TODO: add Snapps *)
type command = Signed_command of {payload: payload} [@@deriving yojson]

type diff_commands =
  { commands: command With_opt_status.t list
  ; internal_command_balances:
      Transaction_status.Internal_command_balance_data.t list }
[@@deriving yojson]

type staged_ledger_diff = {diff: diff_commands} [@@deriving yojson]

(* essentially External_transition.t with some fields missing
   and state_hash added
*)

type t =
  { state_hash: State_hash.t
  ; protocol_state: protocol_state
  ; staged_ledger_diff: staged_ledger_diff }
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

let blockchain_state_of_extensional_block (block : Extensional.Block.t) =
  { staged_ledger_hash= {non_snark= {ledger_hash= block.ledger_hash}}
  ; timestamp= block.timestamp }

let mk_global_slot slot_number = {slot_number}

let mk_ledger hash = {hash}

let mk_epoch_data seed hash = {ledger= mk_ledger hash; seed}

let consensus_state_of_extensional_block (block : Extensional.Block.t) :
    consensus_state =
  { curr_global_slot= mk_global_slot block.global_slot
  ; global_slot_since_genesis= block.global_slot_since_genesis
  ; staking_epoch_data=
      mk_epoch_data block.staking_epoch_seed block.staking_epoch_ledger_hash
  ; next_epoch_data=
      mk_epoch_data block.next_epoch_seed block.next_epoch_ledger_hash
  ; block_stake_winner= block.block_winner
  ; block_creator= block.creator }

let protocol_state_body_of_extensional_block (block : Extensional.Block.t) =
  let blockchain_state = blockchain_state_of_extensional_block block in
  let consensus_state = consensus_state_of_extensional_block block in
  {blockchain_state; consensus_state}

let protocol_state_of_extensional_block block =
  {body= protocol_state_body_of_extensional_block block}

let common_of_user_cmd (user_cmd : Extensional.User_command.t) =
  { fee= user_cmd.fee
  ; fee_token= user_cmd.fee_token
  ; fee_payer_pk= user_cmd.fee_payer
  ; nonce= user_cmd.nonce
  ; valid_until= user_cmd.valid_until
  ; memo= user_cmd.memo }

let body_of_user_cmd (user_cmd : Extensional.User_command.t) =
  let payload =
    { source_pk= user_cmd.source
    ; receiver_pk= user_cmd.receiver
    ; token_id= user_cmd.token
    ; amount= user_cmd.amount }
  in
  match user_cmd.typ with
  | "payment" ->
      Payment payload
  | "delegation" ->
      Stake_delegation payload
  | "create_token" ->
      Create_new_token payload
  | "create_account" ->
      Create_token_account payload
  | "mint_tokens" ->
      Mint_tokens payload
  | cmd ->
      failwithf "Unknown user command \"%s\"" cmd ()

let payload_of_user_cmd user_cmd =
  {common= common_of_user_cmd user_cmd; body= body_of_user_cmd user_cmd}

let status_of_user_cmd (user_cmd : Extensional.User_command.t) =
  let open Transaction_status in
  let balance_data =
    { Balance_data.fee_payer_balance= Some user_cmd.fee_payer_balance
    ; source_balance= user_cmd.source_balance
    ; receiver_balance= user_cmd.receiver_balance }
  in
  match user_cmd.status with
  | "applied" ->
      Some
        (Applied
           ( { fee_payer_account_creation_fee_paid=
                 user_cmd.fee_payer_account_creation_fee_paid
             ; receiver_account_creation_fee_paid=
                 user_cmd.receiver_account_creation_fee_paid
             ; created_token= user_cmd.created_token }
           , balance_data ))
  | "failed" -> (
    match user_cmd.failure_reason with
    | Some reason ->
        Some (Failed (reason, balance_data))
    | None ->
        failwith "Failed user command status, no reason given" )
  | s ->
      failwithf "Unexpected user command status \"%s\"" s ()

let signed_cmd_with_status_of_user_cmd (user_cmd : Extensional.User_command.t)
    =
  { With_opt_status.data= Signed_command {payload= payload_of_user_cmd user_cmd}
  ; status= status_of_user_cmd user_cmd }

let user_commands_of_extensional_block user_cmds_tbl
    (block : Extensional.Block.t) =
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

let diff_commands_of_extensional_block user_cmds_tbl internal_cmds_tbl block =
  { commands= user_commands_of_extensional_block user_cmds_tbl block
  ; internal_command_balances=
      List.filter_opt
        (internal_commands_of_extensional_block internal_cmds_tbl block) }

let staged_ledger_diff_of_extensional_block user_cmds_tbl internal_cmds_tbl
    block =
  { diff=
      diff_commands_of_extensional_block user_cmds_tbl internal_cmds_tbl block
  }

let block_of_extensional_block user_cmds_tbl internal_cmds_tbl
    (block : Extensional.Block.t) : t =
  let state_hash = block.state_hash in
  let protocol_state = protocol_state_of_extensional_block block in
  let staged_ledger_diff =
    staged_ledger_diff_of_extensional_block user_cmds_tbl internal_cmds_tbl
      block
  in
  {state_hash; protocol_state; staged_ledger_diff}
