open Core_kernel
open Mina_base
open Currency
open Signature_lib
open Mina_transaction
module Zkapp_command_logic = Zkapp_command_logic
module Global_slot_since_genesis = Mina_numbers.Global_slot_since_genesis

module Transaction_applied = struct
  module UC = Signed_command

  module Signed_command_applied = struct
    module Common = struct
      [%%versioned
      module Stable = struct
        module V2 = struct
          type t =
            { user_command : Signed_command.Stable.V2.t With_status.Stable.V2.t
            }
          [@@deriving sexp, to_yojson]

          let to_latest = Fn.id
        end
      end]
    end

    module Body = struct
      [%%versioned
      module Stable = struct
        module V2 = struct
          type t =
            | Payment of { new_accounts : Account_id.Stable.V2.t list }
            | Stake_delegation of
                { previous_delegate : Public_key.Compressed.Stable.V1.t option }
            | Failed
          [@@deriving sexp, to_yojson]

          let to_latest = Fn.id
        end
      end]
    end

    [%%versioned
    module Stable = struct
      module V2 = struct
        type t = { common : Common.Stable.V2.t; body : Body.Stable.V2.t }
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]

    let new_accounts (t : t) =
      match t.body with
      | Payment { new_accounts; _ } ->
          new_accounts
      | Stake_delegation _ | Failed ->
          []
  end

  module Zkapp_command_applied = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { accounts :
              (Account_id.Stable.V2.t * Account.Stable.V2.t option) list
          ; command : Zkapp_command.Stable.V1.t With_status.Stable.V2.t
          ; new_accounts : Account_id.Stable.V2.t list
          }
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Command_applied = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          | Signed_command of Signed_command_applied.Stable.V2.t
          | Zkapp_command of Zkapp_command_applied.Stable.V1.t
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Fee_transfer_applied = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          { fee_transfer : Fee_transfer.Stable.V2.t With_status.Stable.V2.t
          ; new_accounts : Account_id.Stable.V2.t list
          ; burned_tokens : Currency.Amount.Stable.V1.t
          }
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Coinbase_applied = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          { coinbase : Coinbase.Stable.V1.t With_status.Stable.V2.t
          ; new_accounts : Account_id.Stable.V2.t list
          ; burned_tokens : Currency.Amount.Stable.V1.t
          }
        [@@deriving sexp, to_yojson]

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
          | Fee_transfer of Fee_transfer_applied.Stable.V2.t
          | Coinbase of Coinbase_applied.Stable.V2.t
        [@@deriving sexp, to_yojson]

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
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  let burned_tokens : t -> Currency.Amount.t =
   fun { varying; _ } ->
    match varying with
    | Command _ ->
        Currency.Amount.zero
    | Fee_transfer f ->
        f.burned_tokens
    | Coinbase c ->
        c.burned_tokens

  let new_accounts : t -> Account_id.t list =
   fun { varying; _ } ->
    match varying with
    | Command c -> (
        match c with
        | Signed_command sc ->
            Signed_command_applied.new_accounts sc
        | Zkapp_command zc ->
            zc.new_accounts )
    | Fee_transfer f ->
        f.new_accounts
    | Coinbase c ->
        c.new_accounts

  let supply_increase : t -> Currency.Amount.Signed.t Or_error.t =
   fun t ->
    let open Or_error.Let_syntax in
    let burned_tokens = Currency.Amount.Signed.of_unsigned (burned_tokens t) in
    let account_creation_fees =
      let account_creation_fee_int =
        Genesis_constants.Constraint_constants.compiled.account_creation_fee
        |> Currency.Fee.to_nanomina_int
      in
      let num_accounts_created = List.length @@ new_accounts t in
      (* int type is OK, no danger of overflow *)
      Currency.Amount.(
        Signed.of_unsigned
        @@ of_nanomina_int_exn (account_creation_fee_int * num_accounts_created))
    in
    let txn : Transaction.t =
      match t.varying with
      | Command
          (Signed_command { common = { user_command = { data; _ }; _ }; _ }) ->
          Command (Signed_command data)
      | Command (Zkapp_command c) ->
          Command (Zkapp_command c.command.data)
      | Fee_transfer f ->
          Fee_transfer f.fee_transfer.data
      | Coinbase c ->
          Coinbase c.coinbase.data
    in
    let%bind expected_supply_increase =
      Transaction.expected_supply_increase txn
    in
    let rec process_decreases total = function
      | [] ->
          Some total
      | amt :: amts ->
          let%bind.Option sum =
            Currency.Amount.Signed.(add @@ negate amt) total
          in
          process_decreases sum amts
    in
    let total =
      process_decreases
        (Currency.Amount.Signed.of_unsigned expected_supply_increase)
        [ burned_tokens; account_creation_fees ]
    in
    Option.value_map total ~default:(Or_error.error_string "overflow")
      ~f:(fun v -> Ok v)

  let transaction_with_status : t -> Transaction.t With_status.t =
   fun { varying; _ } ->
    match varying with
    | Command (Signed_command uc) ->
        With_status.map uc.common.user_command ~f:(fun cmd ->
            Transaction.Command (User_command.Signed_command cmd) )
    | Command (Zkapp_command s) ->
        With_status.map s.command ~f:(fun c ->
            Transaction.Command (User_command.Zkapp_command c) )
    | Fee_transfer f ->
        With_status.map f.fee_transfer ~f:(fun f -> Transaction.Fee_transfer f)
    | Coinbase c ->
        With_status.map c.coinbase ~f:(fun c -> Transaction.Coinbase c)

  let transaction_status : t -> Transaction_status.t =
   fun { varying; _ } ->
    match varying with
    | Command
        (Signed_command { common = { user_command = { status; _ }; _ }; _ }) ->
        status
    | Command (Zkapp_command c) ->
        c.command.status
    | Fee_transfer f ->
        f.fee_transfer.status
    | Coinbase c ->
        c.coinbase.status
end

