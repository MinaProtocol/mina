open Core
open Signature_lib
open Mina_base
open Mina_transaction
open Mina_state
open Snark_params
module Global_slot = Mina_numbers.Global_slot
open Currency
open Pickles_types
module Impl = Pickles.Impls.Step
module Ledger = Mina_ledger.Ledger
module Sparse_ledger = Mina_ledger.Sparse_ledger
module Transaction_validator = Transaction_validator

let top_hash_logging_enabled = ref false

let to_preunion (t : Transaction.t) =
  match t with
  | Command (Signed_command x) ->
      `Transaction (Transaction.Command x)
  | Fee_transfer x ->
      `Transaction (Fee_transfer x)
  | Coinbase x ->
      `Transaction (Coinbase x)
  | Command (Zkapp_command x) ->
      `Zkapp_command x

let with_top_hash_logging f =
  let old = !top_hash_logging_enabled in
  top_hash_logging_enabled := true ;
  try
    let ret = f () in
    top_hash_logging_enabled := old ;
    ret
  with err ->
    top_hash_logging_enabled := old ;
    raise err

module Proof_type = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = [ `Base | `Merge ]
      [@@deriving compare, equal, hash, sexp, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Pending_coinbase_stack_state = struct
  module Init_stack = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Base of Pending_coinbase.Stack_versioned.Stable.V1.t | Merge
        [@@deriving sexp, hash, compare, equal, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'pending_coinbase t =
          { source : 'pending_coinbase; target : 'pending_coinbase }
        [@@deriving sexp, hash, compare, equal, fields, yojson, hlist]

        let to_latest pending_coinbase { source; target } =
          { source = pending_coinbase source; target = pending_coinbase target }
      end
    end]

    let typ pending_coinbase =
      Tick.Typ.of_hlistable
        [ pending_coinbase; pending_coinbase ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  type 'pending_coinbase poly = 'pending_coinbase Poly.t =
    { source : 'pending_coinbase; target : 'pending_coinbase }
  [@@deriving sexp, hash, compare, equal, fields, yojson]

  (* State of the coinbase stack for the current transaction snark *)
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Pending_coinbase.Stack_versioned.Stable.V1.t Poly.Stable.V1.t
      [@@deriving sexp, hash, compare, equal, yojson]

      let to_latest = Fn.id
    end
  end]

  type var = Pending_coinbase.Stack.var Poly.t

  let typ = Poly.typ Pending_coinbase.Stack.typ

  let to_input ({ source; target } : t) =
    Random_oracle.Input.Chunked.append
      (Pending_coinbase.Stack.to_input source)
      (Pending_coinbase.Stack.to_input target)

  let var_to_input ({ source; target } : var) =
    Random_oracle.Input.Chunked.append
      (Pending_coinbase.Stack.var_to_input source)
      (Pending_coinbase.Stack.var_to_input target)

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)
end

