(* extensional.ml -- extensional representations of archive db data *)

open Mina_base
open Signature_lib

(* the tables in the archive db uses foreign keys to refer to other
   tables; the types here fills in the data from those other tables, using
   their native OCaml types to assure the validity of the data
*)

module User_command = struct
  (* for `typ` and `status`, a string is enough
     in any case, there aren't existing string conversions for the
     original OCaml types
  *)
  type t =
    { sequence_no: int
    ; typ: string
    ; fee_payer: Public_key.Compressed.t
    ; source: Public_key.Compressed.t
    ; receiver: Public_key.Compressed.t
    ; fee_token: Token_id.t
    ; token: Token_id.t
    ; nonce: Account.Nonce.t
    ; amount: Currency.Amount.t option
    ; fee: Currency.Fee.t
    ; valid_until: Mina_numbers.Global_slot.t option
    ; memo: Signed_command_memo.t
    ; hash: Transaction_hash.t
    ; status: string option
    ; failure_reason: Transaction_status.Failure.t option
    ; fee_payer_account_creation_fee_paid: Currency.Amount.t option
    ; receiver_account_creation_fee_paid: Currency.Amount.t option
    ; created_token: Token_id.t option }
  [@@deriving yojson]
end

module Internal_command = struct
  (* for `typ`, a string is enough
     no existing string conversion for the original OCaml type
  *)
  type t =
    { global_slot: int64
    ; sequence_no: int
    ; secondary_sequence_no: int
    ; typ: string
    ; receiver: Public_key.Compressed.t
    ; fee: Currency.Amount.t
    ; token: Token_id.t
    ; hash: Transaction_hash.t }
  [@@deriving yojson]
end

module Block = struct
  type t =
    { state_hash: State_hash.t
    ; parent_hash: State_hash.t
    ; creator: Public_key.Compressed.t
    ; block_winner: Public_key.Compressed.t
    ; snarked_ledger_hash: Frozen_ledger_hash.t
    ; staking_epoch_seed: Epoch_seed.t
    ; staking_epoch_ledger_hash: Frozen_ledger_hash.t
    ; next_epoch_seed: Epoch_seed.t
    ; next_epoch_ledger_hash: Frozen_ledger_hash.t
    ; ledger_hash: Ledger_hash.t
    ; height: Unsigned_extended.UInt32.t
    ; global_slot: Mina_numbers.Global_slot.t
    ; global_slot_since_genesis: Mina_numbers.Global_slot.t
    ; timestamp: Block_time.t
    ; user_cmds: User_command.t list
    ; internal_cmds: Internal_command.t list }
  [@@deriving yojson]
end