module type S = sig
  type ledger

  type location

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
      { first_pass_ledger : ledger
      ; second_pass_ledger : ledger
      ; fee_excess : Amount.Signed.t
      ; supply_increase : Amount.Signed.t
      ; protocol_state : Zkapp_precondition.Protocol_state.View.t
      ; block_global_slot : Mina_numbers.Global_slot_since_genesis.t
            (* Slot of block when the transaction is applied. NOTE: This is at least 1 slot after the protocol_state's view, which is for the *previous* slot. *)
      }
  end

  module Transaction_partially_applied : sig
    module Zkapp_command_partially_applied : sig
      type t =
        { command : Zkapp_command.t
        ; previous_hash : Ledger_hash.t
        ; original_first_pass_account_states :
            (Account_id.t * (location * Account.t) option) list
        ; constraint_constants : Genesis_constants.Constraint_constants.t
        ; state_view : Zkapp_precondition.Protocol_state.View.t
        ; global_state : Global_state.t
        ; local_state :
            ( Stack_frame.value
            , Stack_frame.value list
            , Amount.Signed.t
            , ledger
            , bool
            , Zkapp_command.Transaction_commitment.t
            , Mina_numbers.Index.t
            , Transaction_status.Failure.Collection.t )
            Zkapp_command_logic.Local_state.t
        }
    end

    type 'applied fully_applied =
      { previous_hash : Ledger_hash.t; applied : 'applied }

    type t =
      | Signed_command of
          Transaction_applied.Signed_command_applied.t fully_applied
      | Zkapp_command of Zkapp_command_partially_applied.t
      | Fee_transfer of Transaction_applied.Fee_transfer_applied.t fully_applied
      | Coinbase of Transaction_applied.Coinbase_applied.t fully_applied

    val command : t -> Transaction.t
  end

  val apply_user_command :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Global_slot_since_genesis.t
    -> ledger
    -> Signed_command.With_valid_signature.t
    -> Transaction_applied.Signed_command_applied.t Or_error.t

  val apply_user_command_unchecked :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Global_slot_since_genesis.t
    -> ledger
    -> Signed_command.t
    -> Transaction_applied.Signed_command_applied.t Or_error.t

  val update_action_state :
       Snark_params.Tick.Field.t Pickles_types.Vector.Vector_5.t
    -> Zkapp_account.Actions.t
    -> txn_global_slot:Global_slot_since_genesis.t
    -> last_action_slot:Global_slot_since_genesis.t
    -> Snark_params.Tick.Field.t Pickles_types.Vector.Vector_5.t
       * Global_slot_since_genesis.t

  val apply_zkapp_command_unchecked :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> global_slot:Mina_numbers.Global_slot_since_genesis.t
    -> state_view:Zkapp_precondition.Protocol_state.View.t
    -> ledger
    -> Zkapp_command.t
    -> ( Transaction_applied.Zkapp_command_applied.t
       * ( ( Stack_frame.value
           , Stack_frame.value list
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
    -> global_slot:Mina_numbers.Global_slot_since_genesis.t
    -> state_view:Zkapp_precondition.Protocol_state.View.t
    -> init:'acc
    -> f:
         (   'acc
          -> Global_state.t
             * ( Stack_frame.value
               , Stack_frame.value list
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

  val apply_zkapp_command_first_pass_aux :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> global_slot:Mina_numbers.Global_slot_since_genesis.t
    -> state_view:Zkapp_precondition.Protocol_state.View.t
    -> init:'acc
    -> f:
         (   'acc
          -> Global_state.t
             * ( Stack_frame.value
               , Stack_frame.value list
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
    -> (Transaction_partially_applied.Zkapp_command_partially_applied.t * 'acc)
       Or_error.t

  val apply_zkapp_command_second_pass_aux :
       init:'acc
    -> f:
         (   'acc
          -> Global_state.t
             * ( Stack_frame.value
               , Stack_frame.value list
               , Amount.Signed.t
               , ledger
               , bool
               , Zkapp_command.Transaction_commitment.t
               , Mina_numbers.Index.t
               , Transaction_status.Failure.Collection.t )
               Zkapp_command_logic.Local_state.t
          -> 'acc )
    -> ledger
    -> Transaction_partially_applied.Zkapp_command_partially_applied.t
    -> (Transaction_applied.Zkapp_command_applied.t * 'acc) Or_error.t

  val apply_fee_transfer :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Global_slot_since_genesis.t
    -> ledger
    -> Fee_transfer.t
    -> Transaction_applied.Fee_transfer_applied.t Or_error.t

  val apply_coinbase :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Global_slot_since_genesis.t
    -> ledger
    -> Coinbase.t
    -> Transaction_applied.Coinbase_applied.t Or_error.t

  val apply_transaction_first_pass :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> global_slot:Global_slot_since_genesis.t
    -> txn_state_view:Zkapp_precondition.Protocol_state.View.t
    -> ledger
    -> Transaction.t
    -> Transaction_partially_applied.t Or_error.t

  val apply_transaction_second_pass :
       ledger
    -> Transaction_partially_applied.t
    -> Transaction_applied.t Or_error.t

  val apply_transactions :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> global_slot:Mina_numbers.Global_slot_since_genesis.t
    -> txn_state_view:Zkapp_precondition.Protocol_state.View.t
    -> ledger
    -> Transaction.t list
    -> Transaction_applied.t list Or_error.t

  val has_locked_tokens :
       global_slot:Global_slot_since_genesis.t
    -> account_id:Account_id.t
    -> ledger
    -> bool Or_error.t

  module For_tests : sig
    module Stack (Elt : sig
      type t
    end) : sig
      type t = Elt.t list

      val if_ : bool -> then_:t -> else_:t -> t

      val empty : unit -> t

      val is_empty : t -> bool

      val pop_exn : t -> Elt.t * t

      val pop : t -> (Elt.t * t) option

      val push : Elt.t -> onto:t -> t
    end

    val validate_timing_with_min_balance :
         account:Account.t
      -> txn_amount:Amount.t
      -> txn_global_slot:Global_slot_since_genesis.t
      -> (Account.Timing.t * [> `Min_balance of Balance.t ]) Or_error.t

    val validate_timing :
         account:Account.t
      -> txn_amount:Amount.t
      -> txn_global_slot:Global_slot_since_genesis.t
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
        at global slot %{sexp: Global_slot_since_genesis.t}, the balance \
        %{sexp: Balance.t} is insufficient"
      kind txn_amount txn_global_slot account.Account.Poly.balance
    |> Or_error.tag ~tag:nsf_tag
  in
  let min_balance_error min_balance =
    Or_error.errorf
      !"For timed account, the requested transaction for amount %{sexp: \
        Amount.t} at global slot %{sexp: Global_slot_since_genesis.t}, \
        applying the transaction would put the balance below the calculated \
        minimum balance of %{sexp: Balance.t}"
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

module Make (L : Ledger_intf.S) :
  S with type ledger := L.t and type location := L.location = struct
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
            failwith "Ledger location with no account" )
    | None ->
        Ok (`New, Account.create account_id Balance.zero)

  let set_with_location ledger location account =
    match location with
    | `Existing location ->
        Ok (set ledger location account)
    | `New ->
        create_new_account ledger (Account.identifier account) account

  let add_amount balance amount =
    error_opt "overflow" (Balance.add_amount balance amount)

  let sub_amount balance amount =
    error_opt "insufficient funds" (Balance.sub_amount balance amount)

  let sub_account_creation_fee
      ~(constraint_constants : Genesis_constants.Constraint_constants.t) action
      amount =
    let fee = constraint_constants.account_creation_fee in
    if Ledger_intf.equal_account_state action `Added then
      error_opt
        (sprintf
           !"Error subtracting account creation fee %{sexp: Currency.Fee.t}; \
             transaction amount %{sexp: Currency.Amount.t} insufficient"
           fee amount )
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
      Global_slot_since_genesis.(current_global_slot <= valid_until)
      !"Current global slot %{sexp: Global_slot_since_genesis.t} greater than \
        transaction expiry slot %{sexp: Global_slot_since_genesis.t}"
      current_global_slot valid_until

  module Transaction_applied = struct
    include Transaction_applied

    let transaction : t -> Transaction.t With_status.t =
     fun { varying; _ } ->
      match varying with
      | Command (Signed_command uc) ->
          With_status.map uc.common.user_command ~f:(fun cmd ->
              Transaction.Command (User_command.Signed_command cmd) )
      | Command (Zkapp_command s) ->
          With_status.map s.command ~f:(fun c ->
              Transaction.Command (User_command.Zkapp_command c) )
      | Fee_transfer f ->
          With_status.map f.fee_transfer ~f:(fun f ->
              Transaction.Fee_transfer f )
      | Coinbase c ->
          With_status.map c.coinbase ~f:(fun c -> Transaction.Coinbase c)

    let transaction_status : t -> Transaction_status.t =
     fun { varying; _ } ->
      match varying with
      | Command
          (Signed_command { common = { user_command = { status; _ }; _ }; _ })
        ->
          status
      | Command (Zkapp_command c) ->
          c.command.status
      | Fee_transfer f ->
          f.fee_transfer.status
      | Coinbase c ->
          c.coinbase.status
  end

  let get_new_accounts action pk =
    if Ledger_intf.equal_account_state action `Added then [ pk ] else []

  let has_locked_tokens ~global_slot ~account_id ledger =
    let open Or_error.Let_syntax in
    let%map _, account = get_with_location ledger account_id in
    Account.has_locked_tokens ~global_slot account

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
    let%bind location, account = get_with_location ledger fee_payer in
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
    , { account with
        balance
      ; nonce = Account.Nonce.succ account.nonce
      ; receipt_chain_hash =
          Receipt.Chain_hash.cons_signed_command_payload command
            account.receipt_chain_hash
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
    let%map loc, account' =
      pay_fee' ~command:(Signed_command_payload user_command.payload) ~nonce
        ~fee_payer
        ~fee:(Signed_command.fee user_command)
        ~ledger ~current_global_slot
    in
    (loc, account')

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
    let%bind fee_payer_location, fee_payer_account =
      pay_fee ~user_command ~signer_pk ~ledger ~current_global_slot
    in
    let%bind () =
      if Account.has_permission_to_send fee_payer_account then Ok ()
      else
        Or_error.error_string
          Transaction_status.Failure.(describe Update_not_permitted_balance)
    in
    let%bind () =
      if Account.has_permission_to_increment_nonce fee_payer_account then Ok ()
      else
        Or_error.error_string
          Transaction_status.Failure.(describe Update_not_permitted_nonce)
    in
    (* Charge the fee. This must happen, whether or not the command itself
       succeeds, to ensure that the network is compensated for processing this
       command.
    *)
    let%bind () =
      set_with_location ledger fee_payer_location fee_payer_account
    in
    let receiver = Signed_command.receiver user_command in
    let exception Reject of Error.t in
    let ok_or_reject = function Ok x -> x | Error err -> raise (Reject err) in
    let compute_updates () =
      let open Result.Let_syntax in
      (* Compute the necessary changes to apply the command, failing if any of
         the conditions are not met.
      *)
      match payload.body with
      | Stake_delegation _ ->
          let receiver_location, _receiver_account =
            (* Check that receiver account exists. *)
            get_with_location ledger receiver |> ok_or_reject
          in
          let%bind () =
            match receiver_location with
            | `Existing _ ->
                return ()
            | `New ->
                Result.fail Transaction_status.Failure.Receiver_not_present
          in
          let%bind () =
            Result.ok_if_true
              (Account.has_permission_to_set_delegate fee_payer_account)
              ~error:Transaction_status.Failure.Update_not_permitted_delegate
          in
          let previous_delegate = fee_payer_account.delegate in
          (* Timing is always valid, but we need to record any switch from
             timed to untimed here to stay in sync with the snark.
          *)
          let%map fee_payer_account =
            let%map timing =
              validate_timing ~txn_amount:Amount.zero
                ~txn_global_slot:current_global_slot ~account:fee_payer_account
              |> Result.map_error ~f:timing_error_to_user_command_status
            in
            { fee_payer_account with
              delegate = Some (Account_id.public_key receiver)
            ; timing
            }
          in
          ( [ (fee_payer_location, fee_payer_account) ]
          , Transaction_applied.Signed_command_applied.Body.Stake_delegation
              { previous_delegate } )
      | Payment { amount; _ } ->
          let%bind fee_payer_account =
            let ret =
              let%bind balance =
                Result.map_error (sub_amount fee_payer_account.balance amount)
                  ~f:(fun _ ->
                    Transaction_status.Failure.Source_insufficient_balance )
              in
              let%map timing =
                validate_timing ~txn_amount:amount
                  ~txn_global_slot:current_global_slot
                  ~account:fee_payer_account
                |> Result.map_error ~f:timing_error_to_user_command_status
              in
              { fee_payer_account with balance; timing }
            in
            (* Don't accept transactions with insufficient balance from the fee-payer.
               TODO: eliminate this condition and accept transaction with failed status
            *)
            match ret with
            | Ok x ->
                Ok x
            | Error failure ->
                raise
                  (Reject
                     (Error.createf "%s"
                        (Transaction_status.Failure.describe failure) ) )
          in
          let receiver_location, receiver_account =
            if Account_id.equal fee_payer receiver then
              (fee_payer_location, fee_payer_account)
            else get_with_location ledger receiver |> ok_or_reject
          in
          let%bind () =
            Result.ok_if_true
              (Account.has_permission_to_send fee_payer_account)
              ~error:Transaction_status.Failure.Update_not_permitted_balance
          in
          let%bind () =
            Result.ok_if_true
              (Account.has_permission_to_receive receiver_account)
              ~error:Transaction_status.Failure.Update_not_permitted_balance
          in
          (* Charge the account creation fee. *)
          let%bind receiver_amount =
            match receiver_location with
            | `Existing _ ->
                return amount
            | `New ->
                (* Subtract the creation fee from the transaction amount. *)
                sub_account_creation_fee ~constraint_constants `Added amount
                |> Result.map_error ~f:(fun _ ->
                       Transaction_status.Failure
                       .Amount_insufficient_to_create_account )
          in
          let%map receiver_account =
            incr_balance receiver_account receiver_amount
          in
          let new_accounts =
            match receiver_location with
            | `Existing _ ->
                []
            | `New ->
                [ receiver ]
          in
          let updated_accounts =
            if Account_id.equal fee_payer receiver then
              (* [receiver_account] at this point has all the updates*)
              [ (receiver_location, receiver_account) ]
            else
              [ (receiver_location, receiver_account)
              ; (fee_payer_location, fee_payer_account)
              ]
          in
          ( updated_accounts
          , Transaction_applied.Signed_command_applied.Body.Payment
              { new_accounts } )
    in
    match compute_updates () with
    | Ok (located_accounts, applied_body) ->
        (* Update the ledger. *)
        let%bind () =
          List.fold located_accounts ~init:(Ok ())
            ~f:(fun acc (location, account) ->
              let%bind () = acc in
              set_with_location ledger location account )
        in
        let applied_common : Transaction_applied.Signed_command_applied.Common.t
            =
          { user_command = { data = user_command; status = Applied } }
        in
        return
          ( { common = applied_common; body = applied_body }
            : Transaction_applied.Signed_command_applied.t )
    | Error failure ->
        (* Do not update the ledger. Except for the fee payer which is already updated *)
        let applied_common : Transaction_applied.Signed_command_applied.Common.t
            =
          { user_command =
              { data = user_command
              ; status =
                  Failed
                    (Transaction_status.Failure.Collection.of_single_failure
                       failure )
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

  module Global_state = struct
    type t =
      { first_pass_ledger : L.t
      ; second_pass_ledger : L.t
      ; fee_excess : Amount.Signed.t
      ; supply_increase : Amount.Signed.t
      ; protocol_state : Zkapp_precondition.Protocol_state.View.t
      ; block_global_slot : Global_slot_since_genesis.t
      }

    let first_pass_ledger { first_pass_ledger; _ } =
      L.create_masked first_pass_ledger

    let set_first_pass_ledger ~should_update t ledger =
      if should_update then L.apply_mask t.first_pass_ledger ~masked:ledger ;
      t

    let second_pass_ledger { second_pass_ledger; _ } =
      L.create_masked second_pass_ledger

    let set_second_pass_ledger ~should_update t ledger =
      if should_update then L.apply_mask t.second_pass_ledger ~masked:ledger ;
      t

    let fee_excess { fee_excess; _ } = fee_excess

    let set_fee_excess t fee_excess = { t with fee_excess }

    let supply_increase { supply_increase; _ } = supply_increase

    let set_supply_increase t supply_increase = { t with supply_increase }

    let block_global_slot { block_global_slot; _ } = block_global_slot
  end

  module Transaction_partially_applied = struct
    module Zkapp_command_partially_applied = struct
      type t =
        { command : Zkapp_command.t
        ; previous_hash : Ledger_hash.t
        ; original_first_pass_account_states :
            (Account_id.t * (location * Account.t) option) list
        ; constraint_constants : Genesis_constants.Constraint_constants.t
        ; state_view : Zkapp_precondition.Protocol_state.View.t
        ; global_state : Global_state.t
        ; local_state :
            ( Stack_frame.value
            , Stack_frame.value list
            , Amount.Signed.t
            , L.t
            , bool
            , Zkapp_command.Transaction_commitment.t
            , Mina_numbers.Index.t
            , Transaction_status.Failure.Collection.t )
            Zkapp_command_logic.Local_state.t
        }
    end

    type 'applied fully_applied =
      { previous_hash : Ledger_hash.t; applied : 'applied }

    (* TODO: lift previous_hash up in the types *)
    type t =
      | Signed_command of
          Transaction_applied.Signed_command_applied.t fully_applied
      | Zkapp_command of Zkapp_command_partially_applied.t
      | Fee_transfer of Transaction_applied.Fee_transfer_applied.t fully_applied
      | Coinbase of Transaction_applied.Coinbase_applied.t fully_applied

    let command (t : t) : Transaction.t =
      match t with
      | Signed_command s ->
          Transaction.Command
            (User_command.Signed_command s.applied.common.user_command.data)
      | Zkapp_command z ->
          Command (User_command.Zkapp_command z.command)
      | Fee_transfer f ->
          Fee_transfer f.applied.fee_transfer.data
      | Coinbase c ->
          Coinbase c.applied.coinbase.data
  end

  module Inputs = struct
    let with_label ~label:_ f = f ()

    let value_if b ~then_ ~else_ = if b then then_ else else_

    module Global_state = Global_state

    module Field = struct
      type t = Snark_params.Tick.Field.t

      let if_ = value_if

      let equal = Snark_params.Tick.Field.equal
    end

    module Bool = struct
      type t = bool

      module Assert = struct
        let is_true ~pos b =
          try assert b
          with Assert_failure _ ->
            let file, line, col, _ecol = pos in
            raise (Assert_failure (file, line, col))

        let any ~pos bs = List.exists ~f:Fn.id bs |> is_true ~pos
      end

      let if_ = value_if

      let true_ = true

      let false_ = false

      let equal = Bool.equal

      let not = not

      let ( ||| ) = ( || )

      let ( &&& ) = ( && )

      let display b ~label = sprintf "%s: %b" label b

      let all = List.for_all ~f:Fn.id

      type failure_status = Transaction_status.Failure.t option

      type failure_status_tbl = Transaction_status.Failure.Collection.t

      let is_empty t = List.join t |> List.is_empty

      let assert_with_failure_status_tbl ~pos b failure_status_tbl =
        let file, line, col, ecol = pos in
        if (not b) && not (is_empty failure_status_tbl) then
          (* Raise a more useful error message if we have a failure
             description. *)
          let failure_msg =
            Yojson.Safe.to_string
            @@ Transaction_status.Failure.Collection.Display.to_yojson
            @@ Transaction_status.Failure.Collection.to_display
                 failure_status_tbl
          in
          Error.raise @@ Error.of_string
          @@ sprintf "File %S, line %d, characters %d-%d: %s" file line col ecol
               failure_msg
        else
          try assert b
          with Assert_failure _ -> raise (Assert_failure (file, line, col))
    end

    module Account_id = struct
      include Account_id

      let if_ = value_if
    end

    module Ledger = struct
      type t = L.t

      let if_ = value_if

      let empty = L.empty

      type inclusion_proof = [ `Existing of location | `New ]

      let get_account p l =
        let loc, acct =
          Or_error.ok_exn (get_with_location l (Account_update.account_id p))
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
      type t = Field.t

      let empty = Zkapp_command.Transaction_commitment.empty

      let commitment ~account_updates =
        let account_updates_hash =
          Mina_base.Zkapp_command.Call_forest.hash account_updates
        in
        Zkapp_command.Transaction_commitment.create ~account_updates_hash

      let full_commitment ~account_update ~memo_hash ~commitment =
        (* when called from Zkapp_command_logic.apply, the account_update is the fee payer *)
        let fee_payer_hash =
          Zkapp_command.Digest.Account_update.create account_update
        in
        Zkapp_command.Transaction_commitment.create_complete commitment
          ~memo_hash ~fee_payer_hash

      let if_ = value_if
    end

    module Index = struct
      type t = Mina_numbers.Index.t

      let zero, succ = Mina_numbers.Index.(zero, succ)

      let if_ = value_if
    end

    module Public_key = struct
      type t = Public_key.Compressed.t

      let if_ = value_if
    end

    module Controller = struct
      type t = Permissions.Auth_required.t

      let if_ = value_if

      let check ~proof_verifies ~signature_verifies perm =
        (* Invariant: We either have a proof, a signature, or neither. *)
        assert (not (proof_verifies && signature_verifies)) ;
        let tag =
          if proof_verifies then Control.Tag.Proof
          else if signature_verifies then Control.Tag.Signature
          else Control.Tag.None_given
        in
        Permissions.Auth_required.check perm tag

      let verification_key_perm_fallback_to_signature_with_older_version =
        Permissions.Auth_required
        .verification_key_perm_fallback_to_signature_with_older_version
    end

    module Txn_version = struct
      type t = Mina_numbers.Txn_version.t

      let if_ = value_if

      let equal_to_current = Mina_numbers.Txn_version.equal_to_current

      let older_than_current = Mina_numbers.Txn_version.older_than_current
    end

    module Global_slot_since_genesis = struct
      include Mina_numbers.Global_slot_since_genesis

      let if_ = value_if
    end

    module Global_slot_span = struct
      include Mina_numbers.Global_slot_span

      let if_ = value_if
    end

    module Nonce = struct
      type t = Account.Nonce.t

      let if_ = value_if

      let succ = Account.Nonce.succ
    end

    module Receipt_chain_hash = struct
      type t = Receipt.Chain_hash.t

      module Elt = struct
        type t = Receipt.Zkapp_command_elt.t

        let of_transaction_commitment tc =
          Receipt.Zkapp_command_elt.Zkapp_command_commitment tc
      end

      let cons_zkapp_command_commitment =
        Receipt.Chain_hash.cons_zkapp_command_commitment

      let if_ = value_if
    end

    module State_hash = struct
      include State_hash

      let if_ = value_if
    end

    module Timing = struct
      type t = Account_update.Update.Timing_info.t option

      let if_ = value_if

      let vesting_period (t : t) =
        match t with
        | Some t ->
            t.vesting_period
        | None ->
            (Account_timing.to_record Untimed).vesting_period
    end

    module Balance = struct
      include Balance

      let if_ = value_if
    end

    module Verification_key = struct
      type t = (Side_loaded_verification_key.t, Field.t) With_hash.t option

      let if_ = value_if
    end

    module Verification_key_hash = struct
      type t = Field.t option

      let equal vk1 vk2 = Option.equal Field.equal vk1 vk2
    end

    module Actions = struct
      type t = Zkapp_account.Actions.t

      let is_empty = List.is_empty

      let push_events = Account_update.Actions.push_events
    end

    module Zkapp_uri = struct
      type t = string

      let if_ = value_if
    end

    module Token_symbol = struct
      type t = Account.Token_symbol.t

      let if_ = value_if
    end

    module Account = struct
      include Account

      module Permissions = struct
        let access : t -> Controller.t = fun a -> a.permissions.access

        let edit_state : t -> Controller.t = fun a -> a.permissions.edit_state

        let send : t -> Controller.t = fun a -> a.permissions.send

        let receive : t -> Controller.t = fun a -> a.permissions.receive

        let set_delegate : t -> Controller.t =
         fun a -> a.permissions.set_delegate

        let set_permissions : t -> Controller.t =
         fun a -> a.permissions.set_permissions

        let set_verification_key_auth : t -> Controller.t =
         fun a -> fst a.permissions.set_verification_key

        let set_verification_key_txn_version : t -> Txn_version.t =
         fun a -> snd a.permissions.set_verification_key

        let set_zkapp_uri : t -> Controller.t =
         fun a -> a.permissions.set_zkapp_uri

        let edit_action_state : t -> Controller.t =
         fun a -> a.permissions.edit_action_state

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
          validate_timing_with_min_balance' ~txn_amount:Amount.zero
            ~txn_global_slot ~account
        in
        ( invalid_timing
        , Account_update.Update.Timing_info.of_account_timing timing )

      let receipt_chain_hash (a : t) : Receipt.Chain_hash.t =
        a.receipt_chain_hash

      let set_receipt_chain_hash (a : t) hash =
        { a with receipt_chain_hash = hash }

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

      let last_action_slot (a : t) = (get_zkapp a).last_action_slot

      let set_last_action_slot last_action_slot (a : t) =
        set_zkapp a ~f:(fun zkapp -> { zkapp with last_action_slot })

      let action_state (a : t) = (get_zkapp a).action_state

      let set_action_state action_state (a : t) =
        set_zkapp a ~f:(fun zkapp -> { zkapp with action_state })

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

      let if_ = value_if

      module Signed = struct
        include Signed

        let if_ = value_if

        (* Correctness of these functions hinges on the fact that zero is
           only ever expressed as {sgn = Pos; magnitude = zero}. Sadly, this
           is not guaranteed by the module's signature, as it's internal
           structure is exposed. Create function never produces this unwanted
           value, but the type's internal structure is still exposed, so it's
           possible theoretically to obtain it.

           For the moment, however, there is some consolation in the fact that
           addition never produces negative zero, even if it was one of its
           arguments. For that reason the risk of this function misbehaving is
           minimal and can probably be safely ignored. *)
        let is_non_neg (t : t) = Sgn.equal t.sgn Pos

        let is_neg (t : t) = Sgn.equal t.sgn Neg
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

      let if_ = value_if
    end

    module Protocol_state_precondition = struct
      include Zkapp_precondition.Protocol_state
    end

    module Valid_while_precondition = struct
      include Zkapp_precondition.Valid_while
    end

    module Account_update = struct
      include Account_update

      module Account_precondition = struct
        include Account_update.Account_precondition

        let nonce (t : Account_update.t) = nonce t.body.preconditions.account
      end

      type 'a or_ignore = 'a Zkapp_basic.Or_ignore.t

      type call_forest = Zkapp_call_forest.t

      type transaction_commitment = Transaction_commitment.t

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

        let app_state (account_update : t) =
          account_update.body.update.app_state

        let verification_key (account_update : t) =
          Zkapp_basic.Set_or_keep.map ~f:Option.some
            account_update.body.update.verification_key

        let actions (account_update : t) = account_update.body.actions

        let zkapp_uri (account_update : t) =
          account_update.body.update.zkapp_uri

        let token_symbol (account_update : t) =
          account_update.body.update.token_symbol

        let delegate (account_update : t) = account_update.body.update.delegate

        let voting_for (account_update : t) =
          account_update.body.update.voting_for

        let permissions (account_update : t) =
          account_update.body.update.permissions
      end
    end

    module Set_or_keep = struct
      include Zkapp_basic.Set_or_keep

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

      let if_ = value_if

      let empty () = []

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

    module Call_forest = Zkapp_call_forest

    module Stack_frame = struct
      include Stack_frame

      type t = value

      let if_ = Zkapp_command.value_if

      let make = Stack_frame.make
    end

    module Call_stack = Stack (Stack_frame)

    module Local_state = struct
      type t =
        ( Stack_frame.t
        , Call_stack.t
        , Amount.Signed.t
        , Ledger.t
        , Bool.t
        , Transaction_commitment.t
        , Index.t
        , Bool.failure_status_tbl )
        Zkapp_command_logic.Local_state.t

      let add_check (t : t) failure b =
        let failure_status_tbl =
          match t.failure_status_tbl with
          | hd :: tl when not b ->
              (failure :: hd) :: tl
          | old_failure_status_tbl ->
              old_failure_status_tbl
        in
        { t with failure_status_tbl; success = t.success && b }

      let update_failure_status_tbl (t : t) failure_status b =
        match failure_status with
        | None ->
            { t with success = t.success && b }
        | Some failure ->
            add_check t failure b

      let add_new_failure_status_bucket (t : t) =
        { t with failure_status_tbl = [] :: t.failure_status_tbl }
    end

    module Nonce_precondition = struct
      let is_constant =
        Zkapp_precondition.Numeric.is_constant
          Zkapp_precondition.Numeric.Tc.nonce
    end
  end

  module Env = struct
    open Inputs

    type t =
      < account_update : Account_update.t
      ; zkapp_command : Zkapp_command.t
      ; account : Account.t
      ; ledger : Ledger.t
      ; amount : Amount.t
      ; signed_amount : Amount.Signed.t
      ; bool : Bool.t
      ; token_id : Token_id.t
      ; global_state : Global_state.t
      ; inclusion_proof : [ `Existing of location | `New ]
      ; local_state :
          ( Stack_frame.t
          , Call_stack.t
          , Amount.Signed.t
          , L.t
          , bool
          , Transaction_commitment.t
          , Index.t
          , Transaction_status.Failure.Collection.t )
          Zkapp_command_logic.Local_state.t
      ; protocol_state_precondition : Zkapp_precondition.Protocol_state.t
      ; valid_while_precondition : Zkapp_precondition.Valid_while.t
      ; transaction_commitment : Transaction_commitment.t
      ; full_transaction_commitment : Transaction_commitment.t
      ; field : Snark_params.Tick.Field.t
      ; failure : Transaction_status.Failure.t option >

    let perform ~constraint_constants:_ (type r)
        (eff : (r, t) Zkapp_command_logic.Eff.t) : r =
      match eff with
      | Check_valid_while_precondition (valid_while, global_state) ->
          Zkapp_precondition.Valid_while.check valid_while
            global_state.block_global_slot
          |> Or_error.is_ok
      | Check_protocol_state_precondition (pred, global_state) -> (
          Zkapp_precondition.Protocol_state.check pred
            global_state.protocol_state
          |> fun or_err -> match or_err with Ok () -> true | Error _ -> false )
      | Check_account_precondition
          (account_update, account, new_account, local_state) ->
          let local_state = ref local_state in
          let check failure b =
            local_state := Inputs.Local_state.add_check !local_state failure b
          in
          Zkapp_precondition.Account.check ~new_account ~check
            account_update.body.preconditions.account account ;
          !local_state
      | Init_account { account_update = _; account = a } ->
          a
  end

  module M = Zkapp_command_logic.Make (Inputs)

  let update_action_state action_state actions ~txn_global_slot
      ~last_action_slot =
    let action_state', last_action_slot' =
      M.update_action_state action_state actions ~txn_global_slot
        ~last_action_slot
    in
    (action_state', last_action_slot')

  (* apply zkapp command fee payer's while stubbing out the second pass ledger
     CAUTION: If you use the intermediate local states, you MUST update the
       [will_succeed] field to [false] if the [status] is [Failed].*)
  let apply_zkapp_command_first_pass_aux (type user_acc) ~constraint_constants
      ~global_slot ~(state_view : Zkapp_precondition.Protocol_state.View.t)
      ~(init : user_acc) ~f
      ?((* TODO: can this be ripped out from here? *)
        fee_excess = Amount.Signed.zero)
      ?((* TODO: is the right? is it never used for zkapps? *)
        supply_increase = Amount.Signed.zero) (ledger : L.t)
      (command : Zkapp_command.t) :
      ( Transaction_partially_applied.Zkapp_command_partially_applied.t
      * user_acc )
      Or_error.t =
    let open Or_error.Let_syntax in
    let previous_hash = merkle_root ledger in
    let original_first_pass_account_states =
      let id = Zkapp_command.fee_payer command in
      [ ( id
        , Option.Let_syntax.(
            let%bind loc = L.location_of_account ledger id in
            let%map a = L.get ledger loc in
            (loc, a)) )
      ]
    in
    let perform eff = Env.perform ~constraint_constants eff in
    let initial_state :
        Inputs.Global_state.t * _ Zkapp_command_logic.Local_state.t =
      ( { protocol_state = state_view
        ; first_pass_ledger = ledger
        ; second_pass_ledger =
            (* We stub out the second_pass_ledger initially, and then poke the
               correct value in place after the first pass is finished.
            *)
            L.empty ~depth:0 ()
        ; fee_excess
        ; supply_increase
        ; block_global_slot = global_slot
        }
      , { stack_frame =
            ({ calls = []
             ; caller = Token_id.default
             ; caller_caller = Token_id.default
             } : Inputs.Stack_frame.t)
        ; call_stack = []
        ; transaction_commitment = Inputs.Transaction_commitment.empty
        ; full_transaction_commitment = Inputs.Transaction_commitment.empty
        ; excess = Currency.Amount.(Signed.of_unsigned zero)
        ; supply_increase = Currency.Amount.(Signed.of_unsigned zero)
        ; ledger = L.empty ~depth:0 ()
        ; success = true
        ; account_update_index = Inputs.Index.zero
        ; failure_status_tbl = []
        ; will_succeed = true
        } )
    in
    let user_acc = f init initial_state in
    let account_updates = Zkapp_command.all_account_updates command in
    let%map global_state, local_state =
      Or_error.try_with (fun () ->
          M.start ~constraint_constants
            { account_updates
            ; memo_hash = Signed_command_memo.hash command.memo
            ; will_succeed =
                (* It's always valid to set this value to true, and it will
                   have no effect outside of the snark.
                *)
                true
            }
            { perform } initial_state )
    in
    ( { Transaction_partially_applied.Zkapp_command_partially_applied.command
      ; previous_hash
      ; original_first_pass_account_states
      ; constraint_constants
      ; state_view
      ; global_state
      ; local_state
      }
    , user_acc )

  let apply_zkapp_command_first_pass ~constraint_constants ~global_slot
      ~(state_view : Zkapp_precondition.Protocol_state.View.t)
      ?((* TODO: can this be ripped out from here? *)
        fee_excess = Amount.Signed.zero)
      ?((* TODO: is the right? is it never used for zkapps? *)
        supply_increase = Amount.Signed.zero) (ledger : L.t)
      (command : Zkapp_command.t) :
      Transaction_partially_applied.Zkapp_command_partially_applied.t Or_error.t
      =
    let open Or_error.Let_syntax in
    let%map partial_stmt, _user_acc =
      apply_zkapp_command_first_pass_aux ~constraint_constants ~global_slot
        ~state_view ~fee_excess ~supply_increase ledger command ~init:None
        ~f:(fun _acc state -> Some state)
    in
    partial_stmt

  let apply_zkapp_command_second_pass_aux (type user_acc) ~(init : user_acc) ~f
      ledger
      (c : Transaction_partially_applied.Zkapp_command_partially_applied.t) :
      (Transaction_applied.Zkapp_command_applied.t * user_acc) Or_error.t =
    let open Or_error.Let_syntax in
    let perform eff =
      Env.perform ~constraint_constants:c.constraint_constants eff
    in
    let original_account_states =
      (*get the original states of all the accounts in each pass.
        If an account updated in the first pass is referenced in account
        updates, then retain the value before first pass application*)
      (* IMPORTANT: this account list must be sorted by Account_id in increasing order,
         if this ordering changes the scan state hash will be affected and made
         incompatible. *)
      Account_id.Map.to_alist ~key_order:`Increasing
      @@ List.fold ~init:Account_id.Map.empty
           ~f:(fun account_states (id, acc_opt) ->
             Account_id.Map.update account_states id
               ~f:(Option.value ~default:acc_opt) )
           ( c.original_first_pass_account_states
           @ List.map (Zkapp_command.accounts_referenced c.command)
               ~f:(fun id ->
                 ( id
                 , Option.Let_syntax.(
                     let%bind loc = L.location_of_account ledger id in
                     let%map a = L.get ledger loc in
                     (loc, a)) ) ) )
    in
    let rec step_all (user_acc : user_acc)
        ( (g_state : Inputs.Global_state.t)
        , (l_state : _ Zkapp_command_logic.Local_state.t) ) :
        (user_acc * Transaction_status.Failure.Collection.t) Or_error.t =
      if List.is_empty l_state.stack_frame.Stack_frame.calls then
        Ok (user_acc, l_state.failure_status_tbl)
      else
        let%bind states =
          Or_error.try_with (fun () ->
              M.step ~constraint_constants:c.constraint_constants { perform }
                (g_state, l_state) )
        in
        step_all (f user_acc states) states
    in
    let account_states_after_fee_payer =
      (*To check if the accounts remain unchanged in the event the transaction
         fails. First pass updates will remain even if the transaction fails to
         apply zkapp account updates*)
      List.map (Zkapp_command.accounts_referenced c.command) ~f:(fun id ->
          ( id
          , Option.Let_syntax.(
              let%bind loc = L.location_of_account ledger id in
              let%map a = L.get ledger loc in
              (loc, a)) ) )
    in
    let accounts () =
      List.map original_account_states
        ~f:(Tuple2.map_snd ~f:(Option.map ~f:snd))
    in
    (* Warning: This is an abstraction leak / hack.
       Here, we update global second pass ledger to be the input ledger, and
       then update the local ledger to be the input ledger *IF AND ONLY IF*
       there are more transaction segments to be processed in this pass.

       TODO: Remove this, and uplift the logic into the call in staged ledger.
    *)
    let global_state = { c.global_state with second_pass_ledger = ledger } in
    let local_state =
      if List.is_empty c.local_state.stack_frame.Stack_frame.calls then
        (* Don't mess with the local state; we've already finished the
           transaction after the fee payer.
        *)
        c.local_state
      else
        (* Install the ledger that should already be in the local state, but
           may not be in some situations depending on who the caller is.
        *)
        { c.local_state with
          ledger = Global_state.second_pass_ledger global_state
        }
    in
    let start = (global_state, local_state) in
    match step_all (f init start) start with
    | Error e ->
        Error e
    | Ok (user_acc, reversed_failure_status_tbl) ->
        let failure_status_tbl = List.rev reversed_failure_status_tbl in
        let account_ids_originally_not_in_ledger =
          List.filter_map original_account_states
            ~f:(fun (acct_id, loc_and_acct) ->
              if Option.is_none loc_and_acct then Some acct_id else None )
        in
        let successfully_applied =
          Transaction_status.Failure.Collection.is_empty failure_status_tbl
        in
        (* if the zkapp command fails in at least 1 account update,
           then all the account updates would be cancelled except
           the fee payer one
        *)
        let failure_status_tbl =
          if successfully_applied then failure_status_tbl
          else
            List.mapi failure_status_tbl ~f:(fun idx fs ->
                if idx > 0 && List.is_empty fs then
                  [ Transaction_status.Failure.Cancelled ]
                else fs )
        in
        (* accounts not originally in ledger, now present in ledger *)
        let new_accounts =
          List.filter account_ids_originally_not_in_ledger ~f:(fun acct_id ->
              Option.is_some @@ L.location_of_account ledger acct_id )
        in
        let valid_result =
          Ok
            ( { Transaction_applied.Zkapp_command_applied.accounts = accounts ()
              ; command =
                  { With_status.data = c.command
                  ; status =
                      ( if successfully_applied then Applied
                      else Failed failure_status_tbl )
                  }
              ; new_accounts
              }
            , user_acc )
        in
        if successfully_applied then valid_result
        else
          let other_account_update_accounts_unchanged =
            List.fold_until account_states_after_fee_payer ~init:true
              ~f:(fun acc (_, loc_opt) ->
                match
                  let open Option.Let_syntax in
                  let%bind loc, a = loc_opt in
                  let%bind a' = L.get ledger loc in
                  Option.some_if (not (Account.equal a a')) ()
                with
                | None ->
                    Continue acc
                | Some _ ->
                    Stop false )
              ~finish:Fn.id
          in
          (* Other zkapp_command failed, therefore, updates in those should not get applied *)
          if
            List.is_empty new_accounts
            && other_account_update_accounts_unchanged
          then valid_result
          else
            Or_error.error_string
              "Zkapp_command application failed but new accounts created or \
               some of the other account_update updates applied"

  let apply_zkapp_command_second_pass ledger c :
      Transaction_applied.Zkapp_command_applied.t Or_error.t =
    let open Or_error.Let_syntax in
    let%map x, () =
      apply_zkapp_command_second_pass_aux ~init:() ~f:Fn.const ledger c
    in
    x

  let apply_zkapp_command_unchecked_aux ~constraint_constants ~global_slot
      ~state_view ~init ~f ?fee_excess ?supply_increase ledger command =
    let open Or_error.Let_syntax in
    apply_zkapp_command_first_pass_aux ~constraint_constants ~global_slot
      ~state_view ?fee_excess ?supply_increase ledger command ~init ~f
    >>= fun (partial_stmt, user_acc) ->
    apply_zkapp_command_second_pass_aux ~init:user_acc ~f ledger partial_stmt

  let apply_zkapp_command_unchecked ~constraint_constants ~global_slot
      ~state_view ledger command =
    let open Or_error.Let_syntax in
    apply_zkapp_command_first_pass ~constraint_constants ~global_slot
      ~state_view ledger command
    >>= apply_zkapp_command_second_pass_aux ledger ~init:None
          ~f:(fun _acc (global_state, local_state) ->
            Some (local_state, global_state.fee_excess) )
    |> Result.map ~f:(fun (account_update_applied, state_res) ->
           (account_update_applied, Option.value_exn state_res) )

  let update_timing_when_no_deduction ~txn_global_slot account =
    validate_timing ~txn_amount:Amount.zero ~txn_global_slot ~account

  let has_permission_to_receive ~ledger receiver_account_id :
      Account.t
      * Ledger_intf.account_state
      * [> `Has_permission_to_receive of bool ] =
    let init_account = Account.initialize receiver_account_id in
    match location_of_account ledger receiver_account_id with
    | None ->
        (* new account, check that default permissions allow receiving *)
        ( init_account
        , `Added
        , `Has_permission_to_receive
            (Account.has_permission_to_receive init_account) )
    | Some loc -> (
        match get ledger loc with
        | None ->
            failwith "Ledger location with no account"
        | Some receiver_account ->
            ( receiver_account
            , `Existed
            , `Has_permission_to_receive
                (Account.has_permission_to_receive receiver_account) ) )

  let no_failure = []

  let update_failed =
    [ Transaction_status.Failure.Update_not_permitted_balance ]

  let empty = Transaction_status.Failure.Collection.empty

  let single_failure =
    Transaction_status.Failure.Collection.of_single_failure
      Update_not_permitted_balance

  let append_entry f (s : Transaction_status.Failure.Collection.t) :
      Transaction_status.Failure.Collection.t =
    match s with [] -> [ f ] | h :: t -> h :: f :: t

  (*Structure of the failure status:
     I. Only one fee transfer in the transaction (`One) and it fails:
        [[failure]]
     II. Two fee transfers in the transaction (`Two)-
      Both fee transfers fail:
        [[failure-of-first-fee-transfer]; [failure-of-second-fee-transfer]]
      First succeeds and second one fails:
        [[];[failure-of-second-fee-transfer]]
      First fails and second succeeds:
        [[failure-of-first-fee-transfer];[]]
  *)
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
        let a, action, `Has_permission_to_receive can_receive =
          has_permission_to_receive ~ledger:t account_id
        in
        let%bind timing = modify_timing a in
        let%bind balance = modify_balance action account_id a.balance ft.fee in
        if can_receive then (
          let%map _action, a, loc = get_or_create t account_id in
          let new_accounts = get_new_accounts action account_id in
          set t loc { a with balance; timing } ;
          (new_accounts, empty, Currency.Amount.zero) )
        else Ok ([], single_failure, Currency.Amount.of_fee ft.fee)
    | `Two (ft1, ft2) ->
        let account_id1 = Fee_transfer.Single.receiver ft1 in
        let a1, action1, `Has_permission_to_receive can_receive1 =
          has_permission_to_receive ~ledger:t account_id1
        in
        let account_id2 = Fee_transfer.Single.receiver ft2 in
        if Account_id.equal account_id1 account_id2 then
          let%bind fee = error_opt "overflow" (Fee.add ft1.fee ft2.fee) in
          let%bind timing = modify_timing a1 in
          let%bind balance =
            modify_balance action1 account_id1 a1.balance fee
          in
          if can_receive1 then (
            let%map _action1, a1, l1 = get_or_create t account_id1 in
            let new_accounts1 = get_new_accounts action1 account_id1 in
            set t l1 { a1 with balance; timing } ;
            (new_accounts1, empty, Currency.Amount.zero) )
          else
            (*failure for each fee transfer single*)
            Ok
              ( []
              , append_entry update_failed single_failure
              , Currency.Amount.of_fee fee )
        else
          let a2, action2, `Has_permission_to_receive can_receive2 =
            has_permission_to_receive ~ledger:t account_id2
          in
          let%bind balance1 =
            modify_balance action1 account_id1 a1.balance ft1.fee
          in
          (*Note: Not updating the timing field of a1 to avoid additional check in transactions snark (check_timing for "receiver"). This is OK because timing rules will not be violated when balance increases and will be checked whenever an amount is deducted from the account. (#5973)*)
          let%bind timing2 = modify_timing a2 in
          let%bind balance2 =
            modify_balance action2 account_id2 a2.balance ft2.fee
          in
          let%bind new_accounts1, failures, burned_tokens1 =
            if can_receive1 then (
              let%map _action1, a1, l1 = get_or_create t account_id1 in
              let new_accounts1 = get_new_accounts action1 account_id1 in
              set t l1 { a1 with balance = balance1 } ;
              ( new_accounts1
              , append_entry no_failure empty
              , Currency.Amount.zero ) )
            else Ok ([], single_failure, Currency.Amount.of_fee ft1.fee)
          in
          let%bind new_accounts2, failures', burned_tokens2 =
            if can_receive2 then (
              let%map _action2, a2, l2 = get_or_create t account_id2 in
              let new_accounts2 = get_new_accounts action2 account_id2 in
              set t l2 { a2 with balance = balance2; timing = timing2 } ;
              ( new_accounts2
              , append_entry no_failure failures
              , Currency.Amount.zero ) )
            else
              Ok
                ( []
                , append_entry update_failed failures
                , Currency.Amount.of_fee ft2.fee )
          in
          let%map burned_tokens =
            error_opt "burned tokens overflow"
              (Currency.Amount.add burned_tokens1 burned_tokens2)
          in
          (new_accounts1 @ new_accounts2, failures', burned_tokens)

  let apply_fee_transfer ~constraint_constants ~txn_global_slot t transfer =
    let open Or_error.Let_syntax in
    let%map new_accounts, failures, burned_tokens =
      process_fee_transfer t transfer
        ~modify_balance:(fun action _ b f ->
          let%bind amount =
            let amount = Amount.of_fee f in
            sub_account_creation_fee ~constraint_constants action amount
          in
          add_amount b amount )
        ~modify_timing:(fun acc ->
          update_timing_when_no_deduction ~txn_global_slot acc )
    in
    let ft_with_status =
      if Transaction_status.Failure.Collection.is_empty failures then
        { With_status.data = transfer; status = Applied }
      else { data = transfer; status = Failed failures }
    in
    Transaction_applied.Fee_transfer_applied.
      { fee_transfer = ft_with_status; new_accounts; burned_tokens }

  (*Structure of the failure status:
     I. No fee transfer and coinbase transfer fails: [[failure]]
     II. With fee transfer-
      Both fee transfer and coinbase fails:
        [[failure-of-fee-transfer]; [failure-of-coinbase]]
      Fee transfer succeeds and coinbase fails:
        [[];[failure-of-coinbase]]
      Fee transfer fails and coinbase succeeds:
        [[failure-of-fee-transfer];[]]
  *)
  let apply_coinbase ~constraint_constants ~txn_global_slot t
      (* TODO: Better system needed for making atomic changes. Could use a monad. *)
        ({ receiver; fee_transfer; amount = coinbase_amount } as cb : Coinbase.t)
      =
    let open Or_error.Let_syntax in
    let%bind ( receiver_reward
             , new_accounts1
             , transferee_update
             , transferee_timing_prev
             , failures1
             , burned_tokens1 ) =
      match fee_transfer with
      | None ->
          return (coinbase_amount, [], None, None, empty, Currency.Amount.zero)
      | Some ({ receiver_pk = transferee; fee } as ft) ->
          assert (not @@ Public_key.Compressed.equal transferee receiver) ;
          let transferee_id = Coinbase.Fee_transfer.receiver ft in
          let fee = Amount.of_fee fee in
          let%bind receiver_reward =
            error_opt "Coinbase fee transfer too large"
              (Amount.sub coinbase_amount fee)
          in
          let transferee_account, action, `Has_permission_to_receive can_receive
              =
            has_permission_to_receive ~ledger:t transferee_id
          in
          let new_accounts = get_new_accounts action transferee_id in
          let%bind timing =
            update_timing_when_no_deduction ~txn_global_slot transferee_account
          in
          let%bind balance =
            let%bind amount =
              sub_account_creation_fee ~constraint_constants action fee
            in
            add_amount transferee_account.balance amount
          in
          if can_receive then
            let%map _action, transferee_account, transferee_location =
              get_or_create t transferee_id
            in
            ( receiver_reward
            , new_accounts
            , Some
                ( transferee_location
                , { transferee_account with balance; timing } )
            , Some transferee_account.timing
            , append_entry no_failure empty
            , Currency.Amount.zero )
          else return (receiver_reward, [], None, None, single_failure, fee)
    in
    let receiver_id = Account_id.create receiver Token_id.default in
    let receiver_account, action2, `Has_permission_to_receive can_receive =
      has_permission_to_receive ~ledger:t receiver_id
    in
    let new_accounts2 = get_new_accounts action2 receiver_id in
    (* Note: Updating coinbase receiver timing only if there is no fee transfer.
       This is so as to not add any extra constraints in transaction snark for checking
       "receiver" timings. This is OK because timing rules will not be violated when
       balance increases and will be checked whenever an amount is deducted from the
       account (#5973)
    *)
    let%bind coinbase_receiver_timing =
      match transferee_timing_prev with
      | None ->
          let%map new_receiver_timing =
            update_timing_when_no_deduction ~txn_global_slot receiver_account
          in
          new_receiver_timing
      | Some _timing ->
          Ok receiver_account.timing
    in
    let%bind receiver_balance =
      let%bind amount =
        sub_account_creation_fee ~constraint_constants action2 receiver_reward
      in
      add_amount receiver_account.balance amount
    in
    let%bind failures, burned_tokens2 =
      if can_receive then (
        let%map _action2, receiver_account, receiver_location =
          get_or_create t receiver_id
        in
        set t receiver_location
          { receiver_account with
            balance = receiver_balance
          ; timing = coinbase_receiver_timing
          } ;
        (append_entry no_failure failures1, Currency.Amount.zero) )
      else return (append_entry update_failed failures1, receiver_reward)
    in
    Option.iter transferee_update ~f:(fun (l, a) -> set t l a) ;
    let%map burned_tokens =
      error_opt "burned tokens overflow"
        (Amount.add burned_tokens1 burned_tokens2)
    in
    let coinbase_with_status =
      if Transaction_status.Failure.Collection.is_empty failures then
        { With_status.data = cb; status = Applied }
      else { With_status.data = cb; status = Failed failures }
    in
    Transaction_applied.Coinbase_applied.
      { coinbase = coinbase_with_status
      ; new_accounts = new_accounts1 @ new_accounts2
      ; burned_tokens
      }

  let apply_transaction_first_pass ~constraint_constants ~global_slot
      ~(txn_state_view : Zkapp_precondition.Protocol_state.View.t) ledger
      (t : Transaction.t) : Transaction_partially_applied.t Or_error.t =
    let open Or_error.Let_syntax in
    let previous_hash = merkle_root ledger in
    let txn_global_slot = global_slot in
    match t with
    | Command (Signed_command txn) ->
        let%map applied =
          apply_user_command_unchecked ~constraint_constants ~txn_global_slot
            ledger txn
        in
        Transaction_partially_applied.Signed_command { previous_hash; applied }
    | Command (Zkapp_command txn) ->
        let%map partially_applied =
          apply_zkapp_command_first_pass ~global_slot ~state_view:txn_state_view
            ~constraint_constants ledger txn
        in
        Transaction_partially_applied.Zkapp_command partially_applied
    | Fee_transfer t ->
        let%map applied =
          apply_fee_transfer ~constraint_constants ~txn_global_slot ledger t
        in
        Transaction_partially_applied.Fee_transfer { previous_hash; applied }
    | Coinbase t ->
        let%map applied =
          apply_coinbase ~constraint_constants ~txn_global_slot ledger t
        in
        Transaction_partially_applied.Coinbase { previous_hash; applied }

  let apply_transaction_second_pass ledger (t : Transaction_partially_applied.t)
      : Transaction_applied.t Or_error.t =
    let open Or_error.Let_syntax in
    let open Transaction_applied in
    match t with
    | Signed_command { previous_hash; applied } ->
        return
          { previous_hash; varying = Varying.Command (Signed_command applied) }
    | Zkapp_command partially_applied ->
        (* TODO: either here or in second phase of apply, need to update the prior global state statement for the fee payer segment to add the second phase ledger at the end *)
        let%map applied =
          apply_zkapp_command_second_pass ledger partially_applied
        in
        { previous_hash = partially_applied.previous_hash
        ; varying = Varying.Command (Zkapp_command applied)
        }
    | Fee_transfer { previous_hash; applied } ->
        return { previous_hash; varying = Varying.Fee_transfer applied }
    | Coinbase { previous_hash; applied } ->
        return { previous_hash; varying = Varying.Coinbase applied }

  let apply_transactions ~constraint_constants ~global_slot ~txn_state_view
      ledger txns =
    let open Or_error in
    Mina_stdlib.Result.List.map txns
      ~f:
        (apply_transaction_first_pass ~constraint_constants ~global_slot
           ~txn_state_view ledger )
    >>= Mina_stdlib.Result.List.map ~f:(apply_transaction_second_pass ledger)

  module For_tests = struct
    module Stack = Inputs.Stack

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
      , Account.Token_symbol.t
      , Balance.t
      , Account_nonce.t
      , unit
      , Public_key.Compressed.t option
      , State_hash.t
      , Account_timing.t
      , Permissions.t
      , Zkapp_account.t option )
      Account.Poly.t
    [@@deriving sexp, compare]
  end

  let min_init_balance = Int64.of_string "8000000000"

  let max_init_balance = Int64.of_string "8000000000000"

  let num_accounts = 10

  let num_transactions = 10

  let depth = Int.ceil_log2 (num_accounts + num_transactions)

  module Init_ledger = struct
    type t = (Keypair.t * int64) array [@@deriving sexp]

    let init ?(zkapp = true) (type l) (module L : Ledger_intf.S with type t = l)
        (init_ledger : t) (l : L.t) =
      Array.iter init_ledger ~f:(fun (kp, amount) ->
          let _tag, account, loc =
            L.get_or_create l
              (Account_id.create
                 (Public_key.compress kp.public_key)
                 Token_id.default )
            |> Or_error.ok_exn
          in
          let permissions : Permissions.t =
            { edit_state = Either
            ; send = Either
            ; receive = None
            ; set_delegate = Either
            ; set_permissions = Either
            ; set_verification_key = (Either, Mina_numbers.Txn_version.current)
            ; set_zkapp_uri = Either
            ; edit_action_state = Either
            ; set_token_symbol = Either
            ; increment_nonce = Either
            ; set_voting_for = Either
            ; access = None
            ; set_timing = Either
            }
          in
          let zkapp =
            if zkapp then
              Some
                { Zkapp_account.default with
                  verification_key =
                    Some
                      { With_hash.hash = Zkapp_basic.F.zero
                      ; data = Side_loaded_verification_key.dummy
                      }
                }
            else None
          in
          L.set l loc
            { account with
              balance =
                Currency.Balance.of_uint64 (Unsigned.UInt64.of_int64 amount)
            ; permissions
            ; zkapp
            } )

    let gen () : t Quickcheck.Generator.t =
      let tbl = Public_key.Compressed.Hash_set.create () in
      let open Quickcheck.Generator in
      let open Let_syntax in
      let rec go acc n =
        if n = 0 then return (Array.of_list acc)
        else
          let%bind kp =
            filter Keypair.gen ~f:(fun kp ->
                not (Hash_set.mem tbl (Public_key.compress kp.public_key)) )
          and amount = Int64.gen_incl min_init_balance max_init_balance in
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
        Currency.Amount.(
          gen_incl
            (of_nanomina_int_exn 1_000_000)
            (of_nanomina_int_exn 100_000_000))
      in
      let gen_fee () =
        Currency.Fee.(
          gen_incl
            (of_nanomina_int_exn 1_000_000)
            (of_nanomina_int_exn 100_000_000))
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
                  (pk, Account_nonce.zero) ) ) )
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
          ; fee_payer_pk = sender_pk
          ; nonce = sender_nonce
          ; valid_until = Global_slot_since_genesis.max_value
          ; memo = Signed_command_memo.dummy
          }
      ; body = Payment { receiver_pk = receiver; amount }
      }
    |> Signed_command.forget_check

  let account_update_send ?(use_full_commitment = true)
      ?(double_sender_nonce = true)
      { Transaction_spec.fee; sender = sender, sender_nonce; receiver; amount }
      : Zkapp_command.t =
    let sender_pk = Public_key.compress sender.public_key in
    let actual_nonce =
      (* Here, we double the spec'd nonce, because we bump the nonce a second
         time for the 'sender' part of the payment.
      *)
      (* TODO: We should make bumping the nonce for signed zkapp_command optional,
         flagged by a field in the account_update (but always true for the fee payer).

         This would also allow us to prevent replays of snapp proofs, by
         allowing them to bump their nonce.
      *)
      if double_sender_nonce then
        sender_nonce |> Account.Nonce.to_uint32
        |> Unsigned.UInt32.(mul (of_int 2))
        |> Account.Nonce.to_uint32
      else sender_nonce
    in
    let zkapp_command : Zkapp_command.Simple.t =
      { fee_payer =
          { Account_update.Fee_payer.body =
              { public_key = sender_pk
              ; fee
              ; valid_until = None
              ; nonce = actual_nonce
              }
              (* Real signature added in below *)
          ; authorization = Signature.dummy
          }
      ; account_updates =
          [ { body =
                { public_key = sender_pk
                ; update = Account_update.Update.noop
                ; token_id = Token_id.default
                ; balance_change = Amount.Signed.(negate (of_unsigned amount))
                ; increment_nonce = double_sender_nonce
                ; events = []
                ; actions = []
                ; call_data = Snark_params.Tick.Field.zero
                ; call_depth = 0
                ; preconditions =
                    { Account_update.Preconditions.network =
                        Zkapp_precondition.Protocol_state.accept
                    ; account = Zkapp_precondition.Account.accept
                    ; valid_while = Ignore
                    }
                ; may_use_token = No
                ; use_full_commitment
                ; implicit_account_creation_fee = true
                ; authorization_kind =
                    ( if use_full_commitment then Signature
                    else Proof Zkapp_basic.F.zero )
                }
            ; authorization =
                ( if use_full_commitment then Signature Signature.dummy
                else Proof (Lazy.force Mina_base.Proof.transaction_dummy) )
            }
          ; { body =
                { public_key = receiver
                ; update = Account_update.Update.noop
                ; token_id = Token_id.default
                ; balance_change = Amount.Signed.of_unsigned amount
                ; increment_nonce = false
                ; events = []
                ; actions = []
                ; call_data = Snark_params.Tick.Field.zero
                ; call_depth = 0
                ; preconditions =
                    { Account_update.Preconditions.network =
                        Zkapp_precondition.Protocol_state.accept
                    ; account = Zkapp_precondition.Account.accept
                    ; valid_while = Ignore
                    }
                ; may_use_token = No
                ; use_full_commitment = false
                ; implicit_account_creation_fee = true
                ; authorization_kind = None_given
                }
            ; authorization = None_given
            }
          ]
      ; memo = Signed_command_memo.empty
      }
    in
    let zkapp_command = Zkapp_command.of_simple zkapp_command in
    let commitment = Zkapp_command.commitment zkapp_command in
    let full_commitment =
      Zkapp_command.Transaction_commitment.create_complete commitment
        ~memo_hash:(Signed_command_memo.hash zkapp_command.memo)
        ~fee_payer_hash:
          (Zkapp_command.Digest.Account_update.create
             (Account_update.of_fee_payer zkapp_command.fee_payer) )
    in
    let account_updates_signature =
      let c = if use_full_commitment then full_commitment else commitment in
      Schnorr.Chunked.sign sender.private_key
        (Random_oracle.Input.Chunked.field c)
    in
    let account_updates =
      Zkapp_command.Call_forest.map zkapp_command.account_updates
        ~f:(fun (account_update : Account_update.t) ->
          match account_update.body.authorization_kind with
          | Signature ->
              { account_update with
                authorization = Control.Signature account_updates_signature
              }
          | _ ->
              account_update )
    in
    let signature =
      Schnorr.Chunked.sign sender.private_key
        (Random_oracle.Input.Chunked.field full_commitment)
    in
    { zkapp_command with
      fee_payer = { zkapp_command.fee_payer with authorization = signature }
    ; account_updates
    }

  let test_eq (type l) (module L : Ledger_intf.S with type t = l) accounts
      (l1 : L.t) (l2 : L.t) =
    List.map accounts ~f:(fun a ->
        Or_error.try_with (fun () ->
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
                      (hide_rc a1) (hide_rc a2) ) ) )
    |> Or_error.combine_errors_unit

  let txn_global_slot = Global_slot_since_genesis.zero

  let iter_err ts ~f =
    List.fold_until ts
      ~finish:(fun () -> Ok ())
      ~init:()
      ~f:(fun () t ->
        match f t with Error e -> Stop (Error e) | Ok _ -> Continue () )

  let view : Zkapp_precondition.Protocol_state.View.t =
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
    ; blockchain_length = len
    ; min_window_density = len
    ; total_currency = a
    ; global_slot_since_genesis = txn_global_slot
    ; staking_epoch_data = epoch_data
    ; next_epoch_data = epoch_data
    }

  (* Quickcheck generator for Zkapp_command.t, derived from Test_spec generator *)
  let gen_zkapp_command_from_test_spec =
    let open Quickcheck.Let_syntax in
    let%bind use_full_commitment = Bool.quickcheck_generator in
    match%map Test_spec.mk_gen ~num_transactions:1 () with
    | { specs = [ spec ]; _ } ->
        account_update_send ~use_full_commitment spec
    | { specs; _ } ->
        failwithf "gen_zkapp_command_from_test_spec: expected one spec, got %d"
          (List.length specs) ()
end
