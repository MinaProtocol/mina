open Core_kernel
open Currency
open Signature_lib
module Global_slot = Mina_numbers.Global_slot

type account_state = [ `Added | `Existed ] [@@deriving equal]

module type Ledger_intf = sig
  type t

  type location

  val get : t -> location -> Account.t option

  val location_of_account : t -> Account_id.t -> location option

  val set : t -> location -> Account.t -> unit

  val get_or_create :
    t -> Account_id.t -> (account_state * Account.t * location) Or_error.t

  val create_new_account : t -> Account_id.t -> Account.t -> unit Or_error.t

  val remove_accounts_exn : t -> Account_id.t list -> unit

  val merkle_root : t -> Ledger_hash.t

  val with_ledger : depth:int -> f:(t -> 'a) -> 'a

  val next_available_token : t -> Token_id.t

  val set_next_available_token : t -> Token_id.t -> unit

  val empty : depth:int -> unit -> t

  val create_masked : t -> t

  val apply_mask : t -> masked:t -> unit
end

module Transaction_applied = struct
  module UC = Signed_command

  module Signed_command_applied = struct
    module Common = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t =
            { user_command : Signed_command.Stable.V1.t With_status.Stable.V1.t
            ; previous_receipt_chain_hash : Receipt.Chain_hash.Stable.V1.t
            ; fee_payer_timing : Account.Timing.Stable.V1.t
            ; source_timing : Account.Timing.Stable.V1.t option
            }
          [@@deriving sexp]

          let to_latest = Fn.id
        end
      end]
    end

    module Body = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t =
            | Payment of
                { previous_empty_accounts : Account_id.Stable.V1.t list }
            | Stake_delegation of
                { previous_delegate : Public_key.Compressed.Stable.V1.t option }
            | Create_new_token of { created_token : Token_id.Stable.V1.t }
            | Create_token_account
            | Mint_tokens
            | Failed
          [@@deriving sexp]

          let to_latest = Fn.id
        end
      end]
    end

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = { common : Common.Stable.V1.t; body : Body.Stable.V1.t }
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]
  end

  module Snapp_command_applied = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          { accounts :
              (Account_id.Stable.V1.t * Account.Stable.V2.t option) list
          ; command : Snapp_command.Stable.V2.t With_status.Stable.V1.t
          }
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]
  end

  module Parties_applied = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { accounts :
              (Account_id.Stable.V1.t * Account.Stable.V2.t option) list
          ; command : Parties.Stable.V1.t With_status.Stable.V1.t
          }
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]
  end

  module Command_applied = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          | Signed_command of Signed_command_applied.Stable.V1.t
          | Parties of Parties_applied.Stable.V1.t
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]
  end

  module Fee_transfer_applied = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { fee_transfer : Fee_transfer.Stable.V1.t
          ; previous_empty_accounts : Account_id.Stable.V1.t list
          ; receiver_timing : Account.Timing.Stable.V1.t
          ; balances : Transaction_status.Fee_transfer_balance_data.Stable.V1.t
          }
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]
  end

  module Coinbase_applied = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { coinbase : Coinbase.Stable.V1.t
          ; previous_empty_accounts : Account_id.Stable.V1.t list
          ; receiver_timing : Account.Timing.Stable.V1.t
          ; balances : Transaction_status.Coinbase_balance_data.Stable.V1.t
          }
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]
  end

  module Varying = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          | Command of Command_applied.Stable.V2.t
          | Fee_transfer of Fee_transfer_applied.Stable.V1.t
          | Coinbase of Coinbase_applied.Stable.V1.t
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { previous_hash : Ledger_hash.Stable.V1.t
        ; varying : Varying.Stable.V2.t
        }
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]

  let transaction_with_status : t -> Transaction.t With_status.t =
   fun { varying; _ } ->
    match varying with
    | Command (Signed_command uc) ->
        With_status.map uc.common.user_command ~f:(fun cmd ->
            Transaction.Command (User_command.Signed_command cmd))
    | Command (Parties s) ->
        With_status.map s.command ~f:(fun c ->
            Transaction.Command (User_command.Parties c))
    | Fee_transfer f ->
        { data = Fee_transfer f.fee_transfer
        ; status =
            Applied
              ( Transaction_status.Auxiliary_data.empty
              , Transaction_status.Fee_transfer_balance_data.to_balance_data
                  f.balances )
        }
    | Coinbase c ->
        { data = Coinbase c.coinbase
        ; status =
            Applied
              ( Transaction_status.Auxiliary_data.empty
              , Transaction_status.Coinbase_balance_data.to_balance_data
                  c.balances )
        }

  let user_command_status : t -> Transaction_status.t =
   fun { varying; _ } ->
    match varying with
    | Command
        (Signed_command { common = { user_command = { status; _ }; _ }; _ }) ->
        status
    | Command (Parties c) ->
        c.command.status
    | Fee_transfer f ->
        Applied
          ( Transaction_status.Auxiliary_data.empty
          , Transaction_status.Fee_transfer_balance_data.to_balance_data
              f.balances )
    | Coinbase c ->
        Applied
          ( Transaction_status.Auxiliary_data.empty
          , Transaction_status.Coinbase_balance_data.to_balance_data c.balances
          )
end

