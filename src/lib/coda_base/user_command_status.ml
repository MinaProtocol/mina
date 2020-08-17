open Core_kernel

module Failure = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Predicate
        | Source_not_present
        | Receiver_not_present
        | Amount_insufficient_to_create_account
        | Cannot_pay_creation_fee_in_token
        | Source_insufficient_balance
        | Receiver_already_exists
        | Not_token_owner
        | Mismatched_token_permissions
        | Overflow
        | User_command_on_snapp_account
        | Snapp_account_not_present
      [@@deriving sexp, yojson, eq, compare]

      let to_latest = Fn.id
    end
  end]

  let to_latest = Fn.id

  let to_string = function
    | Predicate ->
        "Predicate"
    | Source_not_present ->
        "Source_not_present"
    | Receiver_not_present ->
        "Receiver_not_present"
    | Amount_insufficient_to_create_account ->
        "Amount_insufficient_to_create_account"
    | Cannot_pay_creation_fee_in_token ->
        "Cannot_pay_creation_fee_in_token"
    | Source_insufficient_balance ->
        "Source_insufficient_balance"
    | Receiver_already_exists ->
        "Receiver_already_exists"
    | Not_token_owner ->
        "Not_token_owner"
    | Mismatched_token_permissions ->
        "Mismatched_token_permissions"
    | Overflow ->
        "Overflow"
    | User_command_on_snapp_account ->
        "User_command_on_snapp_account"
    | Snapp_account_not_present ->
        "Snapp_account_not_present"

  let of_string = function
    | "Predicate" ->
        Ok Predicate
    | "Source_not_present" ->
        Ok Source_not_present
    | "Receiver_not_present" ->
        Ok Receiver_not_present
    | "Amount_insufficient_to_create_account" ->
        Ok Amount_insufficient_to_create_account
    | "Cannot_pay_creation_fee_in_token" ->
        Ok Cannot_pay_creation_fee_in_token
    | "Source_insufficient_balance" ->
        Ok Source_insufficient_balance
    | "Receiver_already_exists" ->
        Ok Receiver_already_exists
    | "Not_token_owner" ->
        Ok Not_token_owner
    | "Mismatched_token_permissions" ->
        Ok Mismatched_token_permissions
    | "Overflow" ->
        Ok Overflow
    | "Snapp_account_not_present" ->
        Ok Snapp_account_not_present
    | _ ->
        Error "User_command_status.Failure.of_string: Unknown value"

  let describe = function
    | Predicate ->
        "A predicate failed"
    | Source_not_present ->
        "The source account does not exist"
    | Receiver_not_present ->
        "The receiver account does not exist"
    | Amount_insufficient_to_create_account ->
        "Cannot create account: transaction amount is smaller than the \
         account creation fee"
    | Cannot_pay_creation_fee_in_token ->
        "Cannot create account: account creation fees cannot be paid in \
         non-default tokens"
    | Source_insufficient_balance ->
        "The source account has an insufficient balance"
    | Receiver_already_exists ->
        "Attempted to create an account that already exists"
    | Not_token_owner ->
        "The source account does not own the token"
    | Mismatched_token_permissions ->
        "The permissions for this token do not match those in the command"
    | Overflow ->
        "The resulting balance is too large to store"
    | User_command_on_snapp_account ->
        "The source of a user command cannot be a snapp account"
    | Snapp_account_not_present ->
        "A snapp account does not exist"
end

module Auxiliary_data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { fee_payer_account_creation_fee_paid:
            Currency.Amount.Stable.V1.t option
        ; receiver_account_creation_fee_paid:
            Currency.Amount.Stable.V1.t option
        ; created_token: Token_id.Stable.V1.t option }
      [@@deriving sexp, yojson, eq, compare]

      let to_latest = Fn.id
    end
  end]

  let empty =
    { fee_payer_account_creation_fee_paid= None
    ; receiver_account_creation_fee_paid= None
    ; created_token= None }
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      | Applied of Auxiliary_data.Stable.V1.t
      | Failed of Failure.Stable.V1.t
    [@@deriving sexp, yojson, eq, compare]

    let to_latest = Fn.id
  end
end]
