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

    type 's t = 's Stable.Latest.t = {source: 's; target: 's}
    [@@deriving sexp, hash, compare, yojson]
  end

  module Init_stack = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Base of Pending_coinbase.Stack_versioned.Stable.V1.t | Merge
        [@@deriving sexp, hash, compare, eq, yojson]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t = Base of Pending_coinbase.Stack.t | Merge
    [@@deriving sexp, hash, compare, yojson]
  end

  (* State of the coinbase stack for the current transaction snark *)
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Pending_coinbase.Stack_versioned.Stable.V1.t Poly.Stable.V1.t
      [@@deriving sexp, hash, compare, eq, yojson]

      let to_latest = Fn.id
    end
  end]

  type 's t_ = 's Poly.Stable.Latest.t = {source: 's; target: 's}
  [@@deriving sexp, hash, compare, eq, fields, yojson]

  type t = Pending_coinbase.Stack_versioned.Stable.Latest.t t_
  [@@deriving sexp, hash, compare, yojson]

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

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)
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
        [@@deriving version, bin_io, compare, equal, hash, sexp, yojson]
      end
    end]
  end

  type ('lh, 'amt, 'pc, 'signed_amt, 'sok) t_ =
        ('lh, 'amt, 'pc, 'signed_amt, 'sok) Poly.Stable.Latest.t =
    { source: 'lh
    ; target: 'lh
    ; supply_increase: 'amt
    ; pending_coinbase_stack_state:
        'pc Pending_coinbase_stack_state.Poly.Stable.Latest.t
    ; fee_excess: 'signed_amt
    ; sok_digest: 'sok }

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Frozen_ledger_hash.Stable.V1.t
        , Currency.Amount.Stable.V1.t
        , Pending_coinbase.Stack_versioned.Stable.V1.t
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
          , Pending_coinbase.Stack_versioned.Stable.V1.t
          , ( Currency.Amount.Stable.V1.t
            , Sgn.Stable.V1.t )
            Currency.Signed_poly.Stable.V1.t
          , Sok_message.Digest.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving version, bin_io, compare, equal, hash, sexp, yojson]

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

  let gen =
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
  module T = Pickles.Proof.Make (Nat.N2) (Nat.N2)

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = T.t
      [@@deriving version {asserted}, yojson, bin_io, compare, sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving yojson, compare, sexp]
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

  include struct
    open Snarky.Request

    type _ t +=
      | Transaction : Transaction_union.t t
      | State_body : Coda_state.Protocol_state.Body.Value.t t
      | Init_stack : Pending_coinbase.Stack.t t
  end

  module User_command_failure = struct
    (** The various ways that a user command may fail. These should be computed
        before applying the snark, to ensure that only the base fee is charged
        to the fee-payer if executing the user command will later fail.
    *)
    type 'bool t =
      { predicate_failed: 'bool (* All *)
      ; source_not_present: 'bool (* All *)
      ; receiver_not_present: 'bool (* Delegate only *)
      ; amount_insufficient_to_create: 'bool
            (* Payment only, token=fee_token *)
      ; fee_payer_balance_insufficient_to_create: 'bool
            (* Payment only, token<>fee_token *)
      ; fee_payer_bad_timing_for_create: 'bool
            (* Payment only, token<>fee_token *)
      ; source_insufficient_balance: 'bool (* Payment only *)
      ; source_bad_timing: 'bool (* Payment only *) }

    let num_fields = 8

    let to_list
        { predicate_failed
        ; source_not_present
        ; receiver_not_present
        ; amount_insufficient_to_create
        ; fee_payer_balance_insufficient_to_create
        ; fee_payer_bad_timing_for_create
        ; source_insufficient_balance
        ; source_bad_timing } =
      [ predicate_failed
      ; source_not_present
      ; receiver_not_present
      ; amount_insufficient_to_create
      ; fee_payer_balance_insufficient_to_create
      ; fee_payer_bad_timing_for_create
      ; source_insufficient_balance
      ; source_bad_timing ]

    let of_list = function
      | [ predicate_failed
        ; source_not_present
        ; receiver_not_present
        ; amount_insufficient_to_create
        ; fee_payer_balance_insufficient_to_create
        ; fee_payer_bad_timing_for_create
        ; source_insufficient_balance
        ; source_bad_timing ] ->
          { predicate_failed
          ; source_not_present
          ; receiver_not_present
          ; amount_insufficient_to_create
          ; fee_payer_balance_insufficient_to_create
          ; fee_payer_bad_timing_for_create
          ; source_insufficient_balance
          ; source_bad_timing }
      | _ ->
          failwith
            "Transaction_snark.Base.User_command_failure.to_list: bad length"

    let typ : (Boolean.var t, bool t) Typ.t =
      let open Typ in
      list ~length:num_fields Boolean.typ
      |> transport ~there:to_list ~back:of_list
      |> transport_var ~there:to_list ~back:of_list

    let any t = Boolean.any (to_list t)

    (** Compute which -- if any -- of the failure cases will be hit when
        evaluating the given user command, and indicate whether the fee-payer
        would need to pay the account creation fee if the user command were to
        succeed (irrespective or whether it actually will or not).
    *)
    let compute_unchecked
        ~(constraint_constants : Genesis_constants.Constraint_constants.t)
        ~txn_global_slot ~(fee_payer_account : Account.t)
        ~(receiver_account : Account.t) ~(source_account : Account.t)
        ({payload; signature= _; signer= _} : Transaction_union.t) =
      match payload.body.tag with
      | Fee_transfer | Coinbase ->
          (* Not user commands, return no failure. *)
          ( `Should_pay_to_create false
          , of_list (List.init num_fields ~f:(fun _ -> false)) )
      | _ -> (
          let fail s =
            failwithf
              "Transaction_snark.Base.User_command_failure.compute_unchecked: \
               %s"
              s ()
          in
          let fee_token = payload.common.fee_token in
          let token = payload.body.token_id in
          let fee_payer =
            Account_id.create payload.common.fee_payer_pk fee_token
          in
          let source = Account_id.create payload.body.source_pk token in
          let receiver = Account_id.create payload.body.receiver_pk token in
          (* This should shadow the logic in [Sparse_ledger]. *)
          let fee_payer_account =
            { fee_payer_account with
              balance=
                Option.value_exn ?here:None ?error:None ?message:None
                @@ Balance.sub_amount fee_payer_account.balance
                     (Amount.of_fee payload.common.fee) }
          in
          let predicate_failed =
            (* TODO: Predicates. *)
            not
              (Public_key.Compressed.equal payload.common.fee_payer_pk
                 payload.body.source_pk)
          in
          match payload.body.tag with
          | Fee_transfer | Coinbase ->
              assert false
          | Stake_delegation ->
              let receiver_account =
                if Account_id.equal receiver fee_payer then fee_payer_account
                else receiver_account
              in
              let receiver_not_present =
                let id = Account.identifier receiver_account in
                if Account_id.equal Account_id.empty id then true
                else if Account_id.equal receiver id then false
                else fail "bad receiver account ID"
              in
              let source_account =
                if Account_id.equal source fee_payer then fee_payer_account
                else source_account
              in
              let source_not_present =
                let id = Account.identifier source_account in
                if Account_id.equal Account_id.empty id then true
                else if Account_id.equal source id then false
                else fail "bad source account ID"
              in
              ( `Should_pay_to_create false
              , { predicate_failed
                ; source_not_present
                ; receiver_not_present
                ; amount_insufficient_to_create= false
                ; fee_payer_balance_insufficient_to_create= false
                ; fee_payer_bad_timing_for_create= false
                ; source_insufficient_balance= false
                ; source_bad_timing= false } )
          | Payment ->
              let receiver_account =
                if Account_id.equal receiver fee_payer then fee_payer_account
                else receiver_account
              in
              let receiver_needs_creating =
                let id = Account.identifier receiver_account in
                if Account_id.equal Account_id.empty id then true
                else if Account_id.equal receiver id then false
                else fail "bad receiver account ID"
              in
              let fee_token_is_token = Token_id.equal fee_token token in
              let amount_insufficient_to_create, creation_fee =
                let creation_amount =
                  Amount.of_fee constraint_constants.account_creation_fee
                in
                if receiver_needs_creating then
                  if fee_token_is_token then
                    ( Option.is_none
                        (Amount.sub payload.body.amount creation_amount)
                    , Amount.zero )
                  else (false, creation_amount)
                else (false, Amount.zero)
              in
              let fee_payer_balance_insufficient_to_create =
                Amount.(
                  Balance.to_amount fee_payer_account.balance < creation_fee)
              in
              let fee_payer_bad_timing_for_create =
                fee_payer_balance_insufficient_to_create
                || Or_error.is_error
                     (Transaction_logic.validate_timing
                        ~txn_amount:creation_fee ~txn_global_slot
                        ~account:fee_payer_account)
              in
              let source_account =
                if Account_id.equal source fee_payer then fee_payer_account
                else source_account
              in
              let source_not_present =
                let id = Account.identifier source_account in
                if Account_id.equal Account_id.empty id then true
                else if Account_id.equal source id then false
                else fail "bad source account ID"
              in
              let fee_payer_is_source = Account_id.equal fee_payer source in
              let source_insufficient_balance =
                (not fee_payer_is_source)
                &&
                if Account_id.equal source receiver then
                  (* The final balance will be [0 - account_creation_fee]. *)
                  receiver_needs_creating && fee_token_is_token
                else
                  Amount.(
                    Balance.to_amount source_account.balance
                    < payload.body.amount)
              in
              let source_bad_timing =
                source_insufficient_balance
                || (not fee_payer_is_source)
                   &&
                   if Account_id.equal source receiver then
                     (* The final balance will be [0 - account_creation_fee]. *)
                     receiver_needs_creating && fee_token_is_token
                   else
                     Or_error.is_error
                       (Transaction_logic.validate_timing
                          ~txn_amount:payload.body.amount ~txn_global_slot
                          ~account:source_account)
              in
              ( `Should_pay_to_create
                  (receiver_needs_creating && not fee_token_is_token)
              , { predicate_failed
                ; source_not_present
                ; receiver_not_present= false
                ; amount_insufficient_to_create
                ; fee_payer_balance_insufficient_to_create
                ; fee_payer_bad_timing_for_create
                ; source_insufficient_balance
                ; source_bad_timing } ) )

    let%snarkydef compute_as_prover ~constraint_constants ~txn_global_slot
        (txn : Transaction_union.var) =
      let%bind data =
        exists (Typ.Internal.ref ())
          ~compute:
            As_prover.(
              let%map txn = read Transaction_union.typ txn in
              let fee_token = txn.payload.common.fee_token in
              let token = txn.payload.body.token_id in
              let fee_payer =
                Account_id.create txn.payload.common.fee_payer_pk fee_token
              in
              let source =
                Account_id.create txn.payload.body.source_pk token
              in
              let receiver =
                Account_id.create txn.payload.body.receiver_pk token
              in
              (txn, fee_payer, source, receiver))
      in
      let%bind fee_payer_idx =
        exists (Typ.Internal.ref ())
          ~request:
            As_prover.(
              let%map _txn, fee_payer, _source, _receiver =
                read (Typ.Internal.ref ()) data
              in
              Ledger_hash.Find_index fee_payer)
      in
      let%bind fee_payer_account =
        exists (Typ.Internal.ref ())
          ~request:
            As_prover.(
              let%map fee_payer_idx =
                read (Typ.Internal.ref ()) fee_payer_idx
              in
              Ledger_hash.Get_element fee_payer_idx)
      in
      let%bind source_idx =
        exists (Typ.Internal.ref ())
          ~request:
            As_prover.(
              let%map _txn, _fee_payer, source, _receiver =
                read (Typ.Internal.ref ()) data
              in
              Ledger_hash.Find_index source)
      in
      let%bind source_account =
        exists (Typ.Internal.ref ())
          ~request:
            As_prover.(
              let%map source_idx = read (Typ.Internal.ref ()) source_idx in
              Ledger_hash.Get_element source_idx)
      in
      let%bind receiver_idx =
        exists (Typ.Internal.ref ())
          ~request:
            As_prover.(
              let%map _txn, _fee_payer, _source, receiver =
                read (Typ.Internal.ref ()) data
              in
              Ledger_hash.Find_index receiver)
      in
      let%bind receiver_account =
        exists (Typ.Internal.ref ())
          ~request:
            As_prover.(
              let%map receiver_idx = read (Typ.Internal.ref ()) receiver_idx in
              Ledger_hash.Get_element receiver_idx)
      in
      let%map should_pay_to_create, t =
        exists
          (Typ.( * ) Boolean.typ typ)
          ~compute:
            As_prover.(
              let%bind txn, _fee_payer, _source, _receiver =
                read (Typ.Internal.ref ()) data
              in
              let%bind fee_payer_account, _path =
                read (Typ.Internal.ref ()) fee_payer_account
              in
              let%bind source_account, _path =
                read (Typ.Internal.ref ()) source_account
              in
              let%bind receiver_account, _path =
                read (Typ.Internal.ref ()) receiver_account
              in
              let%map txn_global_slot = read Global_slot.typ txn_global_slot in
              let `Should_pay_to_create should_pay_to_create, t =
                compute_unchecked ~constraint_constants ~txn_global_slot
                  ~fee_payer_account ~source_account ~receiver_account txn
              in
              (should_pay_to_create, t))
      in
      (`Should_pay_to_create should_pay_to_create, t)
  end

  let%snarkydef check_signature shifted ~payload ~is_user_command ~signer
      ~signature =
    let%bind input = Transaction_union_payload.Checked.to_input payload in
    let%bind verifies =
      Schnorr.Checked.verifies shifted signature signer input
    in
    Boolean.Assert.any [Boolean.not is_user_command; verifies]

  let check_timing ~balance_check ~timed_balance_check ~account ~txn_amount
      ~txn_global_slot =
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
    let%bind () = balance_check (Boolean.not underflow) in
    let%bind sufficient_timed_balance =
      make_checked (fun () ->
          Snarky_integer.Integer.(gte ~m proposed_balance_int curr_min_balance)
      )
    in
    let%bind () =
      let%bind ok = Boolean.(any [not is_timed; sufficient_timed_balance]) in
      timed_balance_check ok
    in
    let%bind is_timed_balance_zero =
      make_checked (fun () ->
          Snarky_integer.Integer.equal ~m curr_min_balance zero_int )
    in
    (* if current min balance is zero, then timing becomes untimed *)
    let%bind is_untimed = Boolean.((not is_timed) || is_timed_balance_zero) in
    let%map timing =
      Account.Timing.if_ is_untimed ~then_:Account.Timing.untimed_var
        ~else_:account.timing
    in
    (`Min_balance curr_min_balance, timing)

  let chain if_ b ~then_ ~else_ =
    let%bind then_ = then_ and else_ = else_ in
    if_ b ~then_ ~else_

  let%snarkydef apply_tagged_transaction
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      (type shifted)
      (shifted : (module Inner_curve.Checked.Shifted.S with type t = shifted))
      root pending_coinbase_stack_init pending_coinbase_stack_before
      pending_coinbase_after state_body
      ({signer; signature; payload} as txn : Transaction_union.var) =
    let tag = payload.body.tag in
    let is_user_command = Transaction_union.Tag.Unpacked.is_user_command tag in
    let%bind () =
      [%with_label "Check transaction signature"]
        (check_signature shifted ~payload ~is_user_command ~signer ~signature)
    in
    let%bind signer_pk = Public_key.compress_var signer in
    let%bind () =
      [%with_label "Fee-payer must sign the transaction"]
        ((* TODO: Enable multi-sig. *)
         Public_key.Compressed.Checked.Assert.equal signer_pk
           payload.common.fee_payer_pk)
    in
    let fee = payload.common.fee in
    let token = payload.body.token_id in
    let receiver = Account_id.Checked.create payload.body.receiver_pk token in
    let source = Account_id.Checked.create payload.body.source_pk token in
    (* Information for the fee-payer. *)
    let nonce = payload.common.nonce in
    let fee_token = payload.common.fee_token in
    let fee_payer =
      Account_id.Checked.create payload.common.fee_payer_pk fee_token
    in
    (* Compute transaction kind. *)
    let is_payment = Transaction_union.Tag.Unpacked.is_payment tag in
    let is_fee_transfer = Transaction_union.Tag.Unpacked.is_fee_transfer tag in
    let is_stake_delegation =
      Transaction_union.Tag.Unpacked.is_stake_delegation tag
    in
    let is_coinbase = Transaction_union.Tag.Unpacked.is_coinbase tag in
    let%bind tokens_equal = Token_id.Checked.equal token fee_token in
    let%bind token_default =
      Token_id.(Checked.equal token (var_of_t default))
    in
    let%bind () =
      [%with_label "Validate tokens"]
        (let%bind () =
           (* TODO: Remove this check and update the transaction snark once we
              have an exchange rate mechanism. See issue #4447.
           *)
           [%with_label "Validate fee token"]
             (Token_id.Checked.Assert.equal fee_token
                Token_id.(var_of_t default))
         in
         [%with_label "Validate delegated token is default"]
           Boolean.(Assert.any [token_default; not is_stake_delegation]))
    in
    let current_global_slot =
      Coda_state.Protocol_state.Body.consensus_state state_body
      |> Consensus.Data.Consensus_state.curr_global_slot_var
    in
    let%bind () =
      [%with_label "Check slot validity"]
        ( Global_slot.Checked.(
            current_global_slot <= payload.common.valid_until)
        >>= Boolean.Assert.is_true )
    in
    (* Check coinbase stack. Protocol state body is pushed into the Pending coinbase stack once per block. For example, consider any two transactions in a block. Their pending coinbase stacks would be:
      transaction1: s1 -> t1 = s1+ protocol_state_body + maybe_coinbase
      transaction2: t1 -> t1 + maybe_another_coinbase (Note: protocol_state_body is not pushed again)

    However, for each transaction, we need to constrain the protoccol state body. The way this is done is by having the stack (init_stack) without the current protocol state body, pushing the state body to it in every transaction snark and checking if it matches the target. We also need to constrain the source for the merges to work correctly. Basically,
      init_stack + protocol_state_body + maybe_coinbase = target
      AND
      init_stack = source || init_stack + protocol_state_body = source *)

    (* These are all the possible cases:

       Init_stack     Source                 Target 
      --------------------------------------------------------------
        i               i                       i + state
        i               i                       i + state + coinbase
        i               i + state               i + state
        i               i + state               i + state + coinbase
        i + coinbase    i + state + coinbase    i + state + coinbase
    *)
    let%bind () =
      [%with_label "Compute coinbase stack"]
        (let%bind state_body_hash =
           Coda_state.Protocol_state.Body.hash_checked state_body
         in
         let%bind pending_coinbase_stack_with_state =
           Pending_coinbase.Stack.Checked.push_state state_body_hash
             pending_coinbase_stack_init
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
           (let%bind correct_coinbase_target_stack =
              Pending_coinbase.Stack.equal_var
                computed_pending_coinbase_stack_after pending_coinbase_after
            in
            let%bind valid_init_state =
              let%bind equal_source =
                Pending_coinbase.Stack.equal_var pending_coinbase_stack_init
                  pending_coinbase_stack_before
              in
              let%bind equal_source_with_state =
                Pending_coinbase.Stack.equal_var
                  pending_coinbase_stack_with_state
                  pending_coinbase_stack_before
              in
              Boolean.(equal_source || equal_source_with_state)
            in
            Boolean.Assert.all [correct_coinbase_target_stack; valid_init_state]))
    in
    (* Interrogate failure cases. This value is created without constraints;
       the failures should be checked against potential failures to ensure
       consistency.
    *)
    let%bind `Should_pay_to_create should_pay_to_create, user_command_failure =
      User_command_failure.compute_as_prover ~constraint_constants
        ~txn_global_slot:current_global_slot txn
    in
    let%bind () =
      (* The fee-payer should only be charged for creation if this is a user
         command.
      *)
      Boolean.(Assert.any [is_user_command; not should_pay_to_create])
    in
    let%bind user_command_fails =
      User_command_failure.any user_command_failure
    in
    let%bind () =
      [%with_label "A failing user command is a user command"]
        Boolean.(Assert.any [is_user_command; not user_command_fails])
    in
    let%bind () =
      [%with_label "Check success failure against predicted"]
        (* TODO: Predicates. *)
        (let%bind bypass_predicate =
           Public_key.Compressed.Checked.equal payload.common.fee_payer_pk
             payload.body.source_pk
         in
         Boolean.Assert.( = ) user_command_failure.predicate_failed
           (Boolean.not bypass_predicate))
    in
    let account_creation_amount =
      Amount.Checked.of_fee
        Fee.(var_of_t constraint_constants.account_creation_fee)
    in
    let%bind root_after_fee_payer_update =
      [%with_label "Update fee payer"]
        (Frozen_ledger_hash.modify_account_send
           ~depth:constraint_constants.ledger_depth root
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
             let%bind should_pay_for_receiver =
               Boolean.(should_pay_to_create && not user_command_fails)
             in
             let%bind is_empty_and_writeable =
               (* If this is a coinbase with zero fee, do not create the
                  account, since the fee amount won't be enough to pay for it.
               *)
               let%bind is_zero_fee =
                 fee |> Fee.var_to_number |> Number.to_var
                 |> Field.(Checked.equal (Var.constant zero))
               in
               Boolean.(is_empty_and_writeable && not is_zero_fee)
             in
             let%bind amount =
               [%with_label "Compute fee payer amount"]
                 (let fee_payer_amount =
                    let sgn = Sgn.Checked.neg_if_true is_user_command in
                    Amount.Signed.create
                      ~magnitude:(Amount.Checked.of_fee fee)
                      ~sgn
                  in
                  let%bind account_creation_fee =
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
             let txn_global_slot = current_global_slot in
             let%bind `Min_balance min_balance, timing =
               [%with_label "Check fee payer timing"]
                 (let%bind txn_amount =
                    Amount.Checked.if_
                      (Sgn.Checked.is_neg amount.sgn)
                      ~then_:amount.magnitude
                      ~else_:Amount.(var_of_t zero)
                  in
                  let balance_check ok =
                    [%with_label "Check fee payer balance"]
                      (Boolean.Assert.is_true ok)
                  in
                  let timed_balance_check ok =
                    [%with_label "Check fee payer timed balance"]
                      (Boolean.Assert.is_true ok)
                  in
                  check_timing ~balance_check ~timed_balance_check ~account
                    ~txn_amount ~txn_global_slot)
             in
             let%bind balance =
               [%with_label "Check payer balance"]
                 (Balance.Checked.add_signed_amount account.balance amount)
             in
             let%bind () =
               [%with_label "Validate fee_payer failures"]
                 (let failed_pay_for_receiver =
                    (* should_pay_to_create && user_command_fails *)
                    Boolean.Unsafe.of_cvar
                      Field.Var.(
                        sub
                          (should_pay_to_create :> t)
                          (should_pay_for_receiver :> t))
                  in
                  let account_creation_fee =
                    constraint_constants.account_creation_fee |> Fee.to_bits
                    |> Bignum_bigint.of_bits_lsb
                    |> Snarky_integer.Integer.constant ~m
                  in
                  let%bind account_creation_fee =
                    make_checked (fun () ->
                        Snarky_integer.Integer.if_ ~m failed_pay_for_receiver
                          ~then_:account_creation_fee
                          ~else_:
                            (Snarky_integer.Integer.constant ~m
                               Bignum_bigint.zero) )
                  in
                  let balance =
                    Snarky_integer.Integer.of_bits ~m
                    @@ Balance.var_to_bits balance
                  in
                  let%bind `Underflow underflow, new_balance =
                    make_checked (fun () ->
                        Snarky_integer.Integer.subtract_unpacking_or_zero ~m
                          balance account_creation_fee )
                  in
                  let%bind () =
                    [%with_label "balance failure matches predicted"]
                      (Boolean.Assert.( = ) underflow
                         user_command_failure
                           .fee_payer_balance_insufficient_to_create)
                  in
                  let%bind bad_timing_for_create =
                    let%bind lt_min_balance =
                      make_checked (fun () ->
                          Snarky_integer.Integer.lt ~m new_balance min_balance
                      )
                    in
                    Boolean.(underflow || lt_min_balance)
                  in
                  [%with_label "Timing failure matches predicted"]
                    (Boolean.Assert.( = ) bad_timing_for_create
                       user_command_failure.fee_payer_bad_timing_for_create))
             in
             let%map public_key =
               Public_key.Compressed.Checked.if_ is_empty_and_writeable
                 ~then_:(Account_id.Checked.public_key fee_payer)
                 ~else_:account.public_key
             and token_id =
               Token_id.Checked.if_ is_empty_and_writeable
                 ~then_:(Account_id.Checked.token_id fee_payer)
                 ~else_:account.token_id
             and delegate =
               Public_key.Compressed.Checked.if_ is_empty_and_writeable
                 ~then_:(Account_id.Checked.public_key fee_payer)
                 ~else_:account.delegate
             in
             { Account.Poly.balance
             ; public_key
             ; token_id
             ; token_owner= account.token_owner
             ; nonce= next_nonce
             ; receipt_chain_hash
             ; delegate
             ; voting_for= account.voting_for
             ; timing } ))
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
         (* The fee for entering the coinbase transaction is paid up front. *)
         let%bind coinbase_receiver_fee =
           Amount.Checked.if_ is_coinbase
             ~then_:(Amount.Checked.of_fee fee)
             ~else_:(Amount.var_of_t Amount.zero)
         in
         Amount.Checked.sub base_amount coinbase_receiver_fee)
    in
    let%bind root_after_receiver_update =
      [%with_label "Update receiver"]
        (Frozen_ledger_hash.modify_account_recv
           ~depth:constraint_constants.ledger_depth root_after_fee_payer_update
           receiver ~f:(fun ~is_empty_and_writeable account ->
             (* this account is:
               - the receiver for payments
               - the delegated-to account for stake delegation
               - the receiver for a coinbase
               - the first receiver for a fee transfer
             *)
             let%bind is_empty_delegatee =
               Boolean.(is_empty_and_writeable && is_stake_delegation)
             in
             let%bind () =
               [%with_label "Receiver existence failure matches predicted"]
                 (Boolean.Assert.( = ) is_empty_delegatee
                    user_command_failure.receiver_not_present)
             in
             let is_empty_and_writeable =
               (* is_empty_and_writable && not is_stake_delegation *)
               Boolean.Unsafe.of_cvar
               @@ Field.Var.(
                    sub (is_empty_and_writeable :> t) (is_empty_delegatee :> t))
             in
             let%bind () =
               [%with_label "Validate should_pay_for_receiver"]
                 ( Boolean.(is_empty_and_writeable && not tokens_equal)
                 >>= Boolean.Assert.( = ) should_pay_to_create )
             in
             let%bind balance =
               (* [receiver_increase] will be zero in the stake delegation
                  case.
               *)
               let%bind receiver_amount =
                 let%bind should_pay_creation_fee =
                   Boolean.(is_empty_and_writeable && not should_pay_to_create)
                 in
                 let%bind account_creation_amount =
                   Amount.Checked.if_ should_pay_creation_fee
                     ~then_:account_creation_amount
                     ~else_:Amount.(var_of_t zero)
                 in
                 let%bind amount_for_new_account, `Underflow underflow =
                   Amount.Checked.sub_flagged receiver_increase
                     account_creation_amount
                 in
                 let%bind () =
                   [%with_label
                     "Receiver creation fee failure matches predicted"]
                     (Boolean.Assert.( = ) underflow
                        user_command_failure.amount_insufficient_to_create)
                 in
                 Currency.Amount.Checked.if_ user_command_fails
                   ~then_:Amount.(var_of_t zero)
                   ~else_:amount_for_new_account
               in
               (* TODO: Is this a sanity check, or can overflow here actually
                  happen? If it is possible, we should add a case for it to
                  [User_command_failure.t] and check it here.
                *)
               Balance.Checked.(account.balance + receiver_amount)
             in
             let%bind is_empty_and_writeable =
               (* Do not create a new account if the user command will fail. *)
               Boolean.(is_empty_and_writeable && not user_command_fails)
             in
             let%bind may_delegate =
               (* Only default tokens may participate in delegation. *)
               Boolean.(is_empty_and_writeable && token_default)
             in
             let%map delegate =
               Public_key.Compressed.Checked.if_ may_delegate
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
             ; token_owner= account.token_owner
             ; nonce= account.nonce
             ; receipt_chain_hash= account.receipt_chain_hash
             ; delegate
             ; voting_for= account.voting_for
             ; timing= account.timing } ))
    in
    let%bind fee_payer_is_source = Account_id.Checked.equal fee_payer source in
    let%bind root_after_source_update =
      [%with_label "Update source"]
        (Frozen_ledger_hash.modify_account_send
           ~depth:constraint_constants.ledger_depth
           ~is_writeable:
             (* [modify_account_send] does this failure check for us. *)
             user_command_failure.source_not_present root_after_receiver_update
           source ~f:(fun ~is_empty_and_writeable:_ account ->
             (* this account is:
               - the source for payments
               - the delegator for stake delegation
               - the fee-receiver for a coinbase
               - the second receiver for a fee transfer
             *)
             let%bind () =
               [%with_label
                 "Check source failure cases do not apply when fee-payer is \
                  source"]
                 (let num_failures =
                    let open Field.Var in
                    add
                      (user_command_failure.source_insufficient_balance :> t)
                      (user_command_failure.source_bad_timing :> t)
                  in
                  let not_fee_payer_is_source =
                    (Boolean.not fee_payer_is_source :> Field.Var.t)
                  in
                  (* Equivalent to:
                    if fee_payer_is_source then
                      num_failures = 0
                    else
                      num_failures = num_failures
                 *)
                  assert_r1cs not_fee_payer_is_source num_failures num_failures)
             in
             let%bind amount =
               (* Only payments should affect the balance at this stage. *)
               if_ is_payment ~typ:Amount.typ ~then_:payload.body.amount
                 ~else_:Amount.(var_of_t zero)
             in
             let txn_global_slot = current_global_slot in
             let%bind `Min_balance _, timing =
               [%with_label "Check source timing"]
                 (let balance_check ok =
                    [%with_label
                      "Check source balance failure matches predicted"]
                      (Boolean.Assert.( = ) ok
                         (Boolean.not
                            user_command_failure.source_insufficient_balance))
                  in
                  let timed_balance_check ok =
                    [%with_label
                      "Check source timed balance failure matches predicted"]
                      (let%bind ok =
                         Boolean.(
                           ok
                           && not
                                user_command_failure
                                  .source_insufficient_balance)
                       in
                       Boolean.Assert.( = ) ok
                         (Boolean.not user_command_failure.source_bad_timing))
                  in
                  check_timing ~balance_check ~timed_balance_check ~account
                    ~txn_amount:amount ~txn_global_slot)
             in
             let%bind balance, `Underflow underflow =
               Balance.Checked.sub_amount_flagged account.balance amount
             in
             let%bind () =
               (* TODO: Remove the redundancy in balance calculation between
                  here and [check_timing].
               *)
               [%with_label "Check source balance failure matches predicted"]
                 (Boolean.Assert.( = ) underflow
                    user_command_failure.source_insufficient_balance)
             in
             let%map delegate =
               Public_key.Compressed.Checked.if_ is_stake_delegation
                 ~then_:(Account_id.Checked.public_key receiver)
                 ~else_:account.delegate
             in
             (* NOTE: Technically we update the account here even in the case
                of [user_command_fails], but we throw the resulting hash away
                in [final_root] below, so it shouldn't matter.
             *)
             { Account.Poly.balance
             ; public_key= account.public_key
             ; token_id= account.token_id
             ; token_owner= account.token_owner
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
    let%bind supply_increase =
      Amount.Checked.if_ is_coinbase ~then_:payload.body.amount
        ~else_:Amount.(var_of_t zero)
    in
    let%map final_root =
      (* Ensure that only the fee-payer was charged if this was an invalid user
         command.
      *)
      Frozen_ledger_hash.if_ user_command_fails
        ~then_:root_after_fee_payer_update ~else_:root_after_source_update
    in
    (final_root, fee_excess, supply_increase)

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
  let%snarkydef main ~constraint_constants
      (statement : Statement.With_sok.Checked.t) =
    let%bind (module Shifted) = Tick.Inner_curve.Checked.Shifted.create () in
    let%bind t =
      with_label __LOC__
        (exists Transaction_union.typ ~request:(As_prover.return Transaction))
    in
    let%bind pending_coinbase_init =
      exists Pending_coinbase.Stack.typ ~request:(As_prover.return Init_stack)
    in
    let%bind state_body =
      exists
        (Coda_state.Protocol_state.Body.typ ~constraint_constants)
        ~request:(As_prover.return State_body)
    in
    let pc = statement.pending_coinbase_stack_state in
    let%bind root_after, fee_excess, supply_increase =
      apply_tagged_transaction ~constraint_constants
        (module Shifted)
        statement.source pending_coinbase_init pc.source pc.target state_body t
      (* 
        root_before pending_coinbase_init pending_coinbase_before
        pending_coinbase_after state_body te*)
    in
    Checked.all_unit
      [ Frozen_ledger_hash.assert_equal root_after statement.target
      ; Currency.Amount.Checked.assert_equal supply_increase
          statement.supply_increase
      ; Currency.Amount.Signed.Checked.assert_equal fee_excess
          statement.fee_excess ]

  let rule ~constraint_constants : _ Pickles.Inductive_rule.t =
    { prevs= []
    ; main=
        (fun [] x ->
          Run.run_checked (main ~constraint_constants x) ;
          [] )
    ; main_value= (fun [] _ -> []) }

  let transaction_union_handler handler (transaction : Transaction_union.t)
      (state_body : Coda_state.Protocol_state.Body.Value.t)
      (init_stack : Pending_coinbase.Stack.t) : Snarky.Request.request -> _ =
   fun (With {request; respond} as r) ->
    let k r = respond (Provide r) in
    match request with
    | Transaction ->
        k transaction
    | State_body ->
        k state_body
    | Init_stack ->
        k init_stack
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
    let%bind () =
      with_label __LOC__
        (let%bind valid_pending_coinbase_stack_transition =
           Pending_coinbase.Stack.Checked.check_merge
             ~transition1:
               ( s1.pending_coinbase_stack_state.source
               , s1.pending_coinbase_stack_state.target )
             ~transition2:
               ( s2.pending_coinbase_stack_state.source
               , s2.pending_coinbase_stack_state.target )
         in
         Boolean.Assert.is_true valid_pending_coinbase_stack_transition)
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
      match Genesis_constants.Proof_level.compiled with
      | Full ->
          true
      | _ ->
          false
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

let system ~constraint_constants =
  time "Transaction_snark.system" (fun () ->
      Pickles.compile ~cache:Cache_dir.cache
        (module Statement.With_sok.Checked)
        (module Statement.With_sok)
        ~typ:Statement.With_sok.typ
        ~branches:(module Nat.N2)
        ~max_branching:(module Nat.N2)
        ~name:"transaction-snark"
        ~choices:(fun ~self ->
          [Base.rule ~constraint_constants; Merge.rule self] ) )

module Verification = struct
  module type S = sig
    val tag : tag

    val verify : (t * Sok_message.t) list -> bool

    val id : Pickles.Verification_key.Id.t Lazy.t

    val verification_key : Pickles.Verification_key.t Lazy.t

    val verify_against_digest : t -> bool
  end
end

module type S = sig
  include Verification.S

  val cache_handle : Pickles.Cache_handle.t

  val of_transaction :
       sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> init_stack:Pending_coinbase.Stack.t
    -> Transaction.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val of_user_command :
       sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> init_stack:Pending_coinbase.Stack.t
    -> User_command.With_valid_signature.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val of_fee_transfer :
       sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> init_stack:Pending_coinbase.Stack.t
    -> Fee_transfer.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val merge : t -> t -> sok_digest:Sok_message.Digest.t -> t Or_error.t
end

let check_transaction_union ?(preeval = false) ~constraint_constants
    sok_message source target pc transaction state_body init_stack handler =
  let sok_digest = Sok_message.digest sok_message in
  let handler =
    Base.transaction_union_handler handler transaction state_body init_stack
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
             >>= Base.main ~constraint_constants))
          handler)
       ())
  |> ignore