module type S = sig
  type ledger

  module Transaction_applied : sig
    module Signed_command_applied : sig
      module Common : sig
        type t = Transaction_applied.Signed_command_applied.Common.t =
          { user_command : Signed_command.t With_status.t
          ; previous_receipt_chain_hash : Receipt.Chain_hash.t
          ; fee_payer_timing : Account.Timing.t
          ; source_timing : Account.Timing.t option
          }
        [@@deriving sexp]
      end

      module Body : sig
        type t = Transaction_applied.Signed_command_applied.Body.t =
          | Payment of { previous_empty_accounts : Account_id.t list }
          | Stake_delegation of
              { previous_delegate : Public_key.Compressed.t option }
          | Create_new_token of { created_token : Token_id.t }
          | Create_token_account
          | Mint_tokens
          | Failed
        [@@deriving sexp]
      end

      type t = Transaction_applied.Signed_command_applied.t =
        { common : Common.t; body : Body.t }
      [@@deriving sexp]
    end

    module Parties_applied : sig
      type t = Transaction_applied.Parties_applied.t =
        { accounts : (Account_id.t * Account.t option) list
        ; command : Parties.t With_status.t
        }
      [@@deriving sexp]
    end

    module Command_applied : sig
      type t = Transaction_applied.Command_applied.t =
        | Signed_command of Signed_command_applied.t
        | Parties of Parties_applied.t
      [@@deriving sexp]
    end

    module Fee_transfer_applied : sig
      type t = Transaction_applied.Fee_transfer_applied.t =
        { fee_transfer : Fee_transfer.t
        ; previous_empty_accounts : Account_id.t list
        ; receiver_timing : Account.Timing.t
        ; balances : Transaction_status.Fee_transfer_balance_data.t
        }
      [@@deriving sexp]
    end

    module Coinbase_applied : sig
      type t = Transaction_applied.Coinbase_applied.t =
        { coinbase : Coinbase.t
        ; previous_empty_accounts : Account_id.t list
        ; receiver_timing : Account.Timing.t
        ; balances : Transaction_status.Coinbase_balance_data.t
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

    val transaction : t -> Transaction.t With_status.t

    val user_command_status : t -> Transaction_status.t
  end

  module Global_state : sig
    type t =
      { ledger : ledger
      ; fee_excess : Amount.Signed.t
      ; protocol_state : Snapp_predicate.Protocol_state.View.t
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

  val apply_parties_unchecked :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> state_view:Snapp_predicate.Protocol_state.View.t
    -> ledger
    -> Parties.t
    -> ( Transaction_applied.Parties_applied.t
       * ( ( (Party.t, unit) Parties.Call_forest.t
           , (Party.t, unit) Parties.Call_forest.t list
           , Token_id.t
           , Amount.t
           , ledger
           , bool
           , unit
           , Transaction_status.Failure.t option )
           Parties_logic.Local_state.t
         * Amount.Signed.t ) )
       Or_error.t

  (** Apply all parties within a parties transaction. This behaves as
      [apply_parties_unchecked], except that the [~init] and [~f] arguments
      are provided to allow for the accumulation of the intermediate states.

      Invariant: [f] is always applied at least once, so it is valid to use an
      [_ option] as the initial state and call [Option.value_exn] on the
      accumulated result.

      This can be used to collect the intermediate states to make them
      available for snark work. In particular, since the transaction snark has
      a cap on the number of parties of each kind that may be included, we can
      use this to retrieve the (source, target) pairs for each batch of
      parties to include in the snark work spec / transaction snark witness.
  *)
  val apply_parties_unchecked_aux :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> state_view:Snapp_predicate.Protocol_state.View.t
    -> init:'acc
    -> f:
         (   'acc
          -> Global_state.t
             * ( (Party.t, unit) Parties.Call_forest.t
               , (Party.t, unit) Parties.Call_forest.t list
               , Token_id.t
               , Amount.t
               , ledger
               , bool
               , unit
               , Transaction_status.Failure.t option )
               Parties_logic.Local_state.t
          -> 'acc)
    -> ?fee_excess:Amount.Signed.t
    -> ledger
    -> Parties.t
    -> (Transaction_applied.Parties_applied.t * 'acc) Or_error.t

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
    -> txn_state_view:Snapp_predicate.Protocol_state.View.t
    -> ledger
    -> Transaction.t
    -> Transaction_applied.t Or_error.t

  val merkle_root_after_parties_exn :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_state_view:Snapp_predicate.Protocol_state.View.t
    -> ledger
    -> Parties.Valid.t
    -> Ledger_hash.t * [ `Next_available_token of Token_id.t ]

  val merkle_root_after_user_command_exn :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Global_slot.t
    -> ledger
    -> Signed_command.With_valid_signature.t
    -> Ledger_hash.t * [ `Next_available_token of Token_id.t ]

  val undo :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> ledger
    -> Transaction_applied.t
    -> unit Or_error.t

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

module Make (L : Ledger_intf) : S with type ledger := L.t = struct
  open L

  let error s = Or_error.errorf "Ledger.apply_transaction: %s" s

  let error_opt e = Option.value_map ~default:(error e) ~f:Or_error.return

  let get_with_location ledger account_id =
    match location_of_account ledger account_id with
    | Some location -> (
        match get ledger location with
        | Some account ->
            Ok (`Existing location, account)
        | None ->
            (* Needed to support sparse ledger. *)
            Ok (`New, Account.create account_id Balance.zero) )
    | None ->
        Ok (`New, Account.create account_id Balance.zero)

  let set_with_location ledger location account =
    match location with
    | `Existing location ->
        Ok (set ledger location account)
    | `New ->
        create_new_account ledger (Account.identifier account) account

  let get' ledger tag location =
    error_opt (sprintf "%s account not found" tag) (get ledger location)

  let location_of_account' ledger tag key =
    error_opt
      (sprintf "%s location not found" tag)
      (location_of_account ledger key)

  let add_amount balance amount =
    error_opt "overflow" (Balance.add_amount balance amount)

  let sub_amount balance amount =
    error_opt "insufficient funds" (Balance.sub_amount balance amount)

  let sub_account_creation_fee
      ~(constraint_constants : Genesis_constants.Constraint_constants.t) action
      amount =
    let fee = constraint_constants.account_creation_fee in
    if equal_account_state action `Added then
      error_opt
        (sprintf
           !"Error subtracting account creation fee %{sexp: Currency.Fee.t}; \
             transaction amount %{sexp: Currency.Amount.t} insufficient"
           fee amount)
        Amount.(sub amount (of_fee fee))
    else Ok amount

  let check b = ksprintf (fun s -> if b then Ok () else Or_error.error_string s)

  let validate_nonces txn_nonce account_nonce =
    check
      (Account.Nonce.equal account_nonce txn_nonce)
      !"Nonce in account %{sexp: Account.Nonce.t} different from nonce in \
        transaction %{sexp: Account.Nonce.t}"
      account_nonce txn_nonce

  let validate_time ~valid_until ~current_global_slot =
    check
      Global_slot.(current_global_slot <= valid_until)
      !"Current global slot %{sexp: Global_slot.t} greater than transaction \
        expiry slot %{sexp: Global_slot.t}"
      current_global_slot valid_until

  module Transaction_applied = struct
    include Transaction_applied

    let transaction : t -> Transaction.t With_status.t =
     fun { varying; _ } ->
      match varying with
      | Command (Signed_command uc) ->
          With_status.map uc.common.user_command ~f:(fun cmd ->
              Transaction.Command (User_command.Signed_command cmd))
      | Command (Parties s) ->
          With_status.map s.command ~f:(fun c ->
              Transaction.Command (User_command.Parties c))
      | Fee_transfer f ->
          { data = Fee_transfer f.fee_transfer
          ; status =
              Applied
                ( Transaction_status.Auxiliary_data.empty
                , Transaction_status.Fee_transfer_balance_data.to_balance_data
                    f.balances )
          }
      | Coinbase c ->
          { data = Coinbase c.coinbase
          ; status =
              Applied
                ( Transaction_status.Auxiliary_data.empty
                , Transaction_status.Coinbase_balance_data.to_balance_data
                    c.balances )
          }

    let user_command_status : t -> Transaction_status.t =
     fun { varying; _ } ->
      match varying with
      | Command
          (Signed_command { common = { user_command = { status; _ }; _ }; _ })
        ->
          status
      | Command (Parties c) ->
          c.command.status
      | Fee_transfer f ->
          Applied
            ( Transaction_status.Auxiliary_data.empty
            , Transaction_status.Fee_transfer_balance_data.to_balance_data
                f.balances )
      | Coinbase c ->
          Applied
            ( Transaction_status.Auxiliary_data.empty
            , Transaction_status.Coinbase_balance_data.to_balance_data
                c.balances )
  end

  let previous_empty_accounts action pk =
    if equal_account_state action `Added then [ pk ] else []

  let has_locked_tokens ~global_slot ~account_id ledger =
    let open Or_error.Let_syntax in
    let%map _, account = get_with_location ledger account_id in
    Account.has_locked_tokens ~global_slot account

  let get_user_account_with_location ledger account_id =
    let open Or_error.Let_syntax in
    let%bind ((_, acct) as r) = get_with_location ledger account_id in
    let%map () =
      check
        (Option.is_none acct.snapp)
        !"Expected account %{sexp: Account_id.t} to be a user account, got a \
          snapp account."
        account_id
    in
    r

  let failure (e : Transaction_status.Failure.t) = e

  let incr_balance (acct : Account.t) amt =
    match add_amount acct.balance amt with
    | Ok balance ->
        Ok { acct with balance }
    | Error _ ->
        Result.fail (failure Overflow)

  (* Helper function for [apply_user_command_unchecked] *)
  let pay_fee' ~command ~nonce ~fee_payer ~fee ~ledger ~current_global_slot =
    let open Or_error.Let_syntax in
    (* Fee-payer information *)
    let%bind location, account =
      get_user_account_with_location ledger fee_payer
    in
    let%bind () =
      match location with
      | `Existing _ ->
          return ()
      | `New ->
          Or_error.errorf "The fee-payer account does not exist"
    in
    let fee = Amount.of_fee fee in
    let%bind balance = sub_amount account.balance fee in
    let%bind () = validate_nonces nonce account.nonce in
    let%map timing =
      validate_timing ~txn_amount:fee ~txn_global_slot:current_global_slot
        ~account
    in
    ( location
    , account
    , { account with
        balance
      ; nonce = Account.Nonce.succ account.nonce
      ; receipt_chain_hash =
          Receipt.Chain_hash.cons command account.receipt_chain_hash
      ; timing
      } )

  (* Helper function for [apply_user_command_unchecked] *)
  let pay_fee ~user_command ~signer_pk ~ledger ~current_global_slot =
    let open Or_error.Let_syntax in
    (* Fee-payer information *)
    let nonce = Signed_command.nonce user_command in
    let fee_payer = Signed_command.fee_payer user_command in
    let%bind () =
      let fee_token = Signed_command.fee_token user_command in
      let%bind () =
        (* TODO: Enable multi-sig. *)
        if
          Public_key.Compressed.equal
            (Account_id.public_key fee_payer)
            signer_pk
        then return ()
        else
          Or_error.errorf
            "Cannot pay fees from a public key that did not sign the \
             transaction"
      in
      let%map () =
        (* TODO: Remove this check and update the transaction snark once we have
           an exchange rate mechanism. See issue #4447.
        *)
        if Token_id.equal fee_token Token_id.default then return ()
        else
          Or_error.errorf
            "Cannot create transactions with fee_token different from the \
             default"
      in
      ()
    in
    let%map loc, account, account' =
      pay_fee' ~command:(Signed_command user_command.payload) ~nonce ~fee_payer
        ~fee:(Signed_command.fee user_command)
        ~ledger ~current_global_slot
    in
    let applied_common : Transaction_applied.Signed_command_applied.Common.t =
      { user_command =
          { data = user_command
          ; status =
              Applied
                ( Transaction_status.Auxiliary_data.empty
                , Transaction_status.Balance_data.empty )
          }
      ; previous_receipt_chain_hash = account.receipt_chain_hash
      ; fee_payer_timing = account.timing
      ; source_timing = None
      }
    in
    (loc, account', applied_common)

  (* someday: It would probably be better if we didn't modify the receipt chain hash
     in the case that the sender is equal to the receiver, but it complicates the SNARK, so
     we don't for now. *)
  let apply_user_command_unchecked
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~txn_global_slot ledger
      ({ payload; signer; signature = _ } as user_command : Signed_command.t) =
    let open Or_error.Let_syntax in
    let signer_pk = Public_key.compress signer in
    let current_global_slot = txn_global_slot in
    let%bind () =
      validate_time
        ~valid_until:(Signed_command.valid_until user_command)
        ~current_global_slot
    in
    (* Fee-payer information *)
    let fee_payer = Signed_command.fee_payer user_command in
    let%bind fee_payer_location, fee_payer_account, applied_common =
      pay_fee ~user_command ~signer_pk ~ledger ~current_global_slot
    in
    (* Charge the fee. This must happen, whether or not the command itself
       succeeds, to ensure that the network is compensated for processing this
       command.
    *)
    let%bind () =
      set_with_location ledger fee_payer_location fee_payer_account
    in
    let next_available_token = next_available_token ledger in
    let source = Signed_command.source ~next_available_token user_command in
    let receiver = Signed_command.receiver ~next_available_token user_command in
    let exception Reject of Error.t in
    let ok_or_reject = function Ok x -> x | Error err -> raise (Reject err) in
    let charge_account_creation_fee_exn (account : Account.t) =
      let balance =
        Option.value_exn
          (Balance.sub_amount account.balance
             (Amount.of_fee constraint_constants.account_creation_fee))
      in
      let account = { account with balance } in
      let timing =
        Or_error.ok_exn
          (validate_timing ~txn_amount:Amount.zero
             ~txn_global_slot:current_global_slot ~account)
      in
      { account with timing }
    in
    let compute_updates () =
      let open Result.Let_syntax in
      (* Compute the necessary changes to apply the command, failing if any of
         the conditions are not met.
      *)
      let%bind predicate_passed =
        if
          Public_key.Compressed.equal
            (Signed_command.fee_payer_pk user_command)
            (Signed_command.source_pk user_command)
        then return true
        else
          match payload.body with
          | Create_new_token _ ->
              (* Any account is allowed to create a new token associated with a
                 public key.
              *)
              return true
          | Create_token_account _ ->
              (* Predicate failure is deferred here. It will be checked later. *)
              let predicate_result =
                (* TODO(#4554): Hook predicate evaluation in here once
                   implemented.
                *)
                false
              in
              return predicate_result
          | Payment _ | Stake_delegation _ | Mint_tokens _ ->
              (* TODO(#4554): Hook predicate evaluation in here once implemented. *)
              Result.fail Transaction_status.Failure.Predicate
      in
      match payload.body with
      | Stake_delegation _ ->
          let receiver_location, _receiver_account =
            (* Check that receiver account exists. *)
            get_with_location ledger receiver |> ok_or_reject
          in
          let source_location, source_account =
            get_with_location ledger source |> ok_or_reject
          in
          let%bind () =
            match (source_location, receiver_location) with
            | `Existing _, `Existing _ ->
                return ()
            | `New, _ ->
                Result.fail Transaction_status.Failure.Source_not_present
            | _, `New ->
                Result.fail Transaction_status.Failure.Receiver_not_present
          in
          let previous_delegate = source_account.delegate in
          let source_timing = source_account.timing in
          (* Timing is always valid, but we need to record any switch from
             timed to untimed here to stay in sync with the snark.
          *)
          let%map timing =
            validate_timing ~txn_amount:Amount.zero
              ~txn_global_slot:current_global_slot ~account:source_account
            |> Result.map_error ~f:timing_error_to_user_command_status
          in
          let source_account =
            { source_account with
              delegate = Some (Account_id.public_key receiver)
            ; timing
            }
          in
          ( [ (source_location, source_account) ]
          , `Source_timing source_timing
          , Transaction_status.Auxiliary_data.empty
          , Transaction_applied.Signed_command_applied.Body.Stake_delegation
              { previous_delegate } )
      | Payment { amount; token_id = token; _ } ->
          let receiver_location, receiver_account =
            get_with_location ledger receiver |> ok_or_reject
          in
          let%bind source_location, source_timing, source_account =
            let ret =
              if Account_id.equal source receiver then
                (*just check if the timing needs updating*)
                let%bind location, account =
                  match receiver_location with
                  | `Existing _ ->
                      return (receiver_location, receiver_account)
                  | `New ->
                      Result.fail Transaction_status.Failure.Source_not_present
                in
                let source_timing = account.timing in
                let%map timing =
                  validate_timing ~txn_amount:amount
                    ~txn_global_slot:current_global_slot ~account
                  |> Result.map_error ~f:timing_error_to_user_command_status
                in
                (location, source_timing, { account with timing })
              else
                let location, account =
                  get_with_location ledger source |> ok_or_reject
                in
                let%bind () =
                  match location with
                  | `Existing _ ->
                      return ()
                  | `New ->
                      Result.fail Transaction_status.Failure.Source_not_present
                in
                let source_timing = account.timing in
                let%bind timing =
                  validate_timing ~txn_amount:amount
                    ~txn_global_slot:current_global_slot ~account
                  |> Result.map_error ~f:timing_error_to_user_command_status
                in
                let%map balance =
                  Result.map_error (sub_amount account.balance amount)
                    ~f:(fun _ ->
                      Transaction_status.Failure.Source_insufficient_balance)
                in
                (location, source_timing, { account with timing; balance })
            in
            if Account_id.equal fee_payer source then
              (* Don't process transactions with insufficient balance from the
                 fee-payer.
              *)
              match ret with
              | Ok x ->
                  Ok x
              | Error failure ->
                  raise
                    (Reject
                       (Error.createf "%s"
                          (Transaction_status.Failure.describe failure)))
            else ret
          in
          (* Charge the account creation fee. *)
          let%bind receiver_amount =
            match receiver_location with
            | `Existing _ ->
                return amount
            | `New ->
                if Token_id.(equal default) token then
                  (* Subtract the creation fee from the transaction amount. *)
                  sub_account_creation_fee ~constraint_constants `Added amount
                  |> Result.map_error ~f:(fun _ ->
                         Transaction_status.Failure
                         .Amount_insufficient_to_create_account)
                else
                  Result.fail
                    Transaction_status.Failure.Cannot_pay_creation_fee_in_token
          in
          let%map receiver_account =
            incr_balance receiver_account receiver_amount
          in
          let previous_empty_accounts, auxiliary_data =
            match receiver_location with
            | `Existing _ ->
                ([], Transaction_status.Auxiliary_data.empty)
            | `New ->
                ( [ receiver ]
                , { Transaction_status.Auxiliary_data.empty with
                    receiver_account_creation_fee_paid =
                      Some
                        (Amount.of_fee
                           constraint_constants.account_creation_fee)
                  } )
          in
          ( [ (receiver_location, receiver_account)
            ; (source_location, source_account)
            ]
          , `Source_timing source_timing
          , auxiliary_data
          , Transaction_applied.Signed_command_applied.Body.Payment
              { previous_empty_accounts } )
      | Create_new_token { disable_new_accounts; _ } ->
          (* NOTE: source and receiver are definitionally equal here. *)
          let fee_payer_account =
            Or_error.try_with (fun () ->
                charge_account_creation_fee_exn fee_payer_account)
            |> ok_or_reject
          in
          let receiver_location, receiver_account =
            get_with_location ledger receiver |> ok_or_reject
          in
          ( match receiver_location with
          | `New ->
              ()
          | _ ->
              failwith
                "Token owner account for newly created token already exists?!?!"
          ) ;
          let receiver_account =
            { receiver_account with
              token_permissions =
                Token_permissions.Token_owned { disable_new_accounts }
            }
          in
          return
            ( [ (fee_payer_location, fee_payer_account)
              ; (receiver_location, receiver_account)
              ]
            , `Source_timing receiver_account.timing
            , { Transaction_status.Auxiliary_data.empty with
                fee_payer_account_creation_fee_paid =
                  Some (Amount.of_fee constraint_constants.account_creation_fee)
              ; created_token = Some next_available_token
              }
            , Transaction_applied.Signed_command_applied.Body.Create_new_token
                { created_token = next_available_token } )
      | Create_token_account { account_disabled; _ } ->
          if
            account_disabled
            && Token_id.(equal default) (Account_id.token_id receiver)
          then
            raise
              (Reject
                 (Error.createf
                    "Cannot open a disabled account in the default token")) ;
          let fee_payer_account =
            Or_error.try_with (fun () ->
                charge_account_creation_fee_exn fee_payer_account)
            |> ok_or_reject
          in
          let receiver_location, receiver_account =
            get_with_location ledger receiver |> ok_or_reject
          in
          let%bind () =
            match receiver_location with
            | `New ->
                return ()
            | `Existing _ ->
                Result.fail Transaction_status.Failure.Receiver_already_exists
          in
          let receiver_account =
            { receiver_account with
              token_permissions =
                Token_permissions.Not_owned { account_disabled }
            }
          in
          let source_location, source_account =
            get_with_location ledger source |> ok_or_reject
          in
          let%bind source_account =
            if Account_id.equal source receiver then return receiver_account
            else if Account_id.equal source fee_payer then
              return fee_payer_account
            else
              match source_location with
              | `New ->
                  Result.fail Transaction_status.Failure.Source_not_present
              | `Existing _ ->
                  return source_account
          in
          let%bind () =
            match source_account.token_permissions with
            | Token_owned { disable_new_accounts } ->
                if
                  not
                    ( Bool.equal account_disabled disable_new_accounts
                    || predicate_passed )
                then
                  Result.fail
                    Transaction_status.Failure.Mismatched_token_permissions
                else return ()
            | Not_owned _ ->
                if Token_id.(equal default) (Account_id.token_id receiver) then
                  return ()
                else Result.fail Transaction_status.Failure.Not_token_owner
          in
          let source_timing = source_account.timing in
          let%map source_account =
            let%map timing =
              validate_timing ~txn_amount:Amount.zero
                ~txn_global_slot:current_global_slot ~account:source_account
              |> Result.map_error ~f:timing_error_to_user_command_status
            in
            { source_account with timing }
          in
          let located_accounts =
            if Account_id.equal source receiver then
              (* For token_id= default, we allow this *)
              [ (fee_payer_location, fee_payer_account)
              ; (source_location, source_account)
              ]
            else
              [ (receiver_location, receiver_account)
              ; (fee_payer_location, fee_payer_account)
              ; (source_location, source_account)
              ]
          in
          ( located_accounts
          , `Source_timing source_timing
          , { Transaction_status.Auxiliary_data.empty with
              fee_payer_account_creation_fee_paid =
                Some (Amount.of_fee constraint_constants.account_creation_fee)
            }
          , Transaction_applied.Signed_command_applied.Body.Create_token_account
          )
      | Mint_tokens { token_id = token; amount; _ } ->
          let%bind () =
            if Token_id.(equal default) token then
              Result.fail Transaction_status.Failure.Not_token_owner
            else return ()
          in
          let receiver_location, receiver_account =
            get_with_location ledger receiver |> ok_or_reject
          in
          let%bind () =
            match receiver_location with
            | `Existing _ ->
                return ()
            | `New ->
                Result.fail Transaction_status.Failure.Receiver_not_present
          in
          let%bind receiver_account = incr_balance receiver_account amount in
          let%map source_location, source_timing, source_account =
            let location, account =
              if Account_id.equal source receiver then
                (receiver_location, receiver_account)
              else get_with_location ledger source |> ok_or_reject
            in
            let%bind () =
              match location with
              | `Existing _ ->
                  return ()
              | `New ->
                  Result.fail Transaction_status.Failure.Source_not_present
            in
            let%bind () =
              match account.token_permissions with
              | Token_owned _ ->
                  return ()
              | Not_owned _ ->
                  Result.fail Transaction_status.Failure.Not_token_owner
            in
            let source_timing = account.timing in
            let%map timing =
              validate_timing ~txn_amount:Amount.zero
                ~txn_global_slot:current_global_slot ~account
              |> Result.map_error ~f:timing_error_to_user_command_status
            in
            (location, source_timing, { account with timing })
          in
          ( [ (receiver_location, receiver_account)
            ; (source_location, source_account)
            ]
          , `Source_timing source_timing
          , Transaction_status.Auxiliary_data.empty
          , Transaction_applied.Signed_command_applied.Body.Mint_tokens )
    in
    let compute_balances () =
      let compute_balance account_id =
        match get_user_account_with_location ledger account_id with
        | Ok (`Existing _, account) ->
            Some account.balance
        | _ ->
            None
      in
      { Transaction_status.Balance_data.fee_payer_balance =
          compute_balance fee_payer
      ; source_balance = compute_balance source
      ; receiver_balance = compute_balance receiver
      }
    in
    match compute_updates () with
    | Ok
        ( located_accounts
        , `Source_timing source_timing
        , auxiliary_data
        , applied_body ) ->
        (* Update the ledger. *)
        let%bind () =
          List.fold located_accounts ~init:(Ok ())
            ~f:(fun acc (location, account) ->
              let%bind () = acc in
              set_with_location ledger location account)
        in
        let applied_common =
          { applied_common with
            source_timing = Some source_timing
          ; user_command =
              { data = user_command
              ; status = Applied (auxiliary_data, compute_balances ())
              }
          }
        in
        return
          ( { common = applied_common; body = applied_body }
            : Transaction_applied.Signed_command_applied.t )
    | Error failure ->
        (* Do not update the ledger. Except for the fee payer which is already updated *)
        let applied_common =
          { applied_common with
            user_command =
              { data = user_command
              ; status = Failed (failure, compute_balances ())
              }
          }
        in
        return
          ( { common = applied_common; body = Failed }
            : Transaction_applied.Signed_command_applied.t )
    | exception Reject err ->
        (* TODO: These transactions should never reach this stage, this error
           should be fatal.
        *)
        Error err

  let apply_user_command ~constraint_constants ~txn_global_slot ledger
      (user_command : Signed_command.With_valid_signature.t) =
    apply_user_command_unchecked ~constraint_constants ~txn_global_slot ledger
      (Signed_command.forget_check user_command)

  let apply_body ~is_start
      ({ body =
           { public_key = _
           ; token_id = _
           ; update =
               { app_state = _
               ; delegate = _
               ; verification_key = _
               ; permissions = _
               ; snapp_uri = _
               ; token_symbol = _
               ; timing = _
               ; voting_for = _
               }
           ; balance_change = _
           ; increment_nonce
           ; events = _ (* This is for the snapp to use, we don't need it. *)
           ; call_data = _ (* This is for the snapp to use, we don't need it. *)
           ; sequence_events = _
           ; call_depth = _ (* This is used to build the 'stack of stacks'. *)
           ; protocol_state = _
           ; use_full_commitment
           }
       ; predicate
       } :
        Party.Predicated.t) (a : Account.t) : (Account.t, _) Result.t =
    let open Result.Let_syntax in
    (* enforce that either the predicate is `Accept`,
         the nonce is incremented,
         or the full commitment is used to avoid replays. *)
    let%map () =
      let predicate_is_accept =
        Snapp_predicate.Account.is_accept @@ Party.Predicate.to_full predicate
      in
      List.exists ~f:Fn.id
        [ predicate_is_accept
        ; increment_nonce
        ; use_full_commitment && not is_start
        ]
      |> Result.ok_if_true
           ~error:Transaction_status.Failure.Parties_replay_check_failed
    in
    a

  module Global_state = struct
    type t =
      { ledger : L.t
      ; fee_excess : Amount.Signed.t
      ; protocol_state : Snapp_predicate.Protocol_state.View.t
      }

    let ledger { ledger; _ } = L.create_masked ledger

    let set_ledger ~should_update t ledger =
      if should_update then L.apply_mask t.ledger ~masked:ledger ;
      t

    let fee_excess { fee_excess; _ } = fee_excess

    let set_fee_excess t fee_excess = { t with fee_excess }

    let global_slot_since_genesis { protocol_state; _ } =
      protocol_state.global_slot_since_genesis
  end

  module Inputs = struct
    module First_party = Party.Signed
    module Global_state = Global_state

    module Field = struct
      type t = Snark_params.Tick.Field.t

      let if_ = Parties.value_if
    end

    module Bool = struct
      type t = bool

      let assert_ b = assert b

      let if_ = Parties.value_if

      let true_ = true

      let false_ = false

      let equal = Bool.equal

      let not = not

      let ( ||| ) = ( || )

      let ( &&& ) = ( && )

      let all = List.for_all ~f:Fn.id

      type failure_status = Transaction_status.Failure.t option

      let assert_with_failure_status b failure_status =
        match (b, failure_status) with
        | false, Some failure ->
            (* Raise a more useful error message if we have a failure
               description.
            *)
            Error.raise
              (Error.of_string @@ Transaction_status.Failure.to_string failure)
        | _ ->
            assert b
    end

    module Ledger = struct
      type t = L.t

      let if_ = Parties.value_if

      let empty = L.empty

      type inclusion_proof = [ `Existing of location | `New ]

      let get_account p l =
        let loc, acct =
          Or_error.ok_exn (get_with_location l (Party.account_id p))
        in
        (acct, loc)

      let set_account l (a, loc) =
        Or_error.ok_exn (set_with_location l loc a) ;
        l

      let check_inclusion _ledger (_account, _loc) = ()

      let check_account public_key token_id
          ((account, loc) : Account.t * inclusion_proof) =
        assert (Public_key.Compressed.equal public_key account.public_key) ;
        assert (Token_id.equal token_id account.token_id) ;
        match loc with `Existing _ -> `Is_new false | `New -> `Is_new true
    end

    module Transaction_commitment = struct
      type t = unit

      let empty = ()

      let if_ = Parties.value_if

      let commitment ~party:_ ~other_parties:_ ~memo_hash:_ = ()

      let full_commitment ~party:_ ~commitment:_ = ()
    end

    module Public_key = struct
      type t = Public_key.Compressed.t

      let if_ = Parties.value_if
    end

    module Controller = struct
      type t = Permissions.Auth_required.t

      let if_ = Parties.value_if

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

    module Global_slot = struct
      include Mina_numbers.Global_slot

      let if_ = Parties.value_if
    end

    module Nonce = struct
      type t = Account.Nonce.t

      let if_ = Parties.value_if

      let succ = Account.Nonce.succ
    end

    module State_hash = struct
      include State_hash

      let if_ = Parties.value_if
    end

    module Timing = struct
      type t = Party.Update.Timing_info.t option

      let if_ = Parties.value_if

      let vesting_period (t : t) =
        match t with
        | Some t ->
            t.vesting_period
        | None ->
            (Account_timing.to_record Untimed).vesting_period
    end

    module Balance = struct
      include Balance

      let if_ = Parties.value_if
    end

    module Verification_key = struct
      type t = (Side_loaded_verification_key.t, Field.t) With_hash.t option

      let if_ = Parties.value_if
    end

    module Events = struct
      type t = Field.t array list

      let is_empty = List.is_empty

      let push_events = Party.Sequence_events.push_events
    end

    module Snapp_uri = struct
      type t = string

      let if_ = Parties.value_if
    end

    module Token_symbol = struct
      type t = Account.Token_symbol.t

      let if_ = Parties.value_if
    end

    module Account = struct
      include Account

      module Permissions = struct
        let edit_state : t -> Controller.t = fun a -> a.permissions.edit_state

        let send : t -> Controller.t = fun a -> a.permissions.send

        let receive : t -> Controller.t = fun a -> a.permissions.receive

        let set_delegate : t -> Controller.t =
         fun a -> a.permissions.set_delegate

        let set_permissions : t -> Controller.t =
         fun a -> a.permissions.set_permissions

        let set_verification_key : t -> Controller.t =
         fun a -> a.permissions.set_verification_key

        let set_snapp_uri : t -> Controller.t =
         fun a -> a.permissions.set_snapp_uri

        let edit_sequence_state : t -> Controller.t =
         fun a -> a.permissions.edit_sequence_state

        let set_token_symbol : t -> Controller.t =
         fun a -> a.permissions.set_token_symbol

        let increment_nonce : t -> Controller.t =
         fun a -> a.permissions.increment_nonce

        let set_voting_for : t -> Controller.t =
         fun a -> a.permissions.set_voting_for

        type t = Permissions.t

        let if_ = Parties.value_if
      end

      type timing = Party.Update.Timing_info.t option

      let timing (a : t) : timing =
        Party.Update.Timing_info.of_account_timing a.timing

      let set_timing (timing : timing) (a : t) : t =
        { a with
          timing =
            Option.value_map ~default:Account_timing.Untimed
              ~f:Party.Update.Timing_info.to_account_timing timing
        }

      let balance (a : t) : Balance.t = a.balance

      let set_balance (balance : Balance.t) (a : t) : t = { a with balance }

      let check_timing ~txn_global_slot account =
        let invalid_timing, timing, _ =
          validate_timing_with_min_balance' ~txn_amount:Amount.zero
            ~txn_global_slot ~account
        in
        (invalid_timing, Party.Update.Timing_info.of_account_timing timing)

      let make_snapp (a : t) =
        let snapp =
          match a.snapp with
          | None ->
              Some Snapp_account.default
          | Some _ as snapp ->
              snapp
        in
        { a with snapp }

      let unmake_snapp (a : t) : t =
        let snapp =
          match a.snapp with
          | None ->
              None
          | Some snapp ->
              if Snapp_account.(equal default snapp) then None else Some snapp
        in
        { a with snapp }

      let get_snapp (a : t) = Option.value_exn a.snapp

      let set_snapp (a : t) ~f : t = { a with snapp = Option.map a.snapp ~f }

      let proved_state (a : t) = (get_snapp a).proved_state

      let set_proved_state proved_state (a : t) =
        set_snapp a ~f:(fun snapp -> { snapp with proved_state })

      let app_state (a : t) = (get_snapp a).app_state

      let set_app_state app_state (a : t) =
        set_snapp a ~f:(fun snapp -> { snapp with app_state })

      let register_verification_key (_ : t) = ()

      let verification_key (a : t) = (get_snapp a).verification_key

      let set_verification_key verification_key (a : t) =
        set_snapp a ~f:(fun snapp -> { snapp with verification_key })

      let last_sequence_slot (a : t) = (get_snapp a).last_sequence_slot

      let set_last_sequence_slot last_sequence_slot (a : t) =
        set_snapp a ~f:(fun snapp -> { snapp with last_sequence_slot })

      let sequence_state (a : t) = (get_snapp a).sequence_state

      let set_sequence_state sequence_state (a : t) =
        set_snapp a ~f:(fun snapp -> { snapp with sequence_state })

      let snapp_uri (a : t) = a.snapp_uri

      let set_snapp_uri snapp_uri (a : t) = { a with snapp_uri }

      let token_symbol (a : t) = a.token_symbol

      let set_token_symbol token_symbol (a : t) = { a with token_symbol }

      let public_key (a : t) = a.public_key

      let set_public_key public_key (a : t) = { a with public_key }

      let delegate (a : t) = Account.delegate_opt a.delegate

      let set_delegate delegate (a : t) =
        let delegate =
          if Signature_lib.Public_key.Compressed.(equal empty) delegate then
            None
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

    module Amount = struct
      open Currency.Amount

      type unsigned = t

      type t = unsigned

      let if_ = Parties.value_if

      module Signed = struct
        include Signed

        let if_ = Parties.value_if

        let is_pos (t : t) = Sgn.equal t.sgn Pos
      end

      let zero = zero

      let equal = equal

      let add_flagged = add_flagged

      let add_signed_flagged (x1 : t) (x2 : Signed.t) : t * [ `Overflow of bool ]
          =
        let y, `Overflow b = Signed.(add_flagged (of_unsigned x1) x2) in
        match y.sgn with
        | Pos ->
            (y.magnitude, `Overflow b)
        | Neg ->
            (* We want to capture the accurate value so that this will match
               with the values in the snarked logic.
            *)
            let magnitude =
              Amount.to_uint64 y.magnitude
              |> Unsigned.UInt64.(mul (sub zero one))
              |> Amount.of_uint64
            in
            (magnitude, `Overflow true)

      let of_constant_fee = of_fee
    end

    module Token_id = struct
      include Token_id

      let if_ = Parties.value_if
    end

    module Protocol_state_predicate = struct
      include Snapp_predicate.Protocol_state
    end

    module Party = struct
      include Party

      type parties = (Party.t, unit) Parties.Call_forest.t

      type transaction_commitment = Transaction_commitment.t

      let check_authorization ~commitment:_ ~at_party:_ (party : t) =
        (* The transaction's validity should already have been checked before
           this point.
        *)
        match party.authorization with
        | Signature _ ->
            (`Proof_verifies false, `Signature_verifies true)
        | Proof _ ->
            (`Proof_verifies true, `Signature_verifies false)
        | None_given ->
            (`Proof_verifies false, `Signature_verifies false)

      module Update = struct
        open Snapp_basic

        type 'a set_or_keep = 'a Snapp_basic.Set_or_keep.t

        let timing (party : t) : Account.timing set_or_keep =
          Set_or_keep.map ~f:Option.some party.data.body.update.timing

        let app_state (party : t) = party.data.body.update.app_state

        let verification_key (party : t) =
          Snapp_basic.Set_or_keep.map ~f:Option.some
            party.data.body.update.verification_key

        let sequence_events (party : t) = party.data.body.sequence_events

        let snapp_uri (party : t) = party.data.body.update.snapp_uri

        let token_symbol (party : t) = party.data.body.update.token_symbol

        let delegate (party : t) = party.data.body.update.delegate

        let voting_for (party : t) = party.data.body.update.voting_for

        let permissions (party : t) = party.data.body.update.permissions
      end
    end

    module Set_or_keep = struct
      include Snapp_basic.Set_or_keep

      let set_or_keep ~if_:_ t x = set_or_keep t x
    end

    module Opt = struct
      type 'a t = 'a option

      let is_some = Option.is_some

      let map = Option.map

      let or_default ~if_ x ~default =
        if_ (is_some x) ~then_:(Option.value ~default x) ~else_:default

      let or_exn x = Option.value_exn x
    end

    module Stack (Elt : sig
      type t
    end) =
    struct
      type t = Elt.t list

      let if_ = Parties.value_if

      let empty = []

      let is_empty = List.is_empty

      let pop_exn : t -> Elt.t * t = function
        | [] ->
            failwith "pop_exn"
        | x :: xs ->
            (x, xs)

      let pop : t -> (Elt.t * t) option = function
        | x :: xs ->
            Some (x, xs)
        | _ ->
            None

      let push x ~onto : t = x :: onto
    end

    module Parties = struct
      type t = (Party.t, unit) Parties.Call_forest.t

      let empty = []

      let if_ = Parties.value_if

      let is_empty = List.is_empty

      let of_parties_list : Party.t list -> t =
        Parties.Call_forest.of_parties_list ~party_depth:(fun (p : Party.t) ->
            p.data.body.call_depth)

      let pop_exn : t -> (Party.t * t) * t = function
        | { stack_hash = (); elt = { party; calls; party_digest = () } } :: xs
          ->
            ((party, calls), xs)
        | _ ->
            failwith "pop_exn"
    end

    module Call_stack = Stack (Parties)

    module Local_state = struct
      type t =
        ( Parties.t
        , Call_stack.t
        , Token_id.t
        , Amount.t
        , Ledger.t
        , Bool.t
        , Transaction_commitment.t
        , Bool.failure_status )
        Parties_logic.Local_state.t

      let add_check (t : t) failure b =
        let failure_status =
          match t.failure_status with
          | None when not b ->
              Some failure
          | old_failure_status ->
              old_failure_status
        in
        { t with failure_status; success = t.success && b }
    end
  end

  module Env = struct
    open Inputs

    type t =
      < party : Party.t
      ; parties : Parties.t
      ; account : Account.t
      ; ledger : Ledger.t
      ; amount : Amount.t
      ; signed_amount : Amount.Signed.t
      ; bool : Bool.t
      ; token_id : Token_id.t
      ; global_state : Global_state.t
      ; inclusion_proof : [ `Existing of location | `New ]
      ; local_state :
          ( Parties.t
          , Call_stack.t
          , Token_id.t
          , Amount.t
          , L.t
          , bool
          , Transaction_commitment.t
          , Transaction_status.Failure.t option )
          Parties_logic.Local_state.t
      ; protocol_state_predicate : Snapp_predicate.Protocol_state.t
      ; transaction_commitment : unit
      ; full_transaction_commitment : unit
      ; field : Snark_params.Tick.Field.t
      ; failure : Transaction_status.Failure.t option >

    let perform ~constraint_constants:_ (type r)
        (eff : (r, t) Parties_logic.Eff.t) : r =
      match eff with
      | Check_protocol_state_predicate (pred, global_state) -> (
          Snapp_predicate.Protocol_state.check pred global_state.protocol_state
          |> fun or_err -> match or_err with Ok () -> true | Error _ -> false )
      | Check_predicate (_is_start, party, account, _global_state) -> (
          match party.data.predicate with
          | Accept ->
              true
          | Nonce n ->
              Account.Nonce.equal account.nonce n
          | Full p ->
              Or_error.is_ok (Snapp_predicate.Account.check p account) )
      | Check_auth { is_start; party = p; account = a } -> (
          if (is_start : bool) then
            [%test_eq: Control.Tag.t] Signature (Control.tag p.authorization) ;
          match apply_body ~is_start p.data a with
          | Error failure ->
              (a, false, Some failure)
          | Ok a ->
              (a, true, None) )
  end

  module M = Parties_logic.Make (Inputs)

  let apply_parties_unchecked_aux (type user_acc)
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~(state_view : Snapp_predicate.Protocol_state.View.t) ~(init : user_acc)
      ~(f : user_acc -> _ -> user_acc) ?(fee_excess = Amount.Signed.zero)
      (ledger : L.t) (c : Parties.t) :
      (Transaction_applied.Parties_applied.t * user_acc) Or_error.t =
    let open Or_error.Let_syntax in
    let original_account_states =
      List.map (Parties.accounts_accessed c) ~f:(fun id ->
          ( id
          , Option.Let_syntax.(
              let%bind loc = L.location_of_account ledger id in
              let%map a = L.get ledger loc in
              (loc, a)) ))
    in
    let perform eff = Env.perform ~constraint_constants eff in
    let rec step_all user_acc
        ( (g_state : Inputs.Global_state.t)
        , (l_state : _ Parties_logic.Local_state.t) ) : user_acc Or_error.t =
      if List.is_empty l_state.parties then Ok user_acc
      else
        let%bind states =
          Or_error.try_with (fun () ->
              M.step ~constraint_constants { perform } (g_state, l_state))
        in
        step_all (f user_acc states) states
    in
    let initial_state : Inputs.Global_state.t * _ Parties_logic.Local_state.t =
      ( { protocol_state = state_view; ledger; fee_excess }
      , { parties = []
        ; call_stack = []
        ; transaction_commitment = ()
        ; full_transaction_commitment = ()
        ; token_id = Token_id.default
        ; excess = Currency.Amount.zero
        ; ledger
        ; success = true
        ; failure_status = None
        } )
    in
    let user_acc = f init initial_state in
    let%bind (start : Inputs.Global_state.t * _) =
      let parties =
        let p = Party.Fee_payer.to_signed c.fee_payer in
        { Party.authorization = Control.Signature p.authorization
        ; data =
            { p.data with predicate = Party.Predicate.Nonce p.data.predicate }
        }
        :: c.other_parties
      in
      Or_error.try_with (fun () ->
          M.start ~constraint_constants
            { parties = Inputs.Parties.of_parties_list parties
            ; memo_hash = Signed_command_memo.hash c.memo
            }
            { perform } initial_state)
    in
    let accounts () =
      List.map original_account_states
        ~f:(Tuple2.map_snd ~f:(Option.map ~f:snd))
    in
    match step_all (f user_acc start) start with
    | Error e ->
        Error e
    | Ok s ->
        Ok
          ( { Transaction_applied.Parties_applied.accounts = accounts ()
            ; command =
                { With_status.data = c
                ; status =
                    (* TODO *)
                    Applied
                      ( { fee_payer_account_creation_fee_paid = None
                        ; receiver_account_creation_fee_paid = None
                        ; created_token = None
                        }
                      , { fee_payer_balance = None
                        ; source_balance = None
                        ; receiver_balance = None
                        } )
                }
            }
          , s )

  let apply_parties_unchecked ~constraint_constants ~state_view ledger c =
    apply_parties_unchecked_aux ~constraint_constants ~state_view ledger c
      ~init:None ~f:(fun _acc (global_state, local_state) ->
        Some (local_state, global_state.fee_excess))
    |> Result.map ~f:(fun (party_applied, state_res) ->
           (party_applied, Option.value_exn state_res))

  let update_timing_when_no_deduction ~txn_global_slot account =
    validate_timing ~txn_amount:Amount.zero ~txn_global_slot ~account

  let process_fee_transfer t (transfer : Fee_transfer.t) ~modify_balance
      ~modify_timing =
    let open Or_error.Let_syntax in
    (* TODO(#4555): Allow token_id to vary from default. *)
    let%bind () =
      if
        List.for_all
          ~f:Token_id.(equal default)
          (One_or_two.to_list (Fee_transfer.fee_tokens transfer))
      then return ()
      else Or_error.errorf "Cannot pay fees in non-default tokens."
    in
    match Fee_transfer.to_singles transfer with
    | `One ft ->
        let account_id = Fee_transfer.Single.receiver ft in
        (* TODO(#4496): Do not use get_or_create here; we should not create a
           new account before we know that the transaction will go through and
           thus the creation fee has been paid.
        *)
        let%bind action, a, loc = get_or_create t account_id in
        let emptys = previous_empty_accounts action account_id in
        let%bind timing = modify_timing a in
        let%map balance = modify_balance action account_id a.balance ft.fee in
        set t loc { a with balance; timing } ;
        (emptys, a.timing)
    | `Two (ft1, ft2) ->
        let account_id1 = Fee_transfer.Single.receiver ft1 in
        (* TODO(#4496): Do not use get_or_create here; we should not create a
           new account before we know that the transaction will go through and
           thus the creation fee has been paid.
        *)
        let%bind action1, a1, l1 = get_or_create t account_id1 in
        let emptys1 = previous_empty_accounts action1 account_id1 in
        let account_id2 = Fee_transfer.Single.receiver ft2 in
        if Account_id.equal account_id1 account_id2 then (
          let%bind fee = error_opt "overflow" (Fee.add ft1.fee ft2.fee) in
          let%bind timing = modify_timing a1 in
          let%map balance = modify_balance action1 account_id1 a1.balance fee in
          set t l1 { a1 with balance; timing } ;
          (emptys1, a1.timing) )
        else
          (* TODO(#4496): Do not use get_or_create here; we should not create a
             new account before we know that the transaction will go through
             and thus the creation fee has been paid.
          *)
          let%bind action2, a2, l2 = get_or_create t account_id2 in
          let emptys2 = previous_empty_accounts action2 account_id2 in
          let%bind balance1 =
            modify_balance action1 account_id1 a1.balance ft1.fee
          in
          (*Note: Not updating the timing field of a1 to avoid additional check in transactions snark (check_timing for "receiver"). This is OK because timing rules will not be violated when balance increases and will be checked whenever an amount is deducted from the account. (#5973)*)
          let%bind timing2 = modify_timing a2 in
          let%map balance2 =
            modify_balance action2 account_id2 a2.balance ft2.fee
          in
          set t l1 { a1 with balance = balance1 } ;
          set t l2 { a2 with balance = balance2; timing = timing2 } ;
          (emptys1 @ emptys2, a2.timing)

  let apply_fee_transfer ~constraint_constants ~txn_global_slot t transfer =
    let open Or_error.Let_syntax in
    let%map previous_empty_accounts, receiver_timing =
      process_fee_transfer t transfer
        ~modify_balance:(fun action _ b f ->
          let%bind amount =
            let amount = Amount.of_fee f in
            sub_account_creation_fee ~constraint_constants action amount
          in
          add_amount b amount)
        ~modify_timing:(fun acc ->
          update_timing_when_no_deduction ~txn_global_slot acc)
    in
    let compute_balance account_id =
      match get_user_account_with_location t account_id with
      | Ok (`Existing _, account) ->
          Some account.balance
      | _ ->
          None
    in
    let balances =
      match Fee_transfer.to_singles transfer with
      | `One ft ->
          { Transaction_status.Fee_transfer_balance_data.receiver1_balance =
              Option.value_exn
                (compute_balance (Fee_transfer.Single.receiver ft))
          ; receiver2_balance = None
          }
      | `Two (ft1, ft2) ->
          { Transaction_status.Fee_transfer_balance_data.receiver1_balance =
              Option.value_exn
                (compute_balance (Fee_transfer.Single.receiver ft1))
          ; receiver2_balance =
              compute_balance (Fee_transfer.Single.receiver ft2)
          }
    in
    Transaction_applied.Fee_transfer_applied.
      { fee_transfer = transfer
      ; previous_empty_accounts
      ; receiver_timing
      ; balances
      }

  let undo_fee_transfer ~constraint_constants t
      ({ previous_empty_accounts; fee_transfer; receiver_timing; balances = _ } :
        Transaction_applied.Fee_transfer_applied.t) =
    let open Or_error.Let_syntax in
    let%map _ =
      process_fee_transfer t fee_transfer
        ~modify_balance:(fun _ aid b f ->
          let action =
            if List.mem ~equal:Account_id.equal previous_empty_accounts aid then
              `Added
            else `Existed
          in
          let%bind amount =
            sub_account_creation_fee ~constraint_constants action
              (Amount.of_fee f)
          in
          sub_amount b amount)
        ~modify_timing:(fun _ -> Ok receiver_timing)
    in
    remove_accounts_exn t previous_empty_accounts

  let apply_coinbase ~constraint_constants ~txn_global_slot t
      (* TODO: Better system needed for making atomic changes. Could use a monad. *)
        ({ receiver; fee_transfer; amount = coinbase_amount } as cb :
          Coinbase.t) =
    let open Or_error.Let_syntax in
    let%bind receiver_reward, emptys1, transferee_update, transferee_timing_prev
        =
      match fee_transfer with
      | None ->
          return (coinbase_amount, [], None, None)
      | Some ({ receiver_pk = transferee; fee } as ft) ->
          assert (not @@ Public_key.Compressed.equal transferee receiver) ;
          let transferee_id = Coinbase.Fee_transfer.receiver ft in
          let fee = Amount.of_fee fee in
          let%bind receiver_reward =
            error_opt "Coinbase fee transfer too large"
              (Amount.sub coinbase_amount fee)
          in
          let%bind action, transferee_account, transferee_location =
            (* TODO(#4496): Do not use get_or_create here; we should not create
               a new account before we know that the transaction will go
               through and thus the creation fee has been paid.
            *)
            get_or_create t transferee_id
          in
          let emptys = previous_empty_accounts action transferee_id in
          let%bind timing =
            update_timing_when_no_deduction ~txn_global_slot transferee_account
          in
          let%map balance =
            let%bind amount =
              sub_account_creation_fee ~constraint_constants action fee
            in
            add_amount transferee_account.balance amount
          in
          ( receiver_reward
          , emptys
          , Some
              (transferee_location, { transferee_account with balance; timing })
          , Some transferee_account.timing )
    in
    let receiver_id = Account_id.create receiver Token_id.default in
    let%bind action2, receiver_account, receiver_location =
      (* TODO(#4496): Do not use get_or_create here; we should not create a new
         account before we know that the transaction will go through and thus
         the creation fee has been paid.
      *)
      get_or_create t receiver_id
    in
    let emptys2 = previous_empty_accounts action2 receiver_id in
    (* Note: Updating coinbase receiver timing only if there is no fee transfer. This is so as to not add any extra constraints in transaction snark for checking "receiver" timings. This is OK because timing rules will not be violated when balance increases and will be checked whenever an amount is deducted from the account(#5973)*)
    let%bind receiver_timing_for_applied, coinbase_receiver_timing =
      match transferee_timing_prev with
      | None ->
          let%map new_receiver_timing =
            update_timing_when_no_deduction ~txn_global_slot receiver_account
          in
          (receiver_account.timing, new_receiver_timing)
      | Some timing ->
          Ok (timing, receiver_account.timing)
    in
    let%map receiver_balance =
      let%bind amount =
        sub_account_creation_fee ~constraint_constants action2 receiver_reward
      in
      add_amount receiver_account.balance amount
    in
    set t receiver_location
      { receiver_account with
        balance = receiver_balance
      ; timing = coinbase_receiver_timing
      } ;
    Option.iter transferee_update ~f:(fun (l, a) -> set t l a) ;
    Transaction_applied.Coinbase_applied.
      { coinbase = cb
      ; previous_empty_accounts = emptys1 @ emptys2
      ; receiver_timing = receiver_timing_for_applied
      ; balances =
          { Transaction_status.Coinbase_balance_data.coinbase_receiver_balance =
              receiver_balance
          ; fee_transfer_receiver_balance =
              Option.map transferee_update ~f:(fun (_, a) -> a.balance)
          }
      }

  (* Don't have to be atomic here because these should never fail. In fact, none of
     the undo functions should ever return an error. This should be fixed in the types. *)
  let undo_coinbase ~constraint_constants t
      Transaction_applied.Coinbase_applied.
        { coinbase = { receiver; fee_transfer; amount = coinbase_amount }
        ; previous_empty_accounts
        ; receiver_timing
        ; balances = _
        } =
    let receiver_reward, receiver_timing =
      match fee_transfer with
      | None ->
          (coinbase_amount, Some receiver_timing)
      | Some ({ receiver_pk = _; fee } as ft) ->
          let fee = Amount.of_fee fee in
          let transferee_id = Coinbase.Fee_transfer.receiver ft in
          let transferee_location =
            Or_error.ok_exn (location_of_account' t "transferee" transferee_id)
          in
          let transferee_account =
            Or_error.ok_exn (get' t "transferee" transferee_location)
          in
          let transferee_balance =
            let action =
              if
                List.mem previous_empty_accounts transferee_id
                  ~equal:Account_id.equal
              then `Added
              else `Existed
            in
            let amount =
              sub_account_creation_fee ~constraint_constants action fee
              |> Or_error.ok_exn
            in
            Option.value_exn
              (Balance.sub_amount transferee_account.balance amount)
          in
          set t transferee_location
            { transferee_account with
              balance = transferee_balance
            ; timing = receiver_timing
            } ;
          (Option.value_exn (Amount.sub coinbase_amount fee), None)
    in
    let receiver_id = Account_id.create receiver Token_id.default in
    let receiver_location =
      Or_error.ok_exn (location_of_account' t "receiver" receiver_id)
    in
    let receiver_account =
      Or_error.ok_exn (get' t "receiver" receiver_location)
    in
    let receiver_balance =
      let action =
        if List.mem previous_empty_accounts receiver_id ~equal:Account_id.equal
        then `Added
        else `Existed
      in
      let amount =
        sub_account_creation_fee ~constraint_constants action receiver_reward
        |> Or_error.ok_exn
      in
      Option.value_exn (Balance.sub_amount receiver_account.balance amount)
    in
    let timing =
      Option.value ~default:receiver_account.timing receiver_timing
    in
    set t receiver_location
      { receiver_account with balance = receiver_balance; timing } ;
    remove_accounts_exn t previous_empty_accounts

  let undo_user_command
      ~(constraint_constants : Genesis_constants.Constraint_constants.t) ledger
      { Transaction_applied.Signed_command_applied.common =
          { user_command =
              { data = { payload; signer = _; signature = _ } as user_command
              ; status = _
              }
          ; previous_receipt_chain_hash
          ; fee_payer_timing
          ; source_timing
          }
      ; body
      } =
    let open Or_error.Let_syntax in
    (* Fee-payer information *)
    let fee_payer = Signed_command.fee_payer user_command in
    let nonce = Signed_command.nonce user_command in
    let%bind fee_payer_location =
      location_of_account' ledger "fee payer" fee_payer
    in
    (* Refund the fee to the fee-payer. *)
    let%bind fee_payer_account =
      let%bind account = get' ledger "fee payer" fee_payer_location in
      let%bind () = validate_nonces (Account.Nonce.succ nonce) account.nonce in
      let%map balance =
        add_amount account.balance
          (Amount.of_fee (Signed_command.fee user_command))
      in
      { account with
        balance
      ; nonce
      ; receipt_chain_hash = previous_receipt_chain_hash
      ; timing = fee_payer_timing
      }
    in
    (* Update the fee-payer's account. *)
    set ledger fee_payer_location fee_payer_account ;
    let next_available_token =
      match body with
      | Create_new_token { created_token } ->
          created_token
      | _ ->
          next_available_token ledger
    in
    let source = Signed_command.source ~next_available_token user_command in
    let source_timing =
      (* Prefer fee-payer original timing when applicable, since it is the
         'true' original.
      *)
      if Account_id.equal fee_payer source then Some fee_payer_timing
      else source_timing
    in
    (* Reverse any other effects that the user command had. *)
    match (Signed_command.Payload.body payload, body) with
    | _, Failed ->
        (* The user command failed, only the fee was charged. *)
        return ()
    | Stake_delegation (Set_delegate _), Stake_delegation { previous_delegate }
      ->
        let%bind source_location =
          location_of_account' ledger "source" source
        in
        let%map source_account = get' ledger "source" source_location in
        set ledger source_location
          { source_account with
            delegate = previous_delegate
          ; timing = Option.value ~default:source_account.timing source_timing
          }
    | Payment { amount; _ }, Payment { previous_empty_accounts } ->
        let receiver =
          Signed_command.receiver ~next_available_token user_command
        in
        let%bind receiver_location, receiver_account =
          let%bind location = location_of_account' ledger "receiver" receiver in
          let%map account = get' ledger "receiver" location in
          let balance =
            (* NOTE: [sub_amount] is only [None] if the account creation fee
               was charged, in which case this account will be deleted by
               [remove_accounts_exn] below anyway.
            *)
            Option.value ~default:Balance.zero
              (Balance.sub_amount account.balance amount)
          in
          (location, { account with balance })
        in
        let%map source_location, source_account =
          let%bind location, account =
            if Account_id.equal source receiver then
              return (receiver_location, receiver_account)
            else
              let%bind location = location_of_account' ledger "source" source in
              let%map account = get' ledger "source" location in
              (location, account)
          in
          let%map balance = add_amount account.balance amount in
          ( location
          , { account with
              balance
            ; timing = Option.value ~default:account.timing source_timing
            } )
        in
        set ledger receiver_location receiver_account ;
        set ledger source_location source_account ;
        remove_accounts_exn ledger previous_empty_accounts
    | Create_new_token _, Create_new_token _
    | Create_token_account _, Create_token_account ->
        (* We group these commands together because their undo behaviour is
           identical: remove the created account, and un-charge the fee payer
           for creating the account. *)
        let fee_payer_account =
          let balance =
            Option.value_exn
              (Balance.add_amount fee_payer_account.balance
                 (Amount.of_fee constraint_constants.account_creation_fee))
          in
          { fee_payer_account with balance }
        in
        let%bind source_location =
          location_of_account' ledger "source" source
        in
        let%map source_account =
          if Account_id.equal fee_payer source then return fee_payer_account
          else get' ledger "source" source_location
        in
        let receiver =
          Signed_command.receiver ~next_available_token user_command
        in
        set ledger fee_payer_location fee_payer_account ;
        set ledger source_location
          { source_account with
            timing = Option.value ~default:source_account.timing source_timing
          } ;
        remove_accounts_exn ledger [ receiver ] ;
        (* Restore to the previous [next_available_token]. This is a no-op if
           the [next_available_token] did not change.
        *)
        set_next_available_token ledger next_available_token
    | Mint_tokens { amount; _ }, Mint_tokens ->
        let receiver =
          Signed_command.receiver ~next_available_token user_command
        in
        let%bind receiver_location, receiver_account =
          let%bind location = location_of_account' ledger "receiver" receiver in
          let%map account = get' ledger "receiver" location in
          let balance =
            Option.value_exn (Balance.sub_amount account.balance amount)
          in
          (location, { account with balance })
        in
        let%map source_location, source_account =
          let%map location, account =
            if Account_id.equal source receiver then
              return (receiver_location, receiver_account)
            else
              let%bind location = location_of_account' ledger "source" source in
              let%map account = get' ledger "source" location in
              (location, account)
          in
          ( location
          , { account with
              timing = Option.value ~default:account.timing source_timing
            } )
        in
        set ledger receiver_location receiver_account ;
        set ledger source_location source_account
    | _, _ ->
        failwith "Transaction_applied/command mismatch"

  let undo_parties ~constraint_constants:_ ledger
      { Transaction_applied.Parties_applied.accounts; command = _ } =
    let to_update, to_delete =
      List.partition_map accounts ~f:(fun (id, a) ->
          match a with Some a -> `Fst (id, a) | None -> `Snd id)
    in
    let to_update =
      List.dedup_and_sort
        ~compare:(fun (x, _) (y, _) -> Account_id.compare x y)
        to_update
    in
    let open Or_error.Let_syntax in
    let%map to_update =
      List.map to_update ~f:(fun (id, a) ->
          let%map loc =
            location_of_account' ledger (sprintf !"%{sexp:Account_id.t}" id) id
          in
          (`Existing loc, a))
      |> Or_error.all
    in
    remove_accounts_exn ledger to_delete ;
    List.iter to_update ~f:(fun (location, account) ->
        ignore @@ set_with_location ledger location account)

  let undo :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> t
      -> Transaction_applied.t
      -> unit Or_error.t =
   fun ~constraint_constants ledger applied ->
    let open Or_error.Let_syntax in
    let%map res =
      match applied.varying with
      | Fee_transfer u ->
          undo_fee_transfer ~constraint_constants ledger u
      | Command (Signed_command u) ->
          undo_user_command ~constraint_constants ledger u
      | Command (Parties p) ->
          undo_parties ~constraint_constants ledger p
      | Coinbase c ->
          undo_coinbase ~constraint_constants ledger c ;
          Ok ()
    in
    Debug_assert.debug_assert (fun () ->
        [%test_eq: Ledger_hash.t] applied.previous_hash (merkle_root ledger)) ;
    res

  let apply_transaction ~constraint_constants
      ~(txn_state_view : Snapp_predicate.Protocol_state.View.t) ledger
      (t : Transaction.t) =
    O1trace.measure "apply_transaction" (fun () ->
        let previous_hash = merkle_root ledger in
        let txn_global_slot = txn_state_view.global_slot_since_genesis in
        Or_error.map
          ( match t with
          | Command (Signed_command txn) ->
              Or_error.map
                (apply_user_command_unchecked ~constraint_constants
                   ~txn_global_slot ledger txn) ~f:(fun applied ->
                  Transaction_applied.Varying.Command (Signed_command applied))
          | Command (Parties txn) ->
              Or_error.map
                (apply_parties_unchecked ~state_view:txn_state_view
                   ~constraint_constants ledger txn) ~f:(fun (applied, _) ->
                  Transaction_applied.Varying.Command (Parties applied))
          | Fee_transfer t ->
              Or_error.map
                (apply_fee_transfer ~constraint_constants ~txn_global_slot
                   ledger t) ~f:(fun applied ->
                  Transaction_applied.Varying.Fee_transfer applied)
          | Coinbase t ->
              Or_error.map
                (apply_coinbase ~constraint_constants ~txn_global_slot ledger t)
                ~f:(fun applied -> Transaction_applied.Varying.Coinbase applied)
          )
          ~f:(fun varying -> { Transaction_applied.previous_hash; varying }))

  let merkle_root_after_parties_exn ~constraint_constants ~txn_state_view ledger
      payment =
    let applied, _ =
      Or_error.ok_exn
        (apply_parties_unchecked ~constraint_constants
           ~state_view:txn_state_view ledger payment)
    in
    let root = merkle_root ledger in
    let next_available_token = next_available_token ledger in
    Or_error.ok_exn (undo_parties ~constraint_constants ledger applied) ;
    (root, `Next_available_token next_available_token)

  let merkle_root_after_user_command_exn ~constraint_constants ~txn_global_slot
      ledger payment =
    let applied =
      Or_error.ok_exn
        (apply_user_command ~constraint_constants ~txn_global_slot ledger
           payment)
    in
    let root = merkle_root ledger in
    let next_available_token = next_available_token ledger in
    Or_error.ok_exn (undo_user_command ~constraint_constants ledger applied) ;
    (root, `Next_available_token next_available_token)

  module For_tests = struct
    let validate_timing_with_min_balance = validate_timing_with_min_balance

    let validate_timing = validate_timing
  end
end

module For_tests = struct
  open Mina_numbers
  open Currency

  module Account_without_receipt_chain_hash = struct
    type t =
      ( Public_key.Compressed.t
      , Token_id.t
      , Token_permissions.t
      , Account.Token_symbol.t
      , Balance.t
      , Account_nonce.t
      , unit
      , Public_key.Compressed.t option
      , State_hash.t
      , Account_timing.t
      , Permissions.t
      , Snapp_account.t option
      , string )
      Account.Poly.t
    [@@deriving sexp, compare]
  end

  let min_init_balance = 8_000_000_000

  let max_init_balance = 8_000_000_000_000

  let num_accounts = 10

  let num_transactions = 10

  let depth = Int.ceil_log2 (num_accounts + num_transactions)

  module Init_ledger = struct
    type t = (Keypair.t * int) array [@@deriving sexp]

    let init (type l) (module L : Ledger_intf with type t = l) (init_ledger : t)
        (l : L.t) =
      Array.iter init_ledger ~f:(fun (kp, amount) ->
          let _tag, account, loc =
            L.get_or_create l
              (Account_id.create
                 (Public_key.compress kp.public_key)
                 Token_id.default)
            |> Or_error.ok_exn
          in
          L.set l loc { account with balance = Currency.Balance.of_int amount })

    let gen () : t Quickcheck.Generator.t =
      let tbl = Public_key.Compressed.Hash_set.create () in
      let open Quickcheck.Generator in
      let open Let_syntax in
      let rec go acc n =
        if n = 0 then return (Array.of_list acc)
        else
          let%bind kp =
            filter Keypair.gen ~f:(fun kp ->
                not (Hash_set.mem tbl (Public_key.compress kp.public_key)))
          and amount = Int.gen_incl min_init_balance max_init_balance in
          Hash_set.add tbl (Public_key.compress kp.public_key) ;
          go ((kp, amount) :: acc) (n - 1)
      in
      go [] num_accounts
  end

  module Transaction_spec = struct
    type t =
      { fee : Currency.Fee.t
      ; sender : Keypair.t * Account_nonce.t
      ; receiver : Public_key.Compressed.t
      ; amount : Currency.Amount.t
      }
    [@@deriving sexp]

    let gen ~(init_ledger : Init_ledger.t) ~nonces =
      let pk ((kp : Keypair.t), _) = Public_key.compress kp.public_key in
      let open Quickcheck.Let_syntax in
      let%bind receiver_is_new = Bool.quickcheck_generator in
      let gen_index () = Int.gen_incl 0 (Array.length init_ledger - 1) in
      let%bind receiver_index =
        if receiver_is_new then return None else gen_index () >>| Option.return
      in
      let%bind receiver =
        match receiver_index with
        | None ->
            Public_key.Compressed.gen
        | Some i ->
            return (pk init_ledger.(i))
      in
      let%bind sender =
        let%map i =
          match receiver_index with
          | None ->
              gen_index ()
          | Some j ->
              Quickcheck.Generator.filter (gen_index ()) ~f:(( <> ) j)
        in
        fst init_ledger.(i)
      in
      let gen_amount () =
        Currency.Amount.(gen_incl (of_int 1_000_000) (of_int 100_000_000))
      in
      let gen_fee () =
        Currency.Fee.(gen_incl (of_int 1_000_000) (of_int 100_000_000))
      in
      let nonce : Account_nonce.t = Map.find_exn nonces sender in
      let%bind fee = gen_fee () in
      let%bind amount = gen_amount () in
      let nonces =
        Map.set nonces ~key:sender ~data:(Account_nonce.succ nonce)
      in
      let spec = { fee; amount; receiver; sender = (sender, nonce) } in
      return (spec, nonces)
  end

  module Test_spec = struct
    type t = { init_ledger : Init_ledger.t; specs : Transaction_spec.t list }
    [@@deriving sexp]

    let mk_gen ?(num_transactions = num_transactions) () =
      let open Quickcheck.Let_syntax in
      let%bind init_ledger = Init_ledger.gen () in
      let%bind specs =
        let rec go acc n nonces =
          if n = 0 then return (List.rev acc)
          else
            let%bind spec, nonces = Transaction_spec.gen ~init_ledger ~nonces in
            go (spec :: acc) (n - 1) nonces
        in
        go [] num_transactions
          (Keypair.Map.of_alist_exn
             (List.map (Array.to_list init_ledger) ~f:(fun (pk, _) ->
                  (pk, Account_nonce.zero))))
      in
      return { init_ledger; specs }

    let gen = mk_gen ~num_transactions ()
  end

  let command_send
      { Transaction_spec.fee; sender = sender, sender_nonce; receiver; amount }
      : Signed_command.t =
    let sender_pk = Public_key.compress sender.public_key in
    Signed_command.sign sender
      { common =
          { fee
          ; fee_token = Token_id.default
          ; fee_payer_pk = sender_pk
          ; nonce = sender_nonce
          ; valid_until = Global_slot.max_value
          ; memo = Signed_command_memo.dummy
          }
      ; body =
          Payment
            { source_pk = sender_pk
            ; receiver_pk = receiver
            ; token_id = Token_id.default
            ; amount
            }
      }
    |> Signed_command.forget_check

  let party_send ?(use_full_commitment = true)
      { Transaction_spec.fee; sender = sender, sender_nonce; receiver; amount }
      : Parties.t =
    let sender_pk = Public_key.compress sender.public_key in
    let actual_nonce =
      (* Here, we double the spec'd nonce, because we bump the nonce a second
         time for the 'sender' part of the payment.
      *)
      (* TODO: We should make bumping the nonce for signed parties optional,
         flagged by a field in the party (but always true for the fee payer).

         This would also allow us to prevent replays of snapp proofs, by
         allowing them to bump their nonce.
      *)
      sender_nonce |> Account.Nonce.to_uint32
      |> Unsigned.UInt32.(mul (of_int 2))
      |> Account.Nonce.to_uint32
    in
    let parties : Parties.t =
      { fee_payer =
          { Party.Fee_payer.data =
              { body =
                  { public_key = sender_pk
                  ; update = Party.Update.noop
                  ; token_id = ()
                  ; balance_change = fee
                  ; increment_nonce = ()
                  ; events = []
                  ; sequence_events = []
                  ; call_data = Snark_params.Tick.Field.zero
                  ; call_depth = 0
                  ; protocol_state = Snapp_predicate.Protocol_state.accept
                  ; use_full_commitment = ()
                  }
              ; predicate = actual_nonce
              }
              (* Real signature added in below *)
          ; authorization = Signature.dummy
          }
      ; other_parties =
          [ { data =
                { body =
                    { public_key = sender_pk
                    ; update = Party.Update.noop
                    ; token_id = Token_id.default
                    ; balance_change =
                        Amount.Signed.(negate (of_unsigned amount))
                    ; increment_nonce = not use_full_commitment
                    ; events = []
                    ; sequence_events = []
                    ; call_data = Snark_params.Tick.Field.zero
                    ; call_depth = 0
                    ; protocol_state = Snapp_predicate.Protocol_state.accept
                    ; use_full_commitment
                    }
                ; predicate = Nonce (Account.Nonce.succ actual_nonce)
                }
            ; authorization = None_given
            }
          ; { data =
                { body =
                    { public_key = receiver
                    ; update = Party.Update.noop
                    ; token_id = Token_id.default
                    ; balance_change = Amount.Signed.(of_unsigned amount)
                    ; increment_nonce = false
                    ; events = []
                    ; sequence_events = []
                    ; call_data = Snark_params.Tick.Field.zero
                    ; call_depth = 0
                    ; protocol_state = Snapp_predicate.Protocol_state.accept
                    ; use_full_commitment = false
                    }
                ; predicate = Accept
                }
            ; authorization = None_given
            }
          ]
      ; memo = Signed_command_memo.empty
      }
    in
    let commitment = Parties.commitment parties in
    let full_commitment =
      Parties.Transaction_commitment.with_fee_payer commitment
        ~fee_payer_hash:
          (Party.Predicated.digest
             (Party.Predicated.of_fee_payer parties.fee_payer.data))
    in
    let other_parties_signature =
      let c = if use_full_commitment then full_commitment else commitment in
      Schnorr.Chunked.sign sender.private_key
        (Random_oracle.Input.Chunked.field c)
    in
    let other_parties =
      List.map parties.other_parties ~f:(fun party ->
          match party.data.predicate with
          | Nonce _ ->
              { party with authorization = Signature other_parties_signature }
          | _ ->
              party)
    in
    let signature =
      Schnorr.Chunked.sign sender.private_key
        (Random_oracle.Input.Chunked.field full_commitment)
    in
    { parties with
      fee_payer = { parties.fee_payer with authorization = signature }
    ; other_parties
    }

  let test_eq (type l) (module L : Ledger_intf with type t = l) accounts
      (l1 : L.t) (l2 : L.t) =
    Or_error.try_with (fun () ->
        List.iter accounts ~f:(fun a ->
            let mismatch () =
              failwithf
                !"One ledger had the account %{sexp:Account_id.t} but the \
                  other did not"
                a ()
            in
            let hide_rc (a : _ Account.Poly.t) =
              { a with receipt_chain_hash = () }
            in
            match L.(location_of_account l1 a, location_of_account l2 a) with
            | None, None ->
                ()
            | Some _, None | None, Some _ ->
                mismatch ()
            | Some x1, Some x2 -> (
                match L.(get l1 x1, get l2 x2) with
                | None, None ->
                    ()
                | Some _, None | None, Some _ ->
                    mismatch ()
                | Some a1, Some a2 ->
                    [%test_eq: Account_without_receipt_chain_hash.t]
                      (hide_rc a1) (hide_rc a2) )))

  let txn_global_slot = Global_slot.zero

  let constraint_constants =
    { Genesis_constants.Constraint_constants.for_unit_tests with
      account_creation_fee = Fee.of_int 1
    }

  let iter_err ts ~f =
    List.fold_until ts
      ~finish:(fun () -> Ok ())
      ~init:()
      ~f:(fun () t ->
        match f t with Error e -> Stop (Error e) | Ok _ -> Continue ())

  let view : Snapp_predicate.Protocol_state.View.t =
    let h = Frozen_ledger_hash.empty_hash in
    let len = Length.zero in
    let a = Currency.Amount.zero in
    let epoch_data =
      { Epoch_data.Poly.ledger =
          { Epoch_ledger.Poly.hash = h; total_currency = a }
      ; seed = h
      ; start_checkpoint = h
      ; lock_checkpoint = h
      ; epoch_length = len
      }
    in
    { snarked_ledger_hash = h
    ; snarked_next_available_token = Token_id.(next default)
    ; timestamp = Block_time.zero
    ; blockchain_length = len
    ; min_window_density = len
    ; last_vrf_output = ()
    ; total_currency = a
    ; global_slot_since_hard_fork = txn_global_slot
    ; global_slot_since_genesis = txn_global_slot
    ; staking_epoch_data = epoch_data
    ; next_epoch_data = epoch_data
    }

  (* Quickcheck generator for Parties.t, derived from Test_spec generator *)
  let gen_parties_from_test_spec =
    let open Quickcheck.Let_syntax in
    let%bind use_full_commitment = Bool.quickcheck_generator in
    match%map Test_spec.mk_gen ~num_transactions:1 () with
    | { specs = [ spec ]; _ } ->
        party_send ~use_full_commitment spec
    | { specs; _ } ->
        failwithf "gen_parties_from_test_spec: expected one spec, got %d"
          (List.length specs) ()
end
