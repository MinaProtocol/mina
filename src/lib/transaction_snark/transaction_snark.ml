open Core
open Signature_lib
open Coda_base
open Snark_params
module Global_slot = Coda_numbers.Global_slot
module Amount = Currency.Amount
module Balance = Currency.Balance
module Fee = Currency.Fee

let tick_input () =
  let open Tick in
  Data_spec.[Field.typ]

let wrap_input = Tock.Data_spec.[Wrap_input.typ]

let exists' typ ~f = Tick.(exists typ ~compute:As_prover.(map get_state ~f))

module Proof_type = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = [`Base | `Merge] [@@deriving compare, equal, hash, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, hash, compare, yojson]

  let is_base = function `Base -> true | `Merge -> false
end

module Pending_coinbase_stack_state = struct
  (* State of the coinbase stack for the current transaction snark *)
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { source: Pending_coinbase.Stack.Stable.V1.t
        ; target: Pending_coinbase.Stack.Stable.V1.t }
      [@@deriving sexp, hash, compare, eq, fields, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    {source: Pending_coinbase.Stack.t; target: Pending_coinbase.Stack.t}
  [@@deriving sexp, hash, compare, yojson]

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)
end

module Statement = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { source: Frozen_ledger_hash.Stable.V1.t
        ; target: Frozen_ledger_hash.Stable.V1.t
        ; supply_increase: Currency.Amount.Stable.V1.t
        ; pending_coinbase_stack_state:
            Pending_coinbase_stack_state.Stable.V1.t
        ; fee_excess:
            ( Currency.Fee.Stable.V1.t
            , Sgn.Stable.V1.t )
            Currency.Signed_poly.Stable.V1.t
        ; proof_type: Proof_type.Stable.V1.t }
      [@@deriving compare, equal, hash, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { source: Frozen_ledger_hash.t
    ; target: Frozen_ledger_hash.t
    ; supply_increase: Currency.Amount.t
    ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t
    ; fee_excess: Currency.Fee.Signed.t
    ; proof_type: Proof_type.t }
  [@@deriving sexp, hash, compare, yojson]

  let option lab =
    Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

  let merge s1 s2 =
    let open Or_error.Let_syntax in
    let%map fee_excess =
      Currency.Fee.Signed.add s1.fee_excess s2.fee_excess
      |> option "Error adding fees"
    and supply_increase =
      Currency.Amount.add s1.supply_increase s2.supply_increase
      |> option "Error adding supply_increase"
    in
    { source= s1.source
    ; target= s2.target
    ; fee_excess
    ; proof_type= `Merge
    ; supply_increase
    ; pending_coinbase_stack_state=
        { source= s1.pending_coinbase_stack_state.source
        ; target= s2.pending_coinbase_stack_state.target } }

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map source = Frozen_ledger_hash.gen
    and target = Frozen_ledger_hash.gen
    and fee_excess = Currency.Fee.Signed.gen
    and supply_increase = Currency.Amount.gen
    and pending_coinbase_before = Pending_coinbase.Stack.gen
    and pending_coinbase_after = Pending_coinbase.Stack.gen
    and proof_type =
      Bool.quickcheck_generator >>| fun b -> if b then `Merge else `Base
    in
    { source
    ; target
    ; fee_excess
    ; proof_type
    ; supply_increase
    ; pending_coinbase_stack_state=
        {source= pending_coinbase_before; target= pending_coinbase_after} }
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { source: Frozen_ledger_hash.Stable.V1.t
      ; target: Frozen_ledger_hash.Stable.V1.t
      ; proof_type: Proof_type.Stable.V1.t
      ; supply_increase: Amount.Stable.V1.t
      ; pending_coinbase_stack_state: Pending_coinbase_stack_state.Stable.V1.t
      ; fee_excess:
          ( Amount.Stable.V1.t
          , Sgn.Stable.V1.t )
          Currency.Signed_poly.Stable.V1.t
      ; sok_digest: Sok_message.Digest.Stable.V1.t
      ; proof: Proof.Stable.V1.t }
    [@@deriving compare, fields, sexp, version]

    let to_yojson t =
      `Assoc
        [ ("source", Frozen_ledger_hash.to_yojson t.source)
        ; ("target", Frozen_ledger_hash.to_yojson t.target)
        ; ("proof_type", Proof_type.to_yojson t.proof_type)
        ; ("supply_increase", Amount.to_yojson t.supply_increase)
        ; ( "pending_coinbase_stack_state"
          , Pending_coinbase_stack_state.to_yojson
              t.pending_coinbase_stack_state )
        ; ("fee_excess", Amount.Signed.to_yojson t.fee_excess)
        ; ("sok_digest", `String "<opaque>")
        ; ("proof", Proof.to_yojson t.proof) ]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t =
  { source: Frozen_ledger_hash.t
  ; target: Frozen_ledger_hash.t
  ; proof_type: Proof_type.t
  ; supply_increase: Amount.t
  ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t
  ; fee_excess: (Amount.t, Sgn.t) Currency.Signed_poly.t
  ; sok_digest: Sok_message.Digest.t
  ; proof: Proof.t }
[@@deriving fields, sexp]

let to_yojson = Stable.Latest.to_yojson

let statement
    ({ source
     ; target
     ; proof_type
     ; fee_excess
     ; supply_increase
     ; pending_coinbase_stack_state
     ; sok_digest= _
     ; proof= _ } :
      t) =
  { Statement.Stable.V1.source
  ; target
  ; proof_type
  ; supply_increase
  ; pending_coinbase_stack_state
  ; fee_excess=
      Currency.Fee.Signed.create
        ~magnitude:Currency.Amount.(to_fee (Signed.magnitude fee_excess))
        ~sgn:(Currency.Amount.Signed.sgn fee_excess) }

let create = Fields.create

let construct_input ~proof_type ~sok_digest ~state1 ~state2 ~supply_increase
    ~fee_excess
    ~(pending_coinbase_stack_state : Pending_coinbase_stack_state.t) =
  let open Random_oracle in
  let input =
    let open Input in
    List.reduce_exn ~f:append
      [ Sok_message.Digest.to_input sok_digest
      ; Frozen_ledger_hash.to_input state1
      ; Frozen_ledger_hash.to_input state2
      ; Pending_coinbase.Stack.to_input pending_coinbase_stack_state.source
      ; Pending_coinbase.Stack.to_input pending_coinbase_stack_state.target
      ; bitstring (Amount.to_bits supply_increase)
      ; Amount.Signed.to_input fee_excess ]
  in
  let init =
    match proof_type with
    | `Base ->
        Hash_prefix.base_snark
    | `Merge wrap_vk_state ->
        wrap_vk_state
  in
  Random_oracle.hash ~init (pack_input input)

let base_top_hash = construct_input ~proof_type:`Base

let merge_top_hash wrap_vk_bits =
  construct_input ~proof_type:(`Merge wrap_vk_bits)

module Verification_keys = struct
  (* TODO : version *)
  type t =
    { base: Tick.Verification_key.t
    ; wrap: Tock.Verification_key.t
    ; merge: Tick.Verification_key.t }
  [@@deriving bin_io]

  let dummy : t =
    let groth16 =
      Tick_backend.Verification_key.get_dummy
        ~input_size:(Tick.Data_spec.size (tick_input ()))
    in
    { merge= groth16
    ; base= groth16
    ; wrap= Tock_backend.Verification_key.get_dummy ~input_size:Wrap_input.size
    }
end

module Keys0 = struct
  module Verification = Verification_keys

  module Proving = struct
    type t =
      { base: Tick.Proving_key.t
      ; wrap: Tock.Proving_key.t
      ; merge: Tick.Proving_key.t }

    let dummy =
      { merge= Dummy_values.Tick.Groth16.proving_key
      ; base= Dummy_values.Tick.Groth16.proving_key
      ; wrap= Dummy_values.Tock.Bowe_gabizon18.proving_key }
  end

  module T = struct
    type t = {proving: Proving.t; verification: Verification.t}
  end

  include T
end

(* Staging:
   first make tick base.
   then make tick merge (which top_hashes in the tock wrap vk)
   then make tock wrap (which branches on the tick vk) *)

module Base = struct
  open Tick
  open Let_syntax

  let%snarkydef check_signature shifted ~payload ~is_user_command ~signer
      ~signature =
    let%bind verifies =
      Schnorr.Checked.verifies shifted signature signer payload
    in
    Boolean.Assert.any [Boolean.not is_user_command; verifies]

  let check_timing ~account ~txn_amount ~txn_global_slot =
    (* calculations should track Transaction_logic.validate_timing *)
    let open Account.Poly in
    let open Account.Timing.As_record in
    let { is_timed
        ; initial_minimum_balance
        ; cliff_time
        ; vesting_period
        ; vesting_increment } =
      account.timing
    in
    let%bind before_or_at_cliff =
      Global_slot.Checked.(txn_global_slot <= cliff_time)
    in
    let int_of_field field =
      Snarky_integer.Integer.constant ~m
        (Bigint.of_field field |> Bigint.to_bignum_bigint)
    in
    let zero_int = int_of_field Field.zero in
    let balance_to_int balance =
      Snarky_integer.Integer.of_bits ~m @@ Balance.var_to_bits balance
    in
    let txn_amount_int =
      Snarky_integer.Integer.of_bits ~m @@ Amount.var_to_bits txn_amount
    in
    let balance_int = balance_to_int account.balance in
    let%bind curr_min_balance =
      let open Snarky_integer.Integer in
      let initial_minimum_balance_int =
        balance_to_int initial_minimum_balance
      in
      make_checked (fun () ->
          if_ ~m before_or_at_cliff ~then_:initial_minimum_balance_int
            ~else_:
              (let txn_global_slot_int =
                 Global_slot.Checked.to_integer txn_global_slot
               in
               let cliff_time_int =
                 Global_slot.Checked.to_integer cliff_time
               in
               let _, slot_diff =
                 subtract_unpacking_or_zero ~m txn_global_slot_int
                   cliff_time_int
               in
               let vesting_period_int =
                 Global_slot.Checked.to_integer vesting_period
               in
               let num_periods, _ = div_mod ~m slot_diff vesting_period_int in
               let vesting_increment_int =
                 Amount.var_to_bits vesting_increment |> of_bits ~m
               in
               let min_balance_decrement =
                 mul ~m num_periods vesting_increment_int
               in
               let _, min_balance_less_decrement =
                 subtract_unpacking_or_zero ~m initial_minimum_balance_int
                   min_balance_decrement
               in
               min_balance_less_decrement) )
    in
    let%bind `Underflow underflow, proposed_balance_int =
      make_checked (fun () ->
          Snarky_integer.Integer.subtract_unpacking_or_zero ~m balance_int
            txn_amount_int )
    in
    (* underflow indicates insufficient balance *)
    let%bind () = Boolean.(Assert.is_true @@ not underflow) in
    let%bind sufficient_timed_balance =
      make_checked (fun () ->
          Snarky_integer.Integer.(gte ~m proposed_balance_int curr_min_balance)
      )
    in
    let%bind _ =
      with_label
        (sprintf "%s: check proposed balance against calculated min balance"
           __LOC__)
        Boolean.(Assert.any [not is_timed; sufficient_timed_balance])
    in
    let%bind is_timed_balance_zero =
      make_checked (fun () ->
          Snarky_integer.Integer.equal ~m curr_min_balance zero_int )
    in
    (* if current min balance is zero, then timing becomes untimed *)
    let%bind is_untimed = Boolean.((not is_timed) || is_timed_balance_zero) in
    Account.Timing.if_ is_untimed ~then_:Account.Timing.untimed_var
      ~else_:account.timing

  let chain if_ b ~then_ ~else_ =
    let%bind then_ = then_ and else_ = else_ in
    if_ b ~then_ ~else_

  let%snarkydef apply_tagged_transaction (type shifted)
      (shifted : (module Inner_curve.Checked.Shifted.S with type t = shifted))
      root pending_coinbase_stack_before pending_coinbase_after
      state_body_hash_opt
      ({signer; signature; payload} : Transaction_union.var) =
    let%bind is_user_command =
      Transaction_union.Tag.Checked.is_user_command payload.body.tag
    in
    let%bind () =
      [%with_label "Check transaction signature"]
        (check_signature shifted ~payload ~is_user_command ~signer ~signature)
    in
    let%bind signer_pk = Public_key.compress_var signer in
    let fee = payload.common.fee in
    (* Information for the receiver. *)
    let receiver = payload.body.public_key in
    (* Information for the source. *)
    let token = Account_id.Checked.token_id receiver in
    let source = Account_id.Checked.create signer_pk token in
    (* Information for the fee-payer. *)
    let nonce = payload.common.nonce in
    let fee_token = payload.common.fee_token in
    let fee_payer = Account_id.Checked.create signer_pk fee_token in
    (* Compute transaction kind. *)
    let tag = payload.body.tag in
    let%bind is_payment = Transaction_union.Tag.Checked.is_payment tag in
    let%bind is_fee_transfer =
      Transaction_union.Tag.Checked.is_fee_transfer tag
    in
    let%bind is_stake_delegation =
      Transaction_union.Tag.Checked.is_stake_delegation tag
    in
    let%bind is_coinbase = Transaction_union.Tag.Checked.is_coinbase tag in
    let%bind tokens_equal = Token_id.Checked.equal token fee_token in
    let%bind () =
      [%with_label "Validate tokens"]
        (let%bind () =
           (* TODO: Enable using different tokens for fees. *)
           [%with_label "Validate fee token"]
             (Token_id.Checked.Assert.equal fee_token
                Token_id.(var_of_t default))
         in
         [%with_label "Validate transfer token"]
           (Boolean.Assert.any [is_payment; tokens_equal]))
    in
    let%bind () =
      [%with_label "Check slot validity"]
        (let current_global_slot =
           Global_slot.(Checked.constant zero)
           (* TODO: @deepthi is working on passing through the protocol state to
           here. This should be replaced with the real value when her PR lands.
           See issue #4036.
         *)
         in
         Global_slot.Checked.(
           current_global_slot <= payload.common.valid_until)
         >>= Boolean.Assert.is_true)
    in
    (* Check coinbase stack. *)
    let%bind () =
      [%with_label "Compute coinbase stack"]
        (let%bind pending_coinbase_stack_with_state =
           let state_body_hash, push_state =
             Transaction_protocol_state.Block_data.Checked.
               ( state_body_hash state_body_hash_opt
               , push_state state_body_hash_opt )
           in
           let%bind updated_stack =
             Pending_coinbase.Stack.Checked.push_state state_body_hash
               pending_coinbase_stack_before
           in
           Pending_coinbase.Stack.Checked.if_ push_state ~then_:updated_stack
             ~else_:pending_coinbase_stack_before
         in
         let%bind computed_pending_coinbase_stack_after =
           let coinbase =
             (Account_id.Checked.public_key receiver, payload.body.amount)
           in
           let%bind stack' =
             Pending_coinbase.Stack.Checked.push_coinbase coinbase
               pending_coinbase_stack_with_state
           in
           Pending_coinbase.Stack.Checked.if_ is_coinbase ~then_:stack'
             ~else_:pending_coinbase_stack_with_state
         in
         [%with_label "Check coinbase stack"]
           (let%bind correct_coinbase_stack =
              Pending_coinbase.Stack.equal_var
                computed_pending_coinbase_stack_after pending_coinbase_after
            in
            Boolean.Assert.is_true correct_coinbase_stack))
    in
    let%bind payment_insufficient_funds =
      (* Here we 'forsee' whether there will be insufficient funds to send,
         if this is a payment and the fee-payer is distinct from the source
         account.

         In this case, we still charge the fee-payer, but don't modify the
         source or receiver balances.
      *)
      let%bind prover_source =
        exists (Typ.Internal.ref ())
          ~compute:(As_prover.read Account_id.typ source)
      in
      (* TODO: Implement requests within [As_prover] blocks, so we don't need
         these kinds of wrapper.
      *)
      let%bind prover_account_idx =
        exists (Typ.Internal.ref ())
          ~request:
            As_prover.(
              let%map prover_source =
                read (Typ.Internal.ref ()) prover_source
              in
              Ledger_hash.Find_index prover_source)
      in
      let%bind prover_source_account =
        exists (Typ.Internal.ref ())
          ~request:
            As_prover.(
              let%map account_idx =
                read (Typ.Internal.ref ()) prover_account_idx
              in
              Ledger_hash.Get_element account_idx)
      in
      exists Boolean.typ
        ~compute:
          As_prover.(
            let%bind account, _path =
              read (Typ.Internal.ref ()) prover_source_account
            in
            let%bind fee = read Fee.typ fee in
            let%bind is_payment = read Boolean.typ is_payment in
            let%bind source = read (Typ.Internal.ref ()) prover_source in
            let%map fee_payer = read Account_id.typ fee_payer in
            if is_payment && not (Account_id.equal source fee_payer) then
              Option.is_none
                (Balance.sub_amount account.balance (Amount.of_fee fee))
            else false)
    in
    let%bind () =
      [%with_label
        "Predict sufficient funds for a payment if source is the fee-payer"]
        Boolean.(Assert.any [tokens_equal; not payment_insufficient_funds])
    in
    let%bind receiver_increase =
      (* - payments:         payload.body.amount
         - stake delegation: 0
         - coinbase:         payload.body.amount - payload.common.fee
         - fee transfer:     payload.body.amount
      *)
      [%with_label "Compute receiver increase"]
        (let%bind base_amount =
           Amount.Checked.if_ is_stake_delegation
             ~then_:(Amount.var_of_t Amount.zero)
             ~else_:payload.body.amount
         in
         let%bind base_amount' =
           Amount.Checked.if_ payment_insufficient_funds
             ~then_:(Amount.var_of_t Amount.zero)
             ~else_:base_amount
         in
         (* The fee for entering the coinbase transaction is paid up front. *)
         let%bind coinbase_receiver_fee =
           Amount.Checked.if_ is_coinbase
             ~then_:(Amount.Checked.of_fee fee)
             ~else_:(Amount.var_of_t Amount.zero)
         in
         Amount.Checked.sub base_amount' coinbase_receiver_fee)
    in
    let account_creation_amount =
      Amount.Checked.of_fee
        Fee.(var_of_t Coda_compile_config.account_creation_fee)
    in
    let%bind self_account_creation_amount =
      (* If the tokens are equal, the fee for account creation is paid by
         subtracting it from the transferred amount. Otherwise, the fee-payer
         pays.
      *)
      Amount.Checked.if_ tokens_equal ~then_:account_creation_amount
        ~else_:Amount.(var_of_t zero)
    in
    (* Forward-reference to determine whether a new account was created for the
       receiver.
    *)
    let receiver_was_created = ref None in
    let%bind root_after_receiver_update =
      [%with_label "Update receiver"]
        (Frozen_ledger_hash.modify_account_recv root receiver
           ~f:(fun ~is_empty_and_writeable account ->
             (* this account is:
               - the receiver for payments
               - the delegated-to account for stake delegation
               - the receiver for a coinbase 
               - the first receiver for a fee transfer
             *)
             let%bind () =
               (* Check that the account exists if it is a stake delegation. *)
               Boolean.(
                 Assert.any
                   [not is_stake_delegation; not is_empty_and_writeable])
             in
             let%bind is_empty_and_writeable =
               Boolean.(
                 is_empty_and_writeable && not payment_insufficient_funds)
             in
             receiver_was_created := Some is_empty_and_writeable ;
             let%map balance =
               (* receiver_increase will be zero in the stake delegation case *)
               let%bind receiver_amount =
                 let%bind amount_for_new_account, `Underflow underflow =
                   Amount.Checked.sub_flagged receiver_increase
                     self_account_creation_amount
                 in
                 let%bind () =
                   Boolean.(
                     Assert.any [not is_empty_and_writeable; not underflow])
                 in
                 Currency.Amount.Checked.if_ is_empty_and_writeable
                   ~then_:amount_for_new_account ~else_:receiver_increase
               in
               Balance.Checked.(account.balance + receiver_amount)
             and delegate =
               Public_key.Compressed.Checked.if_ is_empty_and_writeable
                 ~then_:(Account_id.Checked.public_key receiver)
                 ~else_:account.delegate
             and public_key =
               Public_key.Compressed.Checked.if_ is_empty_and_writeable
                 ~then_:(Account_id.Checked.public_key receiver)
                 ~else_:account.public_key
             and token_id =
               Token_id.Checked.if_ is_empty_and_writeable ~then_:token
                 ~else_:account.token_id
             in
             { Account.Poly.balance
             ; public_key
             ; token_id
             ; nonce= account.nonce
             ; receipt_chain_hash= account.receipt_chain_hash
             ; delegate
             ; voting_for= account.voting_for
             ; timing= account.timing } ))
    in
    let fee_payer_amount =
      let sgn = Sgn.Checked.neg_if_true is_user_command in
      Amount.Signed.create ~magnitude:(Amount.Checked.of_fee fee) ~sgn
    in
    let receiver_was_created = Option.value_exn !receiver_was_created in
    let%bind root_after_fee_payer_update =
      [%with_label "Update fee payer"]
        (Frozen_ledger_hash.modify_account_send root_after_receiver_update
           ~is_writeable:(Boolean.not is_user_command) fee_payer
           ~f:(fun ~is_empty_and_writeable account ->
             (* this account is:
               - the fee-payer for payments
               - the fee-payer for stake delegation
               - the fee-receiver for a coinbase 
               - the second receiver for a fee transfer
             *)
             let%bind next_nonce =
               Account.Nonce.Checked.succ_if account.nonce is_user_command
             in
             let%bind () =
               [%with_label "Check fee nonce"]
                 (let%bind nonce_matches =
                    Account.Nonce.Checked.equal nonce account.nonce
                  in
                  Boolean.Assert.any
                    [Boolean.not is_user_command; nonce_matches])
             in
             let%bind receipt_chain_hash =
               let current = account.receipt_chain_hash in
               let%bind r = Receipt.Chain_hash.Checked.cons ~payload current in
               Receipt.Chain_hash.Checked.if_ is_user_command ~then_:r
                 ~else_:current
             in
             let%bind amount =
               [%with_label "Compute fee payer amount"]
                 (let%bind account_creation_fee =
                    let%bind should_pay_for_receiver =
                      Boolean.(receiver_was_created && not tokens_equal)
                    in
                    let num_accounts_opened =
                      let open Field.Var in
                      add
                        (should_pay_for_receiver :> t)
                        (is_empty_and_writeable :> t)
                    in
                    let%map magnitude =
                      Amount.Checked.scale num_accounts_opened
                        account_creation_amount
                    in
                    Amount.Signed.create ~magnitude ~sgn:Sgn.Checked.neg
                  in
                  Amount.Signed.Checked.(
                    add fee_payer_amount account_creation_fee))
             in
             (* TODO: use actual slot. See issue #4036. *)
             let txn_global_slot = Global_slot.Checked.zero in
             let%bind timing =
               [%with_label "Check fee payer timing"]
                 (let%bind txn_amount =
                    Amount.Checked.if_
                      (Sgn.Checked.is_neg amount.sgn)
                      ~then_:amount.magnitude
                      ~else_:Amount.(var_of_t zero)
                  in
                  check_timing ~account ~txn_amount ~txn_global_slot)
             in
             let%bind balance =
               [%with_label "Check payer balance"]
                 (Balance.Checked.add_signed_amount account.balance amount)
             in
             let%map delegate =
               Public_key.Compressed.Checked.if_ is_empty_and_writeable
                 ~then_:(Account_id.Checked.public_key source)
                 ~else_:account.delegate
             in
             { Account.Poly.balance
             ; public_key= Account_id.Checked.public_key fee_payer
             ; token_id= Account_id.Checked.token_id fee_payer
             ; nonce= next_nonce
             ; receipt_chain_hash
             ; delegate
             ; voting_for= account.voting_for
             ; timing } ))
    in
    let%bind root_after_source_update =
      [%with_label "Update source"]
        (Frozen_ledger_hash.modify_account_send ~is_writeable:Boolean.false_
           root_after_fee_payer_update source
           ~f:(fun ~is_empty_and_writeable:_ account ->
             (* this account is:
               - the source for payments
               - the delegator for stake delegation
               - the fee-receiver for a coinbase 
               - the second receiver for a fee transfer
             *)
             let%bind successful_payment =
               Boolean.(is_payment && not payment_insufficient_funds)
             in
             let%bind amount =
               (* Only payments should affect the balance at this stage. *)
               if_ successful_payment ~typ:Amount.typ
                 ~then_:payload.body.amount
                 ~else_:Amount.(var_of_t zero)
             in
             (* TODO: use actual slot. See issue #4036. *)
             let txn_global_slot = Global_slot.Checked.zero in
             let%bind timing =
               [%with_label "Check source timing"]
                 (check_timing ~account ~txn_amount:amount ~txn_global_slot)
             in
             let%bind balance =
               [%with_label "Check source balance"]
                 Balance.Checked.(account.balance - amount)
             in
             let%map delegate =
               Public_key.Compressed.Checked.if_ is_stake_delegation
                 ~then_:(Account_id.Checked.public_key payload.body.public_key)
                 ~else_:account.delegate
             in
             { Account.Poly.balance
             ; public_key= account.public_key
             ; token_id= account.token_id
             ; nonce= account.nonce
             ; receipt_chain_hash= account.receipt_chain_hash
             ; delegate
             ; voting_for= account.voting_for
             ; timing } ))
    in
    let%bind fee_excess =
      (* - payments:         payload.common.fee
         - stake delegation: payload.common.fee
         - coinbase:         0 (fee already paid above)
         - fee transfer:     - payload.body.amount - payload.common.fee
      *)
      let open Amount in
      chain Signed.Checked.if_ is_coinbase
        ~then_:(return (Signed.Checked.of_unsigned (var_of_t zero)))
        ~else_:
          (let user_command_excess =
             Signed.Checked.of_unsigned (Checked.of_fee payload.common.fee)
           in
           let%bind fee_transfer_excess =
             let%map magnitude =
               Checked.(payload.body.amount + of_fee payload.common.fee)
             in
             Signed.create ~magnitude ~sgn:Sgn.Checked.neg
           in
           Signed.Checked.if_ is_fee_transfer ~then_:fee_transfer_excess
             ~else_:user_command_excess)
    in
    let%map supply_increase =
      Amount.Checked.if_ is_coinbase ~then_:payload.body.amount
        ~else_:Amount.(var_of_t zero)
    in
    (root_after_source_update, fee_excess, supply_increase)

  (* Someday:
   write the following soundness tests:
   - apply a transaction where the signature is incorrect
   - apply a transaction where the sender does not have enough money in their account
   - apply a transaction and stuff in the wrong target hash
    *)

  module Prover_state = struct
    type t =
      { transaction: Transaction_union.t
      ; state_body_hash_opt: Transaction_protocol_state.Block_data.t
      ; state1: Frozen_ledger_hash.t
      ; state2: Frozen_ledger_hash.t
      ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t
      ; sok_digest: Sok_message.Digest.t }
    [@@deriving fields]
  end

  (* spec for [main top_hash]:
   constraints pass iff
   there exist
      l1 : Frozen_ledger_hash.t,
      l2 : Frozen_ledger_hash.t,
      fee_excess : Amount.Signed.t,
      supply_increase : Amount.t
      pending_coinbase_stack_state: Pending_coinbase_stack_state.t
      t : Tagged_transaction.t
   such that
   H(l1, l2, pending_coinbase_stack_state.source, pending_coinbase_stack_state.target, fee_excess, supply_increase) = top_hash,
   applying [t] to ledger with merkle hash [l1] results in ledger with merkle hash [l2]. *)
  let%snarkydef main top_hash =
    let%bind (module Shifted) = Tick.Inner_curve.Checked.Shifted.create () in
    let%bind root_before =
      exists' Frozen_ledger_hash.typ ~f:Prover_state.state1
    in
    let%bind t =
      with_label __LOC__
        (exists' Transaction_union.typ ~f:Prover_state.transaction)
    in
    let%bind pending_coinbase_before =
      exists' Pending_coinbase.Stack.typ ~f:(fun s ->
          (Prover_state.pending_coinbase_stack_state s).source )
    in
    let%bind pending_coinbase_after =
      exists' Pending_coinbase.Stack.typ ~f:(fun s ->
          (Prover_state.pending_coinbase_stack_state s).target )
    in
    let%bind state_body_hash_opt =
      exists' Transaction_protocol_state.Block_data.typ
        ~f:Prover_state.state_body_hash_opt
    in
    let%bind root_after, fee_excess, supply_increase =
      apply_tagged_transaction
        (module Shifted)
        root_before pending_coinbase_before pending_coinbase_after
        state_body_hash_opt t
    in
    let%map () =
      with_label __LOC__
        (let%bind sok_digest =
           with_label __LOC__
             (exists' Sok_message.Digest.typ ~f:Prover_state.sok_digest)
         in
         let input =
           let open Random_oracle.Input in
           List.reduce_exn ~f:append
             [ Sok_message.Digest.Checked.to_input sok_digest
             ; Frozen_ledger_hash.var_to_input root_before
             ; Frozen_ledger_hash.var_to_input root_after
             ; Pending_coinbase.Stack.var_to_input pending_coinbase_before
             ; Pending_coinbase.Stack.var_to_input pending_coinbase_after
             ; Amount.var_to_input supply_increase
             ; Amount.Signed.Checked.to_input fee_excess ]
         in
         with_label __LOC__
           ( make_checked (fun () ->
                 Random_oracle.Checked.(
                   hash ~init:Hash_prefix.base_snark (pack_input input)) )
           >>= Field.Checked.Assert.equal top_hash ))
    in
    ()

  let create_keys () = generate_keypair main ~exposing:(tick_input ())

  let transaction_union_proof ?(preeval = false) ~proving_key sok_digest state1
      state2 pending_coinbase_stack_state (transaction : Transaction_union.t)
      state_body_hash_opt handler =
    let prover_state : Prover_state.t =
      { transaction
      ; state_body_hash_opt
      ; state1
      ; state2
      ; sok_digest
      ; pending_coinbase_stack_state }
    in
    let main =
      if preeval then failwith "preeval currently disabled" else main
    in
    let main top_hash = handle (main top_hash) handler in
    let top_hash =
      base_top_hash ~sok_digest ~state1 ~state2
        ~fee_excess:(Transaction_union.excess transaction)
        ~supply_increase:(Transaction_union.supply_increase transaction)
        ~pending_coinbase_stack_state
    in
    (top_hash, prove proving_key (tick_input ()) prover_state main top_hash)

  let cached =
    let load =
      let open Cached.Let_syntax in
      let%map verification =
        Cached.component ~label:"transaction_snark_base_verification"
          ~f:Keypair.vk
          (module Verification_key)
      and proving =
        Cached.component ~label:"transaction_snark_base_proving" ~f:Keypair.pk
          (module Proving_key)
      in
      (verification, {proving with value= ()})
    in
    Cached.Spec.create ~load ~name:"transaction-snark base keys"
      ~autogen_path:Cache_dir.autogen_path
      ~manual_install_path:Cache_dir.manual_install_path
      ~brew_install_path:Cache_dir.brew_install_path
      ~s3_install_path:Cache_dir.s3_install_path
      ~digest_input:(fun x ->
        Md5.to_hex (R1CS_constraint_system.digest (Lazy.force x)) )
      ~input:(lazy (constraint_system ~exposing:(tick_input ()) main))
      ~create_env:(fun x -> Keypair.generate (Lazy.force x))
end

module Transition_data = struct
  type t =
    { proof: Proof_type.t * Tock_backend.Proof.t
    ; supply_increase: Amount.t
    ; fee_excess: Amount.Signed.t
    ; sok_digest: Sok_message.Digest.t
    ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t }
  [@@deriving fields]
end

module Merge = struct
  open Tick
  open Let_syntax

  module Prover_state = struct
    type t =
      { tock_vk: Tock_backend.Verification_key.t
      ; sok_digest: Sok_message.Digest.t
      ; ledger_hash1: Frozen_ledger_hash.t
      ; ledger_hash2: Frozen_ledger_hash.t
      ; transition12: Transition_data.t
      ; ledger_hash3: Frozen_ledger_hash.t
      ; transition23: Transition_data.t
      ; pending_coinbase_stack1: Pending_coinbase.Stack.t
      ; pending_coinbase_stack2: Pending_coinbase.Stack.t
      ; pending_coinbase_stack3: Pending_coinbase.Stack.t }
    [@@deriving fields]
  end

  let input = tick_input

  let wrap_input_size = Tock.Data_spec.size wrap_input

  module Verifier = Tick.Verifier

  let construct_input_checked ~prefix ~sok_digest ~state1 ~state2
      ~supply_increase ~fee_excess ~pending_coinbase_stack1
      ~pending_coinbase_stack2 =
    let open Random_oracle in
    let input =
      let open Input in
      List.reduce_exn ~f:append
        [ Sok_message.Digest.Checked.to_input sok_digest
        ; Frozen_ledger_hash.var_to_input state1
        ; Frozen_ledger_hash.var_to_input state2
        ; Pending_coinbase.Stack.var_to_input pending_coinbase_stack1
        ; Pending_coinbase.Stack.var_to_input pending_coinbase_stack2
        ; bitstring
            (Bitstring_lib.Bitstring.Lsb_first.to_list
               (Amount.var_to_bits supply_increase))
        ; Amount.Signed.Checked.to_input fee_excess ]
    in
    make_checked (fun () ->
        Random_oracle.Checked.(
          digest (update ~state:prefix (pack_input input))) )

  let hash_state_if b ~then_ ~else_ =
    make_checked (fun () ->
        Random_oracle.State.map2 then_ else_ ~f:(fun then_ else_ ->
            Run.Field.if_ b ~then_ ~else_ ) )

  (* spec for [verify_transition tock_vk proof_field s1 s2]:
     returns a bool which is true iff
     there is a snark proving making tock_vk
     accept on one of [ H(s1, s2, excess); H(s1, s2, excess, tock_vk) ] *)
  let verify_transition tock_vk tock_vk_precomp wrap_vk_hash_state
      get_transition_data s1 s2 ~pending_coinbase_stack1
      ~pending_coinbase_stack2 supply_increase fee_excess =
    let%bind is_base =
      let get_type s = get_transition_data s |> Transition_data.proof |> fst in
      with_label __LOC__
        (exists' Boolean.typ ~f:(fun s -> Proof_type.is_base (get_type s)))
    in
    let%bind sok_digest =
      exists' Sok_message.Digest.typ
        ~f:(Fn.compose Transition_data.sok_digest get_transition_data)
    in
    let%bind top_hash_init =
      hash_state_if is_base
        ~then_:
          (Random_oracle.State.map ~f:Run.Field.constant Hash_prefix.base_snark)
        ~else_:wrap_vk_hash_state
    in
    let%bind input =
      construct_input_checked ~prefix:top_hash_init ~sok_digest ~state1:s1
        ~state2:s2 ~pending_coinbase_stack1 ~pending_coinbase_stack2
        ~supply_increase ~fee_excess
      >>= Wrap_input.Checked.tick_field_to_scalars
    in
    let%bind proof =
      exists Verifier.Proof.typ
        ~compute:
          As_prover.(
            map get_state ~f:(fun s ->
                get_transition_data s |> Transition_data.proof |> snd
                |> Verifier.proof_of_backend_proof ))
    in
    Verifier.verify tock_vk tock_vk_precomp input proof

  (* spec for [main top_hash]:
     constraints pass iff
     there exist digest, s1, s3, fee_excess, supply_increase pending_coinbase_stack12.source, pending_coinbase_stack23.target, tock_vk such that
     H(digest,s1, s3, pending_coinbase_stack12.source, pending_coinbase_stack23.target, fee_excess, supply_increase, tock_vk) = top_hash,
     verify_transition tock_vk _ s1 s2 pending_coinbase_stack12.source, pending_coinbase_stack12.target is true
     verify_transition tock_vk _ s2 s3 pending_coinbase_stack23.source, pending_coinbase_stack23.target is true
  *)
  let%snarkydef main (top_hash : Pedersen.Checked.Digest.var) =
    let%bind tock_vk =
      exists' (Verifier.Verification_key.typ ~input_size:wrap_input_size)
        ~f:(fun {Prover_state.tock_vk; _} -> Verifier.vk_of_backend_vk tock_vk
      )
    and s1 = exists' Frozen_ledger_hash.typ ~f:Prover_state.ledger_hash1
    and s2 = exists' Frozen_ledger_hash.typ ~f:Prover_state.ledger_hash2
    and s3 = exists' Frozen_ledger_hash.typ ~f:Prover_state.ledger_hash3
    and fee_excess12 =
      exists' Amount.Signed.typ
        ~f:(Fn.compose Transition_data.fee_excess Prover_state.transition12)
    and fee_excess23 =
      exists' Amount.Signed.typ
        ~f:(Fn.compose Transition_data.fee_excess Prover_state.transition23)
    and supply_increase12 =
      exists' Amount.typ
        ~f:
          (Fn.compose Transition_data.supply_increase Prover_state.transition12)
    and supply_increase23 =
      exists' Amount.typ
        ~f:
          (Fn.compose Transition_data.supply_increase Prover_state.transition23)
    and pending_coinbase1 =
      exists' Pending_coinbase.Stack.typ
        ~f:Prover_state.pending_coinbase_stack1
    and pending_coinbase2 =
      exists' Pending_coinbase.Stack.typ
        ~f:Prover_state.pending_coinbase_stack2
    and pending_coinbase3 =
      exists' Pending_coinbase.Stack.typ
        ~f:Prover_state.pending_coinbase_stack3
    in
    let%bind wrap_vk_hash_state =
      make_checked (fun () ->
          Random_oracle.(
            Checked.update
              ~state:
                (State.map Hash_prefix_states.merge_snark ~f:Run.Field.constant)
              (Verifier.Verification_key.to_field_elements tock_vk)) )
    in
    let%bind tock_vk_precomp =
      Verifier.Verification_key.Precomputation.create tock_vk
    in
    let%bind () =
      let%bind total_fees =
        Amount.Signed.Checked.add fee_excess12 fee_excess23
      in
      let%bind supply_increase =
        Amount.Checked.add supply_increase12 supply_increase23
      in
      let%bind input =
        let%bind sok_digest =
          exists' Sok_message.Digest.typ ~f:Prover_state.sok_digest
        in
        construct_input_checked ~prefix:wrap_vk_hash_state ~sok_digest
          ~state1:s1 ~state2:s3 ~pending_coinbase_stack1:pending_coinbase1
          ~pending_coinbase_stack2:pending_coinbase3 ~supply_increase
          ~fee_excess:total_fees
      in
      Field.Checked.Assert.equal top_hash input
    and verify_12 =
      verify_transition tock_vk tock_vk_precomp wrap_vk_hash_state
        Prover_state.transition12 s1 s2
        ~pending_coinbase_stack1:pending_coinbase1
        ~pending_coinbase_stack2:pending_coinbase2 supply_increase12
        fee_excess12
    and verify_23 =
      verify_transition tock_vk tock_vk_precomp wrap_vk_hash_state
        Prover_state.transition23 s2 s3
        ~pending_coinbase_stack1:pending_coinbase2
        ~pending_coinbase_stack2:pending_coinbase3 supply_increase23
        fee_excess23
    in
    Boolean.Assert.all [verify_12; verify_23]

  let create_keys () = generate_keypair ~exposing:(input ()) main

  let cached =
    let load =
      let open Cached.Let_syntax in
      let%map verification =
        Cached.component ~label:"transaction_snark_merge_verification"
          ~f:Keypair.vk
          (module Verification_key)
      and proving =
        Cached.component ~label:"transaction_snark_merge_proving" ~f:Keypair.pk
          (module Proving_key)
      in
      (verification, {proving with value= ()})
    in
    Cached.Spec.create ~load ~name:"transaction-snark merge keys"
      ~autogen_path:Cache_dir.autogen_path
      ~manual_install_path:Cache_dir.manual_install_path
      ~brew_install_path:Cache_dir.brew_install_path
      ~s3_install_path:Cache_dir.s3_install_path
      ~digest_input:(fun x ->
        Md5.to_hex (R1CS_constraint_system.digest (Lazy.force x)) )
      ~input:(lazy (constraint_system ~exposing:(input ()) main))
      ~create_env:(fun x -> Keypair.generate (Lazy.force x))
end

module Verification = struct
  module Keys = Verification_keys

  module type S = sig
    val verify : t -> message:Sok_message.t -> bool

    val verify_against_digest : t -> bool

    val verify_complete_merge :
         Sok_message.Digest.Checked.t
      -> Frozen_ledger_hash.var
      -> Frozen_ledger_hash.var
      -> Pending_coinbase.Stack.var
      -> Pending_coinbase.Stack.var
      -> Currency.Amount.var
      -> (Tock.Proof.t, 's) Tick.As_prover.t
      -> (Tick.Boolean.var, 's) Tick.Checked.t
  end

  module Make (K : sig
    val keys : Keys.t
  end) =
  struct
    open K

    let wrap_vk_state =
      Random_oracle.update ~state:Hash_prefix.merge_snark
        Snark_params.Tick.Verifier.(
          let vk = vk_of_backend_vk keys.wrap in
          let g1 = Tick.Inner_curve.to_affine_exn in
          let g2 = Tick.Pairing.G2.Unchecked.to_affine_exn in
          Verification_key.to_field_elements
            { vk with
              query_base= g1 vk.query_base
            ; query= List.map ~f:g1 vk.query
            ; delta= g2 vk.delta })

    (* someday: Reorganize this module so that the inputs are separated from the proof. *)
    let verify_against_digest
        { source
        ; target
        ; proof
        ; proof_type
        ; fee_excess
        ; sok_digest
        ; supply_increase
        ; pending_coinbase_stack_state } =
      let input =
        match proof_type with
        | `Base ->
            base_top_hash ~sok_digest ~state1:source ~state2:target
              ~pending_coinbase_stack_state ~fee_excess ~supply_increase
        | `Merge ->
            merge_top_hash ~sok_digest wrap_vk_state ~state1:source
              ~state2:target ~pending_coinbase_stack_state ~fee_excess
              ~supply_increase
      in
      Tock.verify proof keys.wrap wrap_input (Wrap_input.of_tick_field input)

    let verify t ~message =
      Sok_message.Digest.equal t.sok_digest (Sok_message.digest message)
      && verify_against_digest t

    (* spec for [verify_merge s1 s2 _]:
      Returns a boolean which is true if there exists a tock proof proving
      (against the wrap verification key) H(s1, s2, Amount.Signed.zero, wrap_vk).
      This in turn should only happen if there exists a tick proof proving
      (against the merge verification key) H(s1, s2, Amount.Signed.zero, wrap_vk).

      We precompute the parts of the pedersen involving wrap_vk and
      Amount.Signed.zero outside the SNARK since this saves us many constraints.
    *)

    let wrap_vk = Merge.Verifier.(constant_vk (vk_of_backend_vk keys.wrap))

    let wrap_precomp =
      Merge.Verifier.(
        Verification_key.Precomputation.create_constant
          (vk_of_backend_vk keys.wrap))

    let verify_complete_merge sok_digest s1 s2
        (pending_coinbase_stack1 : Pending_coinbase.Stack.var)
        (pending_coinbase_stack2 : Pending_coinbase.Stack.var) supply_increase
        get_proof =
      let open Tick in
      let%bind top_hash =
        Merge.construct_input_checked
          ~prefix:(Random_oracle.State.map wrap_vk_state ~f:Run.Field.constant)
          ~state1:s1 ~state2:s2 ~pending_coinbase_stack1
          ~pending_coinbase_stack2 ~sok_digest ~supply_increase
          ~fee_excess:Amount.Signed.(Checked.constant zero)
      in
      let%bind input = Wrap_input.Checked.tick_field_to_scalars top_hash in
      let%map result =
        let%bind proof =
          exists Merge.Verifier.Proof.typ
            ~compute:
              (As_prover.map get_proof ~f:Merge.Verifier.proof_of_backend_proof)
        in
        Merge.Verifier.verify wrap_vk wrap_precomp input proof
      in
      result
  end
end

module Wrap (Vk : sig
  val merge : Tick.Verification_key.t

  val base : Tick.Verification_key.t
end) =
struct
  open Tock
  module Verifier = Tock.Groth_verifier

  let merge_vk = Verifier.vk_of_backend_vk Vk.merge

  let merge_vk_precomp =
    Verifier.Verification_key.Precomputation.create_constant merge_vk

  let base_vk = Verifier.vk_of_backend_vk Vk.base

  let base_vk_precomp =
    Verifier.Verification_key.Precomputation.create_constant base_vk

  module Prover_state = struct
    type t = {proof_type: Proof_type.t; proof: Tick.Proof.t}
    [@@deriving fields]
  end

  let exists' typ ~f = exists typ ~compute:As_prover.(map get_state ~f)

  (* spec for [main input]:
   constraints pass iff
   (b1, b2, .., bn) = unpack input,
   there is a proof making one of [ base_vk; merge_vk ] accept (b1, b2, .., bn) *)
  let%snarkydef main (input : Wrap_input.var) =
    let%bind input = with_label __LOC__ (Wrap_input.Checked.to_scalar input) in
    let%bind is_base =
      exists' Boolean.typ ~f:(fun {Prover_state.proof_type; _} ->
          Proof_type.is_base proof_type )
    in
    let%bind verification_key_precomp =
      with_label __LOC__
        (Verifier.Verification_key.Precomputation.if_ is_base
           ~then_:base_vk_precomp ~else_:merge_vk_precomp)
    in
    let%bind verification_key =
      with_label __LOC__
        (Verifier.Verification_key.if_ is_base
           ~then_:(Verifier.constant_vk base_vk)
           ~else_:(Verifier.constant_vk merge_vk))
    in
    let%bind result =
      let%bind proof =
        exists Verifier.Proof.typ
          ~compute:
            As_prover.(
              map get_state
                ~f:
                  (Fn.compose Verifier.proof_of_backend_proof
                     Prover_state.proof))
      in
      with_label __LOC__
        (Verifier.verify verification_key verification_key_precomp [input]
           proof)
    in
    with_label __LOC__ (Boolean.Assert.is_true result)

  let create_keys () = generate_keypair ~exposing:wrap_input main

  let cached =
    let load =
      let open Cached.Let_syntax in
      let%map verification =
        Cached.component ~label:"transaction_snark_wrap_verification"
          ~f:Keypair.vk
          (module Verification_key)
      and proving =
        Cached.component ~label:"transaction_snark_wrap_proving" ~f:Keypair.pk
          (module Proving_key)
      in
      (verification, {proving with value= ()})
    in
    Cached.Spec.create ~load ~name:"transaction-snark wrap keys"
      ~autogen_path:Cache_dir.autogen_path
      ~manual_install_path:Cache_dir.manual_install_path
      ~brew_install_path:Cache_dir.brew_install_path
      ~s3_install_path:Cache_dir.s3_install_path
      ~digest_input:(fun x ->
        Md5.to_hex (R1CS_constraint_system.digest (Lazy.force x)) )
      ~input:(lazy (constraint_system ~exposing:wrap_input main))
      ~create_env:(fun x -> Keypair.generate (Lazy.force x))
end

module type S = sig
  include Verification.S

  val of_transaction :
       ?preeval:bool
    -> sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> Transaction.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val of_user_command :
       sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> User_command.With_valid_signature.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val of_fee_transfer :
       sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> Fee_transfer.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val merge : t -> t -> sok_digest:Sok_message.Digest.t -> t Or_error.t
end

let check_transaction_union ?(preeval = false) sok_message source target
    pending_coinbase_stack_state transaction state_body_hash_opt handler =
  let sok_digest = Sok_message.digest sok_message in
  let prover_state : Base.Prover_state.t =
    { transaction
    ; state_body_hash_opt
    ; state1= source
    ; state2= target
    ; sok_digest
    ; pending_coinbase_stack_state }
  in
  let top_hash =
    base_top_hash ~sok_digest ~state1:source ~state2:target
      ~pending_coinbase_stack_state
      ~fee_excess:(Transaction_union.excess transaction)
      ~supply_increase:(Transaction_union.supply_increase transaction)
  in
  let open Tick in
  let main =
    if preeval then failwith "preeval currently disabled" else Base.main
  in
  let main =
    handle
      (Checked.map (main (Field.Var.constant top_hash)) ~f:As_prover.return)
      handler
  in
  Or_error.ok_exn (run_and_check main prover_state) |> ignore

let check_transaction ?preeval ~sok_message ~source ~target
    ~pending_coinbase_stack_state
    (transaction_in_block : Transaction.t Transaction_protocol_state.t) handler
    =
  let transaction =
    Transaction_protocol_state.transaction transaction_in_block
  in
  let state_body_hash_opt =
    Transaction_protocol_state.block_data transaction_in_block
  in
  check_transaction_union ?preeval sok_message source target
    pending_coinbase_stack_state
    (Transaction_union.of_transaction transaction)
    state_body_hash_opt handler

let check_user_command ~sok_message ~source ~target pending_coinbase_stack
    t_in_block handler =
  let user_command = Transaction_protocol_state.transaction t_in_block in
  check_transaction ~sok_message ~source ~target
    ~pending_coinbase_stack_state:
      Pending_coinbase_stack_state.Stable.Latest.
        {source= pending_coinbase_stack; target= pending_coinbase_stack}
    {t_in_block with transaction= User_command user_command}
    handler

let generate_transaction_union_witness ?(preeval = false) sok_message source
    target transaction_in_block pending_coinbase_stack_state handler =
  let transaction =
    Transaction_protocol_state.transaction transaction_in_block
  in
  let state_body_hash_opt =
    Transaction_protocol_state.block_data transaction_in_block
  in
  let sok_digest = Sok_message.digest sok_message in
  let prover_state : Base.Prover_state.t =
    { transaction
    ; state_body_hash_opt
    ; state1= source
    ; state2= target
    ; sok_digest
    ; pending_coinbase_stack_state }
  in
  let top_hash =
    base_top_hash ~sok_digest ~state1:source ~state2:target
      ~fee_excess:(Transaction_union.excess transaction)
      ~supply_increase:(Transaction_union.supply_increase transaction)
      ~pending_coinbase_stack_state
  in
  let open Tick in
  let main =
    if preeval then failwith "preeval currently disabled" else Base.main
  in
  let main x = handle (main x) handler in
  generate_auxiliary_input (tick_input ()) prover_state main top_hash

let generate_transaction_witness ?preeval ~sok_message ~source ~target
    pending_coinbase_stack_state
    (transaction_in_block : Transaction.t Transaction_protocol_state.t) handler
    =
  let transaction =
    Transaction_protocol_state.transaction transaction_in_block
  in
  generate_transaction_union_witness ?preeval sok_message source target
    { transaction_in_block with
      transaction= Transaction_union.of_transaction transaction }
    pending_coinbase_stack_state handler

let verification_keys_of_keys {Keys0.verification; _} = verification

module Make (K : sig
  val keys : Keys0.t
end) =
struct
  open K

  include Verification.Make (struct
    let keys = verification_keys_of_keys keys
  end)

  module Wrap = Wrap (struct
    let merge = keys.verification.merge

    let base = keys.verification.base
  end)

  let wrap proof_type proof input =
    let prover_state = {Wrap.Prover_state.proof; proof_type} in
    Tock.prove keys.proving.wrap wrap_input prover_state Wrap.main
      (Wrap_input.of_tick_field input)

  let merge_proof sok_digest ledger_hash1 ledger_hash2 ledger_hash3
      transition12 transition23 =
    let fee_excess =
      Amount.Signed.add transition12.Transition_data.fee_excess
        transition23.Transition_data.fee_excess
      |> Option.value_exn
    in
    let supply_increase =
      Amount.add transition12.supply_increase transition23.supply_increase
      |> Option.value_exn
    in
    let top_hash =
      merge_top_hash wrap_vk_state ~sok_digest ~state1:ledger_hash1
        ~state2:ledger_hash3
        ~pending_coinbase_stack_state:
          Pending_coinbase_stack_state.Stable.Latest.
            { source= transition12.pending_coinbase_stack_state.source
            ; target= transition23.pending_coinbase_stack_state.target }
        ~fee_excess ~supply_increase
    in
    let prover_state =
      { Merge.Prover_state.sok_digest
      ; ledger_hash1
      ; ledger_hash2
      ; ledger_hash3
      ; pending_coinbase_stack1=
          transition12.pending_coinbase_stack_state.source
      ; pending_coinbase_stack2=
          transition12.pending_coinbase_stack_state.target
      ; pending_coinbase_stack3=
          transition23.pending_coinbase_stack_state.target
      ; transition12
      ; transition23
      ; tock_vk= keys.verification.wrap }
    in
    ( top_hash
    , Tick.prove keys.proving.merge (tick_input ()) prover_state Merge.main
        top_hash )

  let of_transaction_union ?preeval sok_digest source target
      ~pending_coinbase_stack_state transaction state_body_hash_opt handler =
    let top_hash, proof =
      Base.transaction_union_proof ?preeval sok_digest
        ~proving_key:keys.proving.base source target
        pending_coinbase_stack_state transaction state_body_hash_opt handler
    in
    { source
    ; sok_digest
    ; target
    ; proof_type= `Base
    ; fee_excess= Transaction_union.excess transaction
    ; pending_coinbase_stack_state
    ; supply_increase= Transaction_union.supply_increase transaction
    ; proof= wrap `Base proof top_hash }

  let of_transaction ?preeval ~sok_digest ~source ~target
      ~pending_coinbase_stack_state transaction_in_block handler =
    let transaction =
      Transaction_protocol_state.transaction transaction_in_block
    in
    let state_body_hash_opt =
      Transaction_protocol_state.block_data transaction_in_block
    in
    of_transaction_union ?preeval sok_digest source target
      ~pending_coinbase_stack_state
      (Transaction_union.of_transaction transaction)
      state_body_hash_opt handler

  let of_user_command ~sok_digest ~source ~target ~pending_coinbase_stack_state
      user_command_in_block handler =
    of_transaction ~sok_digest ~source ~target ~pending_coinbase_stack_state
      { user_command_in_block with
        transaction=
          User_command
            (Transaction_protocol_state.transaction user_command_in_block) }
      handler

  let of_fee_transfer ~sok_digest ~source ~target ~pending_coinbase_stack_state
      transfer_in_block handler =
    of_transaction ~sok_digest ~source ~target ~pending_coinbase_stack_state
      { transfer_in_block with
        transaction=
          Fee_transfer
            (Transaction_protocol_state.transaction transfer_in_block) }
      handler

  let merge t1 t2 ~sok_digest =
    if not (Frozen_ledger_hash.( = ) t1.target t2.source) then
      failwithf
        !"Transaction_snark.merge: t1.target <> t2.source \
          (%{sexp:Frozen_ledger_hash.t} vs %{sexp:Frozen_ledger_hash.t})"
        t1.target t2.source () ;
    let input, proof =
      merge_proof sok_digest t1.source t1.target t2.target
        { Transition_data.proof= (t1.proof_type, t1.proof)
        ; fee_excess= t1.fee_excess
        ; supply_increase= t1.supply_increase
        ; sok_digest= t1.sok_digest
        ; pending_coinbase_stack_state= t1.pending_coinbase_stack_state }
        { Transition_data.proof= (t2.proof_type, t2.proof)
        ; fee_excess= t2.fee_excess
        ; supply_increase= t2.supply_increase
        ; sok_digest= t2.sok_digest
        ; pending_coinbase_stack_state= t2.pending_coinbase_stack_state }
    in
    let open Or_error.Let_syntax in
    let%map fee_excess =
      Amount.Signed.add t1.fee_excess t2.fee_excess
      |> Option.value_map ~f:Or_error.return
           ~default:
             (Or_error.errorf "Transaction_snark.merge: Amount overflow")
    and supply_increase =
      Amount.add t1.supply_increase t2.supply_increase
      |> Option.value_map ~f:Or_error.return
           ~default:
             (Or_error.errorf
                "Transaction_snark.merge: Supply change amount overflow")
    in
    { source= t1.source
    ; target= t2.target
    ; sok_digest
    ; fee_excess
    ; supply_increase
    ; pending_coinbase_stack_state=
        { source= t1.pending_coinbase_stack_state.source
        ; target= t2.pending_coinbase_stack_state.target }
    ; proof_type= `Merge
    ; proof= wrap `Merge proof input }
end

module Keys = struct
  module Storage = Storage.List.Make (Storage.Disk)

  module Per_snark_location = struct
    module T = struct
      type t =
        { base: Storage.location
        ; merge: Storage.location
        ; wrap: Storage.location }
      [@@deriving sexp]
    end

    include T
    include Sexpable.To_stringable (T)
  end

  let checksum ~prefix ~base ~merge ~wrap =
    Md5.digest_string
      ( "Transaction_snark_" ^ prefix ^ Md5.to_hex base ^ Md5.to_hex merge
      ^ Md5.to_hex wrap )

  module Verification = struct
    include Keys0.Verification
    module Location = Per_snark_location

    let checksum ~base ~merge ~wrap =
      checksum ~prefix:"transaction_snark_verification" ~base ~merge ~wrap

    let load ({merge; base; wrap} : Location.t) =
      let open Storage in
      let logger = Logger.create () in
      let tick_controller =
        Controller.create ~logger (module Tick.Verification_key)
      in
      let tock_controller =
        Controller.create ~logger (module Tock.Verification_key)
      in
      let open Async in
      let load c p =
        match%map load_with_checksum c p with
        | Ok x ->
            x
        | Error _e ->
            failwithf
              !"Transaction_snark: load failed on %{sexp:Storage.location}"
              p ()
      in
      let%map base = load tick_controller base
      and merge = load tick_controller merge
      and wrap = load tock_controller wrap in
      let t = {base= base.data; merge= merge.data; wrap= wrap.data} in
      ( t
      , checksum ~base:base.checksum ~merge:merge.checksum ~wrap:wrap.checksum
      )
  end

  module Proving = struct
    include Keys0.Proving
    module Location = Per_snark_location

    let checksum ~base ~merge ~wrap =
      checksum ~prefix:"transaction_snark_proving" ~base ~merge ~wrap

    let load ({merge; base; wrap} : Location.t) =
      let open Storage in
      let logger = Logger.create () in
      let tick_controller =
        Controller.create ~logger (module Tick.Proving_key)
      in
      let tock_controller =
        Controller.create ~logger (module Tock.Proving_key)
      in
      let open Async in
      let load c p =
        match%map load_with_checksum c p with
        | Ok x ->
            x
        | Error _e ->
            failwithf
              !"Transaction_snark: load failed on %{sexp:Storage.location}"
              p ()
      in
      let%map base = load tick_controller base
      and merge = load tick_controller merge
      and wrap = load tock_controller wrap in
      let t = {base= base.data; merge= merge.data; wrap= wrap.data} in
      ( t
      , checksum ~base:base.checksum ~merge:merge.checksum ~wrap:wrap.checksum
      )
  end

  module Location = struct
    module T = struct
      type t =
        {proving: Proving.Location.t; verification: Verification.Location.t}
      [@@deriving sexp]
    end

    include T
    include Sexpable.To_stringable (T)
  end

  include Keys0.T

  module Checksum = struct
    type t = {proving: Md5.t; verification: Md5.t}
  end

  let create () =
    let base = Base.create_keys () in
    let merge = Merge.create_keys () in
    let wrap =
      let module Wrap = Wrap (struct
        let base = Tick.Keypair.vk base

        let merge = Tick.Keypair.vk merge
      end) in
      Wrap.create_keys ()
    in
    { proving=
        { base= Tick.Keypair.pk base
        ; merge= Tick.Keypair.pk merge
        ; wrap= Tock.Keypair.pk wrap }
    ; verification=
        { base= Tick.Keypair.vk base
        ; merge= Tick.Keypair.vk merge
        ; wrap= Tock.Keypair.vk wrap } }

  let cached () =
    let paths path = Cache_dir.possible_paths (Filename.basename path) in
    let open Cached.Deferred_with_track_generated.Let_syntax in
    let%bind base_vk, base_pk = Cached.run Base.cached in
    let%bind merge_vk, merge_pk = Cached.run Merge.cached in
    let%map wrap_vk, wrap_pk =
      let module Wrap = Wrap (struct
        let base = base_vk.value

        let merge = merge_vk.value
      end) in
      Cached.run Wrap.cached
    in
    let t : Verification.t =
      {base= base_vk.value; merge= merge_vk.value; wrap= wrap_vk.value}
    in
    let location : Location.t =
      { proving=
          { base= paths base_pk.path
          ; merge= paths merge_pk.path
          ; wrap= paths wrap_pk.path }
      ; verification=
          { base= paths base_vk.path
          ; merge= paths merge_vk.path
          ; wrap= paths wrap_vk.path } }
    in
    let checksum =
      { Checksum.proving=
          Proving.checksum ~base:base_pk.checksum ~merge:merge_pk.checksum
            ~wrap:wrap_pk.checksum
      ; verification=
          Verification.checksum ~base:base_vk.checksum ~merge:merge_vk.checksum
            ~wrap:wrap_vk.checksum }
    in
    (location, t, checksum)
end

let%test_module "transaction_snark" =
  ( module struct
    (* For tests let's just monkey patch ledger and sparse ledger to freeze their
     * ledger_hashes. The nominal type is just so we don't mix this up in our
     * real code. *)
    module Ledger = struct
      include Ledger

      let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t

      let merkle_root_after_user_command_exn t txn =
        Frozen_ledger_hash.of_ledger_hash
        @@ merkle_root_after_user_command_exn t txn
    end

    module Sparse_ledger = struct
      include Sparse_ledger

      let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t
    end

    type wallet = {private_key: Private_key.t; account: Account.t}

    let random_wallets ?(n = min (Int.pow 2 ledger_depth) (1 lsl 10)) () =
      let random_wallet () : wallet =
        let private_key = Private_key.create () in
        let public_key =
          Public_key.compress (Public_key.of_private_key_exn private_key)
        in
        let account_id = Account_id.create public_key Token_id.default in
        { private_key
        ; account=
            Account.create account_id (Balance.of_int (50 + Random.int 100)) }
      in
      Array.init n ~f:(fun _ -> random_wallet ())

    let user_command sender receiver amt fee fee_token nonce memo =
      let payload : User_command.Payload.t =
        User_command.Payload.create ~fee ~fee_token ~nonce ~memo
          ~valid_until:Global_slot.max_value
          ~body:
            (Payment
               { receiver= Account.identifier receiver.account
               ; amount= Amount.of_int amt })
      in
      let signature = Schnorr.sign sender.private_key payload in
      User_command.check
        User_command.Poly.Stable.Latest.
          { payload
          ; signer= Public_key.of_private_key_exn sender.private_key
          ; signature }
      |> Option.value_exn

    let user_command_with_wallet wallets i j amt fee fee_token nonce memo =
      let sender = wallets.(i) in
      let receiver = wallets.(j) in
      user_command sender receiver amt fee fee_token nonce memo

    let keys = Keys.create ()

    include Make (struct
      let keys = keys
    end)

    let state_body_hash = Quickcheck.random_value State_body_hash.gen

    let pending_coinbase_stack_target (t : Transaction.t) state_body_hash_opt
        stack =
      let stack_with_state =
        Option.value_map state_body_hash_opt ~default:stack
          ~f:(fun state_body_hash ->
            Pending_coinbase.Stack.(push_state state_body_hash stack) )
      in
      match t with
      | Coinbase c ->
          Pending_coinbase.(Stack.push_coinbase c stack_with_state)
      | _ ->
          stack_with_state

    let check_balance pk balance ledger =
      let loc = Ledger.location_of_account ledger pk |> Option.value_exn in
      let acc = Ledger.get ledger loc |> Option.value_exn in
      [%test_eq: Balance.t] acc.balance (Balance.of_int balance)

    let of_user_command' sok_digest ledger user_command pending_coinbase_stack
        state_body_hash_opt handler =
      let source = Ledger.merkle_root ledger in
      let target =
        Ledger.merkle_root_after_user_command_exn ledger user_command
      in
      let pending_coinbase_stack_target =
        pending_coinbase_stack_target (User_command user_command)
          state_body_hash_opt pending_coinbase_stack
      in
      let pending_coinbase_stack_state =
        { Pending_coinbase_stack_state.source= pending_coinbase_stack
        ; target= pending_coinbase_stack_target }
      in
      let user_command_in_block =
        { Transaction_protocol_state.Poly.transaction= user_command
        ; block_data= state_body_hash_opt }
      in
      ( of_user_command ~sok_digest ~source ~target
          ~pending_coinbase_stack_state user_command_in_block handler
      , pending_coinbase_stack_target )

    (*
                ~proposer:
                  { x=
                      Snark_params.Tick.Field.of_string
                        "39876046544032071884326965137489542106804584544160987424424979200505499184903744868114140"
                  ; is_odd= true }
                ~fee_transfer:
                  (Some
                     ( { x=
                           Snark_params.Tick.Field.of_string
                             "221715137372156378645114069225806158618712943627692160064142985953895666487801880947288786"
                       ; is_odd= true }
       *)

    let mk_pubkey () =
      Public_key.(compress (of_private_key_exn (Private_key.create ())))

    let coinbase_test state_body_hash_opt =
      let producer = mk_pubkey () in
      let producer_id = Account_id.create producer Token_id.default in
      let receiver = mk_pubkey () in
      let receiver_id = Account_id.create receiver Token_id.default in
      let other = mk_pubkey () in
      let other_id = Account_id.create other Token_id.default in
      let pending_coinbase_init = Pending_coinbase.Stack.empty in
      let cb =
        Coinbase.create
          ~amount:(Currency.Amount.of_int 10)
          ~receiver
          ~fee_transfer:
            (Some (other, Coda_compile_config.account_creation_fee))
        |> Or_error.ok_exn
      in
      let txn_in_block =
        { Transaction_protocol_state.Poly.transaction= Transaction.Coinbase cb
        ; block_data= state_body_hash_opt }
      in
      let pending_coinbase_stack_target =
        pending_coinbase_stack_target txn_in_block.transaction
          state_body_hash_opt pending_coinbase_init
      in
      Ledger.with_ledger ~f:(fun ledger ->
          Ledger.create_new_account_exn ledger producer_id
            (Account.create receiver_id Balance.zero) ;
          let sparse_ledger =
            Sparse_ledger.of_ledger_subset_exn ledger
              [producer_id; receiver_id; other_id]
          in
          check_transaction txn_in_block
            (unstage (Sparse_ledger.handler sparse_ledger))
            ~sok_message:
              (Coda_base.Sok_message.create ~fee:Currency.Fee.zero
                 ~prover:Public_key.Compressed.empty)
            ~source:(Sparse_ledger.merkle_root sparse_ledger)
            ~target:
              Sparse_ledger.(
                merkle_root
                  (apply_transaction_exn sparse_ledger txn_in_block.transaction))
            ~pending_coinbase_stack_state:
              { source= pending_coinbase_init
              ; target= pending_coinbase_stack_target } )

    let%test_unit "coinbase with state body hash" =
      Test_util.with_randomness 123456789 (fun () ->
          let state_body_hash_opt : Transaction_protocol_state.Block_data.t =
            Some state_body_hash
          in
          coinbase_test state_body_hash_opt )

    let%test_unit "coinbase without state body hash" =
      Test_util.with_randomness 12345678 (fun () ->
          let state_body_hash_opt : Transaction_protocol_state.Block_data.t =
            None
          in
          coinbase_test state_body_hash_opt )

    let%test_unit "new_account" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = random_wallets () in
          Ledger.with_ledger ~f:(fun ledger ->
              Array.iter
                (Array.sub wallets ~pos:1 ~len:(Array.length wallets - 1))
                ~f:(fun {account; private_key= _} ->
                  Ledger.create_new_account_exn ledger
                    (Account.identifier account)
                    account ) ;
              let t1 =
                user_command_with_wallet wallets 1 0 8
                  (Fee.of_int (Random.int 20))
                  Token_id.default Account.Nonce.zero
                  (User_command_memo.create_by_digesting_string_exn
                     (Test_util.arbitrary_string
                        ~len:User_command_memo.max_digestible_string_length))
              in
              let state_body_hash_opt : Transaction_protocol_state.Block_data.t
                  =
                None
              in
              let target =
                Ledger.merkle_root_after_user_command_exn ledger t1
              in
              let mentioned_keys =
                User_command.accounts_accessed (t1 :> User_command.t)
              in
              let sparse_ledger =
                Sparse_ledger.of_ledger_subset_exn ledger mentioned_keys
              in
              let sok_message =
                Sok_message.create ~fee:Fee.zero
                  ~prover:wallets.(1).account.public_key
              in
              let pending_coinbase_stack = Pending_coinbase.Stack.empty in
              check_user_command ~sok_message
                ~source:(Ledger.merkle_root ledger)
                ~target pending_coinbase_stack
                {transaction= t1; block_data= state_body_hash_opt}
                (unstage @@ Sparse_ledger.handler sparse_ledger) ) )

    let account_fee = Fee.to_int Coda_compile_config.account_creation_fee

    let state_body_hash_opt : Transaction_protocol_state.Block_data.t = None

    let test_transaction ledger txn =
      let source = Ledger.merkle_root ledger in
      let pending_coinbase_stack = Pending_coinbase.Stack.empty in
      let mentioned_keys, pending_coinbase_stack_target =
        match txn with
        | Transaction.User_command uc ->
            ( User_command.accounts_accessed (uc :> User_command.t)
            , pending_coinbase_stack )
        | Fee_transfer ft ->
            ( One_or_two.map ft ~f:(fun (key, _) ->
                  Account_id.create key Token_id.default )
              |> One_or_two.to_list
            , pending_coinbase_stack )
        | Coinbase ({receiver; fee_transfer; _} as cb) ->
            ( Account_id.create receiver Token_id.default
              :: Option.value_map ~default:[] fee_transfer ~f:(fun ft ->
                     [Account_id.create (fst ft) Token_id.default] )
            , Pending_coinbase.Stack.push_coinbase cb pending_coinbase_stack )
      in
      let signer =
        let txn_union = Transaction_union.of_transaction txn in
        txn_union.signer |> Public_key.compress
      in
      let sparse_ledger =
        Sparse_ledger.of_ledger_subset_exn ledger mentioned_keys
      in
      let _undo = Ledger.apply_transaction ledger txn in
      let target = Ledger.merkle_root ledger in
      let sok_message = Sok_message.create ~fee:Fee.zero ~prover:signer in
      check_transaction ~sok_message ~source ~target
        ~pending_coinbase_stack_state:
          { Pending_coinbase_stack_state.source= pending_coinbase_stack
          ; target= pending_coinbase_stack_target }
        {transaction= txn; block_data= state_body_hash_opt}
        (unstage @@ Sparse_ledger.handler sparse_ledger)

    let%test_unit "account creation fee - user commands" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = random_wallets ~n:3 () |> Array.to_list in
          let sender = List.hd_exn wallets in
          let receivers = List.tl_exn wallets in
          let txns_per_receiver = 2 in
          let amount = 8 in
          let txn_fee = 2 in
          let memo =
            User_command_memo.create_by_digesting_string_exn
              (Test_util.arbitrary_string
                 ~len:User_command_memo.max_digestible_string_length)
          in
          Ledger.with_ledger ~f:(fun ledger ->
              let _, ucs =
                let receivers =
                  List.fold ~init:receivers
                    (List.init (txns_per_receiver - 1) ~f:Fn.id)
                    ~f:(fun acc _ -> receivers @ acc)
                in
                List.fold receivers ~init:(Account.Nonce.zero, [])
                  ~f:(fun (nonce, txns) receiver ->
                    let uc =
                      user_command sender receiver amount (Fee.of_int txn_fee)
                        Token_id.default nonce memo
                    in
                    (Account.Nonce.succ nonce, txns @ [uc]) )
              in
              Ledger.create_new_account_exn ledger
                (Account.identifier sender.account)
                sender.account ;
              let () =
                List.iter ucs ~f:(fun uc ->
                    test_transaction ledger (Transaction.User_command uc) )
              in
              List.iter receivers ~f:(fun receiver ->
                  check_balance
                    (Account.identifier receiver.account)
                    ((amount * txns_per_receiver) - account_fee)
                    ledger ) ;
              check_balance
                (Account.identifier sender.account)
                ( Balance.to_int sender.account.balance
                - (amount + txn_fee) * txns_per_receiver
                  * List.length receivers )
                ledger ) )

    let%test_unit "account creation fee - fee transfers" =
      Test_util.with_randomness 123456789 (fun () ->
          let receivers = random_wallets ~n:3 () |> Array.to_list in
          let txns_per_receiver = 3 in
          let fee = 8 in
          Ledger.with_ledger ~f:(fun ledger ->
              let fts =
                let receivers =
                  List.fold ~init:receivers
                    (List.init (txns_per_receiver - 1) ~f:Fn.id)
                    ~f:(fun acc _ -> receivers @ acc)
                  |> One_or_two.group_list
                in
                List.fold receivers ~init:[] ~f:(fun txns receiver ->
                    let ft : Fee_transfer.t =
                      One_or_two.map receiver ~f:(fun receiver ->
                          ( ( receiver.account.public_key
                            , Currency.Fee.of_int fee )
                            : Fee_transfer.Single.t ) )
                    in
                    txns @ [ft] )
              in
              let () =
                List.iter fts ~f:(fun ft ->
                    let txn = Transaction.Fee_transfer ft in
                    test_transaction ledger txn )
              in
              List.iter receivers ~f:(fun receiver ->
                  check_balance
                    (Account.identifier receiver.account)
                    ((fee * txns_per_receiver) - account_fee)
                    ledger ) ) )

    let%test_unit "account creation fee - coinbase" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = random_wallets ~n:3 () in
          let receiver = wallets.(0) in
          let other = wallets.(1) in
          let dummy_account = wallets.(2) in
          let reward = 10 in
          let fee = Fee.to_int Coda_compile_config.account_creation_fee in
          let coinbase_count = 3 in
          let ft_count = 2 in
          Ledger.with_ledger ~f:(fun ledger ->
              let _, cbs =
                let fts =
                  List.map (List.init ft_count ~f:Fn.id) ~f:(fun _ ->
                      ( other.account.public_key
                      , Coda_compile_config.account_creation_fee ) )
                in
                List.fold ~init:(fts, []) (List.init coinbase_count ~f:Fn.id)
                  ~f:(fun (fts, cbs) _ ->
                    let cb =
                      Coinbase.create
                        ~amount:(Currency.Amount.of_int reward)
                        ~receiver:receiver.account.public_key
                        ~fee_transfer:(List.hd fts)
                      |> Or_error.ok_exn
                    in
                    (Option.value ~default:[] (List.tl fts), cb :: cbs) )
              in
              Ledger.create_new_account_exn ledger
                (Account.identifier dummy_account.account)
                dummy_account.account ;
              let () =
                List.iter cbs ~f:(fun cb ->
                    let txn = Transaction.Coinbase cb in
                    test_transaction ledger txn )
              in
              let fees = fee * ft_count in
              check_balance
                (Account.identifier receiver.account)
                ((reward * coinbase_count) - account_fee - fees)
                ledger ;
              check_balance
                (Account.identifier other.account)
                (fees - account_fee) ledger ) )

    let%test "base_and_merge" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = random_wallets () in
          Ledger.with_ledger ~f:(fun ledger ->
              Array.iter wallets ~f:(fun {account; private_key= _} ->
                  Ledger.create_new_account_exn ledger
                    (Account.identifier account)
                    account ) ;
              let state_body_hash_opt1 = Some state_body_hash in
              let state_body_hash_opt2 :
                  Transaction_protocol_state.Block_data.t =
                None
              in
              let t1 =
                user_command_with_wallet wallets 0 1 8
                  (Fee.of_int (Random.int 20))
                  Token_id.default Account.Nonce.zero
                  (User_command_memo.create_by_digesting_string_exn
                     (Test_util.arbitrary_string
                        ~len:User_command_memo.max_digestible_string_length))
              in
              let t2 =
                user_command_with_wallet wallets 1 2 3
                  (Fee.of_int (Random.int 20))
                  Token_id.default Account.Nonce.zero
                  (User_command_memo.create_by_digesting_string_exn
                     (Test_util.arbitrary_string
                        ~len:User_command_memo.max_digestible_string_length))
              in
              let sok_digest =
                Sok_message.create ~fee:Fee.zero
                  ~prover:wallets.(0).account.public_key
                |> Sok_message.digest
              in
              let state1 = Ledger.merkle_root ledger in
              let sparse_ledger =
                Sparse_ledger.of_ledger_subset_exn ledger
                  (List.concat_map
                     ~f:(fun t ->
                       User_command.accounts_accessed (t :> User_command.t) )
                     [t1; t2])
              in
              let proof12, pending_coinbase_stack_next =
                of_user_command' sok_digest ledger t1
                  Pending_coinbase.Stack.empty state_body_hash_opt1
                  (unstage @@ Sparse_ledger.handler sparse_ledger)
              in
              let sparse_ledger =
                Sparse_ledger.apply_user_command_exn sparse_ledger
                  (t1 :> User_command.t)
              in
              Ledger.apply_user_command ledger t1 |> Or_error.ok_exn |> ignore ;
              [%test_eq: Frozen_ledger_hash.t]
                (Ledger.merkle_root ledger)
                (Sparse_ledger.merkle_root sparse_ledger) ;
              let proof23, pending_coinbase_stack_target =
                of_user_command' sok_digest ledger t2
                  pending_coinbase_stack_next state_body_hash_opt2
                  (unstage @@ Sparse_ledger.handler sparse_ledger)
              in
              let sparse_ledger =
                Sparse_ledger.apply_user_command_exn sparse_ledger
                  (t2 :> User_command.t)
              in
              let pending_coinbase_stack_state =
                Pending_coinbase_stack_state.Stable.Latest.
                  { source= Pending_coinbase.Stack.empty
                  ; target= pending_coinbase_stack_target }
              in
              Ledger.apply_user_command ledger t2 |> Or_error.ok_exn |> ignore ;
              [%test_eq: Frozen_ledger_hash.t]
                (Ledger.merkle_root ledger)
                (Sparse_ledger.merkle_root sparse_ledger) ;
              let total_fees =
                let open Amount in
                let magnitude =
                  of_fee
                    (User_command_payload.fee (t1 :> User_command.t).payload)
                  + of_fee
                      (User_command_payload.fee (t2 :> User_command.t).payload)
                  |> Option.value_exn
                in
                Signed.create ~magnitude ~sgn:Sgn.Pos
              in
              let state3 = Sparse_ledger.merkle_root sparse_ledger in
              let proof13 =
                merge ~sok_digest proof12 proof23 |> Or_error.ok_exn
              in
              Tock.verify proof13.proof keys.verification.wrap wrap_input
                (Wrap_input.of_tick_field
                   (merge_top_hash ~sok_digest ~state1 ~state2:state3
                      ~supply_increase:Amount.zero ~fee_excess:total_fees
                      ~pending_coinbase_stack_state wrap_vk_state)) ) )
  end )

let%test_module "account timing check" =
  ( module struct
    open Core_kernel
    open Coda_numbers
    open Currency
    open Transaction_validator.For_tests

    (* test that unchecked and checked calculations for timing agree *)

    let make_checked_computation account txn_amount txn_global_slot =
      let account = Account.var_of_t account in
      let txn_amount = Amount.var_of_t txn_amount in
      let txn_global_slot = Global_slot.Checked.constant txn_global_slot in
      let open Snarky.Checked.Let_syntax in
      let%map timing =
        Base.check_timing ~account ~txn_amount ~txn_global_slot
      in
      Snarky.As_prover.read Account.Timing.typ timing

    let run_checked_timing_and_compare account txn_amount txn_global_slot
        unchecked_timing =
      let checked_computation =
        make_checked_computation account txn_amount txn_global_slot
      in
      let (), checked_timing =
        Or_error.ok_exn
        @@ Snark_params.Tick.run_and_check checked_computation ()
      in
      Account.Timing.equal checked_timing unchecked_timing

    (* confirm the checked computation fails *)
    let checked_timing_should_fail account txn_amount txn_global_slot =
      let checked_computation =
        make_checked_computation account txn_amount txn_global_slot
      in
      Or_error.is_error
      @@ Snark_params.Tick.run_and_check checked_computation ()

    let%test "before_cliff_time" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000 in
      let initial_minimum_balance = Balance.of_int 80_000 in
      let cliff_time = Global_slot.of_int 1000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 1 in
      let txn_amount = Currency.Amount.of_int 100 in
      let txn_global_slot = Global_slot.of_int 45 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~vesting_period ~vesting_increment
      in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      match timing with
      | Ok (Timed _ as unchecked_timing) ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing
      | _ ->
          false

    let%test "positive min balance" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000 in
      let initial_minimum_balance = Balance.of_int 10_000 in
      let cliff_time = Global_slot.of_int 1000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 100 in
      let txn_global_slot = Coda_numbers.Global_slot.of_int 1900 in
      let timing =
        validate_timing ~account
          ~txn_amount:(Currency.Amount.of_int 100)
          ~txn_global_slot:(Coda_numbers.Global_slot.of_int 1900)
      in
      (* we're 900 slots past the cliff, which is 90 vesting periods
          subtract 90 * 100 = 9,000 from init min balance of 10,000 to get 1000
          so we should still be timed
        *)
      match timing with
      | Ok (Timed _ as unchecked_timing) ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing
      | _ ->
          false

    let%test "curr min balance of zero" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000 in
      let initial_minimum_balance = Balance.of_int 10_000 in
      let cliff_time = Global_slot.of_int 1_000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 100 in
      let txn_global_slot = Coda_numbers.Global_slot.of_int 2_000 in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      (* we're 1000 slots past the cliff, which is 100 vesting periods
          subtract 100 * 100 = 10,000 from init min balance of 10,000 to get zero
          so we should be untimed now
        *)
      match timing with
      | Ok (Untimed as unchecked_timing) ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing
      | _ ->
          false

    let%test "below calculated min balance" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 10_000 in
      let initial_minimum_balance = Balance.of_int 10_000 in
      let cliff_time = Global_slot.of_int 1_000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 101 in
      let txn_global_slot = Coda_numbers.Global_slot.of_int 1_010 in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      match timing with
      | Error _ ->
          checked_timing_should_fail account txn_amount txn_global_slot
      | _ ->
          false

    let%test "insufficient balance" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000 in
      let initial_minimum_balance = Balance.of_int 10_000 in
      let cliff_time = Global_slot.of_int 1000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 100_001 in
      let txn_global_slot = Coda_numbers.Global_slot.of_int 2000 in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      match timing with
      | Error _ ->
          checked_timing_should_fail account txn_amount txn_global_slot
      | _ ->
          false

    let%test "past full vesting" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000 in
      let initial_minimum_balance = Balance.of_int 10_000 in
      let cliff_time = Global_slot.of_int 1000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~vesting_period ~vesting_increment
      in
      (* fully vested, curr min balance = 0, so we can spend the whole balance *)
      let txn_amount = Currency.Amount.of_int 100_000 in
      let txn_global_slot = Coda_numbers.Global_slot.of_int 3000 in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      match timing with
      | Ok (Untimed as unchecked_timing) ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing
      | _ ->
          false
  end )

let constraint_system_digests () =
  let module W = Wrap (struct
    let merge = Verification_keys.dummy.merge

    let base = Verification_keys.dummy.base
  end) in
  let digest = Tick.R1CS_constraint_system.digest in
  let digest' = Tock.R1CS_constraint_system.digest in
  [ ( "transaction-merge"
    , digest Merge.(Tick.constraint_system ~exposing:(input ()) main) )
  ; ( "transaction-base"
    , digest Base.(Tick.constraint_system ~exposing:(tick_input ()) main) )
  ; ( "transaction-wrap"
    , digest' W.(Tock.constraint_system ~exposing:wrap_input main) ) ]
