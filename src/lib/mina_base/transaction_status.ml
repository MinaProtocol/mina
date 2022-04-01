[%%import "/src/config.mlh"]

open Core_kernel

(* if these items change, please also change
   Transaction_snark.Base.User_command_failure.t
   and update the code following it
*)
module Failure = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        | Predicate [@value 1]
        | Source_not_present
        | Receiver_not_present
        | Amount_insufficient_to_create_account
        | Cannot_pay_creation_fee_in_token
        | Source_insufficient_balance
        | Source_minimum_balance_violation
        | Receiver_already_exists
        | Not_token_owner
        | Mismatched_token_permissions
        | Overflow
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
        | Parties_replay_check_failed
        | Fee_payer_nonce_must_increase
        | Account_precondition_unsatisfied
        | Protocol_state_precondition_unsatisfied
        | Incorrect_nonce
        | Invalid_fee_excess
      [@@deriving sexp, yojson, equal, compare, enum, hash]

      let to_latest = Fn.id
    end
  end]

  module Collection = struct
    type display = (int * t list) list [@@deriving to_yojson]

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Stable.V2.t list list
        [@@deriving equal, compare, yojson, sexp, hash]

        let to_latest = Fn.id
      end
    end]

    let to_display t =
      let _, display =
        List.fold_right t ~init:(0, []) ~f:(fun bucket (index, acc) ->
            if List.is_empty bucket then (index + 1, acc)
            else (index + 1, (index, bucket) :: acc))
      in
      display

    let empty = []

    let of_single_failure f : t = [ [ f ] ]

    let is_empty : t -> bool = Fn.compose List.is_empty List.concat
  end

  type failure = t

  let failure_min = min

  let failure_max = max

  let failure_num_bits =
    let num_values = failure_max - failure_min + 1 in
    Int.ceil_log2 num_values

  let gen =
    let open Quickcheck.Let_syntax in
    let%map ndx = Int.gen_uniform_incl failure_min failure_max in
    (* bounds are checked, of_enum always returns Some *)
    Option.value_exn (of_enum ndx)

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
    | Source_minimum_balance_violation ->
        "Source_minimum_balance_violation"
    | Receiver_already_exists ->
        "Receiver_already_exists"
    | Not_token_owner ->
        "Not_token_owner"
    | Mismatched_token_permissions ->
        "Mismatched_token_permissions"
    | Overflow ->
        "Overflow"
    | Signed_command_on_zkapp_account ->
        "Signed_command_on_zkapp_account"
    | Zkapp_account_not_present ->
        "Zkapp_account_not_present"
    | Update_not_permitted_balance ->
        "Update_not_permitted_balance"
    | Update_not_permitted_timing_existing_account ->
        "Update_not_permitted_timing_existing_account"
    | Update_not_permitted_delegate ->
        "update_not_permitted_delegate"
    | Update_not_permitted_app_state ->
        "Update_not_permitted_app_state"
    | Update_not_permitted_verification_key ->
        "Update_not_permitted_verification_key"
    | Update_not_permitted_sequence_state ->
        "Update_not_permitted_sequence_state"
    | Update_not_permitted_zkapp_uri ->
        "Update_not_permitted_zkapp_uri"
    | Update_not_permitted_token_symbol ->
        "Update_not_permitted_token_symbol"
    | Update_not_permitted_permissions ->
        "Update_not_permitted_permissions"
    | Update_not_permitted_nonce ->
        "Update_not_permitted_nonce"
    | Update_not_permitted_voting_for ->
        "Update_not_permitted_voting_for"
    | Parties_replay_check_failed ->
        "Parties_replay_check_failed"
    | Fee_payer_nonce_must_increase ->
        "Fee_payer_nonce_must_increase"
    | Account_precondition_unsatisfied ->
        "Account_precondition_unsatisfied"
    | Protocol_state_precondition_unsatisfied ->
        "Protocol_state_precondition_unsatisfied"
    | Incorrect_nonce ->
        "Incorrect_nonce"
    | Invalid_fee_excess ->
        "Invalid_fee_excess"

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
    | "Source_minimum_balance_violation" ->
        Ok Source_minimum_balance_violation
    | "Receiver_already_exists" ->
        Ok Receiver_already_exists
    | "Not_token_owner" ->
        Ok Not_token_owner
    | "Mismatched_token_permissions" ->
        Ok Mismatched_token_permissions
    | "Overflow" ->
        Ok Overflow
    | "Signed_command_on_zkapp_account" ->
        Ok Signed_command_on_zkapp_account
    | "Zkapp_account_not_present" ->
        Ok Zkapp_account_not_present
    | "Update_not_permitted_balance" ->
        Ok Update_not_permitted_balance
    | "Update_not_permitted_timing_existing_account" ->
        Ok Update_not_permitted_timing_existing_account
    | "update_not_permitted_delegate" ->
        Ok Update_not_permitted_delegate
    | "Update_not_permitted_app_state" ->
        Ok Update_not_permitted_app_state
    | "Update_not_permitted_verification_key" ->
        Ok Update_not_permitted_verification_key
    | "Update_not_permitted_sequence_state" ->
        Ok Update_not_permitted_sequence_state
    | "Update_not_permitted_zkapp_uri" ->
        Ok Update_not_permitted_zkapp_uri
    | "Update_not_permitted_token_symbol" ->
        Ok Update_not_permitted_token_symbol
    | "Update_not_permitted_permissions" ->
        Ok Update_not_permitted_permissions
    | "Update_not_permitted_nonce" ->
        Ok Update_not_permitted_nonce
    | "Update_not_permitted_voting_for" ->
        Ok Update_not_permitted_voting_for
    | "Parties_replay_check_failed" ->
        Ok Parties_replay_check_failed
    | "Fee_payer_nonce_must_increase" ->
        Ok Fee_payer_nonce_must_increase
    | "Account_precondition_unsatisfied" ->
        Ok Account_precondition_unsatisfied
    | "Protocol_state_precondition_unsatisfied" ->
        Ok Protocol_state_precondition_unsatisfied
    | "Incorrect_nonce" ->
        Ok Incorrect_nonce
    | "Invalid_fee_excess" ->
        Ok Invalid_fee_excess
    | _ ->
        Error "Signed_command_status.Failure.of_string: Unknown value"

  let%test_unit "of_string(to_string) roundtrip" =
    for i = failure_min to failure_max do
      let failure = Option.value_exn (of_enum i) in
      [%test_eq: (t, string) Result.t]
        (of_string (to_string failure))
        (Ok failure)
    done

  let describe = function
    | Predicate ->
        "A predicate failed"
    | Source_not_present ->
        "The source account does not exist"
    | Receiver_not_present ->
        "The receiver account does not exist"
    | Amount_insufficient_to_create_account ->
        "Cannot create account: transaction amount is smaller than the account \
         creation fee"
    | Cannot_pay_creation_fee_in_token ->
        "Cannot create account: account creation fees cannot be paid in \
         non-default tokens"
    | Source_insufficient_balance ->
        "The source account has an insufficient balance"
    | Source_minimum_balance_violation ->
        "The source account requires a minimum balance"
    | Receiver_already_exists ->
        "Attempted to create an account that already exists"
    | Not_token_owner ->
        "The source account does not own the token"
    | Mismatched_token_permissions ->
        "The permissions for this token do not match those in the command"
    | Overflow ->
        "The resulting balance is too large to store"
    | Signed_command_on_zkapp_account ->
        "The source of a signed command cannot be a snapp account"
    | Zkapp_account_not_present ->
        "A snapp account does not exist"
    | Update_not_permitted_balance ->
        "The authentication for an account didn't allow the requested update \
         to its balance"
    | Update_not_permitted_timing_existing_account ->
        "The timing of an existing account cannot be updated"
    | Update_not_permitted_delegate ->
        "The authentication for an account didn't allow the requested update \
         to its delegate"
    | Update_not_permitted_app_state ->
        "The authentication for an account didn't allow the requested update \
         to its app state"
    | Update_not_permitted_verification_key ->
        "The authentication for an account didn't allow the requested update \
         to its verification key"
    | Update_not_permitted_sequence_state ->
        "The authentication for an account didn't allow the requested update \
         to its sequence state"
    | Update_not_permitted_zkapp_uri ->
        "The authentication for an account didn't allow the requested update \
         to its snapp URI"
    | Update_not_permitted_token_symbol ->
        "The authentication for an account didn't allow the requested update \
         to its token symbol"
    | Update_not_permitted_permissions ->
        "The authentication for an account didn't allow the requested update \
         to its permissions"
    | Update_not_permitted_nonce ->
        "The authentication for an account didn't allow the requested update \
         to its nonce"
    | Update_not_permitted_voting_for ->
        "The authentication for an account didn't allow the requested update \
         to its voted-for state hash"
    | Parties_replay_check_failed ->
        "Check to avoid replays failed. The party must increment nonce or use \
         full commitment if the authorization is a signature"
    | Fee_payer_nonce_must_increase ->
        "Fee payer party must increment its nonce"
    | Account_precondition_unsatisfied ->
        "The party's account precondition unsatisfied"
    | Protocol_state_precondition_unsatisfied ->
        "The party's protocol state precondition unsatisfied"
    | Incorrect_nonce ->
        "Incorrect nonce"
    | Invalid_fee_excess ->
        "Fee excess from parties transaction more than the transaction fees"