let check_transaction ?preeval ~constraint_constants ~sok_message ~source
    ~target ~pending_coinbase_stack_state ~init_stack
    (transaction_in_block : Transaction.t Transaction_protocol_state.t) handler
    =
  let transaction =
    Transaction_protocol_state.transaction transaction_in_block
  in
  let state_body =
    Transaction_protocol_state.block_data transaction_in_block
  in
  check_transaction_union ?preeval ~constraint_constants sok_message source
    target pending_coinbase_stack_state
    (Transaction_union.of_transaction transaction)
    state_body init_stack handler

let check_user_command ~constraint_constants ~sok_message ~source ~target
    pending_coinbase_stack_state ~init_stack t_in_block handler =
  let user_command = Transaction_protocol_state.transaction t_in_block in
  check_transaction ~constraint_constants ~sok_message ~source ~target
    ~pending_coinbase_stack_state ~init_stack
    {t_in_block with transaction= User_command user_command}
    handler

let generate_transaction_union_witness ?(preeval = false) ~constraint_constants
    sok_message source target transaction_in_block pc init_stack handler =
  let transaction =
    Transaction_protocol_state.transaction transaction_in_block
  in
  let state_body =
    Transaction_protocol_state.block_data transaction_in_block
  in
  let sok_digest = Sok_message.digest sok_message in
  let handler =
    Base.transaction_union_handler handler transaction state_body init_stack
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
  let main x = handle (Base.main ~constraint_constants x) handler in
  generate_auxiliary_input [Statement.With_sok.typ] () main input

