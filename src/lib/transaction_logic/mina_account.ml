open Core_kernel
open Mina_base
open Currency
module Global_slot = Mina_numbers.Global_slot

(* tags for timing validation errors *)
let nsf_tag = "nsf"

let min_balance_tag = "minbal"

let timing_error_to_user_command_status err =
  match Error.Internal_repr.of_info err with
  | Tag_t (tag, _) when String.equal tag nsf_tag ->
      Transaction_status.Failure.Source_insufficient_balance
  | Tag_t (tag, _) when String.equal tag min_balance_tag ->
      Transaction_status.Failure.Source_minimum_balance_violation
  | _ ->
      failwith "Unexpected timed account validation error"

(** [validate_timing_with_min_balance' ~account ~txn_amount ~txn_global_slot]
    returns a tuple of 3 values:
    * [[`Insufficient_balance of bool | `Invalid_timing of bool]] encodes
      possible errors, with the invariant that the return value is always
      [`Invalid_timing false] if there was no error.
    - [`Insufficient_balance true] results if [txn_amount] is larger than the
        balance held in [account].
    - [`Invalid_timing true] results if [txn_amount] is larger than the
        balance available in [account] at global slot [txn_global_slot].
    * [Timing.t], the new timing for [account] calculated at [txn_global_slot].
    * [[`Min_balance of Balance.t]] returns the computed available balance at
      [txn_global_slot].
    - NOTE: We skip this calculation if the error is
        [`Insufficient_balance true].  In this scenario, this value MUST NOT be
        used, as it contains an incorrect placeholder value.
*)
let validate_timing_with_min_balance' ~account ~txn_amount ~txn_global_slot =
  let open Account.Poly in
  let open Account.Timing.Poly in
  match account.timing with
  | Untimed -> (
      (* no time restrictions *)
      match Balance.(account.balance - txn_amount) with
      | None ->
          (`Insufficient_balance true, Untimed, `Min_balance Balance.zero)
      | _ ->
          (`Invalid_timing false, Untimed, `Min_balance Balance.zero) )
  | Timed
      { initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      } ->
      let invalid_balance, invalid_timing, curr_min_balance =
        let account_balance = account.balance in
        match Balance.(account_balance - txn_amount) with
        | None ->
            (* NB: The [initial_minimum_balance] here is the incorrect value,
               but:
               * we don't use it anywhere in this error case; and
               * we don't want to waste time computing it if it will be unused.
            *)
            (true, false, initial_minimum_balance)
        | Some proposed_new_balance ->
            let curr_min_balance =
              Account.min_balance_at_slot ~global_slot:txn_global_slot
                ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
                ~initial_minimum_balance
            in
            if Balance.(proposed_new_balance < curr_min_balance) then
              (false, true, curr_min_balance)
            else (false, false, curr_min_balance)
      in
      (* once the calculated minimum balance becomes zero, the account becomes untimed *)
      let possibly_error =
        if invalid_balance then `Insufficient_balance invalid_balance
        else `Invalid_timing invalid_timing
      in
      if Balance.(curr_min_balance > zero) then
        (possibly_error, account.timing, `Min_balance curr_min_balance)
      else (possibly_error, Untimed, `Min_balance Balance.zero)

let validate_timing_with_min_balance ~account ~txn_amount ~txn_global_slot =
  let open Or_error.Let_syntax in
  let nsf_error kind =
    Or_error.errorf
      !"For %s account, the requested transaction for amount %{sexp: Amount.t} \
        at global slot %{sexp: Global_slot.t}, the balance %{sexp: Balance.t} \
        is insufficient"
      kind txn_amount txn_global_slot account.Account.Poly.balance
    |> Or_error.tag ~tag:nsf_tag
  in
  let min_balance_error min_balance =
    Or_error.errorf
      !"For timed account, the requested transaction for amount %{sexp: \
        Amount.t} at global slot %{sexp: Global_slot.t}, applying the \
        transaction would put the balance below the calculated minimum balance \
        of %{sexp: Balance.t}"
      txn_amount txn_global_slot min_balance
    |> Or_error.tag ~tag:min_balance_tag
  in
  let possibly_error, timing, (`Min_balance curr_min_balance as min_balance) =
    validate_timing_with_min_balance' ~account ~txn_amount ~txn_global_slot
  in
  match possibly_error with
  | `Insufficient_balance true ->
      nsf_error "timed"
  | `Invalid_timing true ->
      min_balance_error curr_min_balance
  | `Insufficient_balance false ->
      failwith "Broken invariant in validate_timing_with_min_balance'"
  | `Invalid_timing false ->
      return (timing, min_balance)

let validate_timing ~account ~txn_amount ~txn_global_slot =
  let open Result.Let_syntax in
  let%map timing, `Min_balance _ =
    validate_timing_with_min_balance ~account ~txn_amount ~txn_global_slot
  in
  timing

let value_if b ~then_ ~else_ = if b then then_ else else_

module Controller = struct
  type t = Permissions.Auth_required.t

  let if_ b ~then_ ~else_ = if b then then_ else else_

  (* TODO: Type safety can be improved by turning these boolean arguments
           into a single variant. *)
  let check ~proof_verifies ~signature_verifies perm =
    (* Invariant: We either have a proof, a signature, or neither. *)
    assert (not (proof_verifies && signature_verifies)) ;
    let tag =
      if proof_verifies then Control.Tag.Proof
      else if signature_verifies then Control.Tag.Signature
      else Control.Tag.None_given
    in
    Permissions.Auth_required.check perm tag
end

module Account = struct
  include Account

  module Permissions = struct
    let access : t -> Controller.t = fun a -> a.permissions.access

    let edit_state : t -> Controller.t = fun a -> a.permissions.edit_state

    let send : t -> Controller.t = fun a -> a.permissions.send

    let receive : t -> Controller.t = fun a -> a.permissions.receive

    let set_delegate : t -> Controller.t = fun a -> a.permissions.set_delegate

    let set_permissions : t -> Controller.t =
     fun a -> a.permissions.set_permissions

    let set_verification_key : t -> Controller.t =
     fun a -> a.permissions.set_verification_key

    let set_zkapp_uri : t -> Controller.t = fun a -> a.permissions.set_zkapp_uri

    let edit_sequence_state : t -> Controller.t =
     fun a -> a.permissions.edit_sequence_state

    let set_token_symbol : t -> Controller.t =
     fun a -> a.permissions.set_token_symbol

    let increment_nonce : t -> Controller.t =
     fun a -> a.permissions.increment_nonce

    let set_voting_for : t -> Controller.t =
     fun a -> a.permissions.set_voting_for

    let set_timing : t -> Controller.t = fun a -> a.permissions.set_timing

    type t = Permissions.t

    let if_ = value_if
  end

  type timing = Account_update.Update.Timing_info.t option

  let timing (a : t) : timing =
    Account_update.Update.Timing_info.of_account_timing a.timing

  let set_timing (a : t) (timing : timing) : t =
    { a with
      timing =
        Option.value_map ~default:Account_timing.Untimed
          ~f:Account_update.Update.Timing_info.to_account_timing timing
    }

  let is_timed (a : t) =
    match a.timing with Account_timing.Untimed -> false | _ -> true

  let set_token_id (a : t) (id : Token_id.t) : t = { a with token_id = id }

  let balance (a : t) : Balance.t = a.balance

  let set_balance (balance : Balance.t) (a : t) : t = { a with balance }

  let check_timing ~txn_global_slot account =
    let invalid_timing, timing, _ =
      validate_timing_with_min_balance' ~txn_amount:Amount.zero ~txn_global_slot
        ~account
    in
    (invalid_timing, Account_update.Update.Timing_info.of_account_timing timing)

  let receipt_chain_hash (a : t) : Receipt.Chain_hash.t = a.receipt_chain_hash

  let set_receipt_chain_hash (a : t) hash = { a with receipt_chain_hash = hash }

  let make_zkapp (a : t) =
    let zkapp =
      match a.zkapp with
      | None ->
          Some Zkapp_account.default
      | Some _ as zkapp ->
          zkapp
    in
    { a with zkapp }

  let unmake_zkapp (a : t) : t =
    let zkapp =
      match a.zkapp with
      | None ->
          None
      | Some zkapp ->
          if Zkapp_account.(equal default zkapp) then None else Some zkapp
    in
    { a with zkapp }

  let get_zkapp (a : t) = Option.value_exn a.zkapp

  let set_zkapp (a : t) ~f : t = { a with zkapp = Option.map a.zkapp ~f }

  let proved_state (a : t) = (get_zkapp a).proved_state

  let set_proved_state proved_state (a : t) =
    set_zkapp a ~f:(fun zkapp -> { zkapp with proved_state })

  let app_state (a : t) = (get_zkapp a).app_state

  let set_app_state app_state (a : t) =
    set_zkapp a ~f:(fun zkapp -> { zkapp with app_state })

  let register_verification_key (_ : t) = ()

  let verification_key (a : t) = (get_zkapp a).verification_key

  let set_verification_key verification_key (a : t) =
    set_zkapp a ~f:(fun zkapp -> { zkapp with verification_key })

  let verification_key_hash (a : t) =
    match a.zkapp with
    | None ->
        None
    | Some zkapp ->
        Option.map zkapp.verification_key ~f:With_hash.hash

  let last_sequence_slot (a : t) = (get_zkapp a).last_sequence_slot

  let set_last_sequence_slot last_sequence_slot (a : t) =
    set_zkapp a ~f:(fun zkapp -> { zkapp with last_sequence_slot })

  let sequence_state (a : t) = (get_zkapp a).sequence_state

  let set_sequence_state sequence_state (a : t) =
    set_zkapp a ~f:(fun zkapp -> { zkapp with sequence_state })

  let zkapp_uri (a : t) =
    Option.value_map a.zkapp ~default:"" ~f:(fun zkapp -> zkapp.zkapp_uri)

  let set_zkapp_uri zkapp_uri (a : t) : t =
    { a with
      zkapp = Option.map a.zkapp ~f:(fun zkapp -> { zkapp with zkapp_uri })
    }

  let token_symbol (a : t) = a.token_symbol

  let set_token_symbol token_symbol (a : t) = { a with token_symbol }

  let public_key (a : t) = a.public_key

  let set_public_key public_key (a : t) = { a with public_key }

  let delegate (a : t) = Account.delegate_opt a.delegate

  let set_delegate delegate (a : t) =
    let delegate =
      if Signature_lib.Public_key.Compressed.(equal empty) delegate then None
      else Some delegate
    in
    { a with delegate }

  let nonce (a : t) = a.nonce

  let set_nonce nonce (a : t) = { a with nonce }

  let voting_for (a : t) = a.voting_for

  let set_voting_for voting_for (a : t) = { a with voting_for }

  let permissions (a : t) = a.permissions

  let set_permissions permissions (a : t) = { a with permissions }
end

module Update = struct
  include Account_update

  module Account_precondition = struct
    include Account_update.Account_precondition

    let nonce (t : Account_update.t) = nonce t.body.preconditions.account
  end

  type 'a or_ignore = 'a Zkapp_basic.Or_ignore.t

  type call_forest = Zkapp_call_forest.t

  let may_use_parents_own_token (p : t) =
    May_use_token.parents_own_token p.body.may_use_token

  let may_use_token_inherited_from_parent (p : t) =
    May_use_token.inherit_from_parent p.body.may_use_token

  let check_authorization ~will_succeed:_ ~commitment:_ ~calls:_
      (account_update : t) =
    (* The transaction's validity should already have been checked before
       this point.
    *)
    match account_update.authorization with
    | Signature _ ->
        (`Proof_verifies false, `Signature_verifies true)
    | Proof _ ->
        (`Proof_verifies true, `Signature_verifies false)
    | None_given ->
        (`Proof_verifies false, `Signature_verifies false)

  let is_proved (account_update : t) =
    match account_update.body.authorization_kind with
    | Proof _ ->
        true
    | Signature | None_given ->
        false

  let is_signed (account_update : t) =
    match account_update.body.authorization_kind with
    | Signature ->
        true
    | Proof _ | None_given ->
        false

  let verification_key_hash (p : t) =
    match p.body.authorization_kind with
    | Proof vk_hash ->
        Some vk_hash
    | _ ->
        None

  module Update = struct
    open Zkapp_basic

    type 'a set_or_keep = 'a Zkapp_basic.Set_or_keep.t

    let timing (account_update : t) : Account.timing set_or_keep =
      Set_or_keep.map ~f:Option.some account_update.body.update.timing

    let app_state (account_update : t) = account_update.body.update.app_state

    let verification_key (account_update : t) =
      Zkapp_basic.Set_or_keep.map ~f:Option.some
        account_update.body.update.verification_key

    let actions (account_update : t) = account_update.body.actions

    let zkapp_uri (account_update : t) = account_update.body.update.zkapp_uri

    let token_symbol (account_update : t) =
      account_update.body.update.token_symbol

    let delegate (account_update : t) = account_update.body.update.delegate

    let voting_for (account_update : t) = account_update.body.update.voting_for

    let permissions (account_update : t) =
      account_update.body.update.permissions
  end
end
