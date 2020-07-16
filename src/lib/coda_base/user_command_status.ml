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
      [@@deriving sexp, yojson, eq, compare]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
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
  [@@deriving sexp, yojson, eq, compare]

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
    | _ ->
        Error "User_command_status.Failure.of_string: Unknown value"

  let describe = function
    | Predicate ->
        "The fee-payer is not authorised to issue this command for the source \
         account"
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
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Applied | Failed of Failure.Stable.V1.t
    [@@deriving sexp, yojson, eq, compare]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t = Applied | Failed of Failure.t
[@@deriving sexp, yojson, eq, compare]

type status = t [@@deriving sexp, yojson, eq, compare]

module With_status = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = {data: 'a; status: Stable.V1.t}
      [@@deriving sexp, yojson, eq, compare]
    end
  end]

  type 'a t = 'a Stable.Latest.t = {data: 'a; status: status}
  [@@deriving sexp, yojson, eq, compare]

  let map ~f {data; status} = {data= f data; status}

  let map_opt ~f {data; status} =
    Option.map (f data) ~f:(fun data -> {data; status})

  let map_result ~f {data; status} =
    Result.map (f data) ~f:(fun data -> {data; status})
end