end

module Balance_data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { fee_payer_balance : Currency.Balance.Stable.V1.t option
        ; source_balance : Currency.Balance.Stable.V1.t option
        ; receiver_balance : Currency.Balance.Stable.V1.t option
        }
      [@@deriving sexp, yojson, equal, compare]

      let to_latest = Fn.id
    end
  end]

  let empty =
    { fee_payer_balance = None; source_balance = None; receiver_balance = None }
end

module Coinbase_balance_data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { coinbase_receiver_balance : Currency.Balance.Stable.V1.t
        ; fee_transfer_receiver_balance : Currency.Balance.Stable.V1.t option
        }
      [@@deriving sexp, yojson, equal, compare]

      let to_latest = Fn.id
    end
  end]

  let of_balance_data_exn
      { Balance_data.fee_payer_balance; source_balance; receiver_balance } =
    ( match source_balance with
    | Some _ ->
        failwith
          "Unexpected source balance for Coinbase_balance_data.of_balance_data"
    | None ->
        () ) ;
    let coinbase_receiver_balance =
      match fee_payer_balance with
      | Some balance ->
          balance
      | None ->
          failwith
            "Missing fee-payer balance for \
             Coinbase_balance_data.of_balance_data"
    in
    { coinbase_receiver_balance
    ; fee_transfer_receiver_balance = receiver_balance
    }

  let to_balance_data
      { coinbase_receiver_balance; fee_transfer_receiver_balance } =
    { Balance_data.fee_payer_balance = Some coinbase_receiver_balance
    ; source_balance = None
    ; receiver_balance = fee_transfer_receiver_balance
    }
