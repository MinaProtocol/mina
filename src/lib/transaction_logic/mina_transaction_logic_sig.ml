open Core_kernel
open Mina_base
open Currency
open Signature_lib
open Mina_transaction
module Global_slot = Mina_numbers.Global_slot

module type S = sig
  type ledger

  module Transaction_applied : sig
    module Signed_command_applied : sig
      module Common : sig
        type t = Transaction_applied.Signed_command_applied.Common.t =
          { user_command : Signed_command.t With_status.t }
        [@@deriving sexp]
      end

      module Body : sig
        type t = Transaction_applied.Signed_command_applied.Body.t =
          | Payment of { new_accounts : Account_id.t list }
          | Stake_delegation of
              { previous_delegate : Public_key.Compressed.t option }
          | Failed
        [@@deriving sexp]
      end

      type t = Transaction_applied.Signed_command_applied.t =
        { common : Common.t; body : Body.t }
      [@@deriving sexp]
    end

    module Zkapp_command_applied : sig
      type t = Transaction_applied.Zkapp_command_applied.t =
        { accounts : (Account_id.t * Account.t option) list
        ; command : Zkapp_command.t With_status.t
        ; new_accounts : Account_id.t list
        }
      [@@deriving sexp]
    end

    module Command_applied : sig
      type t = Transaction_applied.Command_applied.t =
        | Signed_command of Signed_command_applied.t
        | Zkapp_command of Zkapp_command_applied.t
      [@@deriving sexp]
    end

    module Fee_transfer_applied : sig
      type t = Transaction_applied.Fee_transfer_applied.t =
        { fee_transfer : Fee_transfer.t With_status.t
        ; new_accounts : Account_id.t list
        ; burned_tokens : Currency.Amount.t
        }
      [@@deriving sexp]
    end

    module Coinbase_applied : sig
      type t = Transaction_applied.Coinbase_applied.t =
        { coinbase : Coinbase.t With_status.t
        ; new_accounts : Account_id.t list
        ; burned_tokens : Currency.Amount.t
        }
      [@@deriving sexp]
    end

    module Varying : sig
      type t = Transaction_applied.Varying.t =
        | Command of Command_applied.t
        | Fee_transfer of Fee_transfer_applied.t
        | Coinbase of Coinbase_applied.t
      [@@deriving sexp]
    end

    type t = Transaction_applied.t =
      { previous_hash : Ledger_hash.t; varying : Varying.t }
    [@@deriving sexp]

    val burned_tokens : t -> Currency.Amount.t

    val supply_increase : t -> Currency.Amount.Signed.t Or_error.t

    val transaction : t -> Transaction.t With_status.t

    val transaction_status : t -> Transaction_status.t
  end

  module Global_state : sig
    type t =
      { ledger : ledger
      ; fee_excess : Amount.Signed.t
      ; supply_increase : Amount.Signed.t
      ; protocol_state : Zkapp_precondition.Protocol_state.View.t
      ; block_global_slot : Mina_numbers.Global_slot.t
            (* Slot of block when the transaction is applied. NOTE: This is at least 1 slot after the protocol_state's view, which is for the *previous* slot. *)
      }
  end

  val apply_user_command :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Global_slot.t
    -> ledger
    -> Signed_command.With_valid_signature.t
    -> Transaction_applied.Signed_command_applied.t Or_error.t

  val apply_user_command_unchecked :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Global_slot.t
    -> ledger
    -> Signed_command.t
    -> Transaction_applied.Signed_command_applied.t Or_error.t

  val update_sequence_state :
       Snark_params.Tick.Field.t Pickles_types.Vector.Vector_5.t
    -> Zkapp_account.Actions.t
    -> txn_global_slot:Global_slot.t
    -> last_sequence_slot:Global_slot.t
    -> Snark_params.Tick.Field.t Pickles_types.Vector.Vector_5.t * Global_slot.t

  val apply_zkapp_command_unchecked :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> global_slot:Mina_numbers.Global_slot.t
    -> state_view:Zkapp_precondition.Protocol_state.View.t
    -> ledger
    -> Zkapp_command.t
    -> ( Transaction_applied.Zkapp_command_applied.t
       * ( ( Stack_frame.value
           , Stack_frame.value list
           , Token_id.t
           , Amount.Signed.t
           , ledger
           , bool
           , Zkapp_command.Transaction_commitment.t
           , Mina_numbers.Index.t
           , Transaction_status.Failure.Collection.t )
           Zkapp_command_logic.Local_state.t
         * Amount.Signed.t ) )
       Or_error.t

  (** Apply all zkapp_command within a zkapp_command transaction. This behaves as
      [apply_zkapp_command_unchecked], except that the [~init] and [~f] arguments
      are provided to allow for the accumulation of the intermediate states.

      Invariant: [f] is always applied at least once, so it is valid to use an
      [_ option] as the initial state and call [Option.value_exn] on the
      accumulated result.

      This can be used to collect the intermediate states to make them
      available for snark work. In particular, since the transaction snark has
      a cap on the number of zkapp_command of each kind that may be included, we can
      use this to retrieve the (source, target) pairs for each batch of
      zkapp_command to include in the snark work spec / transaction snark witness.
  *)
  val apply_zkapp_command_unchecked_aux :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> global_slot:Mina_numbers.Global_slot.t
    -> state_view:Zkapp_precondition.Protocol_state.View.t
    -> init:'acc
    -> f:
         (   'acc
          -> Global_state.t
             * ( Stack_frame.value
               , Stack_frame.value list
               , Token_id.t
               , Amount.Signed.t
               , ledger
               , bool
               , Zkapp_command.Transaction_commitment.t
               , Mina_numbers.Index.t
               , Transaction_status.Failure.Collection.t )
               Zkapp_command_logic.Local_state.t
          -> 'acc )
    -> ?fee_excess:Amount.Signed.t
    -> ?supply_increase:Amount.Signed.t
    -> ledger
    -> Zkapp_command.t
    -> (Transaction_applied.Zkapp_command_applied.t * 'acc) Or_error.t

  val apply_fee_transfer :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Global_slot.t
    -> ledger
    -> Fee_transfer.t
    -> Transaction_applied.Fee_transfer_applied.t Or_error.t

  val apply_coinbase :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Global_slot.t
    -> ledger
    -> Coinbase.t
    -> Transaction_applied.Coinbase_applied.t Or_error.t

  val apply_transaction :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> global_slot:Global_slot.t
    -> txn_state_view:Zkapp_precondition.Protocol_state.View.t
    -> ledger
    -> Transaction.t
    -> Transaction_applied.t Or_error.t

  val has_locked_tokens :
       global_slot:Global_slot.t
    -> account_id:Account_id.t
    -> ledger
    -> bool Or_error.t

  module For_tests : sig
    val validate_timing_with_min_balance :
         account:Account.t
      -> txn_amount:Amount.t
      -> txn_global_slot:Global_slot.t
      -> (Account.Timing.t * [> `Min_balance of Balance.t ]) Or_error.t

    val validate_timing :
         account:Account.t
      -> txn_amount:Amount.t
      -> txn_global_slot:Global_slot.t
      -> Account.Timing.t Or_error.t
  end
end