let generate_transaction_witness ?preeval ~constraint_constants ~sok_message
    ~source ~target ~init_stack pending_coinbase_stack_state
    (transaction_in_block : Transaction.t Transaction_protocol_state.t) handler
    =
  let transaction =
    Transaction_protocol_state.transaction transaction_in_block
  in
  generate_transaction_union_witness ?preeval ~constraint_constants sok_message
    source target
    { transaction_in_block with
      transaction= Transaction_union.of_transaction transaction }
    pending_coinbase_stack_state init_stack handler

let verify (ts : (t * _) list) ~key =
  List.for_all ts ~f:(fun ({statement; _}, message) ->
      Sok_message.Digest.equal
        (Sok_message.digest message)
        statement.sok_digest )
  && Pickles.verify
       (module Nat.N2)
       (module Statement.With_sok)
       key
       (List.map ts ~f:(fun ({statement; proof}, _) -> (statement, proof)))

module Make () = struct
  let tag, cache_handle, p, Pickles.Provers.[base; merge] =
    system
      ~constraint_constants:Genesis_constants.Constraint_constants.compiled

  module Proof = (val p)

  let id = Proof.id

  let verification_key = Proof.verification_key

  let verify_against_digest {statement; proof} =
    Proof.verify [(statement, proof)]

  let verify ts =
    List.for_all ts ~f:(fun (p, m) ->
        Sok_message.Digest.equal (Sok_message.digest m) p.statement.sok_digest
    )
    && Proof.verify
         (List.map ts ~f:(fun ({statement; proof}, _) -> (statement, proof)))

  let of_transaction_union sok_digest source target
      ~pending_coinbase_stack_state transaction state_body ~init_stack handler
      =
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
            (Base.transaction_union_handler handler transaction state_body
               init_stack)
          s }

  let of_transaction ~sok_digest ~source ~target ~pending_coinbase_stack_state
      ~init_stack transaction_in_block handler =
    let transaction =
      Transaction_protocol_state.transaction transaction_in_block
    in
    let state_body =
      Transaction_protocol_state.block_data transaction_in_block
    in
    of_transaction_union sok_digest source target ~pending_coinbase_stack_state
      ~init_stack
      (Transaction_union.of_transaction transaction)
      state_body handler

  let of_user_command ~sok_digest ~source ~target ~pending_coinbase_stack_state
      ~init_stack user_command_in_block handler =
    of_transaction ~sok_digest ~source ~target ~pending_coinbase_stack_state
      ~init_stack
      { user_command_in_block with
        transaction=
          User_command
            (Transaction_protocol_state.transaction user_command_in_block) }
      handler

  let of_fee_transfer ~sok_digest ~source ~target ~pending_coinbase_stack_state
      ~init_stack transfer_in_block handler =
    of_transaction ~sok_digest ~source ~target ~pending_coinbase_stack_state
      ~init_stack
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
    let constraint_constants =
      Genesis_constants.Constraint_constants.for_unit_tests

    let genesis_constants = Genesis_constants.for_unit_tests

    let consensus_constants =
      Consensus.Constants.create ~constraint_constants
        ~protocol_constants:genesis_constants.protocol

    (* For tests let's just monkey patch ledger and sparse ledger to freeze their
     * ledger_hashes. The nominal type is just so we don't mix this up in our
     * real code. *)
    module Ledger = struct
      include Ledger

      let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t

      let merkle_root_after_user_command_exn t ~txn_global_slot txn =
        Frozen_ledger_hash.of_ledger_hash
        @@ merkle_root_after_user_command_exn ~constraint_constants
             ~txn_global_slot t txn
    end

    module Sparse_ledger = struct
      include Sparse_ledger

      let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t
    end

    type wallet = {private_key: Private_key.t; account: Account.t}

    let ledger_depth = constraint_constants.ledger_depth

    let random_wallets ?(n = min (Int.pow 2 ledger_depth) (1 lsl 10)) () =
      let random_wallet () : wallet =
        let private_key = Private_key.create () in
        let public_key =
          Public_key.compress (Public_key.of_private_key_exn private_key)
        in
        let account_id = Account_id.create public_key Token_id.default in
        { private_key
        ; account=
            Account.create account_id
              (Balance.of_int ((50 + Random.int 100) * 1_000_000_000)) }
      in
      Array.init n ~f:(fun _ -> random_wallet ())

    let user_command ~fee_payer ~source_pk ~receiver_pk ~fee_token ~token amt
        fee nonce memo =
      let payload : User_command.Payload.t =
        User_command.Payload.create ~fee ~fee_token
          ~fee_payer_pk:(Account.public_key fee_payer.account)
          ~nonce ~memo ~valid_until:Global_slot.max_value
          ~body:
            (Payment
               { source_pk
               ; receiver_pk
               ; token_id= token
               ; amount= Amount.of_int amt })
      in
      let signature =
        User_command.sign_payload fee_payer.private_key payload
      in
      User_command.check
        User_command.Poly.Stable.Latest.
          { payload
          ; signer= Public_key.of_private_key_exn fee_payer.private_key
          ; signature }
      |> Option.value_exn

    let user_command_with_wallet wallets ~sender:i ~receiver:j amt fee
        ~fee_token ~token nonce memo =
      let fee_payer = wallets.(i) in
      let receiver = wallets.(j) in
      user_command ~fee_payer
        ~source_pk:(Account.public_key fee_payer.account)
        ~receiver_pk:(Account.public_key receiver.account)
        ~fee_token ~token amt fee nonce memo

    include Make ()

    let state_body =
      let compile_time_genesis =
        (*not using Precomputed_values.for_unit_test because of dependency cycle*)
        Coda_state.Genesis_protocol_state.t
          ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
          ~constraint_constants ~consensus_constants
      in
      compile_time_genesis.data |> Coda_state.Protocol_state.body

    let state_body_hash = Coda_state.Protocol_state.Body.hash state_body

    let pending_coinbase_stack_target (t : Transaction.t) state_body_hash stack
        =
      let stack_with_state =
        Pending_coinbase.Stack.(push_state state_body_hash stack)
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

    let of_user_command' sok_digest ledger user_command
        pending_coinbase_stack_state state_body init_stack handler =
      let source = Ledger.merkle_root ledger in
      let current_global_slot =
        Coda_state.Protocol_state.Body.consensus_state state_body
        |> Consensus.Data.Consensus_state.curr_slot
      in
      let target =
        Ledger.merkle_root_after_user_command_exn ledger
          ~txn_global_slot:current_global_slot user_command
      in
      let user_command_in_block =
        { Transaction_protocol_state.Poly.transaction= user_command
        ; block_data= state_body }
      in
      of_user_command ~sok_digest ~source ~target ~init_stack
        ~pending_coinbase_stack_state user_command_in_block handler

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

    let coinbase_test state_body ~carryforward =
      let mk_pubkey () =
        Public_key.(compress (of_private_key_exn (Private_key.create ())))
      in
      let state_body_hash = Coda_state.Protocol_state.Body.hash state_body in
      let producer = mk_pubkey () in
      let producer_id = Account_id.create producer Token_id.default in
      let receiver = mk_pubkey () in
      let receiver_id = Account_id.create receiver Token_id.default in
      let other = mk_pubkey () in
      let other_id = Account_id.create other Token_id.default in
      let pending_coinbase_init = Pending_coinbase.Stack.empty in
      let cb =
        Coinbase.create
          ~amount:(Currency.Amount.of_int 10_000_000_000)
          ~receiver
          ~fee_transfer:
            (Some
               (Coinbase.Fee_transfer.create ~receiver_pk:other
                  ~fee:constraint_constants.account_creation_fee))
        |> Or_error.ok_exn
      in
      let transaction = Transaction.Coinbase cb in
      let source_stack =
        if carryforward then
          Pending_coinbase.Stack.(
            push_state state_body_hash pending_coinbase_init)
        else pending_coinbase_init
      in
      let pending_coinbase_stack_target =
        pending_coinbase_stack_target transaction state_body_hash
          pending_coinbase_init
      in
      let txn_in_block =
        {Transaction_protocol_state.Poly.transaction; block_data= state_body}
      in
      Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
          Ledger.create_new_account_exn ledger producer_id
            (Account.create receiver_id Balance.zero) ;
          let sparse_ledger =
            Sparse_ledger.of_ledger_subset_exn ledger
              [producer_id; receiver_id; other_id]
          in
          check_transaction txn_in_block
            (unstage (Sparse_ledger.handler sparse_ledger))
            ~constraint_constants
            ~sok_message:
              (Coda_base.Sok_message.create ~fee:Currency.Fee.zero
                 ~prover:Public_key.Compressed.empty)
            ~source:(Sparse_ledger.merkle_root sparse_ledger)
            ~target:
              Sparse_ledger.(
                merkle_root
                  (apply_transaction_exn ~constraint_constants sparse_ledger
                     txn_in_block.transaction))
            ~init_stack:pending_coinbase_init
            ~pending_coinbase_stack_state:
              {source= source_stack; target= pending_coinbase_stack_target} )

    let%test_unit "coinbase with new state body hash" =
      Test_util.with_randomness 123456789 (fun () ->
          coinbase_test state_body ~carryforward:false )

    let%test_unit "coinbase with carry-forward state body hash" =
      Test_util.with_randomness 123456789 (fun () ->
          coinbase_test state_body ~carryforward:true )

    let%test_unit "new_account" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = random_wallets () in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              Array.iter
                (Array.sub wallets ~pos:1 ~len:(Array.length wallets - 1))
                ~f:(fun {account; private_key= _} ->
                  Ledger.create_new_account_exn ledger
                    (Account.identifier account)
                    account ) ;
              let t1 =
                user_command_with_wallet wallets ~sender:1 ~receiver:0
                  8_000_000_000
                  (Fee.of_int (Random.int 20 * 1_000_000_000))
                  ~fee_token:Token_id.default ~token:Token_id.default
                  Account.Nonce.zero
                  (User_command_memo.create_by_digesting_string_exn
                     (Test_util.arbitrary_string
                        ~len:User_command_memo.max_digestible_string_length))
              in
              let current_global_slot =
                Coda_state.Protocol_state.Body.consensus_state state_body
                |> Consensus.Data.Consensus_state.curr_slot
              in
              let target =
                Ledger.merkle_root_after_user_command_exn ledger
                  ~txn_global_slot:current_global_slot t1
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
              let pending_coinbase_stack_target =
                pending_coinbase_stack_target (User_command t1) state_body_hash
                  pending_coinbase_stack
              in
              let pending_coinbase_stack_state =
                { Pending_coinbase_stack_state.source= pending_coinbase_stack
                ; target= pending_coinbase_stack_target }
              in
              check_user_command ~constraint_constants ~sok_message
                ~init_stack:pending_coinbase_stack
                ~source:(Ledger.merkle_root ledger)
                ~target pending_coinbase_stack_state
                {transaction= t1; block_data= state_body}
                (unstage @@ Sparse_ledger.handler sparse_ledger) ) )

    let account_fee = Fee.to_int constraint_constants.account_creation_fee

    let test_transaction ~constraint_constants ?txn_global_slot ledger txn =
      let source = Ledger.merkle_root ledger in
      let pending_coinbase_stack = Pending_coinbase.Stack.empty in
      let state_body, state_body_hash, txn_global_slot =
        match txn_global_slot with
        | None ->
            let txn_global_slot =
              state_body |> Coda_state.Protocol_state.Body.consensus_state
              |> Consensus.Data.Consensus_state.curr_slot
            in
            (state_body, state_body_hash, txn_global_slot)
        | Some txn_global_slot ->
            let state_body =
              let state =
                (* NB: The [previous_state_hash] is a dummy, do not use. *)
                Coda_state.Protocol_state.create
                  ~previous_state_hash:Tick0.Field.zero ~body:state_body
              in
              let consensus_state_at_slot =
                Consensus.Data.Consensus_state.Value.For_tests
                .with_curr_global_slot
                  (Coda_state.Protocol_state.consensus_state state)
                  txn_global_slot
              in
              Coda_state.Protocol_state.(
                create_value
                  ~previous_state_hash:(previous_state_hash state)
                  ~genesis_state_hash:(genesis_state_hash state)
                  ~blockchain_state:(blockchain_state state)
                  ~consensus_state:consensus_state_at_slot
                  ~constants:
                    (Protocol_constants_checked.value_of_t
                       Genesis_constants.compiled.protocol))
                .body
            in
            let state_body_hash =
              Coda_state.Protocol_state.Body.hash state_body
            in
            (state_body, state_body_hash, txn_global_slot)
      in
      let mentioned_keys, pending_coinbase_stack_target =
        let pending_coinbase_stack =
          Pending_coinbase.Stack.push_state state_body_hash
            pending_coinbase_stack
        in
        match txn with
        | Transaction.User_command uc ->
            ( User_command.accounts_accessed (uc :> User_command.t)
            , pending_coinbase_stack )
        | Fee_transfer ft ->
            ( One_or_two.map ft ~f:(fun (key, _) ->
                  Account_id.create key Token_id.default )
              |> One_or_two.to_list
            , pending_coinbase_stack )
        | Coinbase cb ->
            ( Coinbase.accounts_accessed cb
            , Pending_coinbase.Stack.push_coinbase cb pending_coinbase_stack )
      in
      let signer =
        let txn_union = Transaction_union.of_transaction txn in
        txn_union.signer |> Public_key.compress
      in
      let sparse_ledger =
        Sparse_ledger.of_ledger_subset_exn ledger mentioned_keys
      in
      let _undo =
        Or_error.ok_exn
        @@ Ledger.apply_transaction ledger ~constraint_constants
             ~txn_global_slot txn
      in
      let target = Ledger.merkle_root ledger in
      let sok_message = Sok_message.create ~fee:Fee.zero ~prover:signer in
      check_transaction ~constraint_constants ~sok_message ~source ~target
        ~init_stack:pending_coinbase_stack
        ~pending_coinbase_stack_state:
          { Pending_coinbase_stack_state.source= pending_coinbase_stack
          ; target= pending_coinbase_stack_target }
        {transaction= txn; block_data= state_body}
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
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let _, ucs =
                let receivers =
                  List.fold ~init:receivers
                    (List.init (txns_per_receiver - 1) ~f:Fn.id)
                    ~f:(fun acc _ -> receivers @ acc)
                in
                List.fold receivers ~init:(Account.Nonce.zero, [])
                  ~f:(fun (nonce, txns) receiver ->
                    let uc =
                      user_command ~fee_payer:sender
                        ~source_pk:(Account.public_key sender.account)
                        ~receiver_pk:(Account.public_key receiver.account)
                        ~fee_token:Token_id.default ~token:Token_id.default
                        amount (Fee.of_int txn_fee) nonce memo
                    in
                    (Account.Nonce.succ nonce, txns @ [uc]) )
              in
              Ledger.create_new_account_exn ledger
                (Account.identifier sender.account)
                sender.account ;
              let () =
                List.iter ucs ~f:(fun uc ->
                    test_transaction ~constraint_constants ledger
                      (Transaction.User_command uc) )
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
          let fee = 8_000_000_000 in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
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
                    test_transaction ~constraint_constants ledger txn )
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
          let reward = 10_000_000_000 in
          let fee = Fee.to_int constraint_constants.account_creation_fee in
          let coinbase_count = 3 in
          let ft_count = 2 in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let _, cbs =
                let fts =
                  List.map (List.init ft_count ~f:Fn.id) ~f:(fun _ ->
                      Coinbase.Fee_transfer.create
                        ~receiver_pk:other.account.public_key
                        ~fee:constraint_constants.account_creation_fee )
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
                    test_transaction ~constraint_constants ledger txn )
              in
              let fees = fee * ft_count in
              check_balance
                (Account.identifier receiver.account)
                ((reward * coinbase_count) - account_fee - fees)
                ledger ;
              check_balance
                (Account.identifier other.account)
                (fees - account_fee) ledger ) )

    module Pc_with_init_stack = struct
      type t =
        { pc: Pending_coinbase_stack_state.t
        ; init_stack: Pending_coinbase.Stack.t }
    end

    let test_base_and_merge ~state_hash_and_body1 ~state_hash_and_body2
        ~carryforward1 ~carryforward2 =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = random_wallets () in
          (*let state_body = Lazy.force state_body in
      let state_body_hash = Lazy.force state_body_hash in*)
          let state_body_hash1, state_body1 = state_hash_and_body1 in
          let state_body_hash2, state_body2 = state_hash_and_body2 in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              Array.iter wallets ~f:(fun {account; private_key= _} ->
                  Ledger.create_new_account_exn ledger
                    (Account.identifier account)
                    account ) ;
              let memo =
                User_command_memo.create_by_digesting_string_exn
                  (Test_util.arbitrary_string
                     ~len:User_command_memo.max_digestible_string_length)
              in
              let t1 =
                user_command_with_wallet wallets ~sender:0 ~receiver:1
                  8_000_000_000
                  (Fee.of_int (Random.int 20 * 1_000_000_000))
                  ~fee_token:Token_id.default ~token:Token_id.default
                  Account.Nonce.zero memo
              in
              let t2 =
                user_command_with_wallet wallets ~sender:1 ~receiver:2
                  8_000_000_000
                  (Fee.of_int (Random.int 20 * 1_000_000_000))
                  ~fee_token:Token_id.default ~token:Token_id.default
                  Account.Nonce.zero memo
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
              let pending_coinbase_stack_state1 =
                (*No coinbase to add to the stack*)
                let stack_with_state =
                  Pending_coinbase.Stack.(
                    push_state state_body_hash1 Pending_coinbase.Stack.empty)
                in
                (*Since protocol state body is added once per block, the source would already have the state if carryforward=true from the previous transaction in the sequence of transactions in a block. We add state to init_stack and then check if it is equal to the target*)
                let source_stack, target_stack =
                  if carryforward1 then (stack_with_state, stack_with_state)
                  else (Pending_coinbase.Stack.empty, stack_with_state)
                in
                { Pc_with_init_stack.pc=
                    {source= source_stack; target= target_stack}
                ; init_stack= Pending_coinbase.Stack.empty }
              in
              let proof12 =
                of_user_command' sok_digest ledger t1
                  pending_coinbase_stack_state1.pc state_body1
                  pending_coinbase_stack_state1.init_stack
                  (unstage @@ Sparse_ledger.handler sparse_ledger)
              in
              assert (Proof.verify [(proof12.statement, proof12.proof)]) ;
              let sparse_ledger =
                Sparse_ledger.apply_user_command_exn ~constraint_constants
                  sparse_ledger
                  (t1 :> User_command.t)
              in
              let current_global_slot =
                Coda_state.Protocol_state.Body.consensus_state state_body1
                |> Consensus.Data.Consensus_state.curr_slot
              in
              let pending_coinbase_stack_state2, state_body2 =
                let previous_stack = pending_coinbase_stack_state1.pc.target in
                let stack_with_state2 =
                  Pending_coinbase.Stack.(
                    push_state state_body_hash2 previous_stack)
                in
                (*No coinbase to add*)
                let source_stack, target_stack, init_stack, state_body2 =
                  if carryforward2 then
                    (*Source and target already have the protocol state, init_stack will be such that init_stack + state_body_hash1 = target = source *)
                    ( previous_stack
                    , previous_stack
                    , pending_coinbase_stack_state1.init_stack
                    , state_body1 )
                  else
                    (*Add the new state such that previous_stack + state_body_hash2 = init_stack + state_body_hash2 = target*)
                    ( previous_stack
                    , stack_with_state2
                    , previous_stack
                    , state_body2 )
                in
                ( { Pc_with_init_stack.pc=
                      {source= source_stack; target= target_stack}
                  ; init_stack }
                , state_body2 )
              in
              Ledger.apply_user_command ~constraint_constants ledger
                ~txn_global_slot:current_global_slot t1
              |> Or_error.ok_exn |> ignore ;
              [%test_eq: Frozen_ledger_hash.t]
                (Ledger.merkle_root ledger)
                (Sparse_ledger.merkle_root sparse_ledger) ;
              let proof23 =
                of_user_command' sok_digest ledger t2
                  pending_coinbase_stack_state2.pc state_body2
                  pending_coinbase_stack_state2.init_stack
                  (unstage @@ Sparse_ledger.handler sparse_ledger)
              in
              let sparse_ledger =
                Sparse_ledger.apply_user_command_exn ~constraint_constants
                  sparse_ledger
                  (t2 :> User_command.t)
              in
              let current_global_slot =
                Coda_state.Protocol_state.Body.consensus_state state_body2
                |> Consensus.Data.Consensus_state.curr_slot
              in
              Ledger.apply_user_command ledger ~constraint_constants
                ~txn_global_slot:current_global_slot t2
              |> Or_error.ok_exn |> ignore ;
              [%test_eq: Frozen_ledger_hash.t]
                (Ledger.merkle_root ledger)
                (Sparse_ledger.merkle_root sparse_ledger) ;
              let proof13 =
                merge ~sok_digest proof12 proof23 |> Or_error.ok_exn
              in
              Proof.verify [(proof13.statement, proof13.proof)] ) )

    let%test "base_and_merge: transactions in one block (t1,t2 in b1), \
              carryforward the state from a previous transaction t0 in b1" =
      let state_hash_and_body1 = (state_body_hash, state_body) in
      test_base_and_merge ~state_hash_and_body1
        ~state_hash_and_body2:state_hash_and_body1 ~carryforward1:true
        ~carryforward2:true

    (* No new state body, carryforward the stack from the previous transaction*)

    let%test "base_and_merge: transactions in one block (t1,t2 in b1), don't \
              carryforward the state from a previous transaction t0 in b1" =
      let state_hash_and_body1 = (state_body_hash, state_body) in
      test_base_and_merge ~state_hash_and_body1
        ~state_hash_and_body2:state_hash_and_body1 ~carryforward1:false
        ~carryforward2:true

    let%test "base_and_merge: transactions in two different blocks (t1,t2 in \
              b1, b2 resp.), carryforward the state from a previous \
              transaction t0 in b1" =
      let state_hash_and_body1 =
        let state_body0 =
          Coda_state.Protocol_state.negative_one
            ~genesis_ledger:Test_genesis_ledger.t ~constraint_constants
            ~consensus_constants
          |> Coda_state.Protocol_state.body
        in
        let state_body_hash0 =
          Coda_state.Protocol_state.Body.hash state_body0
        in
        (state_body_hash0, state_body0)
      in
      let state_hash_and_body2 = (state_body_hash, state_body) in
      test_base_and_merge ~state_hash_and_body1 ~state_hash_and_body2
        ~carryforward1:true ~carryforward2:false

    (*t2 is in a new state, therefore do not carryforward the previous state*)

    let%test "base_and_merge: transactions in two different blocks (t1,t2 in \
              b1, b2 resp.), don't carryforward the state from a previous \
              transaction t0 in b1" =
      let state_hash_and_body1 =
        let state_body0 =
          Coda_state.Protocol_state.negative_one
            ~genesis_ledger:Test_genesis_ledger.t ~constraint_constants
            ~consensus_constants
          |> Coda_state.Protocol_state.body
        in
        let state_body_hash0 =
          Coda_state.Protocol_state.Body.hash state_body0
        in
        (state_body_hash0, state_body0)
      in
      let state_hash_and_body2 = (state_body_hash, state_body) in
      test_base_and_merge ~state_hash_and_body1 ~state_hash_and_body2
        ~carryforward1:false ~carryforward2:false

    let test_user_command_with_accounts ~constraint_constants ~ledger ~accounts
        ~signer ~fee ~fee_payer_pk ~fee_token ?memo ~valid_until ~nonce body =
      let memo =
        match memo with
        | Some memo ->
            memo
        | None ->
            User_command_memo.create_by_digesting_string_exn
              (Test_util.arbitrary_string
                 ~len:User_command_memo.max_digestible_string_length)
      in
      Array.iter accounts ~f:(fun account ->
          Ledger.create_new_account_exn ledger
            (Account.identifier account)
            account ) ;
      let payload =
        User_command.Payload.create ~fee ~fee_payer_pk ~fee_token ~nonce
          ~valid_until ~memo ~body
      in
      let user_command = User_command.sign signer payload in
      test_transaction ~constraint_constants ledger (User_command user_command)

    let random_int_incl l u = Quickcheck.random_value (Int.gen_incl l u)

    let%test_unit "transfer non-default tokens to a new account" =
      Test_util.with_randomness 123456789 (fun () ->
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let wallets = random_wallets ~n:2 () in
              let signer =
                Keypair.of_private_key_exn wallets.(0).private_key
              in
              let fee_payer_pk = Public_key.compress signer.public_key in
              let source_pk = fee_payer_pk in
              let receiver_pk = wallets.(1).account.public_key in
              let fee_token = Token_id.default in
              let token_id =
                Quickcheck.random_value Token_id.gen_non_default
              in
              let fee_payer = Account_id.create fee_payer_pk fee_token in
              let source = Account_id.create source_pk token_id in
              let receiver = Account_id.create receiver_pk token_id in
              let create_account aid balance =
                Account.create aid (Balance.of_int balance)
              in
              let accounts =
                [| create_account fee_payer 20_000_000_000
                 ; create_account source 30_000_000_000 |]
              in
              let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
              let amount =
                Amount.of_int (random_int_incl 0 30 * 1_000_000_000)
              in
              let valid_until = Global_slot.max_value in
              let nonce = accounts.(0).nonce in
              let () =
                test_user_command_with_accounts ~constraint_constants ~ledger
                  ~accounts ~signer ~fee ~fee_payer_pk ~fee_token ~valid_until
                  ~nonce
                  (Payment {source_pk; receiver_pk; token_id; amount})
              in
              let get_account aid =
                Option.bind
                  (Ledger.location_of_account ledger aid)
                  ~f:(Ledger.get ledger)
              in
              let fee_payer_account =
                Option.value_exn (get_account fee_payer)
              in
              let source_account = Option.value_exn (get_account source) in
              let receiver_account = Option.value_exn (get_account receiver) in
              let sub_amount amt bal =
                Option.value_exn (Balance.sub_amount bal amt)
              in
              let add_amount amt bal =
                Option.value_exn (Balance.add_amount bal amt)
              in
              let sub_fee fee = sub_amount (Amount.of_fee fee) in
              let expected_fee_payer_balance =
                accounts.(0).balance |> sub_fee fee
                |> sub_fee constraint_constants.account_creation_fee
              in
              assert (
                Balance.equal fee_payer_account.balance
                  expected_fee_payer_balance ) ;
              let expected_source_balance =
                accounts.(1).balance |> sub_amount amount
              in
              assert (
                Balance.equal source_account.balance expected_source_balance ) ;
              let expected_receiver_balance =
                Balance.zero |> add_amount amount
              in
              assert (
                Balance.equal receiver_account.balance
                  expected_receiver_balance ) ) )

    let%test_unit "transfer non-default tokens to an existing account" =
      Test_util.with_randomness 123456789 (fun () ->
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let wallets = random_wallets ~n:2 () in
              let signer =
                Keypair.of_private_key_exn wallets.(0).private_key
              in
              let fee_payer_pk = Public_key.compress signer.public_key in
              let source_pk = fee_payer_pk in
              let receiver_pk = wallets.(1).account.public_key in
              let fee_token = Token_id.default in
              let token_id =
                Quickcheck.random_value Token_id.gen_non_default
              in
              let fee_payer = Account_id.create fee_payer_pk fee_token in
              let source = Account_id.create source_pk token_id in
              let receiver = Account_id.create receiver_pk token_id in
              let create_account aid balance =
                Account.create aid (Balance.of_int balance)
              in
              let accounts =
                [| create_account fee_payer 20_000_000_000
                 ; create_account source 30_000_000_000
                 ; create_account receiver 0 |]
              in
              let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
              let amount =
                Amount.of_int (random_int_incl 0 30 * 1_000_000_000)
              in
              let valid_until = Global_slot.max_value in
              let nonce = accounts.(0).nonce in
              let () =
                test_user_command_with_accounts ~constraint_constants ~ledger
                  ~accounts ~signer ~fee ~fee_payer_pk ~fee_token ~valid_until
                  ~nonce
                  (Payment {source_pk; receiver_pk; token_id; amount})
              in
              let get_account aid =
                Option.bind
                  (Ledger.location_of_account ledger aid)
                  ~f:(Ledger.get ledger)
              in
              let fee_payer_account =
                Option.value_exn (get_account fee_payer)
              in
              let source_account = Option.value_exn (get_account source) in
              let receiver_account = Option.value_exn (get_account receiver) in
              let sub_amount amt bal =
                Option.value_exn (Balance.sub_amount bal amt)
              in
              let add_amount amt bal =
                Option.value_exn (Balance.add_amount bal amt)
              in
              let sub_fee fee = sub_amount (Amount.of_fee fee) in
              let expected_fee_payer_balance =
                accounts.(0).balance |> sub_fee fee
              in
              assert (
                Balance.equal fee_payer_account.balance
                  expected_fee_payer_balance ) ;
              let expected_source_balance =
                accounts.(1).balance |> sub_amount amount
              in
              assert (
                Balance.equal source_account.balance expected_source_balance ) ;
              let expected_receiver_balance =
                accounts.(2).balance |> add_amount amount
              in
              assert (
                Balance.equal receiver_account.balance
                  expected_receiver_balance ) ) )

    let%test_unit "insufficient account creation fee for non-default token \
                   transfer" =
      Test_util.with_randomness 123456789 (fun () ->
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let wallets = random_wallets ~n:2 () in
              let signer =
                Keypair.of_private_key_exn wallets.(0).private_key
              in
              let fee_payer_pk = Public_key.compress signer.public_key in
              let source_pk = fee_payer_pk in
              let receiver_pk = wallets.(1).account.public_key in
              let fee_token = Token_id.default in
              let token_id =
                Quickcheck.random_value Token_id.gen_non_default
              in
              let fee_payer = Account_id.create fee_payer_pk fee_token in
              let source = Account_id.create source_pk token_id in
              let receiver = Account_id.create receiver_pk token_id in
              let create_account aid balance =
                Account.create aid (Balance.of_int balance)
              in
              let accounts =
                [| create_account fee_payer 20_000_000_000
                 ; create_account source 30_000_000_000 |]
              in
              let fee = Fee.of_int 20_000_000_000 in
              let amount =
                Amount.of_int (random_int_incl 0 30 * 1_000_000_000)
              in
              let valid_until = Global_slot.max_value in
              let nonce = accounts.(0).nonce in
              let () =
                test_user_command_with_accounts ~constraint_constants ~ledger
                  ~accounts ~signer ~fee ~fee_payer_pk ~fee_token ~valid_until
                  ~nonce
                  (Payment {source_pk; receiver_pk; token_id; amount})
              in
              let get_account aid =
                Option.bind
                  (Ledger.location_of_account ledger aid)
                  ~f:(Ledger.get ledger)
              in
              let fee_payer_account =
                Option.value_exn (get_account fee_payer)
              in
              let source_account = Option.value_exn (get_account source) in
              let receiver_account = get_account receiver in
              let sub_amount amt bal =
                Option.value_exn (Balance.sub_amount bal amt)
              in
              let sub_fee fee = sub_amount (Amount.of_fee fee) in
              let expected_fee_payer_balance =
                accounts.(0).balance |> sub_fee fee
              in
              assert (
                Balance.equal fee_payer_account.balance
                  expected_fee_payer_balance ) ;
              let expected_source_balance = accounts.(1).balance in
              assert (
                Balance.equal source_account.balance expected_source_balance ) ;
              assert (Option.is_none receiver_account) ) )

    let%test_unit "insufficient source balance for non-default token transfer"
        =
      Test_util.with_randomness 123456789 (fun () ->
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let wallets = random_wallets ~n:2 () in
              let signer =
                Keypair.of_private_key_exn wallets.(0).private_key
              in
              let fee_payer_pk = Public_key.compress signer.public_key in
              let source_pk = fee_payer_pk in
              let receiver_pk = wallets.(1).account.public_key in
              let fee_token = Token_id.default in
              let token_id =
                Quickcheck.random_value Token_id.gen_non_default
              in
              let fee_payer = Account_id.create fee_payer_pk fee_token in
              let source = Account_id.create source_pk token_id in
              let receiver = Account_id.create receiver_pk token_id in
              let create_account aid balance =
                Account.create aid (Balance.of_int balance)
              in
              let accounts =
                [| create_account fee_payer 20_000_000_000
                 ; create_account source 30_000_000_000 |]
              in
              let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
              let amount = Amount.of_int 40_000_000_000 in
              let valid_until = Global_slot.max_value in
              let nonce = accounts.(0).nonce in
              let () =
                test_user_command_with_accounts ~constraint_constants ~ledger
                  ~accounts ~signer ~fee ~fee_payer_pk ~fee_token ~valid_until
                  ~nonce
                  (Payment {source_pk; receiver_pk; token_id; amount})
              in
              let get_account aid =
                Option.bind
                  (Ledger.location_of_account ledger aid)
                  ~f:(Ledger.get ledger)
              in
              let fee_payer_account =
                Option.value_exn (get_account fee_payer)
              in
              let source_account = Option.value_exn (get_account source) in
              let receiver_account = get_account receiver in
              let sub_amount amt bal =
                Option.value_exn (Balance.sub_amount bal amt)
              in
              let sub_fee fee = sub_amount (Amount.of_fee fee) in
              let expected_fee_payer_balance =
                accounts.(0).balance |> sub_fee fee
              in
              assert (
                Balance.equal fee_payer_account.balance
                  expected_fee_payer_balance ) ;
              let expected_source_balance = accounts.(1).balance in
              assert (
                Balance.equal source_account.balance expected_source_balance ) ;
              assert (Option.is_none receiver_account) ) )

    let%test_unit "transfer non-existing source" =
      Test_util.with_randomness 123456789 (fun () ->
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let wallets = random_wallets ~n:2 () in
              let signer =
                Keypair.of_private_key_exn wallets.(0).private_key
              in
              let fee_payer_pk = Public_key.compress signer.public_key in
              let source_pk = fee_payer_pk in
              let receiver_pk = wallets.(1).account.public_key in
              let fee_token = Token_id.default in
              let token_id =
                Quickcheck.random_value Token_id.gen_non_default
              in
              let fee_payer = Account_id.create fee_payer_pk fee_token in
              let source = Account_id.create source_pk token_id in
              let receiver = Account_id.create receiver_pk token_id in
              let create_account aid balance =
                Account.create aid (Balance.of_int balance)
              in
              let accounts = [|create_account fee_payer 20_000_000_000|] in
              let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
              let amount = Amount.of_int 20_000_000_000 in
              let valid_until = Global_slot.max_value in
              let nonce = accounts.(0).nonce in
              let () =
                test_user_command_with_accounts ~constraint_constants ~ledger
                  ~accounts ~signer ~fee ~fee_payer_pk ~fee_token ~valid_until
                  ~nonce
                  (Payment {source_pk; receiver_pk; token_id; amount})
              in
              let get_account aid =
                Option.bind
                  (Ledger.location_of_account ledger aid)
                  ~f:(Ledger.get ledger)
              in
              let fee_payer_account =
                Option.value_exn (get_account fee_payer)
              in
              let source_account = get_account source in
              let receiver_account = get_account receiver in
              let sub_amount amt bal =
                Option.value_exn (Balance.sub_amount bal amt)
              in
              let sub_fee fee = sub_amount (Amount.of_fee fee) in
              let expected_fee_payer_balance =
                accounts.(0).balance |> sub_fee fee
              in
              assert (
                Balance.equal fee_payer_account.balance
                  expected_fee_payer_balance ) ;
              assert (Option.is_none source_account) ;
              assert (Option.is_none receiver_account) ) )

    let%test_unit "payment predicate failure" =
      Test_util.with_randomness 123456789 (fun () ->
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let wallets = random_wallets ~n:3 () in
              let signer =
                Keypair.of_private_key_exn wallets.(0).private_key
              in
              let fee_payer_pk = Public_key.compress signer.public_key in
              let source_pk = wallets.(1).account.public_key in
              let receiver_pk = wallets.(2).account.public_key in
              let fee_token = Token_id.default in
              let token_id =
                Quickcheck.random_value Token_id.gen_non_default
              in
              let fee_payer = Account_id.create fee_payer_pk fee_token in
              let source = Account_id.create source_pk token_id in
              let receiver = Account_id.create receiver_pk token_id in
              let create_account aid balance =
                Account.create aid (Balance.of_int balance)
              in
              let accounts =
                [| create_account fee_payer 20_000_000_000
                 ; create_account source 30_000_000_000 |]
              in
              let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
              let amount = Amount.of_int 20_000_000_000 in
              let valid_until = Global_slot.max_value in
              let nonce = accounts.(0).nonce in
              let () =
                test_user_command_with_accounts ~constraint_constants ~ledger
                  ~accounts ~signer ~fee ~fee_payer_pk ~fee_token ~valid_until
                  ~nonce
                  (Payment {source_pk; receiver_pk; token_id; amount})
              in
              let get_account aid =
                Option.bind
                  (Ledger.location_of_account ledger aid)
                  ~f:(Ledger.get ledger)
              in
              let fee_payer_account =
                Option.value_exn (get_account fee_payer)
              in
              let source_account = Option.value_exn (get_account source) in
              let receiver_account = get_account receiver in
              let sub_amount amt bal =
                Option.value_exn (Balance.sub_amount bal amt)
              in
              let sub_fee fee = sub_amount (Amount.of_fee fee) in
              let expected_fee_payer_balance =
                accounts.(0).balance |> sub_fee fee
              in
              assert (
                Balance.equal fee_payer_account.balance
                  expected_fee_payer_balance ) ;
              let expected_source_balance = accounts.(1).balance in
              assert (
                Balance.equal source_account.balance expected_source_balance ) ;
              assert (Option.is_none receiver_account) ) )

    let%test_unit "delegation predicate failure" =
      Test_util.with_randomness 123456789 (fun () ->
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let wallets = random_wallets ~n:3 () in
              let signer =
                Keypair.of_private_key_exn wallets.(0).private_key
              in
              let fee_payer_pk = Public_key.compress signer.public_key in
              let source_pk = wallets.(1).account.public_key in
              let receiver_pk = wallets.(2).account.public_key in
              let fee_token = Token_id.default in
              let token_id = Token_id.default in
              let fee_payer = Account_id.create fee_payer_pk fee_token in
              let source = Account_id.create source_pk token_id in
              let receiver = Account_id.create receiver_pk token_id in
              let create_account aid balance =
                Account.create aid (Balance.of_int balance)
              in
              let accounts =
                [| create_account fee_payer 20_000_000_000
                 ; create_account source 30_000_000_000
                 ; create_account receiver 30_000_000_000 |]
              in
              let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
              let valid_until = Global_slot.max_value in
              let nonce = accounts.(0).nonce in
              let () =
                test_user_command_with_accounts ~constraint_constants ~ledger
                  ~accounts ~signer ~fee ~fee_payer_pk ~fee_token ~valid_until
                  ~nonce
                  (Stake_delegation
                     (Set_delegate
                        {delegator= source_pk; new_delegate= receiver_pk}))
              in
              let get_account aid =
                Option.bind
                  (Ledger.location_of_account ledger aid)
                  ~f:(Ledger.get ledger)
              in
              let fee_payer_account =
                Option.value_exn (get_account fee_payer)
              in
              let source_account = Option.value_exn (get_account source) in
              let receiver_account = get_account receiver in
              let sub_amount amt bal =
                Option.value_exn (Balance.sub_amount bal amt)
              in
              let sub_fee fee = sub_amount (Amount.of_fee fee) in
              let expected_fee_payer_balance =
                accounts.(0).balance |> sub_fee fee
              in
              assert (
                Balance.equal fee_payer_account.balance
                  expected_fee_payer_balance ) ;
              assert (
                Public_key.Compressed.equal source_account.delegate source_pk
              ) ;
              assert (Option.is_some receiver_account) ) )

    let%test_unit "delegation delegatee does not exist" =
      Test_util.with_randomness 123456789 (fun () ->
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let wallets = random_wallets ~n:2 () in
              let signer =
                Keypair.of_private_key_exn wallets.(0).private_key
              in
              let fee_payer_pk = Public_key.compress signer.public_key in
              let source_pk = fee_payer_pk in
              let receiver_pk = wallets.(1).account.public_key in
              let fee_token = Token_id.default in
              let token_id = Token_id.default in
              let fee_payer = Account_id.create fee_payer_pk fee_token in
              let source = Account_id.create source_pk token_id in
              let receiver = Account_id.create receiver_pk token_id in
              let create_account aid balance =
                Account.create aid (Balance.of_int balance)
              in
              let accounts = [|create_account fee_payer 20_000_000_000|] in
              let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
              let valid_until = Global_slot.max_value in
              let nonce = accounts.(0).nonce in
              let () =
                test_user_command_with_accounts ~constraint_constants ~ledger
                  ~accounts ~signer ~fee ~fee_payer_pk ~fee_token ~valid_until
                  ~nonce
                  (Stake_delegation
                     (Set_delegate
                        {delegator= source_pk; new_delegate= receiver_pk}))
              in
              let get_account aid =
                Option.bind
                  (Ledger.location_of_account ledger aid)
                  ~f:(Ledger.get ledger)
              in
              let fee_payer_account =
                Option.value_exn (get_account fee_payer)
              in
              let source_account = Option.value_exn (get_account source) in
              let receiver_account = get_account receiver in
              let sub_amount amt bal =
                Option.value_exn (Balance.sub_amount bal amt)
              in
              let sub_fee fee = sub_amount (Amount.of_fee fee) in
              let expected_fee_payer_balance =
                accounts.(0).balance |> sub_fee fee
              in
              assert (
                Balance.equal fee_payer_account.balance
                  expected_fee_payer_balance ) ;
              assert (
                Public_key.Compressed.equal source_account.delegate source_pk
              ) ;
              assert (Option.is_none receiver_account) ) )

    let%test_unit "delegation delegator does not exist" =
      Test_util.with_randomness 123456789 (fun () ->
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let wallets = random_wallets ~n:3 () in
              let signer =
                Keypair.of_private_key_exn wallets.(0).private_key
              in
              let fee_payer_pk = Public_key.compress signer.public_key in
              let source_pk = wallets.(1).account.public_key in
              let receiver_pk = wallets.(2).account.public_key in
              let fee_token = Token_id.default in
              let token_id = Token_id.default in
              let fee_payer = Account_id.create fee_payer_pk fee_token in
              let source = Account_id.create source_pk token_id in
              let receiver = Account_id.create receiver_pk token_id in
              let create_account aid balance =
                Account.create aid (Balance.of_int balance)
              in
              let accounts =
                [| create_account fee_payer 20_000_000_000
                 ; create_account receiver 30_000_000_000 |]
              in
              let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
              let valid_until = Global_slot.max_value in
              let nonce = accounts.(0).nonce in
              let () =
                test_user_command_with_accounts ~constraint_constants ~ledger
                  ~accounts ~signer ~fee ~fee_payer_pk ~fee_token ~valid_until
                  ~nonce
                  (Stake_delegation
                     (Set_delegate
                        {delegator= source_pk; new_delegate= receiver_pk}))
              in
              let get_account aid =
                Option.bind
                  (Ledger.location_of_account ledger aid)
                  ~f:(Ledger.get ledger)
              in
              let fee_payer_account =
                Option.value_exn (get_account fee_payer)
              in
              let source_account = get_account source in
              let receiver_account = get_account receiver in
              let sub_amount amt bal =
                Option.value_exn (Balance.sub_amount bal amt)
              in
              let sub_fee fee = sub_amount (Amount.of_fee fee) in
              let expected_fee_payer_balance =
                accounts.(0).balance |> sub_fee fee
              in
              assert (
                Balance.equal fee_payer_account.balance
                  expected_fee_payer_balance ) ;
              assert (Option.is_none source_account) ;
              assert (Option.is_some receiver_account) ) )

    let%test_unit "timed account - transactions" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = random_wallets ~n:3 () in
          let sender = wallets.(0) in
          let receivers = Array.to_list wallets |> List.tl_exn in
          let txns_per_receiver = 2 in
          let amount = 8_000_000_000 in
          let txn_fee = 2_000_000_000 in
          let memo =
            User_command_memo.create_by_digesting_string_exn
              (Test_util.arbitrary_string
                 ~len:User_command_memo.max_digestible_string_length)
          in
          let balance = Balance.of_int 100_000_000_000_000 in
          let initial_minimum_balance = Balance.of_int 80_000_000_000_000 in
          let cliff_time = Global_slot.of_int 1000 in
          let vesting_period = Global_slot.of_int 10 in
          let vesting_increment = Amount.of_int 1 in
          let txn_global_slot = Global_slot.of_int 1002 in
          let sender =
            { sender with
              account=
                Or_error.ok_exn
                @@ Account.create_timed
                     (Account.identifier sender.account)
                     balance ~initial_minimum_balance ~cliff_time
                     ~vesting_period ~vesting_increment }
          in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let _, ucs =
                let receiver_ids =
                  List.init (List.length receivers) ~f:(( + ) 1)
                in
                let receivers =
                  List.fold ~init:receiver_ids
                    (List.init (txns_per_receiver - 1) ~f:Fn.id)
                    ~f:(fun acc _ -> receiver_ids @ acc)
                in
                List.fold receivers ~init:(Account.Nonce.zero, [])
                  ~f:(fun (nonce, txns) receiver ->
                    let uc =
                      user_command_with_wallet wallets ~sender:0 ~receiver
                        amount (Fee.of_int txn_fee) ~fee_token:Token_id.default
                        ~token:Token_id.default nonce memo
                    in
                    (Account.Nonce.succ nonce, txns @ [uc]) )
              in
              Ledger.create_new_account_exn ledger
                (Account.identifier sender.account)
                sender.account ;
              let () =
                List.iter ucs ~f:(fun uc ->
                    test_transaction ~constraint_constants ~txn_global_slot
                      ledger (Transaction.User_command uc) )
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
      let%map _, timing =
        Base.check_timing ~balance_check:Tick.Boolean.Assert.is_true
          ~timed_balance_check:Tick.Boolean.Assert.is_true ~account ~txn_amount
          ~txn_global_slot
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
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 80_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 1_000_000_000 in
      let txn_amount = Currency.Amount.of_int 100_000_000_000 in
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
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 100_000_000_000 in
      let txn_global_slot = Coda_numbers.Global_slot.of_int 1_900 in
      let timing =
        validate_timing ~account
          ~txn_amount:(Currency.Amount.of_int 100_000_000_000)
          ~txn_global_slot:(Coda_numbers.Global_slot.of_int 1_900)
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
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1_000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~vesting_period ~vesting_increment
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
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 10_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1_000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 101_000_000_000 in
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
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~vesting_period ~vesting_increment
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
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Global_slot.of_int 1000 in
      let vesting_period = Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~vesting_period ~vesting_increment
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
        Base.(
          Tick.constraint_system ~exposing:[Statement.With_sok.typ]
            (main
               ~constraint_constants:
                 Genesis_constants.Constraint_constants.compiled)) ) ]
