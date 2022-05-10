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
          | Zkapp_uri
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
        ~zkapp_uri:add ~token_symbol:add ~permissions:add ~nonce:add
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
      | "Zkapp_uri" ->
          Ok Zkapp_uri
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
      | Zkapp_uri ->
          "zkApp URI"
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
        | Update_not_permitted of Permission.Stable.V1.t
        | Parties_replay_check_failed
        | Fee_payer_nonce_must_increase
        | Fee_payer_must_be_signed
        | Account_balance_precondition_unsatisfied
        | Account_nonce_precondition_unsatisfied
        | Account_receipt_chain_hash_precondition_unsatisfied
        | Account_delegate_precondition_unsatisfied
        | Account_sequence_state_precondition_unsatisfied
        | Account_app_state_precondition_unsatisfied of int
        | Account_proved_state_precondition_unsatisfied
        | Protocol_state_precondition_unsatisfied
        | Incorrect_nonce
        | Invalid_fee_excess
      [@@deriving sexp, yojson, equal, compare, variants, hash]

      let to_latest = Fn.id
    end
  end]

  module Collection = struct
    (* bin_io used to archive extensional blocks, doesn't need versioning *)
    type display = (int * Stable.Latest.t list) list
    [@@deriving equal, yojson, sexp, bin_io_unversioned]

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

  let all =
    let add acc var = var.Variantslib.Variant.constructor :: acc in
    Variants.fold ~init:[] ~predicate:add ~source_not_present:add
      ~receiver_not_present:add ~amount_insufficient_to_create_account:add
      ~cannot_pay_creation_fee_in_token:add ~source_insufficient_balance:add
      ~source_minimum_balance_violation:add ~receiver_already_exists:add
      ~token_owner_not_caller:add ~overflow:add ~global_excess_overflow:add
      ~local_excess_overflow:add ~signed_command_on_zkapp_account:add
      ~zkapp_account_not_present:add
      ~update_not_permitted:(fun acc { Variantslib.Variant.constructor; _ } ->
        List.rev_append (List.rev_map ~f:constructor Permission.all) acc)
      ~parties_replay_check_failed:add ~fee_payer_nonce_must_increase:add
      ~fee_payer_must_be_signed:add
      ~account_balance_precondition_unsatisfied:add
      ~account_nonce_precondition_unsatisfied:add
      ~account_receipt_chain_hash_precondition_unsatisfied:add
      ~account_delegate_precondition_unsatisfied:add
      ~account_sequence_state_precondition_unsatisfied:add
      ~account_app_state_precondition_unsatisfied:(fun acc var ->
        List.init 8 ~f:var.constructor @ acc)
      ~account_proved_state_precondition_unsatisfied:add
      ~protocol_state_precondition_unsatisfied:add ~incorrect_nonce:add
      ~invalid_fee_excess:add

  let gen = Quickcheck.Generator.of_list all

  let to_string x =
    match x with
    | Update_not_permitted permission ->
        sprintf "Update_not_permitted(%s)" (Permission.to_string permission)
    | Account_app_state_precondition_unsatisfied i ->
        sprintf "Account_app_state_%i_precondition_unsatisfied" i
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
    | "Parties_replay_check_failed" ->
        Ok Parties_replay_check_failed
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
    | "Protocol_state_precondition_unsatisfied" ->
        Ok Protocol_state_precondition_unsatisfied
    | "Incorrect_nonce" ->
        Ok Incorrect_nonce
    | "Invalid_fee_excess" ->
        Ok Invalid_fee_excess
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
                  for
                    i = String.length str - String.length suffix
                    to String.length str - 1
                  do
                    assert (Char.equal suffix.[i] str.[i])
                  done ;
                  parse
                    (String.sub str ~pos:(String.length prefix)
                       ~len:(String.length str - String.length suffix))))
            [ ( "Account_app_state"
              , "precondition_unsatisfied"
              , fun str ->
                  Account_app_state_precondition_unsatisfied (int_of_string str)
              )
            ; ( "Update_not_permitted("
              , ")"
              , fun x ->
                  Update_not_permitted
                    (Result.ok_or_failwith (Permission.of_string x)) )
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
    | Token_owner_not_caller ->
        "A party used a non-default token but its caller was not the token \
         owner"
    | Overflow ->
        "The resulting balance is too large to store"
    | Global_excess_overflow ->
        "The resulting global fee excess is too large to store"
    | Local_excess_overflow ->
        "The resulting local fee excess is too large to store"
    | Signed_command_on_zkapp_account ->
        "The source of a signed command cannot be a snapp account"
    | Zkapp_account_not_present ->
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
    | Fee_payer_must_be_signed ->
        "Fee payer party must have a valid signature"
    | Account_balance_precondition_unsatisfied ->
        "The party's account balance precondition was unsatisfied"
    | Account_nonce_precondition_unsatisfied ->
        "The party's account nonce precondition was unsatisfied"
    | Account_receipt_chain_hash_precondition_unsatisfied ->
        "The party's account receipt-chain hash precondition was unsatisfied"
    | Account_delegate_precondition_unsatisfied ->
        "The party's account delegate precondition was unsatisfied"
    | Account_sequence_state_precondition_unsatisfied ->
        "The party's account sequence state precondition was unsatisfied"
    | Account_app_state_precondition_unsatisfied i ->
        sprintf
          "The party's account app state (%i) precondition was unsatisfied" i
    | Account_proved_state_precondition_unsatisfied ->
        "The party's account proved state precondition was unsatisfied"
    | Protocol_state_precondition_unsatisfied ->
        "The party's protocol state precondition unsatisfied"
    | Incorrect_nonce ->
        "Incorrect nonce"
    | Invalid_fee_excess ->
        "Fee excess from parties transaction more than the transaction fees"
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t = Applied | Failed of Failure.Collection.Stable.V1.t
    [@@deriving sexp, yojson, equal, compare]

    let to_latest = Fn.id
  end
end]