module Statement = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type ( 'ledger_hash
             , 'amount
             , 'pending_coinbase
             , 'fee_excess
             , 'sok_digest
             , 'local_state )
             t =
          { source :
              ( 'ledger_hash
              , 'pending_coinbase
              , 'local_state )
              Registers.Stable.V1.t
          ; target :
              ( 'ledger_hash
              , 'pending_coinbase
              , 'local_state )
              Registers.Stable.V1.t
          ; supply_increase : 'amount
          ; fee_excess : 'fee_excess
          ; sok_digest : 'sok_digest
          }
        [@@deriving compare, equal, hash, sexp, yojson, hlist]
      end
    end]

    let with_empty_local_state ~supply_increase ~fee_excess ~sok_digest ~source
        ~target ~pending_coinbase_stack_state : _ t =
      { supply_increase
      ; fee_excess
      ; sok_digest
      ; source =
          { ledger = source
          ; pending_coinbase_stack =
              pending_coinbase_stack_state.Pending_coinbase_stack_state.source
          ; local_state = Local_state.empty ()
          }
      ; target =
          { ledger = target
          ; pending_coinbase_stack = pending_coinbase_stack_state.target
          ; local_state = Local_state.empty ()
          }
      }

    let typ ledger_hash amount pending_coinbase fee_excess sok_digest
        local_state_typ =
      let registers =
        let open Registers in
        Tick.Typ.of_hlistable
          [ ledger_hash; pending_coinbase; local_state_typ ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist
      in
      Tick.Typ.of_hlistable
        [ registers; registers; amount; fee_excess; sok_digest ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  type ( 'ledger_hash
       , 'amount
       , 'pending_coinbase
       , 'fee_excess
       , 'sok_digest
       , 'local_state )
       poly =
        ( 'ledger_hash
        , 'amount
        , 'pending_coinbase
        , 'fee_excess
        , 'sok_digest
        , 'local_state )
        Poly.t =
    { source : ('ledger_hash, 'pending_coinbase, 'local_state) Registers.t
    ; target : ('ledger_hash, 'pending_coinbase, 'local_state) Registers.t
    ; supply_increase : 'amount
    ; fee_excess : 'fee_excess
    ; sok_digest : 'sok_digest
    }
  [@@deriving compare, equal, hash, sexp, yojson]

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( Frozen_ledger_hash.Stable.V1.t
        , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
        , Pending_coinbase.Stack_versioned.Stable.V1.t
        , Fee_excess.Stable.V1.t
        , unit
        , Local_state.Stable.V1.t )
        Poly.Stable.V2.t
      [@@deriving compare, equal, hash, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  module With_sok = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          ( Frozen_ledger_hash.Stable.V1.t
          , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
          , Pending_coinbase.Stack_versioned.Stable.V1.t
          , Fee_excess.Stable.V1.t
          , Sok_message.Digest.Stable.V1.t
          , Local_state.Stable.V1.t )
          Poly.Stable.V2.t
        [@@deriving compare, equal, hash, sexp, yojson]

        let to_latest = Fn.id
      end
    end]

    type var =
      ( Frozen_ledger_hash.var
      , Currency.Amount.Signed.var
      , Pending_coinbase.Stack.var
      , Fee_excess.var
      , Sok_message.Digest.Checked.t
      , Local_state.Checked.t )
      Poly.t

    let typ : (var, t) Tick.Typ.t =
      Poly.typ Frozen_ledger_hash.typ Currency.Amount.Signed.typ
        Pending_coinbase.Stack.typ Fee_excess.typ Sok_message.Digest.typ
        Local_state.typ

    let to_input { source; target; supply_increase; fee_excess; sok_digest } =
      let input =
        Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
          [| Sok_message.Digest.to_input sok_digest
           ; Registers.to_input source
           ; Registers.to_input target
           ; Amount.Signed.to_input supply_increase
           ; Fee_excess.to_input fee_excess
          |]
      in
      if !top_hash_logging_enabled then
        Format.eprintf
          !"Generating unchecked top hash from:@.%{sexp: Tick.Field.t \
            Random_oracle.Input.Chunked.t}@."
          input ;
      input

    let to_field_elements t = Random_oracle.pack_input (to_input t)

    module Checked = struct
      type t = var

      let to_input { source; target; supply_increase; fee_excess; sok_digest } =
        let open Tick in
        let open Checked.Let_syntax in
        let%bind fee_excess = Fee_excess.to_input_checked fee_excess in
        let source = Registers.Checked.to_input source
        and target = Registers.Checked.to_input target in
        let%bind supply_increase =
          Amount.Signed.Checked.to_input supply_increase
        in
        let input =
          Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
            [| Sok_message.Digest.Checked.to_input sok_digest
             ; source
             ; target
             ; supply_increase
             ; fee_excess
            |]
        in
        let%map () =
          as_prover
            As_prover.(
              if !top_hash_logging_enabled then
                let%map input = Random_oracle.read_typ' input in
                Format.eprintf
                  !"Generating checked top hash from:@.%{sexp: Field.t \
                    Random_oracle.Input.Chunked.t}@."
                  input
              else return ())
        in
        input

      let to_field_elements t =
        let open Tick.Checked.Let_syntax in
        Tick.Run.run_checked (to_input t >>| Random_oracle.Checked.pack_input)
    end
  end

  let option lab =
    Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

  let merge (s1 : _ Poly.t) (s2 : _ Poly.t) =
    let open Or_error.Let_syntax in
    let registers_check_equal (t1 : _ Registers.t) (t2 : _ Registers.t) =
      let check' k f =
        let x1 = Field.get f t1 and x2 = Field.get f t2 in
        k x1 x2
      in
      let module S = struct
        module type S = sig
          type t [@@deriving eq, sexp_of]
        end
      end in
      let check (type t) (module T : S.S with type t = t) f =
        let open T in
        check'
          (fun x1 x2 ->
            if equal x1 x2 then return ()
            else
              Or_error.errorf
                !"%s is inconsistent between transitions (%{sexp: t} vs \
                  %{sexp: t})"
                (Field.name f) x1 x2 )
          f
      in
      let module PC = struct
        type t = Pending_coinbase.Stack.t [@@deriving sexp_of]

        let equal t1 t2 =
          Pending_coinbase.Stack.connected ~first:t1 ~second:t2 ()
      end in
      Registers.Fields.to_list
        ~ledger:(check (module Ledger_hash))
        ~pending_coinbase_stack:(check (module PC))
        ~local_state:(check (module Local_state))
      |> Or_error.combine_errors_unit
    in
    let%map fee_excess = Fee_excess.combine s1.fee_excess s2.fee_excess
    and supply_increase =
      Currency.Amount.Signed.add s1.supply_increase s2.supply_increase
      |> option "Error adding supply_increase"
    and () = registers_check_equal s1.target s2.source in
    ( { source = s1.source
      ; target = s2.target
      ; fee_excess
      ; supply_increase
      ; sok_digest = ()
      }
      : t )

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map source = Registers.gen
    and target = Registers.gen
    and fee_excess = Fee_excess.gen
    and supply_increase = Currency.Amount.Signed.gen in
    ({ source; target; fee_excess; supply_increase; sok_digest = () } : t)
end

module Proof = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Pickles.Proof.Proofs_verified_2.Stable.V2.t
      [@@deriving yojson, compare, equal, sexp, hash]

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      { statement : Statement.With_sok.Stable.V2.t; proof : Proof.Stable.V2.t }
    [@@deriving compare, equal, fields, sexp, version, yojson, hash]

    let to_latest = Fn.id
  end
end]

let proof t = t.proof

let statement t = { t.statement with sok_digest = () }

let sok_digest t = t.statement.sok_digest

let to_yojson = Stable.Latest.to_yojson

let create ~statement ~proof = { statement; proof }

open Tick
open Let_syntax

let chain if_ b ~then_ ~else_ =
  let%bind then_ = then_ and else_ = else_ in
  if_ b ~then_ ~else_

module Zkapp_command_segment = struct
  module Spec = struct
    type single =
      { auth_type : Control.Tag.t
      ; is_start : [ `Yes | `No | `Compute_in_circuit ]
      }

    type t = single list
  end

  module Basic = struct
    module N = Side_loaded_verification_key.Max_branches

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Opt_signed_opt_signed | Opt_signed | Proved
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end
    end]

    let of_controls = function
      | [ Control.Proof _ ] ->
          Proved
      | [ (Control.Signature _ | Control.None_given) ] ->
          Opt_signed
      | [ Control.(Signature _ | None_given)
        ; Control.(Signature _ | None_given)
        ] ->
          Opt_signed_opt_signed
      | _ ->
          failwith
            "Zkapp_command_segment.Basic.of_controls: Unsupported combination"

    let opt_signed ~is_start : Spec.single = { auth_type = Signature; is_start }

    let opt_signed = opt_signed ~is_start:`Compute_in_circuit

    let to_single_list : t -> Spec.single list =
     fun t ->
      match t with
      | Opt_signed_opt_signed ->
          [ opt_signed; opt_signed ]
      | Opt_signed ->
          [ opt_signed ]
      | Proved ->
          [ { auth_type = Proof; is_start = `No } ]

    type (_, _, _, _) t_typed =
      | Opt_signed_opt_signed : (unit, unit, unit, unit) t_typed
      | Opt_signed : (unit, unit, unit, unit) t_typed
      | Proved
          : ( Zkapp_statement.Checked.t * unit
            , Zkapp_statement.t * unit
            , Nat.N2.n * unit
            , N.n * unit )
            t_typed

    let spec : type a b c d. (a, b, c, d) t_typed -> Spec.single list =
     fun t ->
      match t with
      | Opt_signed_opt_signed ->
          [ opt_signed; opt_signed ]
      | Opt_signed ->
          [ opt_signed ]
      | Proved ->
          [ { auth_type = Proof; is_start = `No } ]
  end

  module Witness = Transaction_witness.Zkapp_command_segment_witness
end

(* Currently, a circuit must have at least 1 of every type of constraint. *)
let dummy_constraints () =
  make_checked
    Impl.(
      fun () ->
        let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
        let g = exists Inner_curve.typ ~compute:(fun _ -> Inner_curve.one) in
        ignore
          ( Pickles.Scalar_challenge.to_field_checked'
              (module Impl)
              ~num_bits:16
              (Kimchi_backend_common.Scalar_challenge.create x)
            : Field.t * Field.t * Field.t ) ;
        ignore
          ( Pickles.Step_main_inputs.Ops.scale_fast g ~num_bits:5
              (Shifted_value x)
            : Pickles.Step_main_inputs.Inner_curve.t ) ;
        ignore
          ( Pickles.Step_main_inputs.Ops.scale_fast g ~num_bits:5
              (Shifted_value x)
            : Pickles.Step_main_inputs.Inner_curve.t ) ;
        ignore
          ( Pickles.Step_verifier.Scalar_challenge.endo g ~num_bits:4
              (Kimchi_backend_common.Scalar_challenge.create x)
            : Field.t * Field.t ))

module Base = struct
  module User_command_failure = struct
    (** The various ways that a user command may fail. These should be computed
        before applying the snark, to ensure that only the base fee is charged
        to the fee-payer if executing the user command will later fail.
    *)
    type 'bool t =
      { predicate_failed : 'bool (* User commands *)
      ; source_not_present : 'bool (* User commands *)
      ; receiver_not_present : 'bool (* Delegate, Mint_tokens *)
      ; amount_insufficient_to_create : 'bool (* Payment only *)
      ; token_cannot_create : 'bool (* Payment only, token<>default *)
      ; source_insufficient_balance : 'bool (* Payment only *)
      ; source_minimum_balance_violation : 'bool (* Payment only *)
      ; source_bad_timing : 'bool (* Payment only *)
      }

    let num_fields = 8

    let to_list
        { predicate_failed
        ; source_not_present
        ; receiver_not_present
        ; amount_insufficient_to_create
        ; token_cannot_create
        ; source_insufficient_balance
        ; source_minimum_balance_violation
        ; source_bad_timing
        } =
      [ predicate_failed
      ; source_not_present
      ; receiver_not_present
      ; amount_insufficient_to_create
      ; token_cannot_create
      ; source_insufficient_balance
      ; source_minimum_balance_violation
      ; source_bad_timing
      ]

    let of_list = function
      | [ predicate_failed
        ; source_not_present
        ; receiver_not_present
        ; amount_insufficient_to_create
        ; token_cannot_create
        ; source_insufficient_balance
        ; source_minimum_balance_violation
        ; source_bad_timing
        ] ->
          { predicate_failed
          ; source_not_present
          ; receiver_not_present
          ; amount_insufficient_to_create
          ; token_cannot_create
          ; source_insufficient_balance
          ; source_minimum_balance_violation
          ; source_bad_timing
          }
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
        ({ payload; signature = _; signer = _ } : Transaction_union.t) =
      match payload.body.tag with
      | Fee_transfer | Coinbase ->
          (* Not user commands, return no failure. *)
          of_list (List.init num_fields ~f:(fun _ -> false))
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
              balance =
                Option.value_exn ?here:None ?error:None ?message:None
                @@ Balance.sub_amount fee_payer_account.balance
                     (Amount.of_fee payload.common.fee)
            }
          in
          let predicate_failed =
            if
              Public_key.Compressed.equal payload.common.fee_payer_pk
                payload.body.source_pk
            then false
            else
              match payload.body.tag with
              | Create_account | Mint_tokens ->
                  assert false
              | Payment | Stake_delegation ->
                  (* TODO(#4554): Hook account_precondition evaluation in here once
                     implemented.
                  *)
                  true
              | Fee_transfer | Coinbase ->
                  assert false
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
              { predicate_failed
              ; source_not_present
              ; receiver_not_present
              ; amount_insufficient_to_create = false
              ; token_cannot_create = false
              ; source_insufficient_balance = false
              ; source_minimum_balance_violation = false
              ; source_bad_timing = false
              }
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
              let token_is_default = true in
              let token_cannot_create =
                receiver_needs_creating && not token_is_default
              in
              let amount_insufficient_to_create =
                let creation_amount =
                  Amount.of_fee constraint_constants.account_creation_fee
                in
                receiver_needs_creating
                && Option.is_none
                     (Amount.sub payload.body.amount creation_amount)
              in
              let fee_payer_is_source = Account_id.equal fee_payer source in
              let source_account =
                if fee_payer_is_source then fee_payer_account
                else source_account
              in
              let source_not_present =
                let id = Account.identifier source_account in
                if Account_id.equal Account_id.empty id then true
                else if Account_id.equal source id then false
                else fail "bad source account ID"
              in
              let source_insufficient_balance =
                (* This failure is fatal if fee-payer and source account are
                   the same. This is checked in the transaction pool.
                *)
                (not fee_payer_is_source)
                &&
                if Account_id.equal source receiver then
                  (* The final balance will be [0 - account_creation_fee]. *)
                  receiver_needs_creating
                else
                  Amount.(
                    Balance.to_amount source_account.balance
                    < payload.body.amount)
              in
              let timing_or_error =
                Mina_transaction_logic.validate_timing
                  ~txn_amount:payload.body.amount ~txn_global_slot
                  ~account:source_account
              in
              let source_minimum_balance_violation =
                match timing_or_error with
                | Ok _ ->
                    false
                | Error err ->
                    let open Mina_base in
                    Transaction_status.Failure.equal
                      (Mina_transaction_logic
                       .timing_error_to_user_command_status err )
                      Transaction_status.Failure
                      .Source_minimum_balance_violation
              in
              let source_bad_timing =
                (* This failure is fatal if fee-payer and source account are
                   the same. This is checked in the transaction pool.
                *)
                (not fee_payer_is_source)
                && (not source_insufficient_balance)
                && Or_error.is_error timing_or_error
              in
              { predicate_failed
              ; source_not_present
              ; receiver_not_present = false
              ; amount_insufficient_to_create
              ; token_cannot_create
              ; source_insufficient_balance
              ; source_minimum_balance_violation
              ; source_bad_timing
              }
          | Mint_tokens | Create_account ->
              assert false )

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
              let source = Account_id.create txn.payload.body.source_pk token in
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
      exists typ
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
            compute_unchecked ~constraint_constants ~txn_global_slot
              ~fee_payer_account ~source_account ~receiver_account txn)
  end

  let%snarkydef check_signature shifted ~payload ~is_user_command ~signer
      ~signature =
    let%bind input =
      Transaction_union_payload.Checked.to_input_legacy payload
    in
    let%bind verifies =
      Schnorr.Legacy.Checked.verifies shifted signature signer input
    in
    [%with_label "check signature"]
      (Boolean.Assert.any [ Boolean.not is_user_command; verifies ])

  let check_timing ~balance_check ~timed_balance_check ~account ~txn_amount
      ~txn_global_slot =
    (* calculations should track Mina_transaction_logic.validate_timing *)
    let open Account.Poly in
    let open Account.Timing.As_record in
    let { is_timed
        ; initial_minimum_balance
        ; cliff_time
        ; cliff_amount
        ; vesting_period
        ; vesting_increment
        } =
      account.timing
    in
    let%bind curr_min_balance =
      Account.Checked.min_balance_at_slot ~global_slot:txn_global_slot
        ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
        ~initial_minimum_balance
    in
    let%bind proposed_balance =
      match txn_amount with
      | Some txn_amount ->
          let%bind proposed_balance, `Underflow underflow =
            Balance.Checked.sub_amount_flagged account.balance txn_amount
          in
          (* underflow indicates insufficient balance *)
          let%map () = balance_check (Boolean.not underflow) in
          proposed_balance
      | None ->
          return account.balance
    in
    let%bind sufficient_timed_balance =
      Balance.Checked.( >= ) proposed_balance curr_min_balance
    in
    let%bind () =
      let%bind ok = Boolean.(any [ not is_timed; sufficient_timed_balance ]) in
      timed_balance_check ok
    in
    let%bind is_timed_balance_zero =
      Balance.Checked.equal curr_min_balance
        (Balance.Checked.Unsafe.of_field Field.(Var.constant zero))
    in
    (* if current min balance is zero, then timing becomes untimed *)
    let%bind is_untimed = Boolean.((not is_timed) ||| is_timed_balance_zero) in
    let%map timing =
      Account.Timing.if_ is_untimed ~then_:Account.Timing.untimed_var
        ~else_:account.timing
    in
    (`Min_balance curr_min_balance, timing)

  let side_loaded =
    Memo.of_comparable
      (module Int)
      (fun i ->
        let open Zkapp_statement in
        Pickles.Side_loaded.create ~typ ~name:(sprintf "zkapp_%d" i)
          ~uses_lookup:Maybe
          ~max_proofs_verified:
            (module Pickles.Side_loaded.Verification_key.Max_width) )

  let signature_verifies ~shifted ~payload_digest signature pk =
    let%bind pk =
      Public_key.decompress_var pk
      (*           (Account_id.Checked.public_key fee_payer_id) *)
    in
    Schnorr.Chunked.Checked.verifies shifted signature pk
      (Random_oracle.Input.Chunked.field payload_digest)

  module Zkapp_command_snark = struct
    open Zkapp_command_segment
    open Spec

    module Global_state = struct
      type t =
        { ledger : Ledger_hash.var * Sparse_ledger.t Prover_value.t
        ; fee_excess : Amount.Signed.var
        ; protocol_state : Zkapp_precondition.Protocol_state.View.Checked.t
        }
    end

    let implied_root account incl =
      let open Impl in
      List.foldi incl
        ~init:(Lazy.force (With_hash.hash account))
        ~f:(fun height acc (b, h) ->
          let l = Field.if_ b ~then_:h ~else_:acc
          and r = Field.if_ b ~then_:acc ~else_:h in
          let acc' = Ledger_hash.merge_var ~height l r in
          acc' )

    module type Single_inputs = sig
      val constraint_constants : Genesis_constants.Constraint_constants.t

      val spec : single

      val set_zkapp_input : Zkapp_statement.Checked.t -> unit
    end

    type account_update = Zkapp_call_forest.Checked.account_update =
      { account_update :
          ( Account_update.Body.Checked.t
          , Zkapp_command.Digest.Account_update.Checked.t )
          With_hash.t
      ; control : Control.t Prover_value.t
      }

    module Inputs = struct
      module V = Prover_value
      open Impl

      module Transaction_commitment = struct
        type t = Field.t

        let if_ = Field.if_

        let empty = Field.constant Zkapp_command.Transaction_commitment.empty

        let commitment
            ~account_updates:{ With_hash.hash = account_updates_hash; _ } =
          Zkapp_command.Transaction_commitment.Checked.create
            ~account_updates_hash

        let full_commitment ~account_update:{ account_update; _ } ~memo_hash
            ~commitment =
          Zkapp_command.Transaction_commitment.Checked.create_complete
            commitment ~memo_hash ~fee_payer_hash:account_update.hash
      end

      module Bool = struct
        type t = Boolean.var

        [%%define_locally
        Boolean.(( ||| ), ( &&& ), if_, true_, false_, equal, not, all)]

        module Assert = struct
          let raise_failure ~pos msg =
            let file, line, col, ecol = pos in
            raise
              (Failure
                 (sprintf "File %S, line %d, characters %d-%d: %s" file line col
                    ecol msg ) )

          let is_true ~pos b =
            try Boolean.Assert.is_true b
            with Failure msg -> raise_failure ~pos msg

          let any ~pos bs =
            try Boolean.Assert.any bs
            with Failure msg -> raise_failure ~pos msg
        end

        let display _b ~label:_ = ""

        type failure_status = unit

        type failure_status_tbl = unit

        let assert_with_failure_status_tbl ~pos b _failure_status_tbl =
          Assert.is_true ~pos b
      end

      module Index = struct
        open Mina_numbers.Index.Checked

        type t = var

        let zero = zero

        let succ t = succ t |> run_checked

        let if_ b ~then_ ~else_ = if_ b ~then_ ~else_ |> run_checked
      end

      module Account_id = struct
        type t = Account_id.var

        let if_ b ~then_ ~else_ =
          run_checked (Account_id.Checked.if_ b ~then_ ~else_)

        let derive_token_id = Account_id.Checked.derive_token_id

        let constant id =
          Account_id.(
            Checked.create
              (Public_key.Compressed.var_of_t (public_key id))
              (Token_id.Checked.constant (token_id id)))

        let invalid = constant Account_id.invalid

        let equal x y = Account_id.Checked.equal x y |> run_checked

        let create = Account_id.Checked.create
      end

      module Global_slot = struct
        include Global_slot.Checked

        let ( > ) x y = run_checked (x > y)

        let if_ b ~then_ ~else_ = run_checked (if_ b ~then_ ~else_)

        let equal x y = run_checked (equal x y)
      end

      module Nonce = struct
        type t = Account.Nonce.Checked.t

        let if_ b ~then_ ~else_ =
          run_checked (Account.Nonce.Checked.if_ b ~then_ ~else_)

        let succ t = run_checked (Account.Nonce.Checked.succ t)
      end

      module State_hash = struct
        type t = State_hash.var

        let if_ b ~then_ ~else_ = run_checked (State_hash.if_ b ~then_ ~else_)
      end

      module Timing = struct
        type t = Account_timing.var

        let if_ b ~then_ ~else_ =
          run_checked (Account_timing.if_ b ~then_ ~else_)

        let vesting_period (t : t) = t.vesting_period
      end

      module Balance = struct
        include Balance.Checked

        let if_ b ~then_ ~else_ = run_checked (if_ b ~then_ ~else_)

        let sub_amount_flagged x y = run_checked (sub_amount_flagged x y)

        let add_signed_amount_flagged x y =
          run_checked (add_signed_amount_flagged x y)
      end

      module Receipt_chain_hash = struct
        open Receipt.Chain_hash.Checked

        type nonrec t = t

        module Elt = struct
          type t = Zkapp_command_elt.t

          let of_transaction_commitment tc =
            Zkapp_command_elt.Zkapp_command_commitment tc
        end

        let cons_zkapp_command_commitment index elt t =
          run_checked (cons_zkapp_command_commitment index elt t)

        let if_ b ~then_ ~else_ = run_checked (if_ b ~then_ ~else_)
      end

      module Verification_key = struct
        type t =
          ( Boolean.var
          , ( Side_loaded_verification_key.t option
            , Field.Constant.t )
            With_hash.t
            Data_as_hash.t )
          Zkapp_basic.Flagged_option.t

        let if_ b ~(then_ : t) ~(else_ : t) : t =
          Zkapp_basic.Flagged_option.if_ ~if_:Data_as_hash.if_ b ~then_ ~else_
      end

      module Sequence_events = struct
        type t = Zkapp_account.Sequence_events.var

        let is_empty x =
          run_checked (Account_update.Sequence_events.is_empty_var x)

        let push_events = Account_update.Sequence_events.push_events_checked
      end

      module Zkapp_uri = struct
        type t = string Data_as_hash.t

        let if_ = Data_as_hash.if_
      end

      module Token_symbol = struct
        type t = Account.Token_symbol.var

        let if_ = Account.Token_symbol.if_
      end

      module Account = struct
        type t = (Account.Checked.Unhashed.t, Field.t Lazy.t) With_hash.t

        module Permissions = struct
          type controller = Permissions.Auth_required.Checked.t

          let edit_state : t -> controller =
           fun a -> a.data.permissions.edit_state

          let send : t -> controller = fun a -> a.data.permissions.send

          let receive : t -> controller = fun a -> a.data.permissions.receive

          let set_delegate : t -> controller =
           fun a -> a.data.permissions.set_delegate

          let set_permissions : t -> controller =
           fun a -> a.data.permissions.set_permissions

          let set_verification_key : t -> controller =
           fun a -> a.data.permissions.set_verification_key

          let set_zkapp_uri : t -> controller =
           fun a -> a.data.permissions.set_zkapp_uri

          let edit_sequence_state : t -> controller =
           fun a -> a.data.permissions.edit_sequence_state

          let set_token_symbol : t -> controller =
           fun a -> a.data.permissions.set_token_symbol

          let increment_nonce : t -> controller =
           fun a -> a.data.permissions.increment_nonce

          let set_voting_for : t -> controller =
           fun a -> a.data.permissions.set_voting_for

          type t = Permissions.Checked.t

          let if_ b ~then_ ~else_ = Permissions.Checked.if_ b ~then_ ~else_
        end

        let account_with_hash (account : Account.Checked.Unhashed.t) : t =
          With_hash.of_data account ~hash_data:(fun a ->
              lazy
                (let a =
                   { a with
                     zkapp =
                       ( Zkapp_account.Checked.digest a.zkapp
                       , As_prover.Ref.create (fun () -> None) )
                   }
                 in
                 run_checked (Account.Checked.digest a) ) )

        type timing = Account_timing.var

        let timing (account : t) : timing = account.data.timing

        let set_timing (account : t) (timing : timing) : t =
          { account with data = { account.data with timing } }

        let is_timed ({ data = account; _ } : t) =
          let open Account.Poly in
          let open Account.Timing.As_record in
          let { is_timed; _ } = account.timing in
          is_timed

        let set_token_id (account : t) (token_id : Token_id.Checked.t) : t =
          account_with_hash { account.data with token_id }

        let balance (a : t) : Balance.t = a.data.balance

        let set_balance (balance : Balance.t) ({ data = a; hash } : t) : t =
          { data = { a with balance }; hash }

        let check_timing ~txn_global_slot ({ data = account; _ } : t) =
          let invalid_timing = ref None in
          let balance_check _ = failwith "Should not be called" in
          let timed_balance_check b =
            invalid_timing := Some (Boolean.not b) ;
            return ()
          in
          let `Min_balance _, timing =
            run_checked
            @@ [%with_label "Check zkapp timing"]
                 (check_timing ~balance_check ~timed_balance_check ~account
                    ~txn_amount:None ~txn_global_slot )
          in
          (`Invalid_timing (Option.value_exn !invalid_timing), timing)

        let receipt_chain_hash (a : t) : Receipt_chain_hash.t =
          a.data.receipt_chain_hash

        let set_receipt_chain_hash (a : t)
            (receipt_chain_hash : Receipt_chain_hash.t) : t =
          { a with data = { a.data with receipt_chain_hash } }

        let make_zkapp (a : t) = a

        let unmake_zkapp (a : t) = a

        let proved_state (a : t) = a.data.zkapp.proved_state

        let set_proved_state proved_state ({ data = a; hash } : t) : t =
          { data = { a with zkapp = { a.zkapp with proved_state } }; hash }

        let app_state (a : t) = a.data.zkapp.app_state

        let set_app_state app_state ({ data = a; hash } : t) : t =
          { data = { a with zkapp = { a.zkapp with app_state } }; hash }

        let verification_key (a : t) : Verification_key.t =
          a.data.zkapp.verification_key

        let set_verification_key (verification_key : Verification_key.t)
            ({ data = a; hash } : t) : t =
          { data = { a with zkapp = { a.zkapp with verification_key } }; hash }

        let last_sequence_slot (a : t) = a.data.zkapp.last_sequence_slot

        let set_last_sequence_slot last_sequence_slot ({ data = a; hash } : t) :
            t =
          { data = { a with zkapp = { a.zkapp with last_sequence_slot } }
          ; hash
          }

        let sequence_state (a : t) = a.data.zkapp.sequence_state

        let set_sequence_state sequence_state ({ data = a; hash } : t) : t =
          { data = { a with zkapp = { a.zkapp with sequence_state } }; hash }

        let zkapp_uri (a : t) = a.data.zkapp_uri

        let set_zkapp_uri zkapp_uri ({ data = a; hash } : t) : t =
          { data = { a with zkapp_uri }; hash }

        let token_symbol (a : t) = a.data.token_symbol

        let set_token_symbol token_symbol ({ data = a; hash } : t) : t =
          { data = { a with token_symbol }; hash }

        let public_key (a : t) = a.data.public_key

        let set_public_key public_key ({ data = a; hash } : t) : t =
          { data = { a with public_key }; hash }

        let delegate (a : t) = a.data.delegate

        let set_delegate delegate ({ data = a; hash } : t) : t =
          { data = { a with delegate }; hash }

        let nonce (a : t) = a.data.nonce

        let set_nonce nonce ({ data = a; hash } : t) : t =
          { data = { a with nonce }; hash }

        let voting_for (a : t) = a.data.voting_for

        let set_voting_for voting_for ({ data = a; hash } : t) : t =
          { data = { a with voting_for }; hash }

        let permissions (a : t) = a.data.permissions

        let set_permissions permissions ({ data = a; hash } : t) : t =
          { data = { a with permissions }; hash }
      end

      module Opt = struct
        open Zkapp_basic

        type 'a t = (Bool.t, 'a) Flagged_option.t

        let is_some = Flagged_option.is_some

        let map x ~f = Flagged_option.map ~f x

        let or_default ~if_ x ~default =
          if_ (is_some x) ~then_:(Flagged_option.data x) ~else_:default

        let or_exn x =
          with_label "or_exn is_some" (fun () ->
              Bool.Assert.is_true ~pos:__POS__ (is_some x) ) ;
          Flagged_option.data x
      end

      module Call_forest = Zkapp_call_forest.Checked

      module Stack_frame = struct
        type frame = (Token_id.Checked.t, Call_forest.t) Stack_frame.t

        type t = (frame, Stack_frame.Digest.Checked.t Lazy.t) With_hash.t

        let if_ b ~then_:(t1 : t) ~else_:(t2 : t) : t =
          { With_hash.hash =
              lazy
                (Stack_frame.Digest.Checked.if_ b ~then_:(Lazy.force t1.hash)
                   ~else_:(Lazy.force t2.hash) )
          ; data =
              Stack_frame.Checked.if_ Call_forest.if_ b ~then_:t1.data
                ~else_:t2.data
          }

        let caller (t : t) = t.data.caller

        let caller_caller (t : t) = t.data.caller_caller

        let calls (t : t) = t.data.calls

        let of_frame (frame : frame) : t =
          { data = frame
          ; hash =
              lazy
                (Stack_frame.Digest.Checked.create
                   ~hash_zkapp_command:(fun (calls : Call_forest.t) ->
                     calls.hash )
                   frame )
          }

        let make ~caller ~caller_caller ~calls : t =
          Stack_frame.make ~caller ~caller_caller ~calls |> of_frame

        let hash (t : t) : Stack_frame.Digest.Checked.t = Lazy.force t.hash

        let unhash (h : Stack_frame.Digest.Checked.t)
            (frame :
              ( Mina_base.Token_id.Stable.V1.t
              , Mina_base.Zkapp_command.Call_forest.With_hashes.Stable.V1.t )
              Stack_frame.Stable.V1.t
              V.t ) : t =
          with_label "unhash" (fun () ->
              let frame : frame =
                { caller =
                    exists Token_id.typ ~compute:(fun () ->
                        (V.get frame).caller )
                ; caller_caller =
                    exists Token_id.typ ~compute:(fun () ->
                        (V.get frame).caller_caller )
                ; calls =
                    { hash =
                        exists Mina_base.Zkapp_command.Digest.Forest.typ
                          ~compute:(fun () ->
                            (V.get frame).calls
                            |> Mina_base.Zkapp_command.Call_forest.hash )
                    ; data = V.map frame ~f:(fun frame -> frame.calls)
                    }
                }
              in
              let t = of_frame frame in
              Stack_frame.Digest.Checked.Assert.equal (hash (of_frame frame)) h ;
              t )
      end

      module Call_stack = struct
        module Value = struct
          open Mina_base

          type caller = Token_id.t

          type frame =
            ( caller
            , ( Account_update.t
              , Zkapp_command.Digest.Account_update.t
              , Zkapp_command.Digest.Forest.t )
              Zkapp_command.Call_forest.t )
            Stack_frame.t
        end

        type elt = Stack_frame.t

        module Elt = struct
          type t = (Value.frame, Mina_base.Stack_frame.Digest.t) With_hash.t

          let default : unit -> t =
            Memo.unit (fun () : t ->
                With_hash.of_data ~hash_data:Mina_base.Stack_frame.Digest.create
                  ( { caller = Mina_base.Token_id.default
                    ; caller_caller = Mina_base.Token_id.default
                    ; calls = []
                    }
                    : Value.frame ) )
        end

        let hash (type a) (xs : (a, Call_stack_digest.t) With_stack_hash.t list)
            : Call_stack_digest.t =
          match xs with [] -> Call_stack_digest.empty | x :: _ -> x.stack_hash

        type t =
          ( (Elt.t, Call_stack_digest.t) With_stack_hash.t list V.t
          , Call_stack_digest.Checked.t )
          With_hash.t

        let if_ b ~then_:(t : t) ~else_:(e : t) : t =
          { hash = Call_stack_digest.Checked.if_ b ~then_:t.hash ~else_:e.hash
          ; data = V.if_ b ~then_:t.data ~else_:e.data
          }

        let empty = Call_stack_digest.(constant empty)

        let is_empty ({ hash = x; _ } : t) =
          Call_stack_digest.Checked.equal empty x

        let empty () : t = { hash = empty; data = V.create (fun () -> []) }

        let exists_elt (elt_ref : (Value.frame, _) With_hash.t V.t) :
            Stack_frame.t =
          let elt : Stack_frame.frame =
            let calls : Call_forest.t =
              { hash =
                  exists Mina_base.Zkapp_command.Digest.Forest.typ
                    ~compute:(fun () ->
                      (V.get elt_ref).data.calls
                      |> Mina_base.Zkapp_command.Call_forest.hash )
              ; data = V.map elt_ref ~f:(fun frame -> frame.data.calls)
              }
            and caller =
              exists Mina_base.Token_id.typ ~compute:(fun () ->
                  (V.get elt_ref).data.caller )
            and caller_caller =
              exists Mina_base.Token_id.typ ~compute:(fun () ->
                  (V.get elt_ref).data.caller_caller )
            in
            { caller; caller_caller; calls }
          in
          Stack_frame.of_frame elt

        let pop_exn ({ hash = h; data = r } : t) : elt * t =
          let hd_r = V.create (fun () -> (V.get r |> List.hd_exn).elt) in
          let tl_r = V.create (fun () -> V.get r |> List.tl_exn) in
          let elt : Stack_frame.t = exists_elt hd_r in
          let stack =
            exists Call_stack_digest.typ ~compute:(fun () -> hash (V.get tl_r))
          in
          let h' =
            Call_stack_digest.Checked.cons (Stack_frame.hash elt) stack
          in
          with_label __LOC__ (fun () ->
              Call_stack_digest.Checked.Assert.equal h h' ) ;
          (elt, { hash = stack; data = tl_r })

        let pop ({ hash = h; data = r } as t : t) : (elt * t) Opt.t =
          let input_is_empty = is_empty t in
          let hd_r =
            V.create (fun () ->
                match V.get r |> List.hd with
                | None ->
                    Elt.default ()
                | Some x ->
                    x.elt )
          in
          let tl_r =
            V.create (fun () -> V.get r |> List.tl |> Option.value ~default:[])
          in
          let elt = exists_elt hd_r in
          let stack =
            exists Call_stack_digest.typ ~compute:(fun () -> hash (V.get tl_r))
          in
          let stack_frame_hash = Stack_frame.hash elt in
          let h' = Call_stack_digest.Checked.cons stack_frame_hash stack in
          with_label __LOC__ (fun () ->
              Boolean.Assert.any
                [ input_is_empty; Call_stack_digest.Checked.equal h h' ] ) ;
          { is_some = Boolean.not input_is_empty
          ; data = (elt, { hash = stack; data = tl_r })
          }

        let read_elt (frame : elt) : Elt.t =
          { hash =
              As_prover.read Mina_base.Stack_frame.Digest.typ
                (Stack_frame.hash frame)
          ; data =
              { calls = V.get frame.data.calls.data
              ; caller = As_prover.read Token_id.typ frame.data.caller
              ; caller_caller =
                  As_prover.read Token_id.typ frame.data.caller_caller
              }
          }

        let push (elt : elt) ~onto:({ hash = h_tl; data = r_tl } : t) : t =
          let h = Call_stack_digest.Checked.cons (Stack_frame.hash elt) h_tl in
          let r =
            V.create
              (fun () : (Elt.t, Call_stack_digest.t) With_stack_hash.t list ->
                let hd = read_elt elt in
                let tl = V.get r_tl in
                { With_stack_hash.stack_hash =
                    As_prover.read Call_stack_digest.typ h
                ; elt = hd
                }
                :: tl )
          in
          { hash = h; data = r }
      end

      module Amount = struct
        type t = Amount.Checked.t

        type unsigned = t

        module Signed = struct
          type t = Amount.Signed.Checked.t

          let equal t t' = run_checked (Amount.Signed.Checked.equal t t')

          let if_ b ~then_ ~else_ =
            run_checked (Amount.Signed.Checked.if_ b ~then_ ~else_)

          let is_pos (t : t) =
            Sgn.Checked.is_pos
              (run_checked (Currency.Amount.Signed.Checked.sgn t))

          let negate = Amount.Signed.Checked.negate

          let of_unsigned = Amount.Signed.Checked.of_unsigned

          let add_flagged x y =
            run_checked (Amount.Signed.Checked.add_flagged x y)
        end

        let if_ b ~then_ ~else_ =
          run_checked (Amount.Checked.if_ b ~then_ ~else_)

        let equal t t' = run_checked (Amount.Checked.equal t t')

        let zero = Amount.(var_of_t zero)

        let add_flagged x y = run_checked (Amount.Checked.add_flagged x y)

        let add_signed_flagged (x : t) (y : Signed.t) =
          run_checked (Amount.Checked.add_signed_flagged x y)

        let of_constant_fee fee = Amount.var_of_t (Amount.of_fee fee)
      end

      module Token_id = struct
        type t = Token_id.Checked.t

        let if_ = Token_id.Checked.if_

        let equal x y = Token_id.Checked.equal x y

        let default = Token_id.(Checked.constant default)
      end

      module Public_key = struct
        type t = Public_key.Compressed.var

        let if_ b ~then_ ~else_ =
          run_checked (Public_key.Compressed.Checked.if_ b ~then_ ~else_)
      end

      module Protocol_state_precondition = struct
        type t = Zkapp_precondition.Protocol_state.Checked.t
      end

      module Field = Impl.Field

      module Local_state = struct
        type t =
          ( Stack_frame.t
          , Call_stack.t
          , Token_id.t
          , Amount.Signed.t
          , Ledger_hash.var * Sparse_ledger.t V.t
          , Bool.t
          , Transaction_commitment.t
          , Index.t
          , Bool.failure_status_tbl )
          Mina_transaction_logic.Zkapp_command_logic.Local_state.t

        let add_check (t : t) _failure b =
          { t with success = Bool.(t.success &&& b) }

        let update_failure_status_tbl (t : t) _failure_status b =
          add_check
            (t : t)
            Transaction_status.Failure.Update_not_permitted_voting_for b

        let add_new_failure_status_bucket t = t
      end
    end

    type _ Snarky_backendless.Request.t +=
      | Zkapp_proof :
          (Nat.N2.n, Nat.N2.n) Pickles.Proof.t Snarky_backendless.Request.t

    let handle_zkapp_proof (proof : _ Pickles.Proof.t)
        (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | Zkapp_proof ->
          respond (Provide proof)
      | _ ->
          respond Unhandled

    module Single (I : Single_inputs) = struct
      open I

      let { auth_type; is_start = _ } = spec

      module V = Prover_value
      open Impl

      module Inputs = struct
        include Inputs

        module Account = struct
          include Account

          let register_verification_key ({ data = a; _ } : t) =
            match spec.auth_type with
            | Proof ->
                let vk =
                  exists Side_loaded_verification_key.typ ~compute:(fun () ->
                      Option.value_exn
                        (As_prover.Ref.get
                           (Data_as_hash.ref a.zkapp.verification_key.data) )
                          .data )
                in
                let expected_hash =
                  Data_as_hash.hash a.zkapp.verification_key.data
                in
                let actual_hash = Zkapp_account.Checked.digest_vk vk in
                Field.Assert.equal expected_hash actual_hash ;
                Pickles.Side_loaded.in_circuit (side_loaded 0) vk
            | Signature | None_given ->
                ()
        end

        module Controller = struct
          type t = Permissions.Auth_required.Checked.t

          let if_ = Permissions.Auth_required.Checked.if_

          let check =
            match auth_type with
            | Proof ->
                fun ~proof_verifies:_ ~signature_verifies:_ perm ->
                  Permissions.Auth_required.Checked.eval_proof perm
            | Signature | None_given ->
                fun ~proof_verifies:_ ~signature_verifies perm ->
                  Permissions.Auth_required.Checked.eval_no_proof
                    ~signature_verifies perm
        end

        module Ledger = struct
          type t = Ledger_hash.var * Sparse_ledger.t V.t

          type inclusion_proof = (Boolean.var * Field.t) list

          let if_ b ~then_:((xt, rt) : t) ~else_:((xe, re) : t) =
            ( run_checked (Ledger_hash.if_ b ~then_:xt ~else_:xe)
            , V.if_ b ~then_:rt ~else_:re )

          let empty ~depth () : t =
            let t = Sparse_ledger.empty ~depth () in
            ( Ledger_hash.var_of_t (Sparse_ledger.merkle_root t)
            , V.create (fun () -> t) )

          let idx ledger id = Sparse_ledger.find_index_exn ledger id

          let body_id (body : Account_update.Body.Checked.t) =
            let open As_prover in
            Mina_base.Account_id.create
              (read Signature_lib.Public_key.Compressed.typ body.public_key)
              (read Mina_base.Token_id.typ body.token_id)

          let get_account { account_update; _ } ((_root, ledger) : t) =
            let idx =
              V.map ledger ~f:(fun l -> idx l (body_id account_update.data))
            in
            let account =
              exists Mina_base.Account.Checked.Unhashed.typ ~compute:(fun () ->
                  Sparse_ledger.get_exn (V.get ledger) (V.get idx) )
            in
            let account = Account.account_with_hash account in
            let incl =
              exists
                Typ.(
                  list ~length:constraint_constants.ledger_depth
                    (Boolean.typ * field))
                ~compute:(fun () ->
                  List.map
                    (Sparse_ledger.path_exn (V.get ledger) (V.get idx))
                    ~f:(fun x ->
                      match x with
                      | `Left h ->
                          (false, h)
                      | `Right h ->
                          (true, h) ) )
            in
            (account, incl)

          let set_account ((_root, ledger) : t) ((a, incl) : Account.t * _) : t
              =
            ( implied_root a incl |> Ledger_hash.var_of_hash_packed
            , V.map ledger
                ~f:
                  As_prover.(
                    fun ledger ->
                      let a : Mina_base.Account.t =
                        read Mina_base.Account.Checked.Unhashed.typ a.data
                      in
                      let idx = idx ledger (Mina_base.Account.identifier a) in
                      Sparse_ledger.set_exn ledger idx a) )

          let check_inclusion ((root, _) : t) (account, incl) =
            with_label __LOC__ (fun () ->
                Field.Assert.equal
                  (implied_root account incl)
                  (Ledger_hash.var_to_hash_packed root) )

          let check_account public_key token_id
              (({ data = account; _ }, _) : Account.t * _) =
            let is_new =
              run_checked
                (Signature_lib.Public_key.Compressed.Checked.equal
                   account.public_key
                   Signature_lib.Public_key.Compressed.(var_of_t empty) )
            in
            with_label __LOC__ (fun () ->
                Boolean.Assert.any
                  [ is_new
                  ; run_checked
                      (Signature_lib.Public_key.Compressed.Checked.equal
                         public_key account.public_key )
                  ] ) ;
            with_label __LOC__ (fun () ->
                Boolean.Assert.any
                  [ is_new; Token_id.equal token_id account.token_id ] ) ;
            `Is_new is_new
        end

        module Account_update = struct
          type t = account_update

          type call_forest = Call_forest.t

          type 'a or_ignore = 'a Zkapp_basic.Or_ignore.Checked.t

          type transaction_commitment = Transaction_commitment.t

          let balance_change (t : t) = t.account_update.data.balance_change

          let protocol_state_precondition (t : t) =
            t.account_update.data.preconditions.network

          let token_id (t : t) = t.account_update.data.token_id

          let public_key (t : t) = t.account_update.data.public_key

          let caller (t : t) = t.account_update.data.caller

          let account_id (t : t) = Account_id.create (public_key t) (token_id t)

          let use_full_commitment (t : t) =
            t.account_update.data.use_full_commitment

          let increment_nonce (t : t) = t.account_update.data.increment_nonce

          let check_authorization ~commitment
              ~calls:({ hash = calls; _ } : Call_forest.t)
              ({ account_update; control; _ } : t) =
            let proof_verifies =
              match auth_type with
              | Proof ->
                  set_zkapp_input
                    { account_update = (account_update.hash :> Field.t)
                    ; calls = (calls :> Field.t)
                    } ;
                  Boolean.true_
              | Signature | None_given ->
                  Boolean.false_
            in
            let signature_verifies =
              match auth_type with
              | None_given | Proof ->
                  Boolean.false_
              | Signature ->
                  let signature =
                    exists Signature_lib.Schnorr.Chunked.Signature.typ
                      ~compute:(fun () ->
                        match V.get control with
                        | Signature s ->
                            s
                        | None_given ->
                            Signature.dummy
                        | Proof _ ->
                            assert false )
                  in
                  run_checked
                    (let%bind (module S) =
                       Tick.Inner_curve.Checked.Shifted.create ()
                     in
                     signature_verifies
                       ~shifted:(module S)
                       ~payload_digest:commitment signature
                       account_update.data.public_key )
            in
            ( `Proof_verifies proof_verifies
            , `Signature_verifies signature_verifies )

          module Update = struct
            open Zkapp_basic

            type 'a set_or_keep = 'a Set_or_keep.Checked.t

            let timing ({ account_update; _ } : t) : Account.timing set_or_keep
                =
              Set_or_keep.Checked.map
                ~f:Account_update.Update.Timing_info.Checked.to_account_timing
                account_update.data.update.timing

            let app_state ({ account_update; _ } : t) =
              account_update.data.update.app_state

            let verification_key ({ account_update; _ } : t) =
              account_update.data.update.verification_key

            let sequence_events ({ account_update; _ } : t) =
              account_update.data.sequence_events

            let zkapp_uri ({ account_update; _ } : t) =
              account_update.data.update.zkapp_uri

            let token_symbol ({ account_update; _ } : t) =
              account_update.data.update.token_symbol

            let delegate ({ account_update; _ } : t) =
              account_update.data.update.delegate

            let voting_for ({ account_update; _ } : t) =
              account_update.data.update.voting_for

            let permissions ({ account_update; _ } : t) =
              account_update.data.update.permissions
          end

          module Account_precondition = struct
            let nonce ({ account_update; _ } : t) =
              account_update.data.preconditions.account.nonce
          end
        end

        module Set_or_keep = struct
          include Zkapp_basic.Set_or_keep.Checked
        end

        module Global_state = struct
          include Global_state

          let fee_excess { fee_excess; _ } = fee_excess

          let set_fee_excess t fee_excess = { t with fee_excess }

          let ledger { ledger; _ } = ledger

          let set_ledger ~should_update t ledger =
            { t with
              ledger = Ledger.if_ should_update ~then_:ledger ~else_:t.ledger
            }

          let global_slot_since_genesis { protocol_state; _ } =
            protocol_state.global_slot_since_genesis
        end

        module Nonce_precondition = struct
          let is_constant =
            Zkapp_precondition.Numeric.Checked.is_constant
              Zkapp_precondition.Numeric.Tc.nonce
        end

        let with_label ~label f = with_label label f
      end

      module Env = struct
        open Inputs

        type t =
          < account_update : Account_update.t
          ; account : Account.t
          ; ledger : Ledger.t
          ; amount : Amount.t
          ; signed_amount : Amount.Signed.t
          ; bool : Bool.t
          ; token_id : Token_id.t
          ; global_state : Global_state.t
          ; inclusion_proof : (Bool.t * Field.t) list
          ; zkapp_command : Zkapp_command.t
          ; local_state :
              ( Stack_frame.t
              , Call_stack.t
              , Token_id.t
              , Amount.Signed.t
              , Ledger.t
              , Bool.t
              , Transaction_commitment.t
              , Index.t
              , unit )
              Mina_transaction_logic.Zkapp_command_logic.Local_state.t
          ; protocol_state_precondition :
              Zkapp_precondition.Protocol_state.Checked.t
          ; transaction_commitment : Transaction_commitment.t
          ; full_transaction_commitment : Transaction_commitment.t
          ; field : Field.t
          ; failure : unit >
      end

      include Mina_transaction_logic.Zkapp_command_logic.Make (Inputs)

      let perform (type r)
          (eff : (r, Env.t) Mina_transaction_logic.Zkapp_command_logic.Eff.t) :
          r =
        match eff with
        | Check_protocol_state_precondition
            (protocol_state_predicate, global_state) ->
            Zkapp_precondition.Protocol_state.Checked.check
              protocol_state_predicate global_state.protocol_state
        | Check_account_precondition
            ({ account_update; _ }, account, new_account, local_state) ->
            let local_state = ref local_state in
            let check failure b =
              local_state := Inputs.Local_state.add_check !local_state failure b
            in
            Zkapp_precondition.Account.Checked.check ~new_account ~check
              account_update.data.preconditions.account account.data ;
            !local_state
        | Init_account { account_update = { account_update; _ }; account } ->
            let account' : Account.Checked.Unhashed.t =
              { account.data with
                public_key = account_update.data.public_key
              ; token_id = account_update.data.token_id
              }
            in
            Inputs.Account.account_with_hash account'
    end

    let check_protocol_state ~pending_coinbase_stack_init
        ~pending_coinbase_stack_before ~pending_coinbase_stack_after state_body
        =
      [%with_label "Compute pending coinbase stack"]
        (let%bind state_body_hash =
           Mina_state.Protocol_state.Body.hash_checked state_body
         in
         let%bind computed_pending_coinbase_stack_after =
           Pending_coinbase.Stack.Checked.push_state state_body_hash
             pending_coinbase_stack_init
         in
         [%with_label "Check pending coinbase stack"]
           (let%bind correct_coinbase_target_stack =
              Pending_coinbase.Stack.equal_var
                computed_pending_coinbase_stack_after
                pending_coinbase_stack_after
            in
            let%bind valid_init_state =
              (* Stack update is performed once per scan state tree and the
                 following is true only for the first transaction per block per
                 tree*)
              let%bind equal_source =
                Pending_coinbase.Stack.equal_var pending_coinbase_stack_init
                  pending_coinbase_stack_before
              in
              (*for the rest, both source and target are the same*)
              let%bind equal_source_with_state =
                Pending_coinbase.Stack.equal_var
                  computed_pending_coinbase_stack_after
                  pending_coinbase_stack_before
              in
              Boolean.(equal_source ||| equal_source_with_state)
            in
            Boolean.Assert.all
              [ correct_coinbase_target_stack; valid_init_state ] ) )

    let main ?(witness : Witness.t option) (spec : Spec.t) ~constraint_constants
        (statement : Statement.With_sok.Checked.t) =
      let open Impl in
      run_checked (dummy_constraints ()) ;
      let ( ! ) x = Option.value_exn x in
      let state_body =
        exists (Mina_state.Protocol_state.Body.typ ~constraint_constants)
          ~compute:(fun () -> !witness.state_body)
      in
      let pending_coinbase_stack_init =
        exists Pending_coinbase.Stack.typ ~compute:(fun () ->
            !witness.init_stack )
      in
      let module V = Prover_value in
      run_checked
        (check_protocol_state ~pending_coinbase_stack_init
           ~pending_coinbase_stack_before:
             statement.source.pending_coinbase_stack
           ~pending_coinbase_stack_after:statement.target.pending_coinbase_stack
           state_body ) ;
      let init :
          Global_state.t
          * _ Mina_transaction_logic.Zkapp_command_logic.Local_state.t =
        let g : Global_state.t =
          { ledger =
              ( statement.source.ledger
              , V.create (fun () -> !witness.global_ledger) )
          ; fee_excess = Amount.Signed.(Checked.constant zero)
          ; protocol_state =
              Mina_state.Protocol_state.Body.view_checked state_body
          }
        in
        let l : _ Mina_transaction_logic.Zkapp_command_logic.Local_state.t =
          { stack_frame =
              Inputs.Stack_frame.unhash statement.source.local_state.stack_frame
                (V.create (fun () -> !witness.local_state_init.stack_frame))
          ; call_stack =
              { With_hash.hash = statement.source.local_state.call_stack
              ; data = V.create (fun () -> !witness.local_state_init.call_stack)
              }
          ; transaction_commitment =
              statement.source.local_state.transaction_commitment
          ; full_transaction_commitment =
              statement.source.local_state.full_transaction_commitment
          ; token_id = statement.source.local_state.token_id
          ; excess = statement.source.local_state.excess
          ; ledger =
              ( statement.source.local_state.ledger
              , V.create (fun () -> !witness.local_state_init.ledger) )
          ; success = statement.source.local_state.success
          ; account_update_index =
              statement.source.local_state.account_update_index
          ; failure_status_tbl = ()
          }
        in
        (g, l)
      in
      let start_zkapp_command =
        As_prover.Ref.create (fun () -> !witness.start_zkapp_command)
      in
      let zkapp_input = ref None in
      let global, local =
        List.fold_left spec ~init
          ~f:(fun ((_, local) as acc) account_update_spec ->
            let module S = Single (struct
              let constraint_constants = constraint_constants

              let spec = account_update_spec

              let set_zkapp_input x = zkapp_input := Some x
            end) in
            let finish v =
              let open Mina_transaction_logic.Zkapp_command_logic.Start_data in
              let ps =
                V.map v ~f:(function
                  | `Skip ->
                      []
                  | `Start p ->
                      Zkapp_command.zkapp_command p.zkapp_command )
              in
              let h =
                exists Zkapp_command.Digest.Forest.typ ~compute:(fun () ->
                    Zkapp_command.Call_forest.hash (V.get ps) )
              in
              let start_data =
                { Mina_transaction_logic.Zkapp_command_logic.Start_data
                  .zkapp_command = { With_hash.hash = h; data = ps }
                ; memo_hash =
                    exists Field.typ ~compute:(fun () ->
                        match V.get v with
                        | `Skip ->
                            Field.Constant.zero
                        | `Start p ->
                            p.memo_hash )
                }
              in
              let global_state, local_state =
                with_label "apply" (fun () ->
                    S.apply ~constraint_constants
                      ~is_start:
                        ( match account_update_spec.is_start with
                        | `No ->
                            `No
                        | `Yes ->
                            `Yes start_data
                        | `Compute_in_circuit ->
                            `Compute start_data )
                      S.{ perform }
                      acc )
              in
              (* replace any transaction failure with unit value *)
              (global_state, { local_state with failure_status_tbl = () })
            in
            let acc' =
              match account_update_spec.is_start with
              | `No ->
                  let global_state, local_state =
                    S.apply ~constraint_constants ~is_start:`No
                      S.{ perform }
                      acc
                  in
                  (* replace any transaction failure with unit value *)
                  (global_state, { local_state with failure_status_tbl = () })
              | `Compute_in_circuit ->
                  V.create (fun () ->
                      match As_prover.Ref.get start_zkapp_command with
                      | [] ->
                          `Skip
                      | p :: ps ->
                          let should_pop =
                            Mina_base.Zkapp_command.Call_forest.is_empty
                              (V.get local.stack_frame.data.calls.data)
                          in
                          if should_pop then (
                            As_prover.Ref.set start_zkapp_command ps ;
                            `Start p )
                          else `Skip )
                  |> finish
              | `Yes ->
                  as_prover (fun () ->
                      assert (
                        Mina_base.Zkapp_command.Call_forest.is_empty
                          (V.get local.stack_frame.data.calls.data) ) ) ;
                  V.create (fun () ->
                      match As_prover.Ref.get start_zkapp_command with
                      | [] ->
                          assert false
                      | p :: ps ->
                          As_prover.Ref.set start_zkapp_command ps ;
                          `Start p )
                  |> finish
            in
            acc' )
      in
      let local_state_ledger =
        (* The actual output ledger may differ from the one generated by
           transaction logic, because we handle failures differently between
           the two. However, in the case of failure, we never use this ledger:
           it will never be upgraded to the global ledger. If we have such a
           failure, we just pretend we achieved the target hash.
        *)
        Stack_frame.Digest.Checked.if_ local.success
          ~then_:(Inputs.Stack_frame.hash local.stack_frame)
          ~else_:statement.target.local_state.stack_frame
      in
      with_label __LOC__ (fun () ->
          Local_state.Checked.assert_equal statement.target.local_state
            { local with
              stack_frame = local_state_ledger
            ; call_stack = local.call_stack.hash
            ; ledger = fst local.ledger
            } ) ;
      with_label __LOC__ (fun () ->
          run_checked
            (Frozen_ledger_hash.assert_equal (fst global.ledger)
               statement.target.ledger ) ) ;
      with_label __LOC__ (fun () ->
          run_checked
            (Amount.Signed.Checked.assert_equal statement.supply_increase
               Amount.(Signed.Checked.of_unsigned (var_of_t zero)) ) ) ;
      with_label __LOC__ (fun () ->
          run_checked
            (let expected = statement.fee_excess in
             let got =
               { fee_token_l = Token_id.(Checked.constant default)
               ; fee_excess_l = Amount.Signed.Checked.to_fee global.fee_excess
               ; Fee_excess.fee_token_r = Token_id.(Checked.constant default)
               ; fee_excess_r =
                   Amount.Signed.Checked.to_fee (fst init).fee_excess
               }
             in
             Fee_excess.assert_equal_checked expected got ) ) ;
      Stdlib.( ! ) zkapp_input

    (* Horrible hack :( *)
    let witness : Witness.t option ref = ref None

    let rule (type a b c d) ~constraint_constants ~proof_level
        (t : (a, b, c, d) Basic.t_typed) :
        ( a
        , b
        , c
        , d
        , Statement.With_sok.var
        , Statement.With_sok.t
        , unit
        , unit
        , unit
        , unit )
        Pickles.Inductive_rule.t =
      let open Hlist in
      let open Basic in
      let module M = H4.T (Pickles.Tag) in
      let s = Basic.spec t in
      let prev_should_verify =
        match proof_level with
        | Genesis_constants.Proof_level.Full ->
            true
        | _ ->
            false
      in
      let b = Boolean.var_of_value prev_should_verify in
      match t with
      | Proved ->
          { identifier = "proved"
          ; prevs = M.[ side_loaded 0 ]
          ; main =
              (fun { public_input = stmt } ->
                let zkapp_input =
                  main ?witness:!witness s ~constraint_constants stmt
                in
                let proof =
                  Run.exists (Typ.Internal.ref ()) ~request:(fun () ->
                      Zkapp_proof )
                in
                { previous_proof_statements =
                    [ { public_input = Option.value_exn zkapp_input
                      ; proof
                      ; proof_must_verify = b
                      }
                    ]
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; uses_lookup = false
          }
      | Opt_signed_opt_signed ->
          { identifier = "opt_signed-opt_signed"
          ; prevs = M.[]
          ; main =
              (fun { public_input = stmt } ->
                let zkapp_input_opt =
                  main ?witness:!witness s ~constraint_constants stmt
                in
                assert (Option.is_none zkapp_input_opt) ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; uses_lookup = false
          }
      | Opt_signed ->
          { identifier = "opt_signed"
          ; prevs = M.[]
          ; main =
              (fun { public_input = stmt } ->
                let zkapp_input_opt =
                  main ?witness:!witness s ~constraint_constants stmt
                in
                assert (Option.is_none zkapp_input_opt) ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; uses_lookup = false
          }
  end

  type _ Snarky_backendless.Request.t +=
    | Transaction : Transaction_union.t Snarky_backendless.Request.t
    | State_body :
        Mina_state.Protocol_state.Body.Value.t Snarky_backendless.Request.t
    | Init_stack : Pending_coinbase.Stack.t Snarky_backendless.Request.t

  let%snarkydef add_burned_tokens acc_burned_tokens amount
      ~is_coinbase_or_fee_transfer ~update_account =
    let%bind accumulate_burned_tokens =
      Boolean.all [ is_coinbase_or_fee_transfer; Boolean.not update_account ]
    in
    let%bind amt, `Overflow overflow =
      Amount.Checked.add_flagged acc_burned_tokens amount
    in
    let%bind () =
      Boolean.(Assert.any [ not accumulate_burned_tokens; not overflow ])
    in
    Amount.Checked.if_ accumulate_burned_tokens ~then_:amt
      ~else_:acc_burned_tokens

  let%snarkydef apply_tagged_transaction
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      (type shifted)
      (shifted : (module Inner_curve.Checked.Shifted.S with type t = shifted))
      root pending_coinbase_stack_init pending_coinbase_stack_before
      pending_coinbase_after state_body
      ({ signer; signature; payload } as txn : Transaction_union.var) =
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
           payload.common.fee_payer_pk )
    in
    (* Compute transaction kind. *)
    let is_payment = Transaction_union.Tag.Unpacked.is_payment tag in
    let is_mint_tokens = Transaction_union.Tag.Unpacked.is_mint_tokens tag in
    let is_stake_delegation =
      Transaction_union.Tag.Unpacked.is_stake_delegation tag
    in
    let is_create_account =
      Transaction_union.Tag.Unpacked.is_create_account tag
    in
    let is_fee_transfer = Transaction_union.Tag.Unpacked.is_fee_transfer tag in
    let is_coinbase = Transaction_union.Tag.Unpacked.is_coinbase tag in
    let fee_token = payload.common.fee_token in
    let%bind fee_token_default =
      make_checked (fun () ->
          Token_id.(Checked.equal fee_token (Checked.constant default)) )
    in
    let token = payload.body.token_id in
    let%bind token_default =
      make_checked (fun () ->
          Token_id.(Checked.equal token (Checked.constant default)) )
    in
    let%bind () =
      Checked.all_unit
        [ [%with_label
            "Token_locked value is compatible with the transaction kind"]
            (Boolean.Assert.any
               [ Boolean.not payload.body.token_locked; is_create_account ] )
        ; [%with_label "Token_locked cannot be used with the default token"]
            (Boolean.Assert.any
               [ Boolean.not payload.body.token_locked
               ; Boolean.not token_default
               ] )
        ]
    in
    let%bind () = Boolean.Assert.is_true token_default in
    let%bind () =
      [%with_label "Validate tokens"]
        (Checked.all_unit
           [ [%with_label
               "Fee token is default or command allows non-default fee"]
               (Boolean.Assert.any
                  [ fee_token_default
                  ; is_payment
                  ; is_stake_delegation
                  ; is_fee_transfer
                  ] )
           ; (* TODO: Remove this check and update the transaction snark once we
                have an exchange rate mechanism. See issue #4447.
             *)
             [%with_label "Fees in tokens disabled"]
               (Boolean.Assert.is_true fee_token_default)
           ; [%with_label "Command allows default token"]
               Boolean.(
                 Assert.any
                   [ is_payment
                   ; is_stake_delegation
                   ; is_create_account
                   ; is_fee_transfer
                   ; is_coinbase
                   ])
           ] )
    in
    let current_global_slot =
      Mina_state.Protocol_state.Body.consensus_state state_body
      |> Consensus.Data.Consensus_state.global_slot_since_genesis_var
    in
    (* Query predicted failure/success. *)
    let%bind user_command_failure =
      User_command_failure.compute_as_prover ~constraint_constants
        ~txn_global_slot:current_global_slot txn
    in
    let%bind user_command_fails =
      User_command_failure.any user_command_failure
    in
    let fee = payload.common.fee in
    let receiver = Account_id.Checked.create payload.body.receiver_pk token in
    let source = Account_id.Checked.create payload.body.source_pk token in
    (* Information for the fee-payer. *)
    let nonce = payload.common.nonce in
    let fee_payer =
      Account_id.Checked.create payload.common.fee_payer_pk fee_token
    in
    let%bind () =
      [%with_label "Check slot validity"]
        ( Global_slot.Checked.(current_global_slot <= payload.common.valid_until)
        >>= Boolean.Assert.is_true )
    in

    (* Check coinbase stack. Protocol state body is pushed into the Pending
       coinbase stack once per block. For example, consider any two
       transactions in a block. Their pending coinbase stacks would be:

       transaction1: s1 -> t1 = s1+ protocol_state_body + maybe_coinbase
       transaction2: t1 -> t1 + maybe_another_coinbase
         (Note: protocol_state_body is not pushed again)

       However, for each transaction, we need to constrain the protocol state
       body. This is done is by using the stack ([init_stack]) without the
       current protocol state body, pushing the state body to it in every
       transaction snark and checking if it matches the target.
       We also need to constrain the source for the merges to work correctly.
       Basically,

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
           Mina_state.Protocol_state.Body.hash_checked state_body
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
              Boolean.(equal_source ||| equal_source_with_state)
            in
            [%with_label "target stack and valid init state"]
              (Boolean.Assert.all
                 [ correct_coinbase_target_stack; valid_init_state ] ) ) )
    in
    (* Interrogate failure cases. This value is created without constraints;
       the failures should be checked against potential failures to ensure
       consistency.
    *)
    let%bind () =
      [%with_label "A failing user command is a user command"]
        Boolean.(Assert.any [ is_user_command; not user_command_fails ])
    in
    let predicate_deferred =
      (* Account_precondition check is to be performed later if this is true. *)
      is_create_account
    in
    let%bind predicate_result =
      let%bind is_own_account =
        Public_key.Compressed.Checked.equal payload.common.fee_payer_pk
          payload.body.source_pk
      in
      let predicate_result =
        (* TODO: Predicates. *)
        Boolean.false_
      in
      Boolean.(is_own_account ||| predicate_result)
    in
    let%bind () =
      [%with_label "Check account_precondition failure against predicted"]
        (let%bind predicate_failed =
           Boolean.((not predicate_result) &&& not predicate_deferred)
         in
         assert_r1cs
           (predicate_failed :> Field.Var.t)
           (is_user_command :> Field.Var.t)
           (user_command_failure.predicate_failed :> Field.Var.t) )
    in
    let account_creation_amount =
      Amount.Checked.of_fee
        Fee.(var_of_t constraint_constants.account_creation_fee)
    in
    let%bind is_zero_fee = Fee.(equal_var fee (var_of_t zero)) in
    let is_coinbase_or_fee_transfer = Boolean.not is_user_command in
    let%bind can_create_fee_payer_account =
      (* Fee transfers and coinbases may create an account. We check the normal
         invariants to ensure that the account creation fee is paid.
      *)
      let%bind fee_may_be_charged =
        (* If the fee is zero, we do not create the account at all, so we allow
           this through. Otherwise, the fee must be the default.
        *)
        Boolean.(token_default ||| is_zero_fee)
      in
      Boolean.(is_coinbase_or_fee_transfer &&& fee_may_be_charged)
    in
    let burned_tokens = ref Currency.Amount.(var_of_t zero) in
    let%bind root_after_fee_payer_update =
      [%with_label "Update fee payer"]
        (Frozen_ledger_hash.modify_account_send
           ~depth:constraint_constants.ledger_depth root
           ~is_writeable:can_create_fee_payer_account fee_payer
           ~f:(fun ~is_empty_and_writeable account ->
             (* this account is:
                - the fee-payer for payments
                - the fee-payer for stake delegation
                - the fee-payer for account creation
                - the fee-payer for token minting
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
                    [ Boolean.not is_user_command; nonce_matches ] )
             in
             let%bind receipt_chain_hash =
               let current = account.receipt_chain_hash in
               let%bind r =
                 Receipt.Chain_hash.Checked.cons_signed_command_payload
                   (Signed_command_payload payload) current
               in
               Receipt.Chain_hash.Checked.if_ is_user_command ~then_:r
                 ~else_:current
             in
             let permitted_to_send =
               Account.Checked.has_permission ~to_:`Send account
             in
             let permitted_to_receive =
               Account.Checked.has_permission ~to_:`Receive account
             in
             let%bind () =
               [%with_label
                 "Fee payer balance update should be permitted for all commands"]
                 (Boolean.Assert.any
                    [ Boolean.not is_user_command; permitted_to_send ] )
             in
             (*second fee receiver of a fee transfer and fee receiver of a coinbase transaction remain unchanged if
                1. These accounts are not permitted to receive tokens and,
                2. Receiver account that corresponds to first fee receiver of a fee transfer or coinbase receiver of a coinbase transaction, doesn't allow receiving tokens*)
             let%bind update_account =
               let%bind receiving_allowed =
                 Boolean.all
                   [ is_coinbase_or_fee_transfer; permitted_to_receive ]
               in
               Boolean.any [ is_user_command; receiving_allowed ]
             in
             let%bind is_empty_and_writeable =
               (* If this is a coinbase with zero fee, do not create the
                  account, since the fee amount won't be enough to pay for it.
               *)
               Boolean.(all [ is_empty_and_writeable; not is_zero_fee ])
             in
             let%bind should_pay_to_create =
               (* Coinbases and fee transfers may create, or we may be creating
                  a new token account. These are mutually exclusive, so we can
                  encode this as a boolean.
               *)
               let%bind is_create_account =
                 Boolean.(is_create_account &&& not user_command_fails)
               in
               Boolean.(is_empty_and_writeable ||| is_create_account)
             in
             let%bind amount =
               [%with_label "Compute fee payer amount"]
                 (let fee_payer_amount =
                    let sgn = Sgn.Checked.neg_if_true is_user_command in
                    Amount.Signed.create_var
                      ~magnitude:(Amount.Checked.of_fee fee)
                      ~sgn
                  in
                  (* Account creation fee for fee transfers/coinbases. *)
                  let%bind account_creation_fee =
                    let%map magnitude =
                      Amount.Checked.if_ should_pay_to_create
                        ~then_:account_creation_amount
                        ~else_:Amount.(var_of_t zero)
                    in
                    Amount.Signed.create_var ~magnitude ~sgn:Sgn.Checked.neg
                  in
                  Amount.Signed.Checked.(
                    add fee_payer_amount account_creation_fee) )
             in
             let%bind () =
               [%with_label "Burned tokens in fee payer"]
                 (let%map amt =
                    add_burned_tokens !burned_tokens
                      (Amount.Checked.of_fee fee)
                      ~is_coinbase_or_fee_transfer ~update_account
                  in
                  burned_tokens := amt )
             in
             let txn_global_slot = current_global_slot in
             let%bind timing =
               [%with_label "Check fee payer timing"]
                 (let%bind txn_amount =
                    let%bind sgn = Amount.Signed.Checked.sgn amount in
                    let%bind magnitude =
                      Amount.Signed.Checked.magnitude amount
                    in
                    Amount.Checked.if_ (Sgn.Checked.is_neg sgn) ~then_:magnitude
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
                  let%bind `Min_balance _, timing =
                    check_timing ~balance_check ~timed_balance_check ~account
                      ~txn_amount:(Some txn_amount) ~txn_global_slot
                  in
                  Account_timing.if_ update_account ~then_:timing
                    ~else_:account.timing )
             in
             let%bind balance =
               [%with_label "Check payer balance"]
                 (let%bind updated_balance =
                    Balance.Checked.add_signed_amount account.balance amount
                  in
                  Balance.Checked.if_ update_account ~then_:updated_balance
                    ~else_:account.balance )
             in
             let%map public_key =
               Public_key.Compressed.Checked.if_ is_empty_and_writeable
                 ~then_:(Account_id.Checked.public_key fee_payer)
                 ~else_:account.public_key
             and token_id =
               make_checked (fun () ->
                   Token_id.Checked.if_ is_empty_and_writeable
                     ~then_:(Account_id.Checked.token_id fee_payer)
                     ~else_:account.token_id )
             and delegate =
               Public_key.Compressed.Checked.if_ is_empty_and_writeable
                 ~then_:(Account_id.Checked.public_key fee_payer)
                 ~else_:account.delegate
             in
             { Account.Poly.balance
             ; public_key
             ; token_id
             ; token_permissions = account.token_permissions
             ; token_symbol = account.token_symbol
             ; nonce = next_nonce
             ; receipt_chain_hash
             ; delegate
             ; voting_for = account.voting_for
             ; timing
             ; permissions = account.permissions
             ; zkapp = account.zkapp
             ; zkapp_uri = account.zkapp_uri
             } ) )
    in
    let%bind receiver_increase =
      (* - payments:         payload.body.amount
         - stake delegation: 0
         - account creation: 0
         - token minting:    payload.body.amount
         - coinbase:         payload.body.amount - payload.common.fee
         - fee transfer:     payload.body.amount
      *)
      [%with_label "Compute receiver increase"]
        (let%bind base_amount =
           let%bind zero_transfer =
             Boolean.any [ is_stake_delegation; is_create_account ]
           in
           Amount.Checked.if_ zero_transfer
             ~then_:(Amount.var_of_t Amount.zero)
             ~else_:payload.body.amount
         in
         (* The fee for entering the coinbase transaction is paid up front. *)
         let%bind coinbase_receiver_fee =
           Amount.Checked.if_ is_coinbase
             ~then_:(Amount.Checked.of_fee fee)
             ~else_:(Amount.var_of_t Amount.zero)
         in
         Amount.Checked.sub base_amount coinbase_receiver_fee )
    in
    let receiver_overflow = ref Boolean.false_ in
    let receiver_balance_update_permitted = ref Boolean.true_ in
    let%bind root_after_receiver_update =
      [%with_label "Update receiver"]
        (Frozen_ledger_hash.modify_account_recv
           ~depth:constraint_constants.ledger_depth root_after_fee_payer_update
           receiver ~f:(fun ~is_empty_and_writeable account ->
             (* this account is:
                - the receiver for payments
                - the delegated-to account for stake delegation
                - the created account for an account creation
                - the receiver for minted tokens
                - the receiver for a coinbase
                - the first receiver for a fee transfer
             *)
             let permitted_to_receive =
               Account.Checked.has_permission ~to_:`Receive account
             in
             (*Account remains unchanged if balance update is not permitted for payments, fee_transfers and coinbase transactions*)
             let%bind payment_or_internal_command =
               Boolean.any [ is_payment; is_coinbase_or_fee_transfer ]
             in
             let%bind update_account =
               Boolean.any
                 [ Boolean.not payment_or_internal_command
                 ; permitted_to_receive
                 ]
             in
             receiver_balance_update_permitted := permitted_to_receive ;
             let%bind is_empty_failure =
               let%bind must_not_be_empty =
                 Boolean.(is_stake_delegation ||| is_mint_tokens)
               in
               Boolean.(is_empty_and_writeable &&& must_not_be_empty)
             in
             let%bind () =
               [%with_label "Receiver existence failure matches predicted"]
                 (Boolean.Assert.( = ) is_empty_failure
                    user_command_failure.receiver_not_present )
             in
             let%bind is_empty_and_writeable =
               Boolean.(all [ is_empty_and_writeable; not is_empty_failure ])
             in
             let%bind should_pay_to_create =
               Boolean.(is_empty_and_writeable &&& not is_create_account)
             in
             let%bind () =
               [%with_label
                 "Check whether creation fails due to a non-default token"]
                 (let%bind token_should_not_create =
                    Boolean.(should_pay_to_create &&& Boolean.not token_default)
                  in
                  let%bind token_cannot_create =
                    Boolean.(token_should_not_create &&& is_user_command)
                  in
                  let%bind () =
                    [%with_label
                      "Check that account creation is paid in the default \
                       token for non-user-commands"]
                      ((* This expands to
                          [token_should_not_create =
                            token_should_not_create && is_user_command]
                          which is
                          - [token_should_not_create = token_should_not_create]
                            (ie. always satisfied) for user commands
                          - [token_should_not_create = false] for coinbases/fee
                            transfers.
                       *)
                       Boolean.Assert.( = ) token_should_not_create
                         token_cannot_create )
                  in
                  [%with_label "equal token_cannot_create"]
                    (Boolean.Assert.( = ) token_cannot_create
                       user_command_failure.token_cannot_create ) )
             in
             let%bind balance =
               (* [receiver_increase] will be zero in the stake delegation
                  case.
               *)
               let%bind receiver_amount =
                 let%bind account_creation_amount =
                   Amount.Checked.if_ should_pay_to_create
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
                        user_command_failure.amount_insufficient_to_create )
                 in
                 Currency.Amount.Checked.if_ user_command_fails
                   ~then_:Amount.(var_of_t zero)
                   ~else_:amount_for_new_account
               in

               (* NOTE: Instead of capturing this as part of the user command
                  failures, we capture it inline here and bubble it out to a
                  reference. This behavior is still in line with the
                  out-of-snark transaction logic.

                  Updating [user_command_fails] to include this value from here
                  onwards will ensure that we do not update the source or
                  receiver accounts. The only places where [user_command_fails]
                  may have already affected behaviour are
                  * when the fee-payer is paying the account creation fee, and
                  * when a new token is created.
                  In both of these, this account is new, and will have a
                  balance of 0, so we can guarantee that there is no overflow.
               *)
               let%bind balance, `Overflow overflow =
                 Balance.Checked.add_amount_flagged account.balance
                   receiver_amount
               in
               let%bind () =
                 [%with_label "Overflow error only occurs in user commands"]
                   Boolean.(Assert.any [ is_user_command; not overflow ])
               in
               receiver_overflow := overflow ;
               Balance.Checked.if_ overflow ~then_:account.balance
                 ~else_:balance
             in
             let%bind () =
               [%with_label "Burned tokens in receiver"]
                 (let%map amt =
                    add_burned_tokens !burned_tokens receiver_increase
                      ~is_coinbase_or_fee_transfer
                      ~update_account:permitted_to_receive
                  in
                  burned_tokens := amt )
             in
             let%bind user_command_fails =
               Boolean.(!receiver_overflow ||| user_command_fails)
             in
             let%bind is_empty_and_writeable =
               (* Do not create a new account if the user command will fail or if receiving is not permitted *)
               Boolean.all
                 [ is_empty_and_writeable
                 ; Boolean.not user_command_fails
                 ; update_account
                 ]
             in
             let%bind balance =
               Balance.Checked.if_ update_account ~then_:balance
                 ~else_:account.balance
             in
             let%bind may_delegate =
               (* Only default tokens may participate in delegation. *)
               Boolean.(is_empty_and_writeable &&& token_default)
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
               make_checked (fun () ->
                   Token_id.Checked.if_ is_empty_and_writeable ~then_:token
                     ~else_:account.token_id )
             and token_owner =
               (* TODO: Delete token permissions *)
               Boolean.if_ is_empty_and_writeable ~then_:Boolean.false_
                 ~else_:account.token_permissions.token_owner
             and token_locked =
               Boolean.if_ is_empty_and_writeable
                 ~then_:payload.body.token_locked
                 ~else_:account.token_permissions.token_locked
             in
             { Account.Poly.balance
             ; public_key
             ; token_id
             ; token_permissions =
                 { Token_permissions.token_owner; token_locked }
             ; token_symbol = account.token_symbol
             ; nonce = account.nonce
             ; receipt_chain_hash = account.receipt_chain_hash
             ; delegate
             ; voting_for = account.voting_for
             ; timing = account.timing
             ; permissions = account.permissions
             ; zkapp = account.zkapp
             ; zkapp_uri = account.zkapp_uri
             } ) )
    in
    let%bind user_command_fails =
      Boolean.(!receiver_overflow ||| user_command_fails)
    in
    let%bind fee_payer_is_source = Account_id.Checked.equal fee_payer source in
    let%bind root_after_source_update =
      [%with_label "Update source"]
        (Frozen_ledger_hash.modify_account_send
           ~depth:constraint_constants.ledger_depth
           ~is_writeable:
             (* [modify_account_send] does this failure check for us. *)
             user_command_failure.source_not_present root_after_receiver_update
           source ~f:(fun ~is_empty_and_writeable account ->
             (* this account is:
                - the source for payments
                - the delegator for stake delegation
                - the token owner for account creation
                - the token owner for token minting
                - the fee-receiver for a coinbase
                - the second receiver for a fee transfer
             *)
             let%bind () =
               [%with_label "Check source presence failure matches predicted"]
                 (Boolean.Assert.( = ) is_empty_and_writeable
                    user_command_failure.source_not_present )
             in
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
                  [%with_label "Check num_failures"]
                    (assert_r1cs not_fee_payer_is_source num_failures
                       num_failures ) )
             in
             let permitted_to_update_delegate =
               Account.Checked.has_permission ~to_:`Set_delegate account
             in
             let permitted_to_send =
               Account.Checked.has_permission ~to_:`Send account
             in
             let permitted_to_receive =
               Account.Checked.has_permission ~to_:`Receive account
             in
             (*Account remains unchanged if not permitted to send, receive, or set delegate*)
             let%bind payment_permitted =
               Boolean.all
                 [ is_payment
                 ; permitted_to_send
                 ; !receiver_balance_update_permitted
                 ]
             in
             let%bind update_account =
               let%bind delegation_permitted =
                 Boolean.all
                   [ is_stake_delegation; permitted_to_update_delegate ]
               in
               let%bind fee_receiver_update_permitted =
                 Boolean.all
                   [ is_coinbase_or_fee_transfer; permitted_to_receive ]
               in
               Boolean.any
                 [ payment_permitted
                 ; delegation_permitted
                 ; fee_receiver_update_permitted
                 ]
             in
             let%bind amount =
               (* Only payments should affect the balance at this stage. *)
               if_ payment_permitted ~typ:Amount.typ ~then_:payload.body.amount
                 ~else_:Amount.(var_of_t zero)
             in
             let txn_global_slot = current_global_slot in
             let%bind timing =
               [%with_label "Check source timing"]
                 (let balance_check ok =
                    [%with_label
                      "Check source balance failure matches predicted"]
                      (Boolean.Assert.( = ) ok
                         (Boolean.not
                            user_command_failure.source_insufficient_balance ) )
                  in
                  let timed_balance_check ok =
                    [%with_label
                      "Check source timed balance failure matches predicted"]
                      (let%bind not_ok =
                         Boolean.(
                           (not ok)
                           &&& not
                                 user_command_failure
                                   .source_insufficient_balance)
                       in
                       Boolean.Assert.( = ) not_ok
                         user_command_failure.source_bad_timing )
                  in
                  let%bind `Min_balance _, timing =
                    check_timing ~balance_check ~timed_balance_check ~account
                      ~txn_amount:(Some amount) ~txn_global_slot
                  in
                  Account_timing.if_ update_account ~then_:timing
                    ~else_:account.timing )
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
                    user_command_failure.source_insufficient_balance )
             in
             let%map delegate =
               let%bind may_delegate =
                 Boolean.all [ is_stake_delegation; update_account ]
               in
               Public_key.Compressed.Checked.if_ may_delegate
                 ~then_:(Account_id.Checked.public_key receiver)
                 ~else_:account.delegate
             in
             (* NOTE: Technically we update the account here even in the case
                of [user_command_fails], but we throw the resulting hash away
                in [final_root] below, so it shouldn't matter.
             *)
             { Account.Poly.balance
             ; public_key = account.public_key
             ; token_id = account.token_id
             ; token_permissions = account.token_permissions
             ; token_symbol = account.token_symbol
             ; nonce = account.nonce
             ; receipt_chain_hash = account.receipt_chain_hash
             ; delegate
             ; voting_for = account.voting_for
             ; timing
             ; permissions = account.permissions
             ; zkapp = account.zkapp
             ; zkapp_uri = account.zkapp_uri
             } ) )
    in
    let%bind fee_excess =
      (* - payments:         payload.common.fee
         - stake delegation: payload.common.fee
         - account creation: payload.common.fee
         - token minting:    payload.common.fee
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
           let%bind fee_transfer_excess, fee_transfer_excess_overflowed =
             let%map magnitude, `Overflow overflowed =
               Checked.(
                 add_flagged payload.body.amount (of_fee payload.common.fee))
             in
             (Signed.create_var ~magnitude ~sgn:Sgn.Checked.neg, overflowed)
           in
           let%bind () =
             (* TODO: Reject this in txn pool before fees-in-tokens. *)
             [%with_label "Fee excess does not overflow"]
               Boolean.(
                 Assert.any
                   [ not is_fee_transfer; not fee_transfer_excess_overflowed ])
           in
           Signed.Checked.if_ is_fee_transfer ~then_:fee_transfer_excess
             ~else_:user_command_excess )
    in
    let%bind supply_increase =
      [%with_label "Calculate supply increase"]
        (let%bind expected_supply_increase =
           Amount.Signed.Checked.if_ is_coinbase
             ~then_:(Amount.Signed.Checked.of_unsigned payload.body.amount)
             ~else_:Amount.(Signed.Checked.of_unsigned (var_of_t zero))
         in
         let%bind amt, `Overflow overflow =
           Amount.Signed.Checked.(
             add_flagged expected_supply_increase
               (negate (of_unsigned !burned_tokens)))
         in
         let%map () = Boolean.Assert.is_true (Boolean.not overflow) in
         amt )
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

  (* spec for [main statement]:
     constraints pass iff there exists
        t : Tagged_transaction.t
     such that
     - applying [t] to ledger with merkle hash [l1] results in ledger with merkle hash [l2].
     - applying [t] to [pc.source] with results in pending coinbase stack [pc.target]
     - t has fee excess equal to [fee_excess]
     - t has supply increase equal to [supply_increase]
       where statement includes
        l1 : Frozen_ledger_hash.t,
        l2 : Frozen_ledger_hash.t,
        fee_excess : Amount.Signed.t,
        supply_increase : Amount.Signed.t
        pc: Pending_coinbase_stack_state.t
  *)
  let%snarkydef main ~constraint_constants
      (statement : Statement.With_sok.Checked.t) =
    let%bind () = dummy_constraints () in
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
        (Mina_state.Protocol_state.Body.typ ~constraint_constants)
        ~request:(As_prover.return State_body)
    in
    let%bind root_after, fee_excess, supply_increase =
      apply_tagged_transaction ~constraint_constants
        (module Shifted)
        statement.source.ledger pending_coinbase_init
        statement.source.pending_coinbase_stack
        statement.target.pending_coinbase_stack state_body t
    in
    let%bind fee_excess =
      (* Use the default token for the fee excess if it is zero.
         This matches the behaviour of [Fee_excess.rebalance], which allows
         [verify_complete_merge] to verify a proof without knowledge of the
         particular fee tokens used.
      *)
      let%bind fee_excess_zero =
        Amount.Signed.Checked.equal fee_excess
          Amount.Signed.(Checked.constant zero)
      in
      let%map fee_token_l =
        make_checked (fun () ->
            Token_id.Checked.if_ fee_excess_zero
              ~then_:Token_id.(Checked.constant default)
              ~else_:t.payload.common.fee_token )
      in
      { Fee_excess.fee_token_l
      ; fee_excess_l = Amount.Signed.Checked.to_fee fee_excess
      ; fee_token_r = Token_id.(Checked.constant default)
      ; fee_excess_r = Fee.Signed.(Checked.constant zero)
      }
    in
    let%bind () =
      [%with_label "local state check"]
        (make_checked (fun () ->
             Local_state.Checked.assert_equal statement.source.local_state
               statement.target.local_state ) )
    in
    Checked.all_unit
      [ [%with_label "equal roots"]
          (Frozen_ledger_hash.assert_equal root_after statement.target.ledger)
      ; [%with_label "equal supply_increases"]
          (Currency.Amount.Signed.Checked.assert_equal supply_increase
             statement.supply_increase )
      ; [%with_label "equal fee excesses"]
          (Fee_excess.assert_equal_checked fee_excess statement.fee_excess)
      ]

  let rule ~constraint_constants : _ Pickles.Inductive_rule.t =
    { identifier = "transaction"
    ; prevs = []
    ; main =
        (fun { public_input = x } ->
          Run.run_checked (main ~constraint_constants x) ;
          { previous_proof_statements = []
          ; public_output = ()
          ; auxiliary_output = ()
          } )
    ; uses_lookup = false
    }

  let transaction_union_handler handler (transaction : Transaction_union.t)
      (state_body : Mina_state.Protocol_state.Body.Value.t)
      (init_stack : Pending_coinbase.Stack.t) :
      Snarky_backendless.Request.request -> _ =
   fun (With { request; respond } as r) ->
    match request with
    | Transaction ->
        respond (Provide transaction)
    | State_body ->
        respond (Provide state_body)
    | Init_stack ->
        respond (Provide init_stack)
    | _ ->
        handler r
end

module Transition_data = struct
  type t =
    { proof : Proof_type.t
    ; supply_increase : (Amount.t, Sgn.t) Signed_poly.t
    ; fee_excess : Fee_excess.t
    ; sok_digest : Sok_message.Digest.t
    ; pending_coinbase_stack_state : Pending_coinbase_stack_state.t
    }
  [@@deriving fields]
end

module Merge = struct
  open Tick

  type _ Snarky_backendless.Request.t +=
    | Statements_to_merge :
        (Statement.With_sok.t * Statement.With_sok.t)
        Snarky_backendless.Request.t
    | Proofs_to_merge :
        ( (Nat.N2.n, Nat.N2.n) Pickles.Proof.t
        * (Nat.N2.n, Nat.N2.n) Pickles.Proof.t )
        Snarky_backendless.Request.t

  let handle
      ((left_stmt, right_stmt) : Statement.With_sok.t * Statement.With_sok.t)
      ((left_proof, right_proof) : _ Pickles.Proof.t * _ Pickles.Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Statements_to_merge ->
        respond (Provide (left_stmt, right_stmt))
    | Proofs_to_merge ->
        respond (Provide (left_proof, right_proof))
    | _ ->
        respond Unhandled

  (* spec for [main top_hash]:
     constraints pass iff
     there exist digest, s1, s3, fee_excess, supply_increase pending_coinbase_stack12.source, pending_coinbase_stack23.target, tock_vk such that
     H(digest,s1, s3, pending_coinbase_stack12.source, pending_coinbase_stack23.target, fee_excess, supply_increase, tock_vk) = top_hash,
     verify_transition tock_vk _ s1 s2 pending_coinbase_stack12.source, pending_coinbase_stack12.target is true
     verify_transition tock_vk _ s2 s3 pending_coinbase_stack23.source, pending_coinbase_stack23.target is true
  *)
  let%snarkydef main (s : Statement.With_sok.Checked.t) =
    let%bind s1, s2 =
      exists
        Typ.(Statement.With_sok.typ * Statement.With_sok.typ)
        ~request:(As_prover.return Statements_to_merge)
    in
    let%bind fee_excess =
      Fee_excess.combine_checked s1.Statement.fee_excess s2.Statement.fee_excess
    in
    let%bind () =
      with_label __LOC__
        (let%bind valid_pending_coinbase_stack_transition =
           Pending_coinbase.Stack.Checked.check_merge
             ~transition1:
               ( s1.source.pending_coinbase_stack
               , s1.target.pending_coinbase_stack )
             ~transition2:
               ( s2.source.pending_coinbase_stack
               , s2.target.pending_coinbase_stack )
         in
         Boolean.Assert.is_true valid_pending_coinbase_stack_transition )
    in
    let%bind supply_increase =
      Amount.Signed.Checked.add s1.supply_increase s2.supply_increase
    in
    let%bind () =
      make_checked (fun () ->
          Local_state.Checked.assert_equal s.source.local_state
            s1.source.local_state ;
          Local_state.Checked.assert_equal s.target.local_state
            s2.target.local_state )
    in
    let%map () =
      Checked.all_unit
        [ [%with_label "equal fee excesses"]
            (Fee_excess.assert_equal_checked fee_excess s.fee_excess)
        ; [%with_label "equal supply increases"]
            (Amount.Signed.Checked.assert_equal supply_increase
               s.supply_increase )
        ; [%with_label "equal source ledger hashes"]
            (Frozen_ledger_hash.assert_equal s.source.ledger s1.source.ledger)
        ; [%with_label "equal target, source ledger hashes"]
            (Frozen_ledger_hash.assert_equal s1.target.ledger s2.source.ledger)
        ; [%with_label "equal target ledger hashes"]
            (Frozen_ledger_hash.assert_equal s2.target.ledger s.target.ledger)
        ]
    in
    (s1, s2)

  let rule ~proof_level self : _ Pickles.Inductive_rule.t =
    let prev_should_verify =
      match proof_level with
      | Genesis_constants.Proof_level.Full ->
          true
      | _ ->
          false
    in
    let b = Boolean.var_of_value prev_should_verify in
    { identifier = "merge"
    ; prevs = [ self; self ]
    ; main =
        (fun { public_input = x } ->
          let s1, s2 = Run.run_checked (main x) in
          let p1, p2 =
            Run.exists
              Typ.(Internal.ref () * Internal.ref ())
              ~request:(fun () -> Proofs_to_merge)
          in
          { previous_proof_statements =
              [ { public_input = s1; proof = p1; proof_must_verify = b }
              ; { public_input = s2; proof = p2; proof_must_verify = b }
              ]
          ; public_output = ()
          ; auxiliary_output = ()
          } )
    ; uses_lookup = false
    }
end

open Pickles_types

type tag =
  ( Statement.With_sok.Checked.t
  , Statement.With_sok.t
  , Nat.N2.n
  , Nat.N5.n )
  Pickles.Tag.t

let time lab f =
  let start = Time.now () in
  let x = f () in
  let stop = Time.now () in
  printf "%s: %s\n%!" lab (Time.Span.to_string_hum (Time.diff stop start)) ;
  x

let system ~proof_level ~constraint_constants =
  time "Transaction_snark.system" (fun () ->
      Pickles.compile () ~cache:Cache_dir.cache
        ~public_input:(Input Statement.With_sok.typ) ~auxiliary_typ:Typ.unit
        ~branches:(module Nat.N5)
        ~max_proofs_verified:(module Nat.N2)
        ~name:"transaction-snark"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self ->
          let zkapp_command x =
            Base.Zkapp_command_snark.rule ~constraint_constants ~proof_level x
          in
          [ Base.rule ~constraint_constants
          ; Merge.rule ~proof_level self
          ; zkapp_command Opt_signed_opt_signed
          ; zkapp_command Opt_signed
          ; zkapp_command Proved
          ] ) )

module Verification = struct
  module type S = sig
    val tag : tag

    val verify : (t * Sok_message.t) list -> bool Async.Deferred.t

    val id : Pickles.Verification_key.Id.t Lazy.t

    val verification_key : Pickles.Verification_key.t Lazy.t

    val verify_against_digest : t -> bool Async.Deferred.t

    val constraint_system_digests : (string * Md5_lib.t) list Lazy.t
  end
end

module type S = sig
  include Verification.S

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val cache_handle : Pickles.Cache_handle.t

  val of_non_zkapp_command_transaction :
       statement:Statement.With_sok.t
    -> init_stack:Pending_coinbase.Stack.t
    -> Transaction.Valid.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t Async.Deferred.t

  val of_user_command :
       statement:Statement.With_sok.t
    -> init_stack:Pending_coinbase.Stack.t
    -> Signed_command.With_valid_signature.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t Async.Deferred.t

  val of_fee_transfer :
       statement:Statement.With_sok.t
    -> init_stack:Pending_coinbase.Stack.t
    -> Fee_transfer.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t Async.Deferred.t

  val of_zkapp_command_segment_exn :
       statement:Statement.With_sok.t
    -> witness:Zkapp_command_segment.Witness.t
    -> spec:Zkapp_command_segment.Basic.t
    -> t Async.Deferred.t

  val merge :
    t -> t -> sok_digest:Sok_message.Digest.t -> t Async.Deferred.Or_error.t
end

let check_transaction_union ?(preeval = false) ~constraint_constants
    ~supply_increase sok_message source target init_stack
    pending_coinbase_stack_state transaction state_body handler =
  if preeval then failwith "preeval currently disabled" ;
  let sok_digest = Sok_message.digest sok_message in
  let handler =
    Base.transaction_union_handler handler transaction state_body init_stack
  in
  let statement : Statement.With_sok.t =
    Statement.Poly.with_empty_local_state ~source ~target ~supply_increase
      ~pending_coinbase_stack_state
      ~fee_excess:(Transaction_union.fee_excess transaction)
      ~sok_digest
  in
  let open Tick in
  ignore
    ( Or_error.ok_exn
        (run_and_check
           (handle
              (Checked.map ~f:As_prover.return
                 (let open Checked in
                 exists Statement.With_sok.typ
                   ~compute:(As_prover.return statement)
                 >>= Base.main ~constraint_constants) )
              handler ) )
      : unit )

let check_transaction ?preeval ~constraint_constants ~sok_message ~source
    ~target ~init_stack ~pending_coinbase_stack_state ~zkapp_account1:_
    ~zkapp_account2:_ ~supply_increase
    (transaction_in_block : Transaction.Valid.t Transaction_protocol_state.t)
    handler =
  let transaction =
    Transaction_protocol_state.transaction transaction_in_block
  in
  let state_body = Transaction_protocol_state.block_data transaction_in_block in
  match to_preunion (Transaction.forget transaction) with
  | `Zkapp_command _ ->
      failwith
        "Called non-account_update transaction with zkapp_command transaction"
  | `Transaction t ->
      check_transaction_union ?preeval ~constraint_constants ~supply_increase
        sok_message source target init_stack pending_coinbase_stack_state
        (Transaction_union.of_transaction t)
        state_body handler

let check_user_command ~constraint_constants ~sok_message ~source ~target
    ~init_stack ~pending_coinbase_stack_state ~supply_increase t_in_block
    handler =
  let user_command = Transaction_protocol_state.transaction t_in_block in
  check_transaction ~constraint_constants ~sok_message ~source ~target
    ~init_stack ~pending_coinbase_stack_state ~zkapp_account1:None
    ~zkapp_account2:None ~supply_increase
    { t_in_block with transaction = Command (Signed_command user_command) }
    handler

let generate_transaction_union_witness ?(preeval = false) ~constraint_constants
    ~supply_increase sok_message source target transaction_in_block init_stack
    pending_coinbase_stack_state handler =
  if preeval then failwith "preeval currently disabled" ;
  let transaction =
    Transaction_protocol_state.transaction transaction_in_block
  in
  let state_body = Transaction_protocol_state.block_data transaction_in_block in
  let sok_digest = Sok_message.digest sok_message in
  let handler =
    Base.transaction_union_handler handler transaction state_body init_stack
  in
  let statement : Statement.With_sok.t =
    Statement.Poly.with_empty_local_state ~source ~target ~supply_increase
      ~pending_coinbase_stack_state
      ~fee_excess:(Transaction_union.fee_excess transaction)
      ~sok_digest
  in
  let open Tick in
  let main x = handle (Base.main ~constraint_constants x) handler in
  generate_auxiliary_input [ Statement.With_sok.typ ]
    ~return_typ:(Snarky_backendless.Typ.unit ())
    main statement

let generate_transaction_witness ?preeval ~constraint_constants ~sok_message
    ~source ~target ~init_stack ~pending_coinbase_stack_state ~zkapp_account1:_
    ~zkapp_account2:_ ~supply_increase
    (transaction_in_block : Transaction.Valid.t Transaction_protocol_state.t)
    handler =
  match
    to_preunion
      (Transaction.forget
         (Transaction_protocol_state.transaction transaction_in_block) )
  with
  | `Zkapp_command _ ->
      failwith
        "Called non-account_update transaction with zkapp_command transaction"
  | `Transaction t ->
      generate_transaction_union_witness ?preeval ~constraint_constants
        ~supply_increase sok_message source target
        { transaction_in_block with
          transaction = Transaction_union.of_transaction t
        }
        init_stack pending_coinbase_stack_state handler

let verify (ts : (t * _) list) ~key =
  if
    List.for_all ts ~f:(fun ({ statement; _ }, message) ->
        Sok_message.Digest.equal
          (Sok_message.digest message)
          statement.sok_digest )
  then
    Pickles.verify
      (module Nat.N2)
      (module Statement.With_sok)
      key
      (List.map ts ~f:(fun ({ statement; proof }, _) -> (statement, proof)))
  else Async.return false

let constraint_system_digests ~constraint_constants () =
  let digest = Tick.R1CS_constraint_system.digest in
  [ ( "transaction-merge"
    , digest
        Merge.(
          Tick.constraint_system ~exposing:[ Statement.With_sok.typ ]
            ~return_typ:(Snarky_backendless.Typ.unit ()) (fun x ->
              let open Tick in
              Checked.map ~f:ignore @@ main x )) )
  ; ( "transaction-base"
    , digest
        Base.(
          Tick.constraint_system ~exposing:[ Statement.With_sok.typ ]
            ~return_typ:(Snarky_backendless.Typ.unit ())
            (main ~constraint_constants)) )
  ]

type local_state =
  ( Stack_frame.value
  , Stack_frame.value list
  , Token_id.t
  , Currency.Amount.Signed.t
  , Sparse_ledger.t
  , bool
  , Zkapp_command.Transaction_commitment.t
  , Mina_numbers.Index.t
  , Transaction_status.Failure.Collection.t )
  Mina_transaction_logic.Zkapp_command_logic.Local_state.t

type global_state = Sparse_ledger.Global_state.t

module Zkapp_command_intermediate_state = struct
  type state = { global : global_state; local : local_state }

  type t =
    { kind : [ `Same | `New | `Two_new ]
    ; spec : Zkapp_command_segment.Basic.t
    ; state_before : state
    ; state_after : state
    }
end

(** [group_by_zkapp_command_rev zkapp_commands stmtss] identifies before/after pairs of
    statements, corresponding to zkapp_command in [zkapp_commands] which minimize the
    number of snark proofs needed to prove all of the zkapp_command.

    This function is intended to take the zkapp_command from multiple transactions as
    its input, which may be converted from a [Zkapp_command.t list] using
    [List.map ~f:Zkapp_command.zkapp_command]. The [stmtss] argument should be a list of
    the same length, with 1 more state than the number of zkapp_command for each
    transaction.

    For example, two transactions made up of zkapp_command [[p1; p2; p3]] and
    [[p4; p5]] should have the statements [[[s0; s1; s2; s3]; [s3; s4; s5]]],
    where each [s_n] is the state after applying [p_n] on top of [s_{n-1}], and
    where [s0] is the initial state before any of the transactions have been
    applied.

    Each pair is also identified with one of [`Same], [`New], or [`Two_new],
    indicating that the next one ([`New]) or next two ([`Two_new]) [Zkapp_command.t]s
    will need to be passed as part of the snark witness while applying that
    pair.
*)
let group_by_zkapp_command_rev (zkapp_commands : Account_update.t list list)
    (stmtss : (global_state * local_state) list list) :
    Zkapp_command_intermediate_state.t list =
  let intermediate_state ~kind ~spec ~before ~after =
    { Zkapp_command_intermediate_state.kind
    ; spec
    ; state_before = { global = fst before; local = snd before }
    ; state_after = { global = fst after; local = snd after }
    }
  in
  let rec group_by_zkapp_command_rev
      (zkapp_commands : Account_update.t list list) stmtss acc =
    match (zkapp_commands, stmtss) with
    | ([] | [ [] ]), [ _ ] ->
        (* We've associated statements with all given zkapp_command. *)
        acc
    | [ [ { authorization = a1; _ } ] ], [ [ before; after ] ] ->
        (* There are no later zkapp_command to pair this one with. Prove it on its
           own.
        *)
        intermediate_state ~kind:`Same
          ~spec:(Zkapp_command_segment.Basic.of_controls [ a1 ])
          ~before ~after
        :: acc
    | [ []; [ { authorization = a1; _ } ] ], [ [ _ ]; [ before; after ] ] ->
        (* This account_update is part of a new transaction, and there are no later
           zkapp_command to pair it with. Prove it on its own.
        *)
        intermediate_state ~kind:`New
          ~spec:(Zkapp_command_segment.Basic.of_controls [ a1 ])
          ~before ~after
        :: acc
    | ( ({ authorization = Proof _ as a1; _ } :: zkapp_command) :: zkapp_commands
      , (before :: (after :: _ as stmts)) :: stmtss ) ->
        (* This account_update contains a proof, don't pair it with other zkapp_command. *)
        group_by_zkapp_command_rev
          (zkapp_command :: zkapp_commands)
          (stmts :: stmtss)
          ( intermediate_state ~kind:`Same
              ~spec:(Zkapp_command_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( []
        :: ({ authorization = Proof _ as a1; _ } :: zkapp_command)
           :: zkapp_commands
      , [ _ ] :: (before :: (after :: _ as stmts)) :: stmtss ) ->
        (* This account_update is part of a new transaction, and contains a proof, don't
           pair it with other zkapp_command.
        *)
        group_by_zkapp_command_rev
          (zkapp_command :: zkapp_commands)
          (stmts :: stmtss)
          ( intermediate_state ~kind:`New
              ~spec:(Zkapp_command_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( ({ authorization = a1; _ }
        :: ({ authorization = Proof _; _ } :: _ as zkapp_command) )
        :: zkapp_commands
      , (before :: (after :: _ as stmts)) :: stmtss ) ->
        (* The next account_update contains a proof, don't pair it with this account_update. *)
        group_by_zkapp_command_rev
          (zkapp_command :: zkapp_commands)
          (stmts :: stmtss)
          ( intermediate_state ~kind:`Same
              ~spec:(Zkapp_command_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( ({ authorization = a1; _ } :: ([] as zkapp_command))
        :: (({ authorization = Proof _; _ } :: _) :: _ as zkapp_commands)
      , (before :: (after :: _ as stmts)) :: stmtss ) ->
        (* The next account_update is in the next transaction and contains a proof,
           don't pair it with this account_update.
        *)
        group_by_zkapp_command_rev
          (zkapp_command :: zkapp_commands)
          (stmts :: stmtss)
          ( intermediate_state ~kind:`Same
              ~spec:(Zkapp_command_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( ({ authorization = (Signature _ | None_given) as a1; _ }
        :: { authorization = (Signature _ | None_given) as a2; _ }
           :: zkapp_command )
        :: zkapp_commands
      , (before :: _ :: (after :: _ as stmts)) :: stmtss ) ->
        (* The next two zkapp_command do not contain proofs, and are within the same
           transaction. Pair them.
           Ok to get "use_full_commitment" of [a1] because neither of them
           contain a proof.
        *)
        group_by_zkapp_command_rev
          (zkapp_command :: zkapp_commands)
          (stmts :: stmtss)
          ( intermediate_state ~kind:`Same
              ~spec:(Zkapp_command_segment.Basic.of_controls [ a1; a2 ])
              ~before ~after
          :: acc )
    | ( []
        :: ({ authorization = a1; _ }
           :: ({ authorization = Proof _; _ } :: _ as zkapp_command) )
           :: zkapp_commands
      , [ _ ] :: (before :: (after :: _ as stmts)) :: stmtss ) ->
        (* This account_update is in the next transaction, and the next account_update contains a
           proof, don't pair it with this account_update.
        *)
        group_by_zkapp_command_rev
          (zkapp_command :: zkapp_commands)
          (stmts :: stmtss)
          ( intermediate_state ~kind:`New
              ~spec:(Zkapp_command_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( []
        :: ({ authorization = (Signature _ | None_given) as a1; _ }
           :: { authorization = (Signature _ | None_given) as a2; _ }
              :: zkapp_command )
           :: zkapp_commands
      , [ _ ] :: (before :: _ :: (after :: _ as stmts)) :: stmtss ) ->
        (* The next two zkapp_command do not contain proofs, and are within the same
           new transaction. Pair them.
           Ok to get "use_full_commitment" of [a1] because neither of them
           contain a proof.
        *)
        group_by_zkapp_command_rev
          (zkapp_command :: zkapp_commands)
          (stmts :: stmtss)
          ( intermediate_state ~kind:`New
              ~spec:(Zkapp_command_segment.Basic.of_controls [ a1; a2 ])
              ~before ~after
          :: acc )
    | ( [ { authorization = (Signature _ | None_given) as a1; _ } ]
        :: ({ authorization = (Signature _ | None_given) as a2; _ }
           :: zkapp_command )
           :: zkapp_commands
      , (before :: _after1) :: (_before2 :: (after :: _ as stmts)) :: stmtss )
      ->
        (* The next two zkapp_command do not contain proofs, and the second is within
           a new transaction. Pair them.
           Ok to get "use_full_commitment" of [a1] because neither of them
           contain a proof.
        *)
        group_by_zkapp_command_rev
          (zkapp_command :: zkapp_commands)
          (stmts :: stmtss)
          ( intermediate_state ~kind:`New
              ~spec:(Zkapp_command_segment.Basic.of_controls [ a1; a2 ])
              ~before ~after
          :: acc )
    | ( []
        :: ({ authorization = a1; _ } :: zkapp_command)
           :: (({ authorization = Proof _; _ } :: _) :: _ as zkapp_commands)
      , [ _ ] :: (before :: ([ after ] as stmts)) :: (_ :: _ as stmtss) ) ->
        (* The next transaction contains a proof, and this account_update is in a new
           transaction, don't pair it with the next account_update.
        *)
        group_by_zkapp_command_rev
          (zkapp_command :: zkapp_commands)
          (stmts :: stmtss)
          ( intermediate_state ~kind:`New
              ~spec:(Zkapp_command_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( []
        :: [ { authorization = (Signature _ | None_given) as a1; _ } ]
           :: ({ authorization = (Signature _ | None_given) as a2; _ }
              :: zkapp_command )
              :: zkapp_commands
      , [ _ ]
        :: [ before; _after1 ] :: (_before2 :: (after :: _ as stmts)) :: stmtss
      ) ->
        (* The next two zkapp_command do not contain proofs, the first is within a
           new transaction, and the second is within another new transaction.
           Pair them.
           Ok to get "use_full_commitment" of [a1] because neither of them
           contain a proof.
        *)
        group_by_zkapp_command_rev
          (zkapp_command :: zkapp_commands)
          (stmts :: stmtss)
          ( intermediate_state ~kind:`Two_new
              ~spec:(Zkapp_command_segment.Basic.of_controls [ a1; a2 ])
              ~before ~after
          :: acc )
    | [ [ { authorization = a1; _ } ] ], (before :: after :: _) :: _ ->
        (* This account_update is the final account_update given. Prove it on its own. *)
        intermediate_state ~kind:`Same
          ~spec:(Zkapp_command_segment.Basic.of_controls [ a1 ])
          ~before ~after
        :: acc
    | ( [] :: [ { authorization = a1; _ } ] :: [] :: _
      , [ _ ] :: (before :: after :: _) :: _ ) ->
        (* This account_update is the final account_update given, in a new transaction. Prove it
           on its own.
        *)
        intermediate_state ~kind:`New
          ~spec:(Zkapp_command_segment.Basic.of_controls [ a1 ])
          ~before ~after
        :: acc
    | _, [] ->
        failwith "group_by_zkapp_command_rev: No statements remaining"
    | ([] | [ [] ]), _ ->
        failwith "group_by_zkapp_command_rev: Unmatched statements remaining"
    | [] :: _, [] :: _ ->
        failwith
          "group_by_zkapp_command_rev: No final statement for current \
           transaction"
    | [] :: _, (_ :: _ :: _) :: _ ->
        failwith
          "group_by_zkapp_command_rev: Unmatched statements for current \
           transaction"
    | [] :: [ _ ] :: _, [ _ ] :: (_ :: _ :: _ :: _) :: _ ->
        failwith
          "group_by_zkapp_command_rev: Unmatched statements for next \
           transaction"
    | [ []; [ _ ] ], [ _ ] :: [ _; _ ] :: _ :: _ ->
        failwith
          "group_by_zkapp_command_rev: Unmatched statements after next \
           transaction"
    | (_ :: _) :: _, ([] | [ _ ]) :: _ | (_ :: _ :: _) :: _, [ _; _ ] :: _ ->
        failwith
          "group_by_zkapp_command_rev: Too few statements remaining for the \
           current transaction"
    | ([] | [ _ ]) :: [] :: _, _ ->
        failwith
          "group_by_zkapp_command_rev: The next transaction has no \
           zkapp_command"
    | [] :: (_ :: _) :: _, _ :: ([] | [ _ ]) :: _
    | [] :: (_ :: _ :: _) :: _, _ :: [ _; _ ] :: _ ->
        failwith
          "group_by_zkapp_command_rev: Too few statements remaining for the \
           next transaction"
    | [ _ ] :: (_ :: _) :: _, _ :: ([] | [ _ ]) :: _ ->
        failwith
          "group_by_zkapp_command_rev: Too few statements remaining for the \
           next transaction"
    | [] :: [ _ ] :: (_ :: _) :: _, _ :: _ :: ([] | [ _ ]) :: _ ->
        failwith
          "group_by_zkapp_command_rev: Too few statements remaining for the \
           transaction after next"
    | ([] | [ _ ]) :: (_ :: _) :: _, [ _ ] ->
        failwith
          "group_by_zkapp_command_rev: No statements given for the next \
           transaction"
    | [] :: [ _ ] :: (_ :: _) :: _, [ _; _ :: _ :: _ ] ->
        failwith
          "group_by_zkapp_command_rev: No statements given for transaction \
           after next"
  in
  group_by_zkapp_command_rev zkapp_commands stmtss []

let rec accumulate_call_stack_hashes
    ~(hash_frame : 'frame -> Stack_frame.Digest.t) (frames : 'frame list) :
    ('frame, Call_stack_digest.t) With_stack_hash.t list =
  match frames with
  | [] ->
      []
  | f :: fs ->
      let h_f = hash_frame f in
      let tl = accumulate_call_stack_hashes ~hash_frame fs in
      let h_tl =
        match tl with [] -> Call_stack_digest.empty | t :: _ -> t.stack_hash
      in
      { stack_hash = Call_stack_digest.cons h_f h_tl; elt = f } :: tl

let zkapp_command_witnesses_exn ~constraint_constants ~state_body ~fee_excess
    ledger
    (zkapp_commands :
      ( [ `Pending_coinbase_init_stack of Pending_coinbase.Stack.t ]
      * [ `Pending_coinbase_of_statement of Pending_coinbase_stack_state.t ]
      * Zkapp_command.t )
      list ) =
  let sparse_ledger =
    match ledger with
    | `Ledger ledger ->
        Sparse_ledger.of_ledger_subset_exn ledger
          (List.concat_map
             ~f:(fun (_, _, zkapp_command) ->
               Zkapp_command.accounts_accessed zkapp_command )
             zkapp_commands )
    | `Sparse_ledger sparse_ledger ->
        sparse_ledger
  in
  let state_view = Mina_state.Protocol_state.Body.view state_body in
  let _, _, states_rev =
    List.fold_left ~init:(fee_excess, sparse_ledger, []) zkapp_commands
      ~f:(fun (fee_excess, sparse_ledger, statess_rev) (_, _, zkapp_command) ->
        let _, states =
          Sparse_ledger.apply_zkapp_command_unchecked_with_states sparse_ledger
            ~constraint_constants ~state_view ~fee_excess zkapp_command
          |> Or_error.ok_exn
        in
        let final_state = fst (List.last_exn states) in
        (final_state.fee_excess, final_state.ledger, states :: statess_rev) )
  in
  let states = List.rev states_rev in
  let states_rev =
    group_by_zkapp_command_rev
      ( []
      :: List.map
           ~f:(fun (_, _, zkapp_command) ->
             Zkapp_command.zkapp_command_list zkapp_command )
           zkapp_commands )
      ([ List.hd_exn (List.hd_exn states) ] :: states)
  in
  let commitment = ref (Local_state.dummy ()).transaction_commitment in
  let full_commitment =
    ref (Local_state.dummy ()).full_transaction_commitment
  in
  let remaining_zkapp_command =
    let zkapp_commands =
      List.map zkapp_commands
        ~f:(fun
             ( pending_coinbase_init_stack
             , pending_coinbase_stack_state
             , zkapp_command )
           ->
          ( pending_coinbase_init_stack
          , pending_coinbase_stack_state
          , { Mina_transaction_logic.Zkapp_command_logic.Start_data
              .zkapp_command
            ; memo_hash = Signed_command_memo.hash zkapp_command.memo
            } ) )
    in
    ref zkapp_commands
  in
  let pending_coinbase_init_stack = ref Pending_coinbase.Stack.empty in
  let pending_coinbase_stack_state =
    ref
      { Pending_coinbase_stack_state.source = Pending_coinbase.Stack.empty
      ; target = Pending_coinbase.Stack.empty
      }
  in
  let final_ledger =
    match states_rev with
    | [] ->
        sparse_ledger
    | { Zkapp_command_intermediate_state.state_after =
          { global = { ledger; _ }; _ }
      ; _
      }
      :: _ ->
        ledger
  in
  ( List.fold_right states_rev ~init:[]
      ~f:(fun
           { Zkapp_command_intermediate_state.kind
           ; spec
           ; state_before = { global = source_global; local = source_local }
           ; state_after = { global = target_global; local = target_local }
           }
           witnesses
         ->
        (*Transaction snark says nothing about failure status*)
        let source_local = { source_local with failure_status_tbl = [] } in
        let target_local = { target_local with failure_status_tbl = [] } in
        let current_commitment = !commitment in
        let current_full_commitment = !full_commitment in
        let ( start_zkapp_command
            , next_commitment
            , next_full_commitment
            , pending_coinbase_init_stack
            , pending_coinbase_stack_state ) =
          let empty_if_last (mk : unit -> field * field) : field * field =
            match (target_local.stack_frame.calls, target_local.call_stack) with
            | [], [] ->
                (* The commitment will be cleared, because this is the last
                   account_update.
                *)
                Zkapp_command.Transaction_commitment.(empty, empty)
            | _ ->
                mk ()
          in
          let mk_next_commitments (zkapp_command : Zkapp_command.t) =
            empty_if_last (fun () ->
                let next_commitment = Zkapp_command.commitment zkapp_command in
                let memo_hash = Signed_command_memo.hash zkapp_command.memo in
                let fee_payer_hash =
                  Zkapp_command.Digest.Account_update.create
                    (Account_update.of_fee_payer zkapp_command.fee_payer)
                in
                let next_full_commitment =
                  Zkapp_command.Transaction_commitment.create_complete
                    next_commitment ~memo_hash ~fee_payer_hash
                in
                (next_commitment, next_full_commitment) )
          in
          match kind with
          | `Same ->
              let next_commitment, next_full_commitment =
                empty_if_last (fun () ->
                    (current_commitment, current_full_commitment) )
              in
              ( []
              , next_commitment
              , next_full_commitment
              , !pending_coinbase_init_stack
              , !pending_coinbase_stack_state )
          | `New -> (
              match !remaining_zkapp_command with
              | ( `Pending_coinbase_init_stack pending_coinbase_init_stack1
                , `Pending_coinbase_of_statement pending_coinbase_stack_state1
                , zkapp_command )
                :: rest ->
                  let commitment', full_commitment' =
                    mk_next_commitments zkapp_command.zkapp_command
                  in
                  remaining_zkapp_command := rest ;
                  commitment := commitment' ;
                  full_commitment := full_commitment' ;
                  pending_coinbase_init_stack := pending_coinbase_init_stack1 ;
                  pending_coinbase_stack_state := pending_coinbase_stack_state1 ;
                  ( [ zkapp_command ]
                  , commitment'
                  , full_commitment'
                  , !pending_coinbase_init_stack
                  , !pending_coinbase_stack_state )
              | _ ->
                  failwith "Not enough remaining zkapp_command" )
          | `Two_new -> (
              match !remaining_zkapp_command with
              | ( `Pending_coinbase_init_stack pending_coinbase_init_stack1
                , `Pending_coinbase_of_statement pending_coinbase_stack_state1
                , zkapp_command1 )
                :: ( `Pending_coinbase_init_stack _pending_coinbase_init_stack2
                   , `Pending_coinbase_of_statement
                       pending_coinbase_stack_state2
                   , zkapp_command2 )
                   :: rest ->
                  let commitment', full_commitment' =
                    mk_next_commitments zkapp_command2.zkapp_command
                  in
                  remaining_zkapp_command := rest ;
                  commitment := commitment' ;
                  full_commitment := full_commitment' ;
                  (*TODO: Remove `Two_new case because the resulting pending_coinbase_init_stack will not be correct for zkapp_command2 if it is in a different scan state tree*)
                  pending_coinbase_init_stack := pending_coinbase_init_stack1 ;
                  pending_coinbase_stack_state :=
                    { pending_coinbase_stack_state1 with
                      Pending_coinbase_stack_state.target =
                        pending_coinbase_stack_state2
                          .Pending_coinbase_stack_state.target
                    } ;
                  ( [ zkapp_command1; zkapp_command2 ]
                  , commitment'
                  , full_commitment'
                  , !pending_coinbase_init_stack
                  , !pending_coinbase_stack_state )
              | _ ->
                  failwith "Not enough remaining zkapp_command" )
        in
        let hash_local_state
            (local :
              ( Stack_frame.value
              , Stack_frame.value list
              , _
              , _
              , _
              , _
              , _
              , _
              , _ )
              Mina_transaction_logic.Zkapp_command_logic.Local_state.t ) =
          { local with
            stack_frame = local.stack_frame
          ; call_stack =
              List.map local.call_stack
                ~f:(With_hash.of_data ~hash_data:Stack_frame.Digest.create)
              |> accumulate_call_stack_hashes ~hash_frame:(fun x ->
                     x.With_hash.hash )
          }
        in
        let source_local =
          { (hash_local_state source_local) with
            transaction_commitment = current_commitment
          ; full_transaction_commitment = current_full_commitment
          }
        in
        let target_local =
          { (hash_local_state target_local) with
            transaction_commitment = next_commitment
          ; full_transaction_commitment = next_full_commitment
          }
        in
        let w : Zkapp_command_segment.Witness.t =
          { global_ledger = source_global.ledger
          ; local_state_init = source_local
          ; start_zkapp_command
          ; state_body
          ; init_stack = pending_coinbase_init_stack
          }
        in
        let fee_excess =
          (*capture only the difference in the fee excess*)
          let fee_excess =
            match
              Amount.Signed.(
                add target_global.fee_excess (negate source_global.fee_excess))
            with
            | None ->
                failwith
                  (sprintf
                     !"unexpected fee excess. source %{sexp: Amount.Signed.t} \
                       target %{sexp: Amount.Signed.t}"
                     target_global.fee_excess source_global.fee_excess )
            | Some balance_change ->
                balance_change
          in
          { fee_token_l = Token_id.default
          ; fee_excess_l = Amount.Signed.to_fee fee_excess
          ; Mina_base.Fee_excess.fee_token_r = Token_id.default
          ; fee_excess_r = Fee.Signed.zero
          }
        in
        let call_stack_hash s =
          List.hd s
          |> Option.value_map ~default:Call_stack_digest.empty
               ~f:With_stack_hash.stack_hash
        in
        let statement : Statement.With_sok.t =
          (* empty ledger hash in the local state at the beginning of each
             transaction
             `zkapp_command` in local state is empty for the first segment*)
          let source_local_ledger =
            if Zkapp_command.Call_forest.is_empty source_local.stack_frame.calls
            then Frozen_ledger_hash.empty_hash
            else Sparse_ledger.merkle_root source_local.ledger
          in
          { source =
              { ledger = Sparse_ledger.merkle_root source_global.ledger
              ; pending_coinbase_stack = pending_coinbase_stack_state.source
              ; local_state =
                  { source_local with
                    stack_frame =
                      Stack_frame.Digest.create source_local.stack_frame
                  ; call_stack = call_stack_hash source_local.call_stack
                  ; ledger = source_local_ledger
                  }
              }
          ; target =
              { ledger = Sparse_ledger.merkle_root target_global.ledger
              ; pending_coinbase_stack = pending_coinbase_stack_state.target
              ; local_state =
                  { target_local with
                    stack_frame =
                      Stack_frame.Digest.create target_local.stack_frame
                  ; call_stack = call_stack_hash target_local.call_stack
                  ; ledger = Sparse_ledger.merkle_root target_local.ledger
                  }
              }
          ; supply_increase = Amount.Signed.zero
          ; fee_excess
          ; sok_digest = Sok_message.Digest.default
          }
        in
        (w, spec, statement) :: witnesses )
  , final_ledger )

module Make (Inputs : sig
  val constraint_constants : Genesis_constants.Constraint_constants.t

  val proof_level : Genesis_constants.Proof_level.t
end) =
struct
  open Inputs

  let constraint_constants = constraint_constants

  let ( tag
      , cache_handle
      , p
      , Pickles.Provers.
          [ base; merge; opt_signed_opt_signed; opt_signed; proved ] ) =
    system ~proof_level ~constraint_constants

  module Proof = (val p)

  let id = Proof.id

  let verification_key = Proof.verification_key

  let verify_against_digest { statement; proof } =
    Proof.verify [ (statement, proof) ]

  let verify ts =
    if
      List.for_all ts ~f:(fun (p, m) ->
          Sok_message.Digest.equal (Sok_message.digest m) p.statement.sok_digest )
    then
      Proof.verify
        (List.map ts ~f:(fun ({ statement; proof }, _) -> (statement, proof)))
    else Async.return false

  let first_account_update
      (witness : Transaction_witness.Zkapp_command_segment_witness.t) =
    match witness.local_state_init.stack_frame.calls with
    | [] ->
        with_return (fun { return } ->
            List.iter witness.start_zkapp_command ~f:(fun s ->
                Zkapp_command.Call_forest.iteri
                  ~f:(fun _i x -> return (Some x))
                  s.zkapp_command.account_updates ) ;
            None )
    | xs ->
        Zkapp_command.Call_forest.hd_account_update xs

  let account_update_proof (p : Account_update.t) =
    match p.authorization with
    | Proof p ->
        Some p
    | Signature _ | None_given ->
        None

  let snapp_proof_data
      ~(witness : Transaction_witness.Zkapp_command_segment_witness.t) =
    let open Option.Let_syntax in
    let%bind p = first_account_update witness in
    let%map pi = account_update_proof p in
    let vk =
      let account_id = Account_id.create p.body.public_key p.body.token_id in
      let account : Account.t =
        Sparse_ledger.(
          get_exn witness.local_state_init.ledger
            (find_index_exn witness.local_state_init.ledger account_id))
      in
      match
        Option.value_map ~default:None account.zkapp ~f:(fun s ->
            s.verification_key )
      with
      | None ->
          failwith "No verification key found in the account"
      | Some s ->
          s
    in
    (pi, vk)

  let of_zkapp_command_segment_exn ~statement ~witness
      ~(spec : Zkapp_command_segment.Basic.t) : t Async.Deferred.t =
    Base.Zkapp_command_snark.witness := Some witness ;
    let res =
      match spec with
      | Opt_signed ->
          opt_signed statement
      | Opt_signed_opt_signed ->
          opt_signed_opt_signed statement
      | Proved -> (
          match snapp_proof_data ~witness with
          | None ->
              failwith "of_zkapp_command_segment: Expected exactly one proof"
          | Some (p, v) ->
              Pickles.Side_loaded.in_prover (Base.side_loaded 0) v.data ;
              proved
                ~handler:(Base.Zkapp_command_snark.handle_zkapp_proof p)
                statement )
    in
    let open Async in
    let%map (), (), proof = res in
    Base.Zkapp_command_snark.witness := None ;
    { proof; statement }

  let of_transaction_union ~statement ~init_stack transaction state_body handler
      =
    let open Async in
    let%map (), (), proof =
      base
        ~handler:
          (Base.transaction_union_handler handler transaction state_body
             init_stack )
        statement
    in
    { statement; proof }

  let of_non_zkapp_command_transaction ~statement ~init_stack
      transaction_in_block handler =
    let transaction : Transaction.t =
      Transaction.forget
        (Transaction_protocol_state.transaction transaction_in_block)
    in
    let state_body =
      Transaction_protocol_state.block_data transaction_in_block
    in
    match to_preunion transaction with
    | `Zkapp_command _ ->
        failwith
          "Called Non-zkapp_command transaction with zkapp_command transaction"
    | `Transaction t ->
        of_transaction_union ~statement ~init_stack
          (Transaction_union.of_transaction t)
          state_body handler

  let of_user_command ~statement ~init_stack user_command_in_block handler =
    of_non_zkapp_command_transaction ~statement ~init_stack
      { user_command_in_block with
        transaction =
          Command
            (Signed_command
               (Transaction_protocol_state.transaction user_command_in_block) )
      }
      handler

  let of_fee_transfer ~statement ~init_stack transfer_in_block handler =
    of_non_zkapp_command_transaction ~statement ~init_stack
      { transfer_in_block with
        transaction =
          Fee_transfer
            (Transaction_protocol_state.transaction transfer_in_block)
      }
      handler

  let merge ({ statement = t12; _ } as x12) ({ statement = t23; _ } as x23)
      ~sok_digest =
    let open Async.Deferred.Or_error.Let_syntax in
    let%bind s = Async.return (Statement.merge t12 t23) in
    let s = { s with sok_digest } in
    let open Async in
    let%map (), (), proof =
      merge
        ~handler:
          (Merge.handle (x12.statement, x23.statement) (x12.proof, x23.proof))
        s
    in
    Ok { statement = s; proof }

  let constraint_system_digests =
    lazy (constraint_system_digests ~constraint_constants ())
end

module For_tests = struct
  module Spec = struct
    type t =
      { fee : Currency.Fee.t
      ; sender : Signature_lib.Keypair.t * Mina_base.Account.Nonce.t
      ; fee_payer : (Signature_lib.Keypair.t * Mina_base.Account.Nonce.t) option
      ; receivers :
          (Signature_lib.Public_key.Compressed.t * Currency.Amount.t) list
      ; amount : Currency.Amount.t
      ; zkapp_account_keypairs : Signature_lib.Keypair.t list
      ; memo : Signed_command_memo.t
      ; new_zkapp_account : bool
      ; snapp_update : Account_update.Update.t
            (* Authorization for the update being performed *)
      ; current_auth : Permissions.Auth_required.t
      ; sequence_events : Tick.Field.t array list
      ; events : Tick.Field.t array list
      ; call_data : Tick.Field.t
      ; preconditions : Account_update.Preconditions.t option
      }
    [@@deriving sexp]
  end

  let create_trivial_snapp ~constraint_constants () =
    let tag, _, (module P), Pickles.Provers.[ trivial_prover; _ ] =
      let trivial_rule : _ Pickles.Inductive_rule.t =
        let trivial_main (tx_commitment : Zkapp_statement.Checked.t) :
            unit Checked.t =
          Impl.run_checked (dummy_constraints ())
          |> fun () ->
          Zkapp_statement.Checked.Assert.equal tx_commitment tx_commitment
          |> return
        in
        { identifier = "trivial-rule"
        ; prevs = []
        ; main =
            (fun { public_input = x } ->
              let () = Impl.run_checked (trivial_main x) in
              { previous_proof_statements = []
              ; public_output = ()
              ; auxiliary_output = ()
              } )
        ; uses_lookup = false
        }
      in
      Pickles.compile () ~cache:Cache_dir.cache
        ~public_input:(Input Zkapp_statement.typ) ~auxiliary_typ:Typ.unit
        ~branches:(module Nat.N2)
        ~max_proofs_verified:(module Nat.N2) (* You have to put 2 here... *)
        ~name:"trivial"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self ->
          [ trivial_rule
          ; { identifier = "dummy"
            ; prevs = [ self; self ]
            ; main =
                (fun { public_input = _ } ->
                  let s =
                    Run.exists Field.typ ~compute:(fun () ->
                        Run.Field.Constant.zero )
                  in
                  let public_input =
                    Run.exists Zkapp_statement.typ ~compute:(fun () ->
                        assert false )
                  in
                  let proof =
                    Run.exists (Typ.Internal.ref ()) ~compute:(fun () ->
                        assert false )
                  in
                  Impl.run_checked (dummy_constraints ()) ;
                  (* Unsatisfiable. *)
                  Run.Field.(Assert.equal s (s + one)) ;
                  { previous_proof_statements =
                      [ { public_input
                        ; proof
                        ; proof_must_verify = Boolean.true_
                        }
                      ; { public_input
                        ; proof
                        ; proof_must_verify = Boolean.true_
                        }
                      ]
                  ; public_output = ()
                  ; auxiliary_output = ()
                  } )
            ; uses_lookup = false
            }
          ] )
    in
    let vk = Pickles.Side_loaded.Verification_key.of_compiled tag in
    ( `VK (With_hash.of_data ~hash_data:Zkapp_account.digest_vk vk)
    , `Prover trivial_prover )

  let create_zkapp_command
      ~(constraint_constants : Genesis_constants.Constraint_constants.t) spec
      ~update =
    let { Spec.fee
        ; sender = sender, sender_nonce
        ; fee_payer = fee_payer_opt
        ; receivers
        ; amount
        ; new_zkapp_account
        ; zkapp_account_keypairs
        ; memo
        ; sequence_events
        ; events
        ; call_data
        ; preconditions
        ; _
        } =
      spec
    in
    let sender_pk = sender.public_key |> Public_key.compress in
    let fee_payer : Account_update.Fee_payer.t =
      let public_key, nonce =
        match fee_payer_opt with
        | None ->
            (sender_pk, sender_nonce)
        | Some (fee_payer_kp, fee_payer_nonce) ->
            (fee_payer_kp.public_key |> Public_key.compress, fee_payer_nonce)
      in
      { body =
          { public_key
          ; fee
          ; valid_until =
              Option.bind preconditions ~f:(fun { network; _ } ->
                  match network.global_slot_since_genesis with
                  | Ignore ->
                      None
                  | Check { upper; _ } ->
                      Some upper )
          ; nonce
          }
      ; authorization = Signature.dummy
      }
    in
    let preconditions' =
      Option.value preconditions
        ~default:
          { Account_update.Preconditions.network =
              Option.value_map preconditions
                ~f:(fun { network; _ } -> network)
                ~default:Zkapp_precondition.Protocol_state.accept
          ; account =
              ( if Option.is_none fee_payer_opt then
                Nonce (Account.Nonce.succ sender_nonce)
              else Nonce sender_nonce )
          }
    in

    let sender_account_update : Account_update.Simple.t option =
      let sender_account_update_body : Account_update.Body.Simple.t =
        { public_key = sender_pk
        ; update = Account_update.Update.noop
        ; token_id = Token_id.default
        ; balance_change = Amount.(Signed.(negate (of_unsigned amount)))
        ; increment_nonce = true
        ; events = []
        ; sequence_events = []
        ; call_data = Field.zero
        ; call_depth = 0
        ; preconditions = preconditions'
        ; use_full_commitment = false
        ; caller = Call
        }
      in
      Option.some_if
        ((not (List.is_empty receivers)) || new_zkapp_account)
        ( { body = sender_account_update_body
          ; authorization =
              Control.Signature Signature.dummy (*To be updated later*)
          }
          : Account_update.Simple.t )
    in
    let snapp_zkapp_command : Account_update.Simple.t list =
      let num_keypairs = List.length zkapp_account_keypairs in
      let account_creation_fee =
        Amount.of_fee constraint_constants.account_creation_fee
      in
      (* if creating new snapp accounts, amount must be enough for account creation fees for each *)
      assert (
        (not new_zkapp_account) || num_keypairs = 0
        ||
        match Currency.Amount.scale account_creation_fee num_keypairs with
        | None ->
            false
        | Some product ->
            Currency.Amount.( >= ) amount product ) ;
      (* "fudge factor" so that balances sum to zero *)
      let zeroing_allotment =
        if new_zkapp_account then
          (* value doesn't matter when num_keypairs = 0 *)
          if num_keypairs = 0 then amount
          else
            let otherwise_allotted =
              Option.value_exn
                (Currency.Amount.scale account_creation_fee num_keypairs)
            in
            Option.value_exn (Currency.Amount.sub amount otherwise_allotted)
        else Currency.Amount.zero
      in
      List.mapi zkapp_account_keypairs ~f:(fun ndx zkapp_account_keypair ->
          let public_key =
            Signature_lib.Public_key.compress zkapp_account_keypair.public_key
          in
          let delta =
            if new_zkapp_account && ndx = 0 then
              Amount.Signed.(of_unsigned zeroing_allotment)
            else Amount.Signed.zero
          in
          ( { body =
                { public_key
                ; update
                ; token_id = Token_id.default
                ; balance_change = delta
                ; increment_nonce = false
                ; events
                ; sequence_events
                ; call_data
                ; call_depth = 0
                ; preconditions =
                    { preconditions' with
                      account =
                        Option.map preconditions ~f:(fun { account; _ } ->
                            account )
                        |> Option.value ~default:Accept
                    }
                ; use_full_commitment = true
                ; caller = Call
                }
            ; authorization =
                Control.Signature Signature.dummy (*To be updated later*)
            }
            : Account_update.Simple.t ) )
    in
    let other_receivers =
      List.map receivers ~f:(fun (receiver, amt) : Account_update.Simple.t ->
          { body =
              { public_key = receiver
              ; update
              ; token_id = Token_id.default
              ; balance_change = Amount.Signed.of_unsigned amt
              ; increment_nonce = false
              ; events = []
              ; sequence_events = []
              ; call_data = Field.zero
              ; call_depth = 0
              ; preconditions = { preconditions' with account = Accept }
              ; use_full_commitment = false
              ; caller = Call
              }
          ; authorization = Control.None_given
          } )
    in
    let account_updates_data =
      Option.value_map ~default:[] sender_account_update ~f:(fun p -> [ p ])
      @ snapp_zkapp_command @ other_receivers
    in
    let ps =
      Zkapp_command.Call_forest.With_hashes.of_zkapp_command_simple_list
        account_updates_data
    in
    let account_updates_hash = Zkapp_command.Call_forest.hash ps in
    let commitment : Zkapp_command.Transaction_commitment.t =
      Zkapp_command.Transaction_commitment.create ~account_updates_hash
    in
    let full_commitment =
      Zkapp_command.Transaction_commitment.create_complete commitment
        ~memo_hash:(Signed_command_memo.hash memo)
        ~fee_payer_hash:
          (Zkapp_command.Digest.Account_update.create
             (Account_update.of_fee_payer fee_payer) )
    in
    let fee_payer =
      let fee_payer_signature_auth =
        match fee_payer_opt with
        | None ->
            Signature_lib.Schnorr.Chunked.sign sender.private_key
              (Random_oracle.Input.Chunked.field full_commitment)
        | Some (fee_payer_kp, _) ->
            Signature_lib.Schnorr.Chunked.sign fee_payer_kp.private_key
              (Random_oracle.Input.Chunked.field full_commitment)
      in
      { fee_payer with authorization = fee_payer_signature_auth }
    in
    let sender_account_update =
      Option.map sender_account_update ~f:(fun s : Account_update.Simple.t ->
          let commitment =
            if s.body.use_full_commitment then full_commitment else commitment
          in
          let sender_signature_auth =
            Signature_lib.Schnorr.Chunked.sign sender.private_key
              (Random_oracle.Input.Chunked.field commitment)
          in
          { body = s.body; authorization = Signature sender_signature_auth } )
    in
    ( `Zkapp_command
        (Zkapp_command.of_simple
           { fee_payer; account_updates = other_receivers; memo } )
    , `Sender_account_update sender_account_update
    , `Proof_zkapp_command snapp_zkapp_command
    , `Txn_commitment commitment
    , `Full_txn_commitment full_commitment )

  let deploy_snapp ?(no_auth = false) ~constraint_constants (spec : Spec.t) =
    let `VK vk, `Prover _trivial_prover =
      create_trivial_snapp ~constraint_constants ()
    in
    (* only allow timing on a single new snapp account
       balance changes for other new snapp accounts are just the account creation fee
    *)
    assert (
      Zkapp_basic.Set_or_keep.is_keep spec.snapp_update.timing
      || (spec.new_zkapp_account && List.length spec.zkapp_account_keypairs = 1) ) ;
    let update_vk =
      let update = spec.snapp_update in
      if no_auth then update
      else
        { update with
          verification_key = Zkapp_basic.Set_or_keep.Set vk
        ; permissions =
            Zkapp_basic.Set_or_keep.Set
              { Permissions.user_default with
                edit_state = Permissions.Auth_required.Proof
              ; edit_sequence_state = Proof
              }
        }
    in
    let ( `Zkapp_command { Zkapp_command.fee_payer; account_updates; memo }
        , `Sender_account_update sender_account_update
        , `Proof_zkapp_command snapp_zkapp_command
        , `Txn_commitment commitment
        , `Full_txn_commitment full_commitment ) =
      create_zkapp_command ~constraint_constants spec ~update:update_vk
    in
    assert (List.is_empty account_updates) ;
    (* invariant: same number of keypairs, snapp_zkapp_command *)
    let snapp_zkapp_command_keypairs =
      List.zip_exn snapp_zkapp_command spec.zkapp_account_keypairs
    in
    let snapp_zkapp_command =
      List.map snapp_zkapp_command_keypairs
        ~f:(fun (snapp_account_update, keypair) ->
          if no_auth then
            ( { body = snapp_account_update.body; authorization = None_given }
              : Account_update.Simple.t )
          else
            let commitment =
              if snapp_account_update.body.use_full_commitment then
                full_commitment
              else commitment
            in
            let signature =
              Signature_lib.Schnorr.Chunked.sign keypair.private_key
                (Random_oracle.Input.Chunked.field commitment)
            in
            ( { body = snapp_account_update.body
              ; authorization = Signature signature
              }
              : Account_update.Simple.t ) )
    in
    let account_updates =
      Option.to_list sender_account_update @ snapp_zkapp_command
    in
    let zkapp_command : Zkapp_command.t =
      Zkapp_command.of_simple { fee_payer; account_updates; memo }
    in
    zkapp_command

  let update_states ?zkapp_prover ~constraint_constants (spec : Spec.t) =
    let ( `Zkapp_command { Zkapp_command.fee_payer; account_updates; memo }
        , `Sender_account_update sender_account_update
        , `Proof_zkapp_command snapp_zkapp_command
        , `Txn_commitment commitment
        , `Full_txn_commitment full_commitment ) =
      create_zkapp_command ~constraint_constants spec ~update:spec.snapp_update
    in
    assert (List.is_empty account_updates) ;
    assert (Option.is_none sender_account_update) ;
    assert (not @@ List.is_empty snapp_zkapp_command) ;
    let snapp_zkapp_command =
      snapp_zkapp_command
      |> List.map ~f:(fun p -> (p, p))
      |> Zkapp_command.Call_forest.With_hashes_and_data
         .of_zkapp_command_simple_list
      |> Zkapp_statement.zkapp_statements_of_forest
      |> Zkapp_command.Call_forest.to_account_updates
    in
    let snapp_zkapp_command_keypairs =
      List.zip_exn snapp_zkapp_command spec.zkapp_account_keypairs
    in
    let%map.Async.Deferred snapp_zkapp_command =
      Async.Deferred.List.map snapp_zkapp_command_keypairs
        ~f:(fun
             ( ( (snapp_account_update, simple_snapp_account_update)
               , tx_statement )
             , snapp_keypair )
           ->
          match spec.current_auth with
          | Permissions.Auth_required.Proof ->
              let handler (Snarky_backendless.Request.With { request; respond })
                  =
                match request with _ -> respond Unhandled
              in
              let prover =
                match zkapp_prover with
                | Some prover ->
                    prover
                | None ->
                    let _, `Prover p =
                      create_trivial_snapp ~constraint_constants ()
                    in
                    p
              in
              let%map.Async.Deferred (), (), (pi : Pickles.Side_loaded.Proof.t)
                  =
                prover ~handler tx_statement
              in
              ( { body = simple_snapp_account_update.body
                ; authorization = Proof pi
                }
                : Account_update.Simple.t )
          | Signature ->
              let commitment =
                if snapp_account_update.body.use_full_commitment then
                  full_commitment
                else commitment
              in
              let signature =
                Signature_lib.Schnorr.Chunked.sign snapp_keypair.private_key
                  (Random_oracle.Input.Chunked.field commitment)
              in
              Async.Deferred.return
                ( { body = simple_snapp_account_update.body
                  ; authorization = Signature signature
                  }
                  : Account_update.Simple.t )
          | None ->
              Async.Deferred.return
                ( { body = simple_snapp_account_update.body
                  ; authorization = None_given
                  }
                  : Account_update.Simple.t )
          | _ ->
              failwith
                "Current authorization not Proof or Signature or None_given" )
    in
    let account_updates = snapp_zkapp_command in
    let zkapp_command : Zkapp_command.t =
      Zkapp_command.of_simple { fee_payer; account_updates; memo }
    in
    zkapp_command

  let multiple_transfers (spec : Spec.t) =
    let ( `Zkapp_command zkapp_command
        , `Sender_account_update sender_account_update
        , `Proof_zkapp_command snapp_zkapp_command
        , `Txn_commitment _commitment
        , `Full_txn_commitment _full_commitment ) =
      create_zkapp_command
        ~constraint_constants:Genesis_constants.Constraint_constants.compiled
        spec ~update:spec.snapp_update
    in
    assert (Option.is_some sender_account_update) ;
    assert (List.is_empty snapp_zkapp_command) ;
    let account_updates =
      let sender_account_update = Option.value_exn sender_account_update in
      Zkapp_command.Call_forest.cons
        (Zkapp_command.add_caller_simple sender_account_update Token_id.default)
        zkapp_command.account_updates
    in
    { zkapp_command with account_updates }

  let trivial_zkapp_account ?(permissions = Permissions.user_default) ~vk pk =
    let id = Account_id.create pk Token_id.default in
    { (Account.create id Balance.(of_int 1_000_000_000_000_000)) with
      permissions
    ; zkapp = Some { Zkapp_account.default with verification_key = Some vk }
    }

  let create_trivial_zkapp_account ?(permissions = Permissions.user_default) ~vk
      ~ledger pk =
    let create ledger id account =
      match Ledger.location_of_account ledger id with
      | Some _loc ->
          failwith "Account already present"
      | None ->
          let _loc, _new =
            Ledger.get_or_create_account ledger id account |> Or_error.ok_exn
          in
          ()
    in
    let id = Account_id.create pk Token_id.default in
    let account : Account.t = trivial_zkapp_account ~permissions ~vk pk in
    create ledger id account

  let create_trivial_predicate_snapp ~constraint_constants
      ?(protocol_state_predicate = Zkapp_precondition.Protocol_state.accept)
      ~(snapp_kp : Signature_lib.Keypair.t) spec ledger =
    let { Mina_transaction_logic.For_tests.Transaction_spec.fee
        ; sender = sender, sender_nonce
        ; receiver = _
        ; receiver_is_new = _
        ; amount
        } =
      spec
    in
    let trivial_account_pk =
      Signature_lib.Public_key.compress snapp_kp.public_key
    in
    let `VK vk, `Prover trivial_prover =
      create_trivial_snapp ~constraint_constants ()
    in
    let _v =
      let id =
        Public_key.compress sender.public_key
        |> fun pk -> Account_id.create pk Token_id.default
      in
      Ledger.get_or_create_account ledger id
        (Account.create id Balance.(of_int 888_888))
      |> Or_error.ok_exn
    in
    let () =
      create_trivial_zkapp_account trivial_account_pk ~ledger ~vk
        ~permissions:{ Permissions.user_default with set_permissions = Proof }
    in
    let update_empty_permissions =
      let permissions =
        { Permissions.user_default with send = Permissions.Auth_required.Proof }
        |> Zkapp_basic.Set_or_keep.Set
      in
      { Account_update.Update.dummy with permissions }
    in
    let sender_pk = sender.public_key |> Public_key.compress in
    let fee_payer : Account_update.Fee_payer.t =
      { body =
          { public_key = sender_pk
          ; fee
          ; valid_until = None
          ; nonce = sender_nonce
          }
          (* Real signature added in below *)
      ; authorization = Signature.dummy
      }
    in
    let sender_account_update_data : Account_update.Simple.t =
      { body =
          { public_key = sender_pk
          ; update = Account_update.Update.noop
          ; token_id = Token_id.default
          ; balance_change = Amount.(Signed.(negate (of_unsigned amount)))
          ; increment_nonce = true
          ; events = []
          ; sequence_events = []
          ; call_data = Field.zero
          ; call_depth = 0
          ; preconditions =
              { network = protocol_state_predicate
              ; account = Nonce (Account.Nonce.succ sender_nonce)
              }
          ; use_full_commitment = false
          ; caller = Call
          }
      ; authorization = Signature Signature.dummy
      }
    in
    let snapp_account_update_data : Account_update.Simple.t =
      { body =
          { public_key = trivial_account_pk
          ; update = update_empty_permissions
          ; token_id = Token_id.default
          ; balance_change = Amount.Signed.(of_unsigned amount)
          ; increment_nonce = false
          ; events = []
          ; sequence_events = []
          ; call_data = Field.zero
          ; call_depth = 0
          ; preconditions =
              { network = protocol_state_predicate
              ; account = Full Zkapp_precondition.Account.accept
              }
          ; use_full_commitment = false
          ; caller = Call
          }
      ; authorization = Proof Mina_base.Proof.blockchain_dummy
      }
    in
    let memo = Signed_command_memo.empty in
    let ps =
      Zkapp_command.Call_forest.With_hashes.of_zkapp_command_simple_list
        [ sender_account_update_data; snapp_account_update_data ]
    in
    let account_updates_hash = Zkapp_command.Call_forest.hash ps in
    let transaction : Zkapp_command.Transaction_commitment.t =
      (*FIXME: is this correct? *)
      Zkapp_command.Transaction_commitment.create ~account_updates_hash
    in
    let proof_account_update =
      let tree =
        Zkapp_command.Call_forest.With_hashes.of_zkapp_command_simple_list
          [ snapp_account_update_data ]
        |> List.hd_exn
      in
      tree.elt.account_update_digest
    in
    let tx_statement : Zkapp_statement.t =
      { account_update = (proof_account_update :> Field.t)
      ; calls = (Zkapp_command.Digest.Forest.empty :> Field.t)
      }
    in
    let handler (Snarky_backendless.Request.With { request; respond }) =
      match request with _ -> respond Unhandled
    in
    let%map.Async.Deferred (), (), (pi : Pickles.Side_loaded.Proof.t) =
      trivial_prover ~handler tx_statement
    in
    let fee_payer_signature_auth =
      let txn_comm =
        Zkapp_command.Transaction_commitment.create_complete transaction
          ~memo_hash:(Signed_command_memo.hash memo)
          ~fee_payer_hash:
            (Zkapp_command.Digest.Account_update.create
               (Account_update.of_fee_payer fee_payer) )
      in
      Signature_lib.Schnorr.Chunked.sign sender.private_key
        (Random_oracle.Input.Chunked.field txn_comm)
    in
    let fee_payer =
      { fee_payer with authorization = fee_payer_signature_auth }
    in
    let sender_signature_auth =
      Signature_lib.Schnorr.Chunked.sign sender.private_key
        (Random_oracle.Input.Chunked.field transaction)
    in
    let sender : Account_update.Simple.t =
      { sender_account_update_data with
        authorization = Signature sender_signature_auth
      }
    in
    let account_updates =
      [ sender
      ; { body = snapp_account_update_data.body; authorization = Proof pi }
      ]
    in
    let zkapp_command : Zkapp_command.t =
      Zkapp_command.of_simple { fee_payer; account_updates; memo }
    in
    zkapp_command
end
