[%%import "/src/config.mlh"]

open Core_kernel

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
        | Token_owner_not_caller
        | Overflow
        | Global_excess_overflow
        | Local_excess_overflow
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
      [@@deriving sexp, yojson, equal, compare, variants, hash]

      let to_latest = Fn.id
    end
  end]

  module Collection = struct
    module Display = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t = (int * Stable.V2.t list) list
          [@@deriving equal, compare, yojson, sexp, hash]

          let to_latest = Fn.id
        end
      end]
    end

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Stable.V2.t list list
        [@@deriving equal, compare, yojson, sexp, hash]

        let to_latest = Fn.id
      end
    end]

    let to_display t : Display.t =
      let _, display =
        List.fold_right t ~init:(0, []) ~f:(fun bucket (index, acc) ->
            if List.is_empty bucket then (index + 1, acc)
            else (index + 1, (index, bucket) :: acc) )
      in
      display

    let empty = []

    let of_single_failure f : t = [ [ f ] ]

    let is_empty : t -> bool = Fn.compose List.is_empty List.concat
  end

  type failure = t

  let failure_min = min

  let failure_max = max

  let all =
    let add acc var = var.Variantslib.Variant.constructor :: acc in
    Variants.fold ~init:[] ~predicate:add ~source_not_present:add
      ~receiver_not_present:add ~amount_insufficient_to_create_account:add
      ~cannot_pay_creation_fee_in_token:add ~source_insufficient_balance:add
      ~source_minimum_balance_violation:add ~receiver_already_exists:add
      ~token_owner_not_caller:add ~overflow:add ~global_excess_overflow:add
      ~local_excess_overflow:add ~signed_command_on_zkapp_account:add
      ~zkapp_account_not_present:add ~update_not_permitted_balance:add
      ~update_not_permitted_timing_existing_account:add
      ~update_not_permitted_delegate:add ~update_not_permitted_app_state:add
      ~update_not_permitted_verification_key:add
      ~update_not_permitted_sequence_state:add
      ~update_not_permitted_zkapp_uri:add ~update_not_permitted_token_symbol:add
      ~update_not_permitted_permissions:add ~update_not_permitted_nonce:add
      ~update_not_permitted_voting_for:add
      ~zkapp_command_replay_check_failed:add ~fee_payer_nonce_must_increase:add
      ~fee_payer_must_be_signed:add
      ~account_balance_precondition_unsatisfied:add
      ~account_nonce_precondition_unsatisfied:add
      ~account_receipt_chain_hash_precondition_unsatisfied:add
      ~account_delegate_precondition_unsatisfied:add
      ~account_sequence_state_precondition_unsatisfied:add
      ~account_app_state_precondition_unsatisfied:(fun acc var ->
        List.init 8 ~f:var.constructor @ acc )
      ~account_proved_state_precondition_unsatisfied:add
      ~account_is_new_precondition_unsatisfied:add
      ~protocol_state_precondition_unsatisfied:add ~incorrect_nonce:add
      ~invalid_fee_excess:add ~cancelled:add

  let gen = Quickcheck.Generator.of_list all

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
    | Token_owner_not_caller ->
        "Token_owner_not_caller"
    | Overflow ->
        "Overflow"
    | Global_excess_overflow ->
        "Global_excess_overflow"
    | Local_excess_overflow ->
        "Local_excess_overflow"
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
    | Zkapp_command_replay_check_failed ->
        "Zkapp_command_replay_check_failed"
    | Fee_payer_nonce_must_increase ->
        "Fee_payer_nonce_must_increase"
    | Fee_payer_must_be_signed ->
        "Fee_payer_must_be_signed"
    | Account_balance_precondition_unsatisfied ->
        "Account_balance_precondition_unsatisfied"
    | Account_nonce_precondition_unsatisfied ->
        "Account_nonce_precondition_unsatisfied"
    | Account_receipt_chain_hash_precondition_unsatisfied ->
        "Account_receipt_chain_hash_precondition_unsatisfied"
    | Account_delegate_precondition_unsatisfied ->
        "Account_delegate_precondition_unsatisfied"
    | Account_sequence_state_precondition_unsatisfied ->
        "Account_sequence_state_precondition_unsatisfied"
    | Account_app_state_precondition_unsatisfied i ->
        sprintf "Account_app_state_%i_precondition_unsatisfied" i
    | Account_proved_state_precondition_unsatisfied ->
        "Account_proved_state_precondition_unsatisfied"
    | Account_is_new_precondition_unsatisfied ->
        "Account_is_new_precondition_unsatisfied"
    | Protocol_state_precondition_unsatisfied ->
        "Protocol_state_precondition_unsatisfied"
    | Incorrect_nonce ->
        "Incorrect_nonce"
    | Invalid_fee_excess ->
        "Invalid_fee_excess"
    | Cancelled ->
        "Cancelled"

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
    | "Token_owner_not_caller" ->
        Ok Token_owner_not_caller
    | "Overflow" ->
        Ok Overflow
    | "Global_excess_overflow" ->
        Ok Global_excess_overflow
    | "Local_excess_overflow" ->
        Ok Local_excess_overflow
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
    | "Zkapp_command_replay_check_failed" ->
        Ok Zkapp_command_replay_check_failed
    | "Fee_payer_nonce_must_increase" ->
        Ok Fee_payer_nonce_must_increase
    | "Fee_payer_must_be_signed" ->
        Ok Fee_payer_must_be_signed
    | "Account_balance_precondition_unsatisfied" ->
        Ok Account_balance_precondition_unsatisfied
    | "Account_nonce_precondition_unsatisfied" ->
        Ok Account_nonce_precondition_unsatisfied
    | "Account_receipt_chain_hash_precondition_unsatisfied" ->
        Ok Account_receipt_chain_hash_precondition_unsatisfied
    | "Account_delegate_precondition_unsatisfied" ->
        Ok Account_delegate_precondition_unsatisfied
    | "Account_sequence_state_precondition_unsatisfied" ->
        Ok Account_sequence_state_precondition_unsatisfied
    | "Account_proved_state_precondition_unsatisfied" ->
        Ok Account_proved_state_precondition_unsatisfied
    | "Account_is_new_precondition_unsatisfied" ->
        Ok Account_is_new_precondition_unsatisfied
    | "Protocol_state_precondition_unsatisfied" ->
        Ok Protocol_state_precondition_unsatisfied
    | "Incorrect_nonce" ->
        Ok Incorrect_nonce
    | "Invalid_fee_excess" ->
        Ok Invalid_fee_excess
    | "Cancelled" ->
        Ok Cancelled
    | str -> (
        let res =
          List.find_map
            ~f:(fun (prefix, suffix, parse) ->
              Option.try_with (fun () ->
                  assert (
                    String.length str
                    >= String.length prefix + String.length suffix ) ;
                  for i = 0 to String.length prefix - 1 do
                    assert (Char.equal prefix.[i] str.[i])
                  done ;
                  let offset = String.length str - String.length suffix in
                  for i = 0 to String.length suffix - 1 do
                    assert (Char.equal suffix.[i] str.[offset + i])
                  done ;
                  parse
                    (String.sub str ~pos:(String.length prefix)
                       ~len:(offset - String.length prefix) ) ) )
            [ ( "Account_app_state_"
              , "_precondition_unsatisfied"
              , fun str ->
                  Account_app_state_precondition_unsatisfied (int_of_string str)
              )
            ]
        in
        match res with
        | Some res ->
            Ok res
        | None ->
            Error "Transaction_status.Failure.of_string: Unknown value" )

  let%test_unit "of_string(to_string) roundtrip" =
    List.iter all ~f:(fun failure ->
        [%test_eq: (t, string) Result.t]
          (of_string (to_string failure))
          (Ok failure) )

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
    | Token_owner_not_caller ->
        "An account update used a non-default token but its caller was not the \
         token owner"
    | Overflow ->
        "The resulting balance is too large to store"
    | Global_excess_overflow ->
        "The resulting global fee excess is too large to store"
    | Local_excess_overflow ->
        "The resulting local fee excess is too large to store"
    | Signed_command_on_zkapp_account ->
        "The source of a signed command cannot be a snapp account"
    | Zkapp_account_not_present ->
        "A zkApp account does not exist"
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
    | Zkapp_command_replay_check_failed ->
        "Check to avoid replays failed. The account update must increment \
         nonce or use full commitment if the authorization is a signature"
    | Fee_payer_nonce_must_increase ->
        "Fee payer account update must increment its nonce"
    | Fee_payer_must_be_signed ->
        "Fee payer account update must have a valid signature"
    | Account_balance_precondition_unsatisfied ->
        "The account update's account balance precondition was unsatisfied"
    | Account_nonce_precondition_unsatisfied ->
        "The account update's account nonce precondition was unsatisfied"
    | Account_receipt_chain_hash_precondition_unsatisfied ->
        "The account update's account receipt-chain hash precondition was \
         unsatisfied"
    | Account_delegate_precondition_unsatisfied ->
        "The account update's account delegate precondition was unsatisfied"
    | Account_sequence_state_precondition_unsatisfied ->
        "The account update's account sequence state precondition was \
         unsatisfied"
    | Account_app_state_precondition_unsatisfied i ->
        sprintf
          "The account update's account app state (%i) precondition was \
           unsatisfied"
          i
    | Account_proved_state_precondition_unsatisfied ->
        "The account update's account proved state precondition was unsatisfied"
    | Account_is_new_precondition_unsatisfied ->
        "The account update's account is-new state precondition was unsatisfied"
    | Protocol_state_precondition_unsatisfied ->
        "The account update's protocol state precondition unsatisfied"
    | Incorrect_nonce ->
        "Incorrect nonce"
    | Invalid_fee_excess ->
        "Fee excess from zkapp_command transaction more than the transaction \
         fees"
    | Cancelled ->
        "The account update is cancelled because there's a failure in the \
         zkApp transaction"
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t = Applied | Failed of Failure.Collection.Stable.V1.t
    [@@deriving sexp, yojson, equal, compare]

    let to_latest = Fn.id
  end
end]
