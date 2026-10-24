(** The archive's own representation of a block: the rows of the archive
    database with every foreign key resolved to the value it points to.

    This is the query of [Send_extensional_block] (see {!Rpc.extensional_block})
    and the JSON written by [mina-extract-blocks] and read by
    [mina-archive-blocks --extensional], which is how blocks move from one
    archive to another. Unlike {!Diff}, these types are versioned. *)

open Mina_base
open Mina_transaction
open Signature_lib

(** A signed command (payment or stake delegation) of a block. *)
module User_command : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V2 : sig
      type t =
        { sequence_no : int  (** Position among the block's commands. *)
        ; command_type : Mina_stdlib.Bounded_types.String.Stable.V1.t
              (** ["payment"] or ["delegation"]. *)
        ; fee_payer : Public_key.Compressed.Stable.V1.t
        ; source : Public_key.Compressed.Stable.V1.t
        ; receiver : Public_key.Compressed.Stable.V1.t
        ; nonce : Account.Nonce.Stable.V1.t
        ; amount : Currency.Amount.Stable.V1.t option
        ; fee : Currency.Fee.Stable.V1.t
        ; valid_until :
            Mina_numbers.Global_slot_since_genesis.Stable.V1.t option
        ; memo : Signed_command_memo.Stable.V1.t
        ; hash : Transaction_hash.Stable.V1.t
        ; status : Mina_stdlib.Bounded_types.String.Stable.V1.t
              (** ["applied"] or ["failed"]. *)
        ; failure_reason : Transaction_status.Failure.Stable.V2.t option
        }
      [@@deriving yojson, equal]
    end
  end]

  type t = Stable.Latest.t =
    { sequence_no : int
    ; command_type : string
    ; fee_payer : Public_key.Compressed.t
    ; source : Public_key.Compressed.t
    ; receiver : Public_key.Compressed.t
    ; nonce : Account.Nonce.t
    ; amount : Currency.Amount.t option
    ; fee : Currency.Fee.t
    ; valid_until : Mina_numbers.Global_slot_since_genesis.t option
    ; memo : Signed_command_memo.t
    ; hash : Transaction_hash.t
    ; status : string
    ; failure_reason : Transaction_status.Failure.t option
    }
  [@@deriving yojson, equal]

  (** The fee payer's and the receiver's default-token accounts. *)
  val accounts_referenced : t -> Account_id.t list
end

(** A fee transfer or coinbase of a block. *)
module Internal_command : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V2 : sig
      type t =
        { sequence_no : int
        ; secondary_sequence_no : int
              (** Orders the parts of a command that has several. *)
        ; command_type : Mina_stdlib.Bounded_types.String.Stable.V1.t
              (** ["fee_transfer"], ["fee_transfer_via_coinbase"] or
                  ["coinbase"]. *)
        ; receiver : Public_key.Compressed.Stable.V1.t
        ; fee : Currency.Fee.Stable.V1.t
        ; hash : Transaction_hash.Stable.V1.t
        ; status : Mina_stdlib.Bounded_types.String.Stable.V1.t
        ; failure_reason : Transaction_status.Failure.Stable.V2.t option
        }
      [@@deriving yojson, equal]
    end
  end]

  type t = Stable.Latest.t =
    { sequence_no : int
    ; secondary_sequence_no : int
    ; command_type : string
    ; receiver : Public_key.Compressed.t
    ; fee : Currency.Fee.t
    ; hash : Transaction_hash.t
    ; status : string
    ; failure_reason : Transaction_status.Failure.t option
    }
  [@@deriving yojson, equal]

  (** The receiver's default-token account. *)
  val account_referenced : t -> Account_id.t
end

(** A zkApp command of a block. Authorizations (signatures, proofs) are not
    kept by the archive and so are not here. *)
module Zkapp_command : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V2 : sig
      type t =
        { sequence_no : int
        ; fee_payer : Account_update.Body.Fee_payer.Stable.V1.t
        ; account_updates : Account_update.Body.Simple.Stable.V2.t list
        ; memo : Signed_command_memo.Stable.V1.t
        ; hash : Transaction_hash.Stable.V1.t
        ; status : Mina_stdlib.Bounded_types.String.Stable.V1.t
        ; failure_reasons :
            Transaction_status.Failure.Collection.Display.Stable.V1.t option
        }
      [@@deriving yojson, equal]
    end
  end]

  type t = Stable.Latest.t =
    { sequence_no : int
    ; fee_payer : Account_update.Body.Fee_payer.t
    ; account_updates : Account_update.Body.Simple.t list
    ; memo : Signed_command_memo.t
    ; hash : Transaction_hash.t
    ; status : string
    ; failure_reasons : Transaction_status.Failure.Collection.Display.t option
    }
  [@@deriving yojson, equal]

  (** The fee payer's account and every account update's account. *)
  val accounts_referenced : t -> Account_id.t list
