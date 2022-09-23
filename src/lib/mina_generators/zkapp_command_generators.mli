open Mina_base
open Core_kernel

type failure =
  | Invalid_account_precondition
  | Invalid_protocol_state_precondition
  | Update_not_permitted of
      [ `Delegate
      | `App_state
      | `Voting_for
      | `Verification_key
      | `Zkapp_uri
      | `Token_symbol
      | `Send
      | `Receive ]

type role = [ `Fee_payer | `New_account | `Ordinary_participant ]

val max_account_updates : int

val gen_account_precondition_from_account :
     ?failure:failure
  -> first_use_of_account:bool
  -> Account.t
  -> Account_update.Account_precondition.t Quickcheck.Generator.t

val gen_protocol_state_precondition :
     Zkapp_precondition.Protocol_state.View.t
  -> Zkapp_precondition.Protocol_state.t Quickcheck.Generator.t

(** `gen_zkapp_command_from` generates a zkapp_command and record the change of accounts accordingly
    in `account_state_tbl`. Note that `account_state_tbl` is optional. If it's not provided
    then it would be computed from the ledger. If you plan to generate several zkapp_command,
    then please manually pass `account_state_tbl` to `gen_zkapp_command_from` function.
    If you are generating several zkapp_command, it's better to pre-compute the
    `account_state_tbl` before you call this function. This way you can manually set the
    role of fee payer accounts to be `Fee_payer` in `account_state_tbl` which would prevent
    those accounts being used as ordinary participants in other zkapp_command.

    Generated zkapp_command uses dummy signatures and dummy proofs.
  *)
val gen_zkapp_command_from :
     ?failure:failure
  -> ?max_account_updates:int
  -> fee_payer_keypair:Signature_lib.Keypair.t
  -> keymap:
       Signature_lib.Private_key.t Signature_lib.Public_key.Compressed.Map.t
  -> ?account_state_tbl:(Account.t * role) Account_id.Table.t
  -> ledger:Mina_ledger.Ledger.t
  -> ?protocol_state_view:Zkapp_precondition.Protocol_state.View.t
  -> ?vk:(Side_loaded_verification_key.t, State_hash.t) With_hash.Stable.V1.t
  -> unit
  -> Zkapp_command.t Quickcheck.Generator.t

(** Generate a list of zkapp_command, `fee_payer_keypairs` contains a list of possible fee payers
  *)
val gen_list_of_zkapp_command_from :
     ?failure:failure
  -> ?max_account_updates:int
  -> fee_payer_keypairs:Signature_lib.Keypair.t list
  -> keymap:
       Signature_lib.Private_key.t Signature_lib.Public_key.Compressed.Map.t
  -> ?account_state_tbl:(Account.t * role) Account_id.Table.t
  -> ledger:Mina_ledger.Ledger.t
  -> ?protocol_state_view:Zkapp_precondition.Protocol_state.View.t
  -> ?vk:(Side_loaded_verification_key.t, State_hash.t) With_hash.Stable.V1.t
  -> ?length:int
  -> unit
  -> Zkapp_command.t list Quickcheck.Generator.t
