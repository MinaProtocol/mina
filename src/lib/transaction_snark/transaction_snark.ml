open Core
open Signature_lib
open Coda_base
open Snark_params
module Global_slot = Coda_numbers.Global_slot
module Amount = Currency.Amount
module Balance = Currency.Balance
module Fee = Currency.Fee

module Proof_type = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = [`Base | `Merge] [@@deriving compare, equal, hash, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, hash, compare, yojson]
end

module Pending_coinbase_stack_state = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 's t = {source: 's; target: 's}
        [@@deriving sexp, hash, compare, eq, fields, yojson]
      end
    end]
  end

  (* State of the coinbase stack for the current transaction snark *)
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Pending_coinbase.Stack.Stable.V1.t Poly.Stable.V1.t
      [@@deriving sexp, hash, compare, eq, yojson]

      let to_latest = Fn.id
    end
  end]

  type 's t_ = 's Poly.Stable.Latest.t = {source: 's; target: 's}
  [@@deriving sexp, hash, compare, eq, fields, yojson]

  type t = Stable.Latest.t [@@deriving sexp, hash, compare, yojson]

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)

  let typ =
    let open Snarky.Typ in
    let to_ {source; target} = Snarky.H_list.[source; target] in
    let of_ ([source; target] : (unit, _) Snarky.H_list.t) =
      {source; target}
    in
    of_hlistable
      [Pending_coinbase.Stack.typ; Pending_coinbase.Stack.typ]
      ~var_to_hlist:to_ ~var_of_hlist:of_ ~value_to_hlist:to_
      ~value_of_hlist:of_
end