end

module Fee_transfer_balance_data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { receiver1_balance : Currency.Balance.Stable.V1.t
        ; receiver2_balance : Currency.Balance.Stable.V1.t option
        }
      [@@deriving sexp, yojson, equal, compare]

      let to_latest = Fn.id
    end
  end]

  let of_balance_data_exn
      { Balance_data.fee_payer_balance; source_balance; receiver_balance } =
    ( match source_balance with
    | Some _ ->
        failwith
          "Unexpected source balance for \
           Fee_transfer_balance_data.of_balance_data"
    | None ->
        () ) ;
    let receiver1_balance =
      match fee_payer_balance with
      | Some balance ->
          balance
      | None ->
          failwith
            "Missing fee-payer balance for \
             Fee_transfer_balance_data.of_balance_data"
    in
    { receiver1_balance; receiver2_balance = receiver_balance }

  let to_balance_data { receiver1_balance; receiver2_balance } =
    { Balance_data.fee_payer_balance = Some receiver1_balance
    ; source_balance = None
    ; receiver_balance = receiver2_balance
    }
end

module Internal_command_balance_data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Coinbase of Coinbase_balance_data.Stable.V1.t
        | Fee_transfer of Fee_transfer_balance_data.Stable.V1.t
      [@@deriving sexp, yojson, equal, compare]

      let to_latest = Fn.id
    end
  end]
end

module Auxiliary_data = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { fee_payer_account_creation_fee_paid :
            Currency.Amount.Stable.V1.t option
        ; receiver_account_creation_fee_paid :
            Currency.Amount.Stable.V1.t option
        }
      [@@deriving sexp, yojson, equal, compare]

      let to_latest = Fn.id
    end
  end]

  let empty =
    { fee_payer_account_creation_fee_paid = None
    ; receiver_account_creation_fee_paid = None
    }
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      | Applied of Auxiliary_data.Stable.V2.t * Balance_data.Stable.V1.t
      | Failed of Failure.Collection.Stable.V1.t * Balance_data.Stable.V1.t
    [@@deriving sexp, yojson, equal, compare]

    let to_latest = Fn.id
  end
end]

let balance_data = function
  | Applied (_, balances) | Failed (_, balances) ->
      balances
