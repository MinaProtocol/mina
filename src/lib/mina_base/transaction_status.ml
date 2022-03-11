[%%import "/src/config.mlh"]

open Core_kernel

(* if these items change, please also change
   Transaction_snark.Base.User_command_failure.t
   and update the code following it
*)
module Failure = struct
  module Permission = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          | Balance
          | Timing_existing_account
          | Delegate
          | App_state
          | Verification_key
          | Sequence_state
          | Snapp_uri
          | Token_symbol
          | Permissions
          | Nonce
          | Voting_for
        [@@deriving sexp, yojson, equal, compare, enum, hash, variants]

        let to_latest = Fn.id
      end
    end]

    let all =
      let add acc var = var.Variantslib.Variant.constructor :: acc in
      Variants.fold ~init:[] ~balance:add ~timing_existing_account:add
        ~delegate:add ~app_state:add ~verification_key:add ~sequence_state:add
        ~snapp_uri:add ~token_symbol:add ~permissions:add ~nonce:add
        ~voting_for:add

    let to_string x = Variants.to_name x

    let of_string = function
      | "Balance" ->
          Ok Balance
      | "Timing_existing_account" ->
          Ok Timing_existing_account
      | "Delegate" ->
          Ok Delegate
      | "App_state" ->
          Ok App_state
      | "Verification_key" ->
          Ok Verification_key
      | "Sequence_state" ->
          Ok Sequence_state
      | "Snapp_uri" ->
          Ok Snapp_uri
      | "Token_symbol" ->
          Ok Token_symbol
      | "Permissions" ->
          Ok Permissions
      | "Nonce" ->
          Ok Nonce
      | "Voting_for" ->
          Ok Voting_for
      | _ ->
          Error
            "Signed_command_status.Failure.Permission.of_string: Unknown value"

    let describe = function
      | Balance ->
          "balance"
      | Timing_existing_account ->
          "timing because the account already exists"
      | Delegate ->
          "delegate"
      | App_state ->
          "app state"
      | Verification_key ->
          "verification key"
      | Sequence_state ->
          "sequence state"
      | Snapp_uri ->
          "snapp URI"
      | Token_symbol ->
          "token symbol"
      | Permissions ->
          "permissions"
      | Nonce ->
          "nonce"
      | Voting_for ->
          "voted-for state hash"
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
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
        | Signed_command_on_snapp_account
        | Snapp_account_not_present
        | Update_not_permitted of Permission.Stable.V1.t
        | Parties_replay_check_failed
        | Fee_payer_nonce_must_increase
        | Incorrect_nonce
        | Invalid_fee_excess
      [@@deriving sexp, yojson, equal, compare, variants, hash]

      let to_latest = Fn.id
    end
  end]

  type failure = t

  let failure_min = min

  let failure_max = max

  let all =
    let add acc var = var.Variantslib.Variant.constructor :: acc in
    Variants.fold ~init:[] ~predicate:add ~source_not_present:add
      ~receiver_not_present:add ~amount_insufficient_to_create_account:add
      ~cannot_pay_creation_fee_in_token:add ~source_insufficient_balance:add
      ~source_minimum_balance_violation:add ~receiver_already_exists:add
      ~not_token_owner:add ~mismatched_token_permissions:add ~overflow:add
      ~signed_command_on_snapp_account:add ~snapp_account_not_present:add
      ~update_not_permitted:(fun acc { Variantslib.Variant.constructor; _ } ->
        List.rev_append (List.rev_map ~f:constructor Permission.all) acc)
      ~parties_replay_check_failed:add ~fee_payer_nonce_must_increase:add
      ~incorrect_nonce:add ~invalid_fee_excess:add

  let gen = Quickcheck.Generator.of_list all

  let to_string x =
    match x with
    | Update_not_permitted permission ->
        sprintf "Update_not_permitted(%s)" (Permission.to_string permission)
    | _ ->
        Variants.to_name x

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
    | "Signed_command_on_snapp_account" ->
        Ok Signed_command_on_snapp_account
    | "Snapp_account_not_present" ->
        Ok Snapp_account_not_present
    | "Parties_replay_check_failed" ->
        Ok Parties_replay_check_failed
    | "Fee_payer_nonce_must_increase" ->
        Ok Fee_payer_nonce_must_increase
    | "Incorrect_nonce" ->
        Ok Incorrect_nonce
    | "Invalid_fee_excess" ->
        Ok Invalid_fee_excess
    | s ->
        let open Result.Let_syntax in
        let failure =
          Error "Signed_command_status.Failure.of_string: Unknown value"
        in
        let prefix = "Update_not_permitted(" in
        if String.is_prefix s ~prefix then
          let%bind permission =
            Permission.of_string
              (String.sub s ~pos:(String.length prefix)
                 ~len:(String.length s - String.length prefix - 1))
          in
          if Char.equal s.[String.length s - 1] ')' then
            Ok (Update_not_permitted permission)
          else failure
        else failure

  let%test_unit "of_string(to_string) roundtrip" =
    List.iter all ~f:(fun failure ->
        [%test_eq: (t, string) Result.t]
          (of_string (to_string failure))
          (Ok failure))

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
    | Signed_command_on_snapp_account ->
        "The source of a signed command cannot be a snapp account"
    | Snapp_account_not_present ->
        "A snapp account does not exist"
    | Update_not_permitted permission ->
        sprintf
          "The authentication for an account didn't allow the requested update \
           to its %s"
          (Permission.describe permission)
    | Parties_replay_check_failed ->
        "Check to avoid replays failed. The party must increment nonce or use \
         full commitment if the authorization is a signature"
    | Fee_payer_nonce_must_increase ->
        "Fee payer party must increment its nonce"
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
    module V1 = struct
      type t =
        { fee_payer_account_creation_fee_paid :
            Currency.Amount.Stable.V1.t option
        ; receiver_account_creation_fee_paid :
            Currency.Amount.Stable.V1.t option
        ; created_token : Token_id.Stable.V1.t option
        }
      [@@deriving sexp, yojson, equal, compare]

      let to_latest = Fn.id
    end
  end]

  let empty =
    { fee_payer_account_creation_fee_paid = None
    ; receiver_account_creation_fee_paid = None
    ; created_token = None
    }
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      | Applied of Auxiliary_data.Stable.V1.t * Balance_data.Stable.V1.t
      | Failed of Failure.Stable.V1.t * Balance_data.Stable.V1.t
    [@@deriving sexp, yojson, equal, compare]

    let to_latest = Fn.id
  end
end]

let balance_data = function
  | Applied (_, balances) | Failed (_, balances) ->
      balances