module Statement = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('lh, 'amt, 'pc, 'signed_amt, 'sok) t =
          { source: 'lh
          ; target: 'lh
          ; supply_increase: 'amt
          ; pending_coinbase_stack_state:
              'pc Pending_coinbase_stack_state.Poly.Stable.V1.t
          ; fee_excess: 'signed_amt
          ; sok_digest: 'sok }
        [@@deriving bin_io, compare, equal, hash, sexp, yojson]
      end
    end]
  end

  type ('lh, 'amt, 'pc, 'signed_amt, 'sok) t_ =
        ('lh, 'amt, 'pc, 'signed_amt, 'sok) Poly.Stable.Latest.t =
    { source: 'lh
    ; target: 'lh
    ; supply_increase: 'amt
    ; pending_coinbase_stack_state:
        'pc Pending_coinbase_stack_state.Poly.Stable.V1.t
    ; fee_excess: 'signed_amt
    ; sok_digest: 'sok }

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Frozen_ledger_hash.Stable.V1.t
        , Currency.Amount.Stable.V1.t
        , Pending_coinbase.Stack.Stable.V1.t
        , ( Currency.Amount.Stable.V1.t
          , Sgn.Stable.V1.t )
          Currency.Signed_poly.Stable.V1.t
        , unit )
        Poly.Stable.V1.t
      [@@deriving compare, equal, hash, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, hash, compare, yojson]

  module With_sok = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Frozen_ledger_hash.Stable.V1.t
          , Currency.Amount.Stable.V1.t
          , Pending_coinbase.Stack.Stable.V1.t
          , ( Currency.Amount.Stable.V1.t
            , Sgn.Stable.V1.t )
            Currency.Signed_poly.Stable.V1.t
          , Sok_message.Digest.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving bin_io, compare, equal, hash, sexp, yojson]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t [@@deriving sexp, hash, compare, equal, yojson]

    let to_field_elements
        { source
        ; target
        ; supply_increase
        ; pending_coinbase_stack_state= pc
        ; fee_excess
        ; sok_digest } =
      let open Random_oracle.Input in
      List.reduce_exn ~f:append
        [ Sok_message.Digest.to_input sok_digest
        ; Frozen_ledger_hash.to_input source
        ; Frozen_ledger_hash.to_input target
        ; Pending_coinbase.Stack.to_input pc.source
        ; Pending_coinbase.Stack.to_input pc.target
        ; Amount.to_input supply_increase
        ; Amount.Signed.to_input fee_excess ]
      |> Random_oracle.pack_input

    module Checked = struct
      type t =
        ( Frozen_ledger_hash.var
        , Currency.Amount.var
        , Pending_coinbase.Stack.var
        , Amount.Signed.var
        , Sok_message.Digest.Checked.t (* TODO: Better for this to be packed *)
        )
        t_

      let to_field_elements
          { source
          ; target
          ; supply_increase
          ; pending_coinbase_stack_state= p
          ; fee_excess
          ; sok_digest } =
        let open Random_oracle.Input in
        List.reduce_exn ~f:append
          [ Sok_message.Digest.Checked.to_input sok_digest
          ; Frozen_ledger_hash.var_to_input source
          ; Frozen_ledger_hash.var_to_input target
          ; Pending_coinbase.Stack.var_to_input p.source
          ; Pending_coinbase.Stack.var_to_input p.target
          ; Amount.var_to_input supply_increase
          ; Amount.Signed.Checked.to_input fee_excess ]
        |> Random_oracle.Checked.pack_input
    end

    let typ =
      let open Snarky.Typ in
      let to_
          { source
          ; target
          ; supply_increase
          ; pending_coinbase_stack_state
          ; fee_excess
          ; sok_digest } =
        Snarky.H_list.
          [ source
          ; target
          ; supply_increase
          ; pending_coinbase_stack_state
          ; fee_excess
          ; sok_digest ]
      in
      let of_
          ([ source
           ; target
           ; supply_increase
           ; pending_coinbase_stack_state
           ; fee_excess
           ; sok_digest ] :
            (unit, _) Snarky.H_list.t) =
        { source
        ; target
        ; supply_increase
        ; pending_coinbase_stack_state
        ; fee_excess
        ; sok_digest }
      in
      of_hlistable
        [ Frozen_ledger_hash.typ
        ; Frozen_ledger_hash.typ
        ; Currency.Amount.typ
        ; Pending_coinbase_stack_state.typ
        ; Currency.Amount.Signed.typ
        ; Sok_message.Digest.typ ]
        ~var_to_hlist:to_ ~var_of_hlist:of_ ~value_to_hlist:to_
        ~value_of_hlist:of_
  end

  let option lab =
    Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

  let merge s1 s2 =
    let open Or_error.Let_syntax in
    let%map fee_excess =
      Currency.Amount.Signed.add s1.fee_excess s2.fee_excess
      |> option "Error adding fees"
    and supply_increase =
      Currency.Amount.add s1.supply_increase s2.supply_increase
      |> option "Error adding supply_increase"
    in
    { source= s1.source
    ; target= s2.target
    ; fee_excess
    ; supply_increase
    ; pending_coinbase_stack_state=
        { source= s1.pending_coinbase_stack_state.source
        ; target= s2.pending_coinbase_stack_state.target }
    ; sok_digest= () }

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%map source = Frozen_ledger_hash.gen
    and target = Frozen_ledger_hash.gen
    and fee_excess = Currency.Amount.Signed.gen
    and supply_increase = Currency.Amount.gen
    and pending_coinbase_before = Pending_coinbase.Stack.gen
    and pending_coinbase_after = Pending_coinbase.Stack.gen in
    { source
    ; target
    ; fee_excess
    ; sok_digest= ()
    ; supply_increase
    ; pending_coinbase_stack_state=
        {source= pending_coinbase_before; target= pending_coinbase_after} }
end

module Proof = struct
  open Pickles_types

  module Stable = struct
    module V1 = struct
      module T = Pickles.Proof.Make (Nat.N2) (Nat.N2)

      include (T : module type of T with type t := T.t)

      type t = T.t [@@deriving version {asserted}]
    end
  end

  include Stable.V1
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      {statement: Statement.With_sok.Stable.V1.t; proof: Proof.Stable.V1.t}
    [@@deriving compare, fields, sexp, version]

    let to_yojson {statement= s; proof} =
      `Assoc
        [ ("source", Frozen_ledger_hash.to_yojson s.source)
        ; ("target", Frozen_ledger_hash.to_yojson s.target)
        ; ("supply_increase", Amount.to_yojson s.supply_increase)
        ; ( "pending_coinbase_stack_state"
          , Pending_coinbase_stack_state.to_yojson
              s.pending_coinbase_stack_state )
        ; ("fee_excess", Amount.Signed.to_yojson s.fee_excess)
        ; ("sok_digest", Sok_message.Digest.to_yojson s.sok_digest)
        ; ("proof", Proof.to_yojson proof) ]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t = {statement: Statement.With_sok.t; proof: Proof.t}
[@@deriving sexp]

let proof t = t.proof

let statement t = {t.statement with sok_digest= ()}

let sok_digest t = t.statement.sok_digest

let to_yojson = Stable.Latest.to_yojson

let create ~source ~target ~supply_increase ~pending_coinbase_stack_state
    ~fee_excess ~sok_digest ~proof =
  { statement=
      { source
      ; target
      ; supply_increase
      ; pending_coinbase_stack_state
      ; fee_excess
      ; sok_digest }
  ; proof }

module Base = struct
  open Tick
  open Let_syntax

  type _ Snarky.Request.t +=
    | Transaction : Transaction_union.t Snarky.Request.t
    | State_body : Transaction_protocol_state.Block_data.t Snarky.Request.t

  let%snarkydef check_signature shifted ~payload ~is_user_command ~sender
      ~signature =
    let%bind verifies =
      Schnorr.Checked.verifies shifted signature sender payload
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

  (* spec for
     [apply_tagged_transaction root (tag, { sender; signature; payload }]):
     - if tag = Normal:
        - check that [signature] is a signature by [sender] of payload
        - return:
          - merkle tree [root'] where the sender balance is decremented by
            [payload.amount] and the receiver balance is incremented by [payload.amount].
          - fee excess = +fee.
          -if coinbase, then push it to the stack [pending_coinbase_stack_before]

     - if tag = Fee_transfer
        - return:
          - merkle tree [root'] where the sender balance is incremented by
            fee and the receiver balance is incremented by amount
          - fee excess = -(amount + fee)

  *)
  (* Nonce should only be incremented if it is a "Normal" transaction. *)
  let%snarkydef apply_tagged_transaction (type shifted)
      (shifted : (module Inner_curve.Checked.Shifted.S with type t = shifted))
      root pending_coinbase_stack_before pending_coinbase_after
      state_body_hash_opt
      ({sender; signature; payload} : Transaction_union.var) =
    let nonce = payload.common.nonce in
    let tag = payload.body.tag in
    let%bind is_user_command =
      Transaction_union.Tag.Checked.is_user_command tag
    in
    let%bind () =
      let current_global_slot =
        Global_slot.(Checked.constant zero)
        (* TODO: @deepthi is working on passing through the protocol state to
           here. This should be replaced with the real value when her PR lands.
           See issue #4036.
         *)
      in
      Global_slot.Checked.(current_global_slot <= payload.common.valid_until)
      >>= Boolean.Assert.is_true
    in
    let%bind () =
      check_signature shifted ~payload ~is_user_command ~sender ~signature
    in
    let%bind {excess; sender_delta; supply_increase; receiver_increase} =
      Transaction_union_payload.Changes.Checked.of_payload payload
    in
    let%bind is_stake_delegation =
      Transaction_union.Tag.Checked.is_stake_delegation tag
    in
    let%bind is_payment = Transaction_union.Tag.Checked.is_payment tag in
    let%bind sender_compressed = Public_key.compress_var sender in
    let%bind is_coinbase = Transaction_union.Tag.Checked.is_coinbase tag in
    (*push state for any transaction*)
    let state_body_hash =
      Transaction_protocol_state.Block_data.Checked.state_body_hash
        state_body_hash_opt
    in
    let push_state =
      Transaction_protocol_state.Block_data.Checked.push_state
        state_body_hash_opt
    in
    let%bind pending_coinbase_stack_with_state =
      let%bind updated_stack =
        Pending_coinbase.Stack.Checked.push_state state_body_hash
          pending_coinbase_stack_before
      in
      Pending_coinbase.Stack.Checked.if_ push_state ~then_:updated_stack
        ~else_:pending_coinbase_stack_before
    in
    let coinbase_receiver = payload.body.public_key in
    let coinbase = (coinbase_receiver, payload.body.amount) in
    let%bind computed_pending_coinbase_stack_after =
      let%bind stack' =
        Pending_coinbase.Stack.Checked.push_coinbase coinbase
          pending_coinbase_stack_with_state
      in
      Pending_coinbase.Stack.Checked.if_ is_coinbase ~then_:stack'
        ~else_:pending_coinbase_stack_with_state
    in
    let%bind () =
      with_label __LOC__
        (let%bind correct_coinbase_stack =
           Pending_coinbase.Stack.equal_var
             computed_pending_coinbase_stack_after pending_coinbase_after
         in
         Boolean.Assert.is_true correct_coinbase_stack)
    in
    let account_creation_amount_var =
      Amount.Checked.of_fee
        Fee.(var_of_t Coda_compile_config.account_creation_fee)
    in
    let%bind receiver =
      (* A stake delegation only uses the sender *)
      Public_key.Compressed.Checked.if_ is_stake_delegation
        ~then_:sender_compressed ~else_:payload.body.public_key
    in
    (* we explicitly set the public_key because it could be zero if the account is new *)
    let%bind root_after_receiver_update =
      (* This update should be a no-op in the stake delegation case *)
      Frozen_ledger_hash.modify_account_recv root receiver
        ~f:(fun ~is_empty_and_writeable account ->
          let%map balance =
            (* receiver_increase will be zero in the stake delegation case *)
            let%bind receiver_amount =
              let%bind amount_for_new_account, `Underflow underflow =
                Amount.Checked.sub_flagged receiver_increase
                  account_creation_amount_var
              in
              let%bind () =
                let%bind enough_amount_for_new_account =
                  Boolean.(
                    if_ is_empty_and_writeable ~then_:(not underflow)
                      ~else_:true_)
                in
                Boolean.Assert.is_true enough_amount_for_new_account
              in
              Currency.Amount.Checked.if_ is_empty_and_writeable
                ~then_:amount_for_new_account ~else_:receiver_increase
            in
            Balance.Checked.(account.balance + receiver_amount)
          and delegate =
            Public_key.Compressed.Checked.if_ is_empty_and_writeable
              ~then_:receiver ~else_:account.delegate
          in
          {account with balance; delegate; public_key= receiver} )
    in
    let%map new_root =
      let%bind is_writeable =
        let%bind is_fee_transfer =
          Transaction_union.Tag.Checked.is_fee_transfer tag
        in
        Boolean.any [is_fee_transfer; is_coinbase]
      in
      Frozen_ledger_hash.modify_account_send root_after_receiver_update
        ~is_writeable sender_compressed
        ~f:(fun ~is_empty_and_writeable account ->
          with_label __LOC__
            (let%bind next_nonce =
               Account.Nonce.Checked.succ_if account.nonce is_user_command
             in
             let%bind () =
               with_label __LOC__
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
             (* TODO: use actual slot. See issue #4036. *)
             let txn_global_slot = Global_slot.Checked.zero in
             let%bind timing =
               let%bind txn_amount =
                 (* if not a payment, allow check_timing to pass, regardless of account balance *)
                 if_ is_payment ~typ:Amount.typ ~then_:payload.body.amount
                   ~else_:Amount.(var_of_t zero)
               in
               with_label __LOC__
                 (check_timing ~account ~txn_amount ~txn_global_slot)
             in
             let%bind delegate =
               let if_ = chain Public_key.Compressed.Checked.if_ in
               if_ is_empty_and_writeable ~then_:(return sender_compressed)
                 ~else_:
                   (if_ is_stake_delegation
                      ~then_:(return payload.body.public_key)
                      ~else_:(return account.delegate))
             in
             let%bind sender_amount =
               let%bind amount_for_new_acc =
                 let neg_account_creation_amount =
                   Amount.Signed.create ~magnitude:account_creation_amount_var
                     ~sgn:Sgn.Checked.neg
                 in
                 (*The sender delta could be zero here when a fee transfer is single and a coinbase has no fee transfer in which case sender = receiver. The account would exist after the previous merkle update. Therefore, modify the reciever before modifying the sender so that balance doesn't go below zero*)
                 Amount.Signed.Checked.add sender_delta
                   neg_account_creation_amount
               in
               let%bind () =
                 let is_negative_amt =
                   Sgn.Checked.is_neg amount_for_new_acc.sgn
                 in
                 let%bind enough_amount_for_new_account =
                   Boolean.(
                     if_ is_empty_and_writeable ~then_:(not is_negative_amt)
                       ~else_:true_)
                 in
                 Boolean.Assert.is_true enough_amount_for_new_account
               in
               Currency.Amount.Signed.Checked.if_ is_empty_and_writeable
                 ~then_:amount_for_new_acc ~else_:sender_delta
             in
             let%map balance =
               with_label __LOC__
                 (Balance.Checked.add_signed_amount account.balance
                    sender_amount)
             in
             { Account.Poly.balance
             ; public_key= sender_compressed
             ; nonce= next_nonce
             ; receipt_chain_hash
             ; delegate
             ; voting_for= account.voting_for
             ; timing }) )
    in
    (new_root, excess, supply_increase)

  (* Someday:
   write the following soundness tests:
   - apply a transaction where the signature is incorrect
   - apply a transaction where the sender does not have enough money in their account
   - apply a transaction and stuff in the wrong target hash
    *)

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
  let%snarkydef main (statement : Statement.With_sok.Checked.t) =
    let%bind (module Shifted) = Tick.Inner_curve.Checked.Shifted.create () in
    let%bind t =
      with_label __LOC__
        (exists Transaction_union.typ ~request:(As_prover.return Transaction))
    in
    let%bind state_body_hash_opt =
      exists Transaction_protocol_state.Block_data.typ
        ~request:(As_prover.return State_body)
    in
    let pc = statement.pending_coinbase_stack_state in
    let%bind root_after, fee_excess, supply_increase =
      apply_tagged_transaction
        (module Shifted)
        statement.source pc.source pc.target state_body_hash_opt t
    in
    Checked.all_unit
      [ Frozen_ledger_hash.assert_equal root_after statement.target
      ; Currency.Amount.Checked.assert_equal supply_increase
          statement.supply_increase
      ; Currency.Amount.Signed.Checked.assert_equal fee_excess
          statement.fee_excess ]

  let rule : _ Pickles.Inductive_rule.t =
    { prevs= []
    ; main=
        (fun [] x ->
          Run.run_checked (main x) ;
          [] )
    ; main_value= (fun [] _ -> []) }

  let transaction_union_handler handler (transaction : Transaction_union.t)
      (state_body_hash_opt : Transaction_protocol_state.Block_data.t) :
      Snarky.Request.request -> _ =
   fun (With {request; respond} as r) ->
    let k r = respond (Provide r) in
    match request with
    | Transaction ->
        k transaction
    | State_body ->
        k state_body_hash_opt
    | _ ->
        handler r
end

module Transition_data = struct
  type t =
    { proof: Proof_type.t
    ; supply_increase: Amount.t
    ; fee_excess: Amount.Signed.t
    ; sok_digest: Sok_message.Digest.t
    ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t }
  [@@deriving fields]
end

module Merge = struct
  open Tick

  (* spec for [main top_hash]:
     constraints pass iff
     there exist digest, s1, s3, fee_excess, supply_increase pending_coinbase_stack12.source, pending_coinbase_stack23.target, tock_vk such that
     H(digest,s1, s3, pending_coinbase_stack12.source, pending_coinbase_stack23.target, fee_excess, supply_increase, tock_vk) = top_hash,
     verify_transition tock_vk _ s1 s2 pending_coinbase_stack12.source, pending_coinbase_stack12.target is true
     verify_transition tock_vk _ s2 s3 pending_coinbase_stack23.source, pending_coinbase_stack23.target is true
  *)
  let%snarkydef main ([s1; s2] : _ Pickles_types.Hlist.HlistId.t)
      (s : Statement.With_sok.Checked.t) =
    let%bind fee_excess =
      Amount.Signed.Checked.add s1.Statement.fee_excess s2.Statement.fee_excess
    in
    let%bind supply_increase =
      Amount.Checked.add s1.supply_increase s2.supply_increase
    in
    Checked.all_unit
      [ Amount.Signed.Checked.assert_equal fee_excess s.fee_excess
      ; Amount.Checked.assert_equal supply_increase s.supply_increase
      ; Frozen_ledger_hash.assert_equal s.source s1.source
      ; Frozen_ledger_hash.assert_equal s1.target s2.source
      ; Frozen_ledger_hash.assert_equal s2.target s.target ]

  let rule self : _ Pickles.Inductive_rule.t =
    let prev_should_verify =
      match Coda_compile_config.proof_level with "full" -> true | _ -> false
    in
    let b = Boolean.var_of_value prev_should_verify in
    { prevs= [self; self]
    ; main=
        (fun ps x ->
          Run.run_checked (main ps x) ;
          [b; b] )
    ; main_value= (fun _ _ -> [prev_should_verify; prev_should_verify]) }
end

open Pickles_types

type tag =
  ( Statement.With_sok.Checked.t
  , Statement.With_sok.t
  , Nat.N2.n
  , Nat.N2.n )
  Pickles.Tag.t

let time lab f =
  let start = Time.now () in
  let x = f () in
  let stop = Time.now () in
  printf "%s: %s\n%!" lab (Time.Span.to_string_hum (Time.diff stop start)) ;
  x

let system () =
  time "Transaction_snark.system" (fun () ->
      Pickles.compile ~cache:Cache_dir.cache
        (module Statement.With_sok.Checked)
        (module Statement.With_sok)
        ~typ:Statement.With_sok.typ
        ~branches:(module Nat.N2)
        ~max_branching:(module Nat.N2)
        ~name:"transaction-snark"
        ~choices:(fun ~self -> [Base.rule; Merge.rule self]) )

module Verification = struct
  module type S = sig
    val tag : tag

    val id : Pickles.Verification_key.Id.t Lazy.t

    val verification_key : Pickles.Verification_key.t Lazy.t

    val verify : t -> message:Sok_message.t -> bool

    val verify_against_digest : t -> bool
  end
end

module type S = sig
  include Verification.S

  val of_transaction :
       sok_digest:Sok_message.Digest.t
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

let check_transaction_union ?(preeval = false) sok_message source target pc
    transaction state_body_hash_opt handler =
  let sok_digest = Sok_message.digest sok_message in
  let handler =
    Base.transaction_union_handler handler transaction state_body_hash_opt
  in
  if preeval then failwith "preeval currently disabled" ;
  let open Tick in
  Or_error.ok_exn
    (run_and_check
       (handle
          (Checked.map ~f:As_prover.return
             (let open Checked in
             exists Statement.With_sok.typ
               ~compute:
                 (As_prover.return
                    { Statement.source
                    ; target
                    ; supply_increase=
                        Transaction_union.supply_increase transaction
                    ; fee_excess= Transaction_union.excess transaction
                    ; sok_digest
                    ; pending_coinbase_stack_state= pc })
             >>= Base.main))
          handler)
       ())
  |> ignore

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
      {source= pending_coinbase_stack; target= pending_coinbase_stack}
    {t_in_block with transaction= User_command user_command}
    handler

let generate_transaction_union_witness ?(preeval = false) sok_message source
    target transaction_in_block pc handler =
  let transaction =
    Transaction_protocol_state.transaction transaction_in_block
  in
  let state_body_hash_opt =
    Transaction_protocol_state.block_data transaction_in_block
  in
  let sok_digest = Sok_message.digest sok_message in
  let handler =
    Base.transaction_union_handler handler transaction state_body_hash_opt
  in
  let open Tick in
  let input =
    { Statement.source
    ; target
    ; supply_increase= Transaction_union.supply_increase transaction
    ; fee_excess= Transaction_union.excess transaction
    ; sok_digest
    ; pending_coinbase_stack_state= pc }
  in
  if preeval then failwith "preeval currently disabled" ;
  let main x = handle (Base.main x) handler in
  generate_auxiliary_input [Statement.With_sok.typ] () main input

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

let verify ({statement; proof} : t) ~key ~message =
  Sok_message.Digest.equal (Sok_message.digest message) statement.sok_digest
  && Pickles.verify
       (module Nat.N2)
       (module Statement.With_sok)
       key [(statement, proof)]

module Make () = struct
  let tag, p, Pickles.Provers.[base; merge] = system ()

  module Proof = (val p)

  let id = Proof.id

  let verification_key = Proof.verification_key

  let verify_against_digest {statement; proof} =
    Proof.verify [(statement, proof)]

  let verify t ~message =
    Sok_message.Digest.equal
      (Sok_message.digest message)
      t.statement.sok_digest
    && verify_against_digest t

  let of_transaction_union sok_digest source target
      ~pending_coinbase_stack_state transaction state_body_hash_opt handler =
    let s =
      { Statement.source
      ; target
      ; sok_digest
      ; fee_excess= Transaction_union.excess transaction
      ; supply_increase= Transaction_union.supply_increase transaction
      ; pending_coinbase_stack_state }
    in
    { statement= s
    ; proof=
        base []
          ~handler:
            (Base.transaction_union_handler handler transaction
               state_body_hash_opt)
          s }

  let of_transaction ~sok_digest ~source ~target ~pending_coinbase_stack_state
      transaction_in_block handler =
    let transaction =
      Transaction_protocol_state.transaction transaction_in_block
    in
    let state_body_hash_opt =
      Transaction_protocol_state.block_data transaction_in_block
    in
    of_transaction_union sok_digest source target ~pending_coinbase_stack_state
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

  let merge ({statement= t12; _} as x12) ({statement= t23; _} as x23)
      ~sok_digest =
    let open Or_error.Let_syntax in
    let%map fee_excess =
      Amount.Signed.add t12.Statement.fee_excess t23.Statement.fee_excess
      |> Option.value_map ~f:Or_error.return
           ~default:
             (Or_error.errorf "Transaction_snark.merge: Amount overflow")
    and supply_increase =
      Amount.add t12.supply_increase t23.supply_increase
      |> Option.value_map ~f:Or_error.return
           ~default:
             (Or_error.errorf
                "Transaction_snark.merge: Supply change amount overflow")
    in
    let s =
      { Statement.source= t12.source
      ; target= t23.target
      ; supply_increase
      ; fee_excess
      ; pending_coinbase_stack_state=
          { source= t12.pending_coinbase_stack_state.source
          ; target= t23.pending_coinbase_stack_state.target }
      ; sok_digest }
    in
    { statement= s
    ; proof= merge [(x12.statement, x12.proof); (x23.statement, x23.proof)] s
    }
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
        { private_key
        ; account=
            Account.create
              (Public_key.compress (Public_key.of_private_key_exn private_key))
              (Balance.of_int ((50 + Random.int 100) * 1_000_000_000)) }
      in
      Array.init n ~f:(fun _ -> random_wallet ())

    let user_command sender receiver amt fee nonce memo =
      let payload : User_command.Payload.t =
        User_command.Payload.create ~fee ~nonce ~memo
          ~valid_until:Global_slot.max_value
          ~body:
            (Payment
               { receiver= receiver.account.public_key
               ; amount= Amount.of_int amt })
      in
      let signature = Schnorr.sign sender.private_key payload in
      User_command.check
        User_command.Poly.Stable.Latest.
          { payload
          ; sender= Public_key.of_private_key_exn sender.private_key
          ; signature }
      |> Option.value_exn

    let user_command_with_wallet wallets i j amt fee nonce memo =
      let sender = wallets.(i) in
      let receiver = wallets.(j) in
      user_command sender receiver amt fee nonce memo

    include Make ()

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
      let loc = Ledger.location_of_key ledger pk |> Option.value_exn in
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
      let receiver = mk_pubkey () in
      let other = mk_pubkey () in
      let pending_coinbase_init = Pending_coinbase.Stack.empty in
      let cb =
        Coinbase.create
          ~amount:(Currency.Amount.of_int 10_000_000_000)
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
          Ledger.create_new_account_exn ledger producer
            (Account.create producer Balance.zero) ;
          let sparse_ledger =
            Sparse_ledger.of_ledger_subset_exn ledger
              [producer; receiver; other]
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
                  Ledger.create_new_account_exn ledger account.public_key
                    account ) ;
              let t1 =
                user_command_with_wallet wallets 1 0 8_000_000_000
                  (Fee.of_int (Random.int 20 * 1_000_000_000))
                  Account.Nonce.zero
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
            ( One_or_two.map ft ~f:(fun (key, _) -> key) |> One_or_two.to_list
            , pending_coinbase_stack )
        | Coinbase ({receiver; fee_transfer; _} as cb) ->
            ( receiver
              :: Option.value_map ~default:[] fee_transfer ~f:(fun ft ->
                     [fst ft] )
            , Pending_coinbase.Stack.push_coinbase cb pending_coinbase_stack )
      in
      let sender =
        let txn_union = Transaction_union.of_transaction txn in
        txn_union.sender |> Public_key.compress
      in
      let sparse_ledger =
        Sparse_ledger.of_ledger_subset_exn ledger mentioned_keys
      in
      let _undo = Ledger.apply_transaction ledger txn in
      let target = Ledger.merkle_root ledger in
      let sok_message = Sok_message.create ~fee:Fee.zero ~prover:sender in
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
          let amount = 8_000_000_000 in
          let txn_fee = 2_000_000_000 in
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
                        nonce memo
                    in
                    (Account.Nonce.succ nonce, txns @ [uc]) )
              in
              Ledger.create_new_account_exn ledger sender.account.public_key
                sender.account ;
              let () =
                List.iter ucs ~f:(fun uc ->
                    test_transaction ledger (Transaction.User_command uc) )
              in
              List.iter receivers ~f:(fun receiver ->
                  check_balance receiver.account.public_key
                    ((amount * txns_per_receiver) - account_fee)
                    ledger ) ;
              check_balance sender.account.public_key
                ( Balance.to_int sender.account.balance
                - (amount + txn_fee) * txns_per_receiver
                  * List.length receivers )
                ledger ) )

    let%test_unit "account creation fee - fee transfers" =
      Test_util.with_randomness 123456789 (fun () ->
          let receivers = random_wallets ~n:3 () |> Array.to_list in
          let txns_per_receiver = 3 in
          let fee = 8_000_000_000 in
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
                  check_balance receiver.account.public_key
                    ((fee * txns_per_receiver) - account_fee)
                    ledger ) ) )

    let%test_unit "account creation fee - coinbase" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = random_wallets ~n:3 () in
          let receiver = wallets.(0) in
          let other = wallets.(1) in
          let dummy_account = wallets.(2) in
          let reward = 10_000_000_000 in
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
                dummy_account.account.public_key dummy_account.account ;
              let () =
                List.iter cbs ~f:(fun cb ->
                    let txn = Transaction.Coinbase cb in
                    test_transaction ledger txn )
              in
              let fees = fee * ft_count in
              check_balance receiver.account.public_key
                ((reward * coinbase_count) - account_fee - fees)
                ledger ;
              check_balance other.account.public_key (fees - account_fee)
                ledger ) )

    let%test "base_and_merge" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = random_wallets () in
          Ledger.with_ledger ~f:(fun ledger ->
              Array.iter wallets ~f:(fun {account; private_key= _} ->
                  Ledger.create_new_account_exn ledger account.public_key
                    account ) ;
              let state_body_hash_opt1 = Some state_body_hash in
              let state_body_hash_opt2 :
                  Transaction_protocol_state.Block_data.t =
                None
              in
              let t1 =
                user_command_with_wallet wallets 0 1 8
                  (Fee.of_int (Random.int 20 * 1_000_000_000))
                  Account.Nonce.zero
                  (User_command_memo.create_by_digesting_string_exn
                     (Test_util.arbitrary_string
                        ~len:User_command_memo.max_digestible_string_length))
              in
              let t2 =
                user_command_with_wallet wallets 1 2 3
                  (Fee.of_int (Random.int 20 * 1_000_000_000))
                  Account.Nonce.zero
                  (User_command_memo.create_by_digesting_string_exn
                     (Test_util.arbitrary_string
                        ~len:User_command_memo.max_digestible_string_length))
              in
              let sok_digest =
                Sok_message.create ~fee:Fee.zero
                  ~prover:wallets.(0).account.public_key
                |> Sok_message.digest
              in
              let sparse_ledger =
                Sparse_ledger.of_ledger_subset_exn ledger
                  (List.concat_map
                     ~f:(fun t ->
                       User_command.accounts_accessed (t :> User_command.t) )
                     [t1; t2])
              in
              let proof12, pending_coinbase_stack_next =
                time "proof12" (fun () ->
                    of_user_command' sok_digest ledger t1
                      Pending_coinbase.Stack.empty state_body_hash_opt1
                      (unstage @@ Sparse_ledger.handler sparse_ledger) )
              in
              assert (Proof.verify [(proof12.statement, proof12.proof)]) ;
              let sparse_ledger =
                Sparse_ledger.apply_user_command_exn sparse_ledger
                  (t1 :> User_command.t)
              in
              Ledger.apply_user_command ledger t1 |> Or_error.ok_exn |> ignore ;
              [%test_eq: Frozen_ledger_hash.t]
                (Ledger.merkle_root ledger)
                (Sparse_ledger.merkle_root sparse_ledger) ;
              let proof23, _pending_coinbase_stack_target =
                of_user_command' sok_digest ledger t2
                  pending_coinbase_stack_next state_body_hash_opt2
                  (unstage @@ Sparse_ledger.handler sparse_ledger)
              in
              let sparse_ledger =
                Sparse_ledger.apply_user_command_exn sparse_ledger
                  (t2 :> User_command.t)
              in
              Ledger.apply_user_command ledger t2 |> Or_error.ok_exn |> ignore ;
              [%test_eq: Frozen_ledger_hash.t]
                (Ledger.merkle_root ledger)
                (Sparse_ledger.merkle_root sparse_ledger) ;
              let proof13 =
                merge ~sok_digest proof12 proof23 |> Or_error.ok_exn
              in
              Proof.verify [(proof13.statement, proof13.proof)] ) )
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
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 80_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1_000_000_000_000 in
      let vesting_period = Global_slot.of_int 10_000_000_000 in
      let vesting_increment = Amount.of_int 1_000_000_000 in
      let txn_amount = Currency.Amount.of_int 100_000_000_000 in
      let txn_global_slot = Global_slot.of_int 45_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed pk balance ~initial_minimum_balance ~cliff_time
             ~vesting_period ~vesting_increment
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
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1_000_000_000_000 in
      let vesting_period = Global_slot.of_int 10_000_000_000 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed pk balance ~initial_minimum_balance ~cliff_time
             ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 100_000_000_000 in
      let txn_global_slot =
        Coda_numbers.Global_slot.of_int 1_900_000_000_000
      in
      let timing =
        validate_timing ~account
          ~txn_amount:(Currency.Amount.of_int 100_000_000_000)
          ~txn_global_slot:(Coda_numbers.Global_slot.of_int 1_900_000_000_000)
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
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1_000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed pk balance ~initial_minimum_balance ~cliff_time
             ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 100_000_000_000 in
      let txn_global_slot = Global_slot.of_int 2_000 in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      (* we're 2_000 - 1_000 = 1_000 slots past the cliff, which is 100 vesting periods
          subtract 100 * 100_000_000_000 = 10_000_000_000_000 from init min balance 
          of 10_000_000_000 to get zero, so we should be untimed now
        *)
      match timing with
      | Ok (Untimed as unchecked_timing) ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing
      | _ ->
          false

    let%test "below calculated min balance" =
      let pk = Public_key.Compressed.empty in
      let balance = Balance.of_int 10_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1_000_000_000_000 in
      let vesting_period = Global_slot.of_int 10_000_000_000 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed pk balance ~initial_minimum_balance ~cliff_time
             ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 101_000_000_000 in
      let txn_global_slot =
        Coda_numbers.Global_slot.of_int 1_010_000_000_000
      in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      match timing with
      | Error _ ->
          checked_timing_should_fail account txn_amount txn_global_slot
      | _ ->
          false

    let%test "insufficient balance" =
      let pk = Public_key.Compressed.empty in
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1000_000_000_000 in
      let vesting_period = Global_slot.of_int 10_000_000_000 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed pk balance ~initial_minimum_balance ~cliff_time
             ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 100_001_000_000_000 in
      let txn_global_slot = Global_slot.of_int 2000_000_000_000 in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      match timing with
      | Error _ ->
          checked_timing_should_fail account txn_amount txn_global_slot
      | _ ->
          false

    let%test "past full vesting" =
      let pk = Public_key.Compressed.empty in
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed pk balance ~initial_minimum_balance ~cliff_time
             ~vesting_period ~vesting_increment
      in
      (* fully vested, curr min balance = 0, so we can spend the whole balance *)
      let txn_amount = Currency.Amount.of_int 100_000_000_000_000 in
      let txn_global_slot = Global_slot.of_int 3000 in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      match timing with
      | Ok (Untimed as unchecked_timing) ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing
      | _ ->
          false
  end )

let constraint_system_digests () =
  let digest = Tick.R1CS_constraint_system.digest in
  [ ( "transaction-merge"
    , digest
        Merge.(
          Tick.constraint_system ~exposing:[Statement.With_sok.typ] (fun x ->
              let open Tick in
              let%bind x1 = exists Statement.With_sok.typ in
              let%bind x2 = exists Statement.With_sok.typ in
              main [x1; x2] x )) )
  ; ( "transaction-base"
    , digest
        Base.(Tick.constraint_system ~exposing:[Statement.With_sok.typ] main)
    ) ]