end

(** A whole block, everything the archive stores about it. *)
module Block : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    [@@@with_versioned_json]

    module V3 : sig
      type t =
        { state_hash : State_hash.Stable.V1.t
        ; parent_hash : State_hash.Stable.V1.t
        ; creator : Public_key.Compressed.Stable.V1.t
        ; block_winner : Public_key.Compressed.Stable.V1.t
        ; last_vrf_output : Consensus_vrf.Output.Truncated.Stable.V1.t
        ; snarked_ledger_hash : Frozen_ledger_hash.Stable.V1.t
        ; staking_epoch_data : Mina_base.Epoch_data.Value.Stable.V1.t
        ; next_epoch_data : Mina_base.Epoch_data.Value.Stable.V1.t
        ; min_window_density : Mina_numbers.Length.Stable.V1.t
        ; total_currency : Currency.Amount.Stable.V1.t
        ; sub_window_densities : Mina_numbers.Length.Stable.V1.t list
        ; ledger_hash : Ledger_hash.Stable.V1.t
        ; height : Unsigned_extended.UInt32.Stable.V1.t
        ; global_slot_since_hard_fork :
            Mina_numbers.Global_slot_since_hard_fork.Stable.V1.t
        ; global_slot_since_genesis :
            Mina_numbers.Global_slot_since_genesis.Stable.V1.t
        ; timestamp : Block_time.Stable.V1.t
        ; user_cmds : User_command.Stable.V2.t list
        ; internal_cmds : Internal_command.Stable.V2.t list
        ; zkapp_cmds : Zkapp_command.Stable.V2.t list
        ; protocol_version : Protocol_version.Stable.V2.t
        ; proposed_protocol_version : Protocol_version.Stable.V2.t option
        ; chain_status : Chain_status.Stable.V1.t
        ; accounts_accessed : (int * Account.Stable.V3.t) list
              (** Accounts the block read or wrote, with their ledger index,
                  as they stand after the block. *)
        ; accounts_created :
            (Account_id.Stable.V2.t * Currency.Fee.Stable.V1.t) list
              (** Accounts the block created, with the creation fee paid. *)
        ; tokens_used :
            (Token_id.Stable.V2.t * Account_id.Stable.V2.t option) list
              (** Tokens the block touched, with their owner when they have
                  one. *)
        }
      [@@deriving yojson, equal]
    end
  end]

  type t = Stable.Latest.t =
    { state_hash : State_hash.t
    ; parent_hash : State_hash.t
    ; creator : Public_key.Compressed.t
    ; block_winner : Public_key.Compressed.t
    ; last_vrf_output : Consensus_vrf.Output.Truncated.t
    ; snarked_ledger_hash : Frozen_ledger_hash.t
    ; staking_epoch_data : Mina_base.Epoch_data.Value.t
    ; next_epoch_data : Mina_base.Epoch_data.Value.t
    ; min_window_density : Mina_numbers.Length.t
    ; total_currency : Currency.Amount.t
    ; sub_window_densities : Mina_numbers.Length.t list
    ; ledger_hash : Ledger_hash.t
    ; height : Unsigned_extended.UInt32.t
    ; global_slot_since_hard_fork : Mina_numbers.Global_slot_since_hard_fork.t
    ; global_slot_since_genesis : Mina_numbers.Global_slot_since_genesis.t
    ; timestamp : Block_time.t
    ; user_cmds : User_command.t list
    ; internal_cmds : Internal_command.t list
    ; zkapp_cmds : Zkapp_command.t list
    ; protocol_version : Protocol_version.t
    ; proposed_protocol_version : Protocol_version.t option
    ; chain_status : Chain_status.t
    ; accounts_accessed : (int * Account.t) list
    ; accounts_created : (Account_id.t * Currency.Fee.t) list
    ; tokens_used : (Token_id.t * Account_id.t option) list
    }
  [@@deriving yojson, equal]
end
