(* extensional.ml -- extensional representations of archive db data *)

open Core_kernel
open Mina_base
open Mina_transaction
open Signature_lib

(* the tables in the archive db uses foreign keys to refer to other
   tables; the types here fills in the data from those other tables, using
   their native OCaml types to assure the validity of the data
*)

module User_command = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* for `typ` and `status`, a string is enough
         in any case, there aren't existing string conversions for the
         original OCaml types

         The versioned modules in Transaction_hash.Stable don't have yojson functions
         it would be difficult to add them, so we just use the ones for the
          top-level Transaction.t
      *)
      type t =
        { sequence_no : int
        ; typ : string
        ; fee_payer : Account_id.Stable.V2.t
        ; source : Account_id.Stable.V2.t
        ; receiver : Account_id.Stable.V2.t
        ; nonce : Account.Nonce.Stable.V1.t
        ; amount : Currency.Amount.Stable.V1.t option
        ; fee : Currency.Fee.Stable.V1.t
        ; valid_until : Mina_numbers.Global_slot.Stable.V1.t option
        ; memo : Signed_command_memo.Stable.V1.t
        ; hash : Transaction_hash.Stable.V1.t
              [@to_yojson Transaction_hash.to_yojson]
              [@of_yojson Transaction_hash.of_yojson]
        ; status : string
        ; failure_reason : Transaction_status.Failure.Stable.V2.t option
        }
      [@@deriving yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

module Internal_command = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* for `typ`, a string is enough
         no existing string conversion for the original OCaml type
      *)
      type t =
        { sequence_no : int
        ; secondary_sequence_no : int
        ; typ : string
        ; receiver : Account_id.Stable.V2.t
        ; fee : Currency.Fee.Stable.V1.t
        ; hash : Transaction_hash.Stable.V1.t
              [@to_yojson Transaction_hash.to_yojson]
              [@of_yojson Transaction_hash.of_yojson]
        ; status : string
        ; failure_reason : Transaction_status.Failure.Stable.V2.t option
        }
      [@@deriving yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

(* for fee payer and account updates, authorizations are omitted; signatures, proofs not in archive db *)
module Zkapp_command = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { sequence_no : int
        ; fee_payer : Account_update.Body.Fee_payer.Stable.V1.t
        ; account_updates : Account_update.Body.Simple.Stable.V1.t list
        ; memo : Signed_command_memo.Stable.V1.t
        ; hash : Transaction_hash.Stable.V1.t
              [@to_yojson Transaction_hash.to_yojson]
              [@of_yojson Transaction_hash.of_yojson]
        ; status : string
        ; failure_reasons :
            Transaction_status.Failure.Collection.Display.Stable.V1.t option
        }
      [@@deriving yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

module Block = struct
  [%%versioned
  module Stable = struct
    [@@@with_versioned_json]

    module V2 = struct
      (* in accounts_accessed, the int is the ledger index
         in tokens_used, the account id is the token owner
      *)
      type t =
        { state_hash : State_hash.Stable.V1.t
        ; parent_hash : State_hash.Stable.V1.t
        ; creator : Public_key.Compressed.Stable.V1.t
        ; block_winner : Public_key.Compressed.Stable.V1.t
        ; snarked_ledger_hash : Frozen_ledger_hash.Stable.V1.t
        ; staking_epoch_data : Mina_base.Epoch_data.Value.Stable.V1.t
        ; next_epoch_data : Mina_base.Epoch_data.Value.Stable.V1.t
        ; min_window_density : Mina_numbers.Length.Stable.V1.t
        ; total_currency : Currency.Amount.Stable.V1.t
        ; ledger_hash : Ledger_hash.Stable.V1.t
        ; height : Unsigned_extended.UInt32.Stable.V1.t
        ; global_slot_since_hard_fork : Mina_numbers.Global_slot.Stable.V1.t
        ; global_slot_since_genesis : Mina_numbers.Global_slot.Stable.V1.t
        ; timestamp : Block_time.Stable.V1.t
        ; user_cmds : User_command.Stable.V1.t list
        ; internal_cmds : Internal_command.Stable.V1.t list
        ; zkapp_cmds : Zkapp_command.Stable.V1.t list
        ; chain_status : Chain_status.Stable.V1.t
        ; accounts_accessed : (int * Account.Stable.V2.t) list
        ; accounts_created :
            (Account_id.Stable.V2.t * Currency.Fee.Stable.V1.t) list
        ; tokens_used :
            (Token_id.Stable.V1.t * Account_id.Stable.V2.t option) list
        }
      [@@deriving yojson, equal]

      let to_latest = Fn.id
    end
  end]
end
