module Failure = struct
  module V2 = struct
    type t =
      | Predicate
      | Source_not_present
      | Receiver_not_present
      | Amount_insufficient_to_create_account
      | Cannot_pay_creation_fee_in_token
      | Source_insufficient_balance
      | Source_minimum_balance_violation
      | Receiver_already_exists
      | Token_owner_not_caller
      | Overflow
      | Global_excess_overflow
      | Local_excess_overflow
      | Local_supply_increase_overflow
      | Global_supply_increase_overflow
      | Signed_command_on_zkapp_account
      | Zkapp_account_not_present
      | Update_not_permitted_balance
      | Update_not_permitted_timing_existing_account
      | Update_not_permitted_delegate
      | Update_not_permitted_app_state
      | Update_not_permitted_verification_key
      | Update_not_permitted_sequence_state
      | Update_not_permitted_zkapp_uri
      | Update_not_permitted_token_symbol
      | Update_not_permitted_permissions
      | Update_not_permitted_nonce
      | Update_not_permitted_voting_for
      | Zkapp_command_replay_check_failed
      | Fee_payer_nonce_must_increase
      | Fee_payer_must_be_signed
      | Account_balance_precondition_unsatisfied
      | Account_nonce_precondition_unsatisfied
      | Account_receipt_chain_hash_precondition_unsatisfied
      | Account_delegate_precondition_unsatisfied
      | Account_sequence_state_precondition_unsatisfied
      | Account_app_state_precondition_unsatisfied of int
      | Account_proved_state_precondition_unsatisfied
      | Account_is_new_precondition_unsatisfied
      | Protocol_state_precondition_unsatisfied
      | Incorrect_nonce
      | Invalid_fee_excess
      | Cancelled
  end

  module Collection = struct
    module V1 = struct
      type t = V2.t list list
    end
  end
end

module V2 = struct
  type t = Applied | Failed of Failure.Collection.V1.t
end
