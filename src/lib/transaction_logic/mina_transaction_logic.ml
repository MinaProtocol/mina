open Core_kernel
open Mina_base
open Currency
open Signature_lib
open Mina_transaction
module Currency_amount = Currency_amount
module Zkapp_command_logic = Zkapp_command_logic
module Global_slot = Mina_numbers.Global_slot
include Transaction_logic_intf
module Boolean = Boolean
module Transaction_applied = Transaction_applied

module type S = Mina_transaction_logic_sig.S

let validate_timing = Mina_account.validate_timing

let timing_error_to_user_command_status =
  Mina_account.timing_error_to_user_command_status

let error s = Or_error.errorf "Ledger.apply_transaction: %s" s

let error_opt e = Option.value_map ~default:(error e) ~f:Or_error.return

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
    Global_slot.(current_global_slot <= valid_until)
    !"Current global slot %{sexp: Global_slot.t} greater than transaction \
      expiry slot %{sexp: Global_slot.t}"
    current_global_slot valid_until

let get_new_accounts action pk =
  if Ledger_intf.equal_account_state action `Added then [ pk ] else []

let failure (e : Transaction_status.Failure.t) = e

let incr_balance (acct : Account.t) amt =
  match add_amount acct.balance amt with
  | Ok balance ->
      Ok { acct with balance }
  | Error _ ->
      Result.fail (failure Overflow)

module Make (L : Ledger_intf.S) : S with type ledger := L.t = struct
  module Transaction_applied = Transaction_applied

  let get_with_location ledger account_id =
    let open L in
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
    let open L in
    match location with
    | `Existing location ->
        Ok (set ledger location account)
    | `New ->
        create_new_account ledger (Account.identifier account) account

  let has_locked_tokens ~global_slot ~account_id ledger =
    let open Or_error.Let_syntax in
    let%map _, account = get_with_location ledger account_id in
    Account.has_locked_tokens ~global_slot account

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
      Mina_account.validate_timing ~txn_amount:fee
        ~txn_global_slot:current_global_slot ~account
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
      if
        Account.has_permission ~control:Control.Tag.Signature ~to_:`Access
          fee_payer_account
        && Account.has_permission ~control:Control.Tag.Signature ~to_:`Send
             fee_payer_account
      then Ok ()
      else
        Or_error.error_string
          Transaction_status.Failure.(describe Update_not_permitted_balance)
    in
    (* Charge the fee. This must happen, whether or not the command itself
       succeeds, to ensure that the network is compensated for processing this
       command.
    *)
    let%bind () =
      set_with_location ledger fee_payer_location fee_payer_account
    in
    let source = Signed_command.source user_command in
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
          let source_location, source_account =
            get_with_location ledger source |> ok_or_reject
          in
          let%bind () =
            if
              Account.has_permission ~control:Control.Tag.Signature ~to_:`Access
                source_account
              && Account.has_permission ~control:Control.Tag.Signature
                   ~to_:`Set_delegate source_account
            then Ok ()
            else Error Transaction_status.Failure.Update_not_permitted_delegate
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
          (* Timing is always valid, but we need to record any switch from
             timed to untimed here to stay in sync with the snark.
          *)
          let%map timing =
            Mina_account.validate_timing ~txn_amount:Amount.zero
              ~txn_global_slot:current_global_slot ~account:source_account
            |> Result.map_error
                 ~f:Mina_account.timing_error_to_user_command_status
          in
          let source_account =
            { source_account with
              delegate = Some (Account_id.public_key receiver)
            ; timing
            }
          in
          ( [ (source_location, source_account) ]
          , Transaction_applied.Signed_command_applied.Body.Stake_delegation
              { previous_delegate } )
      | Payment { amount; _ } ->
          let receiver_location, receiver_account =
            get_with_location ledger receiver |> ok_or_reject
          in
          let%bind () =
            if
              Account.has_permission ~control:Control.Tag.None_given
                ~to_:`Access receiver_account
              && Account.has_permission ~control:Control.Tag.None_given
                   ~to_:`Receive receiver_account
            then Ok ()
            else Error Transaction_status.Failure.Update_not_permitted_balance
          in
          let%bind source_location, source_account =
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
                let%map timing =
                  Mina_account.validate_timing ~txn_amount:amount
                    ~txn_global_slot:current_global_slot ~account
                  |> Result.map_error
                       ~f:Mina_account.timing_error_to_user_command_status
                in
                (location, { account with timing })
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
                let%bind timing =
                  Mina_account.validate_timing ~txn_amount:amount
                    ~txn_global_slot:current_global_slot ~account
                  |> Result.map_error
                       ~f:Mina_account.timing_error_to_user_command_status
                in
                let%map balance =
                  Result.map_error (sub_amount account.balance amount)
                    ~f:(fun _ ->
                      Transaction_status.Failure.Source_insufficient_balance )
                in
                (location, { account with timing; balance })
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
                          (Transaction_status.Failure.describe failure) ) )
            else ret
          in
          let%bind () =
            if
              Account.has_permission ~control:Control.Tag.Signature ~to_:`Access
                source_account
              && Account.has_permission ~control:Control.Tag.Signature
                   ~to_:`Send source_account
            then Ok ()
            else Error Transaction_status.Failure.Update_not_permitted_balance
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
          ( [ (receiver_location, receiver_account)
            ; (source_location, source_account)
            ]
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
      { ledger : L.t
      ; fee_excess : Amount.Signed.t
      ; supply_increase : Amount.Signed.t
      ; protocol_state : Zkapp_precondition.Protocol_state.View.t
      ; block_global_slot : Global_slot.t
      }

    let ledger { ledger; _ } = L.create_masked ledger

    let set_ledger ~should_update t ledger =
      if should_update then L.apply_mask t.ledger ~masked:ledger ;
      t

    let fee_excess { fee_excess; _ } = fee_excess

    let set_fee_excess t fee_excess = { t with fee_excess }

    let supply_increase { supply_increase; _ } = supply_increase

    let set_supply_increase t supply_increase = { t with supply_increase }

    let block_global_slot { block_global_slot; _ } = block_global_slot
  end

  module Inputs = struct
    module Bool = Boolean
    module Global_state = Global_state

    let with_label ~label:_ f = f ()

    let value_if b ~then_ ~else_ = if b then then_ else else_

    module Field = struct
      type t = Snark_params.Tick.Field.t

      let if_ = value_if

      let equal = Snark_params.Tick.Field.equal
    end

    module Account_id = struct
      include Account_id

      let if_ = value_if
    end

    module Ledger = struct
      type t = L.t

      let if_ = value_if

      let empty = L.empty

      type inclusion_proof = [ `Existing of L.location | `New ]

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

    module Controller = Mina_account.Controller

    module Global_slot = struct
      include Mina_numbers.Global_slot

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

    module Account = Mina_account.Account
    module Amount = Currency_amount

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
      include Mina_account.Update

      type transaction_commitment = Transaction_commitment.t
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

    module Call_forest = Zkapp_call_forest
    module Stack = Mina_stack.Make
    module Stack_frame = Mina_stack.Frame
    module Call_stack = Stack (Stack_frame)

    module Local_state = struct
      type t =
        ( Stack_frame.t
        , Call_stack.t
        , Token_id.t
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
      ; inclusion_proof : [ `Existing of L.location | `New ]
      ; local_state :
          ( Stack_frame.t
          , Call_stack.t
          , Token_id.t
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
          (account_update, account, new_account, local_state) -> (
          match account_update.body.preconditions.account with
          | Accept ->
              local_state
          | Nonce n ->
              let nonce_matches = Account.Nonce.equal account.nonce n in
              Inputs.Local_state.add_check local_state
                Account_nonce_precondition_unsatisfied nonce_matches
          | Full precondition_account ->
              let local_state = ref local_state in
              let check failure b =
                local_state :=
                  Inputs.Local_state.add_check !local_state failure b
              in
              Zkapp_precondition.Account.check ~new_account ~check
                precondition_account account ;
              !local_state )
      | Init_account { account_update = _; account = a } ->
          a
  end

  module M = Zkapp_command_logic.Make (Inputs)

  let update_sequence_state sequence_state actions ~txn_global_slot
      ~last_sequence_slot =
    let sequence_state', last_sequence_slot' =
      M.update_sequence_state sequence_state actions ~txn_global_slot
        ~last_sequence_slot
    in
    (sequence_state', last_sequence_slot')

  (** Apply a single zkApp transaction from beginning to end, applying an
      accumulation function over the state for each account update.

      CAUTION: If you use the intermediate local states, you MUST update the
      [will_succeed] field to [false] if the [status] is [Failed].
  *)
  let apply_zkapp_command_unchecked_aux (type user_acc)
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~(global_slot : Global_slot.t)
      ~(state_view : Zkapp_precondition.Protocol_state.View.t)
      ~(init : user_acc) ~(f : user_acc -> _ -> user_acc)
      ?(fee_excess = Amount.Signed.zero) ?(supply_increase = Amount.Signed.zero)
      (ledger : L.t) (c : Zkapp_command.t) :
      (Transaction_applied.Zkapp_command_applied.t * user_acc) Or_error.t =
    let open Or_error.Let_syntax in
    let original_account_states =
      List.map (Zkapp_command.accounts_referenced c) ~f:(fun id ->
          ( id
          , Option.Let_syntax.(
              let%bind loc = L.location_of_account ledger id in
              let%map a = L.get ledger loc in
              (loc, a)) ) )
    in
    let perform eff = Env.perform ~constraint_constants eff in
    let rec step_all user_acc
        ( (g_state : Inputs.Global_state.t)
        , (l_state : _ Zkapp_command_logic.Local_state.t) ) :
        (user_acc * Transaction_status.Failure.Collection.t) Or_error.t =
      if List.is_empty l_state.stack_frame.Stack_frame.calls then
        Ok (user_acc, l_state.failure_status_tbl)
      else
        let%bind states =
          Or_error.try_with (fun () ->
              M.step ~constraint_constants { perform } (g_state, l_state) )
        in
        step_all (f user_acc states) states
    in
    let initial_state :
        Inputs.Global_state.t * _ Zkapp_command_logic.Local_state.t =
      ( { protocol_state = state_view
        ; ledger
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
        ; token_id = Token_id.default
        ; excess = Currency.Amount.(Signed.of_unsigned zero)
        ; supply_increase = Currency.Amount.(Signed.of_unsigned zero)
        ; ledger
        ; success = true
        ; account_update_index = Inputs.Index.zero
        ; failure_status_tbl = []
        ; will_succeed = true
        } )
    in
    let user_acc = f init initial_state in
    let%bind (start : Inputs.Global_state.t * _) =
      let zkapp_command = Zkapp_command.zkapp_command c in
      Or_error.try_with (fun () ->
          M.start ~constraint_constants
            { zkapp_command
            ; memo_hash = Signed_command_memo.hash c.memo
            ; will_succeed =
                (* It's always valid to set this value to true, and it will
                   have no effect outside of the snark.
                *)
                true
            }
            { perform } initial_state )
    in
    let account_states_after_fee_payer =
      List.map (Zkapp_command.accounts_referenced c) ~f:(fun id ->
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
    match step_all (f user_acc start) start with
    | Error e ->
        Error e
    | Ok (s, reversed_failure_status_tbl) ->
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
                  { With_status.data = c
                  ; status =
                      ( if successfully_applied then Applied
                      else Failed failure_status_tbl )
                  }
              ; new_accounts
              }
            , s )
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

  let apply_zkapp_command_unchecked ~constraint_constants ~global_slot
      ~state_view ledger c =
    apply_zkapp_command_unchecked_aux ~constraint_constants ~global_slot
      ~state_view ledger c ~init:None
      ~f:(fun _acc (global_state, local_state) ->
        Some (local_state, global_state.fee_excess) )
    |> Result.map ~f:(fun (account_update_applied, state_res) ->
           (account_update_applied, Option.value_exn state_res) )

  let update_timing_when_no_deduction ~txn_global_slot account =
    Mina_account.validate_timing ~txn_amount:Amount.zero ~txn_global_slot
      ~account

  let has_permission_to_receive ~ledger receiver_account_id :
      Account.t
      * Ledger_intf.account_state
      * [> `Has_permission_to_receive of bool ] =
    let open L in
    let init_account = Account.initialize receiver_account_id in
    match location_of_account ledger receiver_account_id with
    | None ->
        (* new account, check that default permissions allow receiving *)
        ( init_account
        , `Added
        , `Has_permission_to_receive
            (Account.has_permission ~control:Control.Tag.None_given
               ~to_:`Receive init_account ) )
    | Some loc -> (
        match get ledger loc with
        | None ->
            failwith "Ledger location with no account"
        | Some receiver_account ->
            ( receiver_account
            , `Existed
            , `Has_permission_to_receive
                (Account.has_permission ~control:Control.Tag.None_given
                   ~to_:`Receive receiver_account ) ) )

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
          let%map _action, a, loc = L.get_or_create t account_id in
          let new_accounts = get_new_accounts action account_id in
          L.set t loc { a with balance; timing } ;
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
            let%map _action1, a1, l1 = L.get_or_create t account_id1 in
            let new_accounts1 = get_new_accounts action1 account_id1 in
            L.set t l1 { a1 with balance; timing } ;
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
              let%map _action1, a1, l1 = L.get_or_create t account_id1 in
              let new_accounts1 = get_new_accounts action1 account_id1 in
              L.set t l1 { a1 with balance = balance1 } ;
              ( new_accounts1
              , append_entry no_failure empty
              , Currency.Amount.zero ) )
            else Ok ([], single_failure, Currency.Amount.of_fee ft1.fee)
          in
          let%bind new_accounts2, failures', burned_tokens2 =
            if can_receive2 then (
              let%map _action2, a2, l2 = L.get_or_create t account_id2 in
              let new_accounts2 = get_new_accounts action2 account_id2 in
              L.set t l2 { a2 with balance = balance2; timing = timing2 } ;
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
              L.get_or_create t transferee_id
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
          L.get_or_create t receiver_id
        in
        L.set t receiver_location
          { receiver_account with
            balance = receiver_balance
          ; timing = coinbase_receiver_timing
          } ;
        (append_entry no_failure failures1, Currency.Amount.zero) )
      else return (append_entry update_failed failures1, receiver_reward)
    in
    Option.iter transferee_update ~f:(fun (l, a) -> L.set t l a) ;
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

  let apply_transaction ~constraint_constants ~global_slot
      ~(txn_state_view : Zkapp_precondition.Protocol_state.View.t) ledger
      (t : Transaction.t) =
    let open L in
    let previous_hash = merkle_root ledger in
    let txn_global_slot = global_slot in
    Or_error.map
      ( match t with
      | Command (Signed_command txn) ->
          Or_error.map
            (apply_user_command_unchecked ~constraint_constants ~txn_global_slot
               ledger txn ) ~f:(fun applied ->
              Transaction_applied.Varying.Command (Signed_command applied) )
      | Command (Zkapp_command txn) ->
          Or_error.map
            (apply_zkapp_command_unchecked ~global_slot
               ~state_view:txn_state_view ~constraint_constants ledger txn )
            ~f:(fun (applied, _) ->
              Transaction_applied.Varying.Command (Zkapp_command applied) )
      | Fee_transfer t ->
          Or_error.map
            (apply_fee_transfer ~constraint_constants ~txn_global_slot ledger t)
            ~f:(fun applied -> Transaction_applied.Varying.Fee_transfer applied)
      | Coinbase t ->
          Or_error.map
            (apply_coinbase ~constraint_constants ~txn_global_slot ledger t)
            ~f:(fun applied -> Transaction_applied.Varying.Coinbase applied) )
      ~f:(fun varying -> { Transaction_applied.previous_hash; varying })

  module For_tests = struct
    let validate_timing_with_min_balance =
      Mina_account.validate_timing_with_min_balance

    let validate_timing = Mina_account.validate_timing
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

    let init (type l) (module L : Ledger_intf.S with type t = l)
        (init_ledger : t) (l : L.t) =
      Array.iter init_ledger ~f:(fun (kp, amount) ->
          let _tag, account, loc =
            L.get_or_create l
              (Account_id.create
                 (Public_key.compress kp.public_key)
                 Token_id.default )
            |> Or_error.ok_exn
          in
          L.set l loc
            { account with
              balance =
                Currency.Balance.of_uint64 (Unsigned.UInt64.of_int64 amount)
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
          ; valid_until = Global_slot.max_value
          ; memo = Signed_command_memo.dummy
          }
      ; body = Payment { source_pk = sender_pk; receiver_pk = receiver; amount }
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
                ; increment_nonce = not use_full_commitment
                ; events = []
                ; actions = []
                ; call_data = Snark_params.Tick.Field.zero
                ; call_depth = 0
                ; preconditions =
                    { Account_update.Preconditions.network =
                        Zkapp_precondition.Protocol_state.accept
                    ; account = Nonce (Account.Nonce.succ actual_nonce)
                    ; valid_while = Ignore
                    }
                ; may_use_token = No
                ; use_full_commitment
                ; implicit_account_creation_fee = true
                ; authorization_kind = Signature
                }
            ; authorization = None_given
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
                    ; account = Accept
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
          match account_update.body.preconditions.account with
          | Nonce _ ->
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

  let txn_global_slot = Global_slot.zero

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
    ; last_vrf_output = ()
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
