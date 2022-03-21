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
  | Command (Parties x) ->
      `Parties x

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
          ; local_state = Local_state.empty
          }
      ; target =
          { ledger = target
          ; pending_coinbase_stack = pending_coinbase_stack_state.target
          ; local_state = Local_state.empty
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
        , Currency.Amount.Stable.V1.t
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
          , Currency.Amount.Stable.V1.t
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
      , Currency.Amount.var
      , Pending_coinbase.Stack.var
      , Fee_excess.var
      , Sok_message.Digest.Checked.t
      , Local_state.Checked.t )
      Poly.t

    let typ : (var, t) Tick.Typ.t =
      Poly.typ Frozen_ledger_hash.typ Currency.Amount.typ
        Pending_coinbase.Stack.typ Fee_excess.typ Sok_message.Digest.typ
        Local_state.typ

    let to_input { source; target; supply_increase; fee_excess; sok_digest } =
      let input =
        Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
          [| Sok_message.Digest.to_input sok_digest
           ; Registers.to_input source
           ; Registers.to_input target
           ; Amount.to_input supply_increase
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
        let input =
          Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
            [| Sok_message.Digest.Checked.to_input sok_digest
             ; source
             ; target
             ; Amount.var_to_input supply_increase
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
                (Field.name f) x1 x2)
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
      Currency.Amount.add s1.supply_increase s2.supply_increase
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
    and supply_increase = Currency.Amount.gen in
    ({ source; target; fee_excess; supply_increase; sok_digest = () } : t)
end

module Proof = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Pickles.Proof.Branching_2.Stable.V2.t
      [@@deriving
        version { asserted }, yojson, bin_io, compare, equal, sexp, hash]

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

module Parties_segment = struct
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
        type t =
          | Opt_signed_unsigned
          | Opt_signed_opt_signed
          | Opt_signed
          | Proved
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end
    end]

    let of_controls = function
      | [ Control.Proof _ ] ->
          Proved
      | [ (Control.Signature _ | Control.None_given) ] ->
          Opt_signed
      | [ Control.(Signature _ | None_given); Control.None_given ] ->
          Opt_signed_unsigned
      | [ Control.(Signature _ | None_given); Control.Signature _ ] ->
          Opt_signed_opt_signed
      | _ ->
          failwith "Parties_segment.Basic.of_controls: Unsupported combination"

    let opt_signed ~is_start : Spec.single = { auth_type = Signature; is_start }

    let unsigned : Spec.single = { auth_type = None_given; is_start = `No }

    let opt_signed = opt_signed ~is_start:`Compute_in_circuit

    let to_single_list : t -> Spec.single list =
     fun t ->
      match t with
      | Opt_signed_unsigned ->
          [ opt_signed; unsigned ]
      | Opt_signed_opt_signed ->
          [ opt_signed; opt_signed ]
      | Opt_signed ->
          [ opt_signed ]
      | Proved ->
          [ { auth_type = Proof; is_start = `No } ]

    type (_, _, _, _) t_typed =
      (* Corresponds to payment *)
      | Opt_signed_unsigned : (unit, unit, unit, unit) t_typed
      | Opt_signed_opt_signed : (unit, unit, unit, unit) t_typed
      | Opt_signed : (unit, unit, unit, unit) t_typed
      | Proved
          : ( Snapp_statement.Checked.t * unit
            , Snapp_statement.t * unit
            , Nat.N2.n * unit
            , N.n * unit )
            t_typed

    let spec : type a b c d. (a, b, c, d) t_typed -> Spec.single list =
     fun t ->
      match t with
      | Opt_signed_unsigned ->
          [ opt_signed; unsigned ]
      | Opt_signed_opt_signed ->
          [ opt_signed; opt_signed ]
      | Opt_signed ->
          [ opt_signed ]
      | Proved ->
          [ { auth_type = Proof; is_start = `No } ]
  end

  module Witness = Transaction_witness.Parties_segment_witness
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
          ( Pickles.Pairing_main.Scalar_challenge.endo g ~num_bits:4
              (Kimchi_backend_common.Scalar_challenge.create x)
            : Field.t * Field.t ))

module Base = struct
  module User_command_failure = struct
    (** The various ways that a user command may fail. These should be computed
        before applying the snark, to ensure that only the base fee is charged
        to the fee-payer if executing the user command will later fail.
    *)
    type 'bool t =
      { predicate_failed : 'bool (* All *)
      ; source_not_present : 'bool (* All *)
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
                  (* TODO(#4554): Hook predicate evaluation in here once
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
                       .timing_error_to_user_command_status err)
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
        let open Snapp_statement in
        Pickles.Side_loaded.create ~typ ~name:(sprintf "snapp_%d" i)
          ~max_branching:(module Pickles.Side_loaded.Verification_key.Max_width)
          ~value_to_field_elements:to_field_elements
          ~var_to_field_elements:Checked.to_field_elements)

  let signature_verifies ~shifted ~payload_digest signature pk =
    let%bind pk =
      Public_key.decompress_var pk
      (*           (Account_id.Checked.public_key fee_payer_id) *)
    in
    Schnorr.Chunked.Checked.verifies shifted signature pk
      (Random_oracle.Input.Chunked.field payload_digest)

  module Parties_snark = struct
    open Parties_segment
    open Spec

    module Prover_value : sig
      type 'a t

      val get : 'a t -> 'a

      val create : (unit -> 'a) -> 'a t

      val map : 'a t -> f:('a -> 'b) -> 'b t

      val if_ : Boolean.var -> then_:'a t -> else_:'a t -> 'a t
    end = struct
      open Impl

      type 'a t = 'a As_prover.Ref.t

      let get = As_prover.Ref.get

      let create = As_prover.Ref.create

      let if_ b ~then_ ~else_ =
        create (fun () ->
            get (if Impl.As_prover.read Boolean.typ b then then_ else else_))

      let map t ~f = create (fun () -> f (get t))
    end

    module Global_state = struct
      type t =
        { ledger : Ledger_hash.var * Sparse_ledger.t Prover_value.t
        ; fee_excess : Amount.Signed.var
        ; protocol_state : Snapp_predicate.Protocol_state.View.Checked.t
        }
    end

    let implied_root account incl =
      let open Impl in
      List.foldi incl ~init:(With_hash.hash account)
        ~f:(fun height acc (b, h) ->
          let l = Field.if_ b ~then_:h ~else_:acc
          and r = Field.if_ b ~then_:acc ~else_:h in
          let acc' = Ledger_hash.merge_var ~height l r in
          acc')

    let apply_body ~is_start
        ({ body =
             { public_key
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
             ; call_data =
                 _ (* This is for the snapp to use, we don't need it. *)
             ; sequence_events = _
             ; call_depth = _ (* This is used to build the 'stack of stacks'. *)
             ; protocol_state = _
             ; use_full_commitment
             }
         ; predicate
         ; caller = _
         } :
          Party.Predicated.Checked.t) (a : Account.Checked.Unhashed.t) :
        Account.Checked.Unhashed.t * _ =
      let open Impl in
      let r = ref [] in
      let proof_must_verify () = Boolean.any (List.map !r ~f:Lazy.force) in

      (* enforce that either the predicate is `Accept`,
         the nonce is incremented,
         or the full commitment is used to avoid replays. *)
      let predicate_is_accept =
        let accept_digest =
          Snapp_predicate.Account.digest Snapp_predicate.Account.accept
          |> Field.constant
        in
        let predicate_digest =
          Snapp_predicate.Account.Checked.digest predicate
        in
        Field.equal accept_digest predicate_digest
      in
      with_label __LOC__ (fun () ->
          Boolean.Assert.any
            [ predicate_is_accept
            ; increment_nonce
            ; Boolean.(use_full_commitment &&& not is_start)
            ]) ;
      let a : Account.Checked.Unhashed.t = { a with public_key } in
      (a, `proof_must_verify proof_must_verify)

    module type Single_inputs = sig
      val constraint_constants : Genesis_constants.Constraint_constants.t

      val spec : single

      val snapp_statement : (int * Snapp_statement.Checked.t) option
    end

    type party =
      { party : (Party.Predicated.Checked.t, Impl.Field.t) With_hash.t
      ; control : Control.t Prover_value.t
      }

    module Inputs = struct
      module V = Prover_value
      open Impl

      module Transaction_commitment = struct
        type t = Field.t

        let if_ = Field.if_

        let empty = Field.constant Parties.Transaction_commitment.empty

        let commitment ~party:{ party; _ }
            ~other_parties:{ With_hash.hash = other_parties; _ } ~memo_hash =
          Parties.Transaction_commitment.Checked.create
            ~other_parties_hash:other_parties
            ~protocol_state_predicate_hash:
              (Snapp_predicate.Protocol_state.Checked.digest
                 party.data.body.protocol_state)
            ~memo_hash

        let full_commitment ~party:{ party; _ } ~commitment =
          Parties.Transaction_commitment.Checked.with_fee_payer commitment
            ~fee_payer_hash:party.hash
      end

      module Bool = struct
        include Boolean

        type t = var

        let display _b ~label:_ = ""

        type failure_status = unit

        let assert_with_failure_status b _failure_status = Assert.is_true b
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

      module Verification_key = struct
        type t =
          ( Boolean.var
          , ( Side_loaded_verification_key.t option
            , Field.Constant.t )
            With_hash.t
            Data_as_hash.t )
          Snapp_basic.Flagged_option.t

        let if_ b ~(then_ : t) ~(else_ : t) : t =
          Snapp_basic.Flagged_option.if_ ~if_:Data_as_hash.if_ b ~then_ ~else_
      end

      module Events = struct
        type t = Snapp_account.Events.var

        let is_empty x = run_checked (Party.Events.is_empty_var x)

        let push_events = Party.Sequence_events.push_events_checked
      end

      module Snapp_uri = struct
        type t = string Data_as_hash.t

        let if_ = Data_as_hash.if_
      end

      module Token_symbol = struct
        type t = Account.Token_symbol.var

        let if_ = Account.Token_symbol.if_
      end

      module Account = struct
        type t = (Account.Checked.Unhashed.t, Field.t) With_hash.t

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

          let set_snapp_uri : t -> controller =
           fun a -> a.data.permissions.set_snapp_uri

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

        let account_with_hash (account : Account.Checked.Unhashed.t) =
          With_hash.of_data account ~hash_data:(fun a ->
              let a =
                { a with
                  snapp =
                    ( Snapp_account.Checked.digest a.snapp
                    , As_prover.Ref.create (fun () -> None) )
                }
              in
              run_checked (Account.Checked.digest a))

        type timing = Account_timing.var

        let timing (account : t) : timing = account.data.timing

        let set_timing (timing : timing) (account : t) : t =
          { account with data = { account.data with timing } }

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
            @@ [%with_label "Check snapp timing"]
                 (check_timing ~balance_check ~timed_balance_check ~account
                    ~txn_amount:None ~txn_global_slot)
          in
          (`Invalid_timing (Option.value_exn !invalid_timing), timing)

        let make_snapp (a : t) = a

        let unmake_snapp (a : t) = a

        let proved_state (a : t) = a.data.snapp.proved_state

        let set_proved_state proved_state ({ data = a; hash } : t) : t =
          { data = { a with snapp = { a.snapp with proved_state } }; hash }

        let app_state (a : t) = a.data.snapp.app_state

        let set_app_state app_state ({ data = a; hash } : t) : t =
          { data = { a with snapp = { a.snapp with app_state } }; hash }

        let verification_key (a : t) : Verification_key.t =
          a.data.snapp.verification_key

        let set_verification_key (verification_key : Verification_key.t)
            ({ data = a; hash } : t) : t =
          { data = { a with snapp = { a.snapp with verification_key } }; hash }

        let last_sequence_slot (a : t) = a.data.snapp.last_sequence_slot

        let set_last_sequence_slot last_sequence_slot ({ data = a; hash } : t) :
            t =
          { data = { a with snapp = { a.snapp with last_sequence_slot } }
          ; hash
          }

        let sequence_state (a : t) = a.data.snapp.sequence_state

        let set_sequence_state sequence_state ({ data = a; hash } : t) : t =
          { data = { a with snapp = { a.snapp with sequence_state } }; hash }

        let snapp_uri (a : t) = a.data.snapp_uri

        let set_snapp_uri snapp_uri ({ data = a; hash } : t) : t =
          { data = { a with snapp_uri }; hash }

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
        open Snapp_basic

        type 'a t = (Bool.t, 'a) Flagged_option.t

        let is_some = Flagged_option.is_some

        let map x ~f = Flagged_option.map ~f x

        let or_default ~if_ x ~default =
          if_ (is_some x) ~then_:(Flagged_option.data x) ~else_:default

        let or_exn x =
          with_label "or_exn is_some" (fun () ->
              Bool.Assert.is_true (is_some x)) ;
          Flagged_option.data x
      end

      module Parties = struct
        type t =
          ( (Party.t * unit, Parties.Digest.t) Parties.Call_forest.t V.t
          , Field.t )
          With_hash.t

        let if_ b ~then_:(t : t) ~else_:(e : t) : t =
          { hash = Field.if_ b ~then_:t.hash ~else_:e.hash
          ; data = V.if_ b ~then_:t.data ~else_:e.data
          }

        let empty = Field.constant Parties.Call_forest.With_hashes.empty

        let is_empty ({ hash = x; _ } : t) = Field.equal empty x

        let empty () : t = { hash = empty; data = V.create (fun () -> []) }

        let hash_cons hash h_tl =
          Random_oracle.Checked.hash ~init:Hash_prefix_states.party_cons
            [| hash; h_tl |]

        let pop_exn ({ hash = h; data = r } : t) : (party * t) * t =
          let hd_r =
            V.create (fun () -> V.get r |> List.hd_exn |> With_stack_hash.elt)
          in
          let party = V.create (fun () -> (V.get hd_r).party |> fst) in
          let caller =
            exists Mina_base.Token_id.typ ~compute:(fun () ->
                (V.get party).data.caller)
          in
          let body =
            exists (Party.Body.typ ()) ~compute:(fun () ->
                (V.get party).data.body)
          in
          let predicate : Party.Predicate.Checked.t =
            exists (Party.Predicate.typ ()) ~compute:(fun () ->
                (V.get party).data.predicate)
          in
          let auth = V.(create (fun () -> (V.get party).authorization)) in
          let party : Party.Predicated.Checked.t =
            { body; predicate; caller }
          in
          let party =
            With_hash.of_data party ~hash_data:Party.Predicated.Checked.digest
          in
          let subforest : t =
            let subforest = V.create (fun () -> (V.get hd_r).calls) in
            let subforest_hash =
              exists Field.typ ~compute:(fun () ->
                  Parties.Call_forest.hash (V.get subforest))
            in
            { hash = subforest_hash; data = subforest }
          in
          let tl_hash =
            exists Field.typ ~compute:(fun () ->
                V.get r |> List.tl_exn |> Parties.Call_forest.hash)
          in
          let tree_hash =
            Random_oracle.Checked.hash ~init:Hash_prefix_states.party_node
              [| party.hash; subforest.hash |]
          in
          Field.Assert.equal (hash_cons tree_hash tl_hash) h ;
          ( ({ party; control = auth }, subforest)
          , { hash = tl_hash
            ; data = V.(create (fun () -> List.tl_exn (get r)))
            } )
      end

      module Stack_frame = struct
        type frame = (Token_id.Checked.t, Parties.t) Stack_frame.t

        type t = (frame, Field.t Lazy.t) With_hash.t

        let if_ b ~then_:(t1 : t) ~else_:(t2 : t) : t =
          { With_hash.hash =
              lazy
                (Field.if_ b ~then_:(Lazy.force t1.hash)
                   ~else_:(Lazy.force t2.hash))
          ; data =
              Stack_frame.Checked.if_ Parties.if_ b ~then_:t1.data
                ~else_:t2.data
          }

        let caller (t : t) = t.data.caller

        let caller_caller (t : t) = t.data.caller_caller

        let calls (t : t) = t.data.calls

        let frame_to_input ({ caller; caller_caller; calls } : frame) =
          List.reduce_exn ~f:Random_oracle.Input.Chunked.append
            [ Token_id.Checked.to_input caller
            ; Token_id.Checked.to_input caller_caller
            ; Random_oracle.Input.Chunked.field calls.hash
            ]

        let of_frame (frame : frame) : t =
          { data = frame
          ; hash =
              lazy
                (Random_oracle.Checked.hash
                   ~init:Hash_prefix_states.party_stack_frame
                   (Random_oracle.Checked.pack_input (frame_to_input frame)))
          }

        let make ~caller ~caller_caller ~calls : t =
          Stack_frame.make ~caller ~caller_caller ~calls |> of_frame

        let hash (t : t) : Field.t = Lazy.force t.hash

        let unhash (h : Field.t)
            (frame :
              ( Mina_base.Token_id.Stable.V1.t
              , unit Mina_base.Parties.Call_forest.With_hashes.Stable.V1.t )
              Stack_frame.Stable.V1.t
              V.t) : t =
          let frame : frame =
            { caller =
                exists Token_id.typ ~compute:(fun () -> (V.get frame).caller)
            ; caller_caller =
                exists Token_id.typ ~compute:(fun () ->
                    (V.get frame).caller_caller)
            ; calls =
                { hash =
                    exists Field.typ ~compute:(fun () ->
                        (V.get frame).calls
                        |> Mina_base.Parties.Call_forest.hash)
                ; data = V.map frame ~f:(fun frame -> frame.calls)
                }
            }
          in
          let t = of_frame frame in
          Field.Assert.equal (hash (of_frame frame)) h ;
          t
      end

      module Call_stack = struct
        module Value = struct
          open Mina_base

          type caller = Token_id.t

          type frame =
            ( caller
            , (Party.t * unit, Parties.Digest.t) Parties.Call_forest.t )
            Stack_frame.t
        end

        type elt = Stack_frame.t

        module Elt = struct
          let invalid_caller = Mina_base.Token_id.invalid

          type t = (Value.frame, Field.Constant.t) With_hash.t

          let default : t =
            { hash = Field.Constant.zero
            ; data =
                { caller = invalid_caller
                ; caller_caller = invalid_caller
                ; calls = []
                }
            }
        end

        let empty_constant = Mina_base.Parties.Call_forest.With_hashes.empty

        let hash_cons hash h_tl =
          Random_oracle.Checked.hash ~init:Hash_prefix_states.party_cons
            [| hash; h_tl |]

        let stack_hash (type a)
            (xs : (a, Field.Constant.t) With_stack_hash.t list) :
            Field.Constant.t =
          Mina_base.Parties.Call_forest.hash xs

        type t =
          ( (Elt.t, Field.Constant.t) With_stack_hash.t list V.t
          , Field.t )
          With_hash.t

        let if_ b ~then_:(t : t) ~else_:(e : t) : t =
          { hash = Field.if_ b ~then_:t.hash ~else_:e.hash
          ; data = V.if_ b ~then_:t.data ~else_:e.data
          }

        let empty = Field.constant empty_constant

        let is_empty ({ hash = x; _ } : t) = Field.equal empty x

        let empty () : t = { hash = empty; data = V.create (fun () -> []) }

        let exists_elt (elt_ref : (Value.frame, _) With_hash.t V.t) :
            Stack_frame.t =
          let elt : Stack_frame.frame =
            let calls : Parties.t =
              { hash =
                  exists Field.typ ~compute:(fun () ->
                      (V.get elt_ref).data.calls
                      |> Mina_base.Parties.Call_forest.hash)
              ; data = V.map elt_ref ~f:(fun frame -> frame.data.calls)
              }
            and caller =
              exists Mina_base.Token_id.typ ~compute:(fun () ->
                  (V.get elt_ref).data.caller)
            and caller_caller =
              exists Mina_base.Token_id.typ ~compute:(fun () ->
                  (V.get elt_ref).data.caller_caller)
            in
            { caller; caller_caller; calls }
          in
          Stack_frame.of_frame elt

        let pop_exn ({ hash = h; data = r } : t) : elt * t =
          let hd_r = V.create (fun () -> (V.get r |> List.hd_exn).elt) in
          let tl_r = V.create (fun () -> V.get r |> List.tl_exn) in
          let elt : Stack_frame.t = exists_elt hd_r in
          let stack =
            exists Field.typ ~compute:(fun () -> stack_hash (V.get tl_r))
          in
          let h' = hash_cons (Stack_frame.hash elt) stack in
          with_label __LOC__ (fun () -> Field.Assert.equal h h') ;
          (elt, { hash = stack; data = tl_r })

        let pop ({ hash = h; data = r } as t : t) : (elt * t) Opt.t =
          let input_is_empty = is_empty t in
          let hd_r =
            V.create (fun () ->
                V.get r |> List.hd
                |> Option.value_map ~default:Elt.default ~f:(fun x -> x.elt))
          in
          let tl_r =
            V.create (fun () -> V.get r |> List.tl |> Option.value ~default:[])
          in
          let elt = exists_elt hd_r in
          let stack =
            exists Field.typ ~compute:(fun () -> stack_hash (V.get tl_r))
          in
          let h' = hash_cons (Stack_frame.hash elt) stack in
          with_label __LOC__ (fun () ->
              Boolean.Assert.any [ input_is_empty; Field.equal h h' ]) ;
          { is_some = Boolean.not input_is_empty
          ; data = (elt, { hash = stack; data = tl_r })
          }

        let read_elt (frame : elt) : Elt.t =
          { hash = As_prover.read Field.typ (Stack_frame.hash frame)
          ; data =
              { calls = V.get frame.data.calls.data
              ; caller = As_prover.read Token_id.typ frame.data.caller
              ; caller_caller =
                  As_prover.read Token_id.typ frame.data.caller_caller
              }
          }

        let push (elt : elt) ~onto:({ hash = h_tl; data = r_tl } : t) : t =
          let h = hash_cons (Stack_frame.hash elt) h_tl in
          let r =
            V.create
              (fun () : (Elt.t, Field.Constant.t) With_stack_hash.t list ->
                let hd = read_elt elt in
                let tl = V.get r_tl in
                { With_stack_hash.stack_hash = As_prover.read Field.typ h
                ; elt = hd
                }
                :: tl)
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

      module Protocol_state_predicate = struct
        type t = Snapp_predicate.Protocol_state.Checked.t
      end

      module Field = Impl.Field

      module Local_state = struct
        type failure_status = unit

        type t =
          ( Stack_frame.t
          , Call_stack.t
          , Token_id.t
          , Amount.t
          , Ledger_hash.var * Sparse_ledger.t V.t
          , Bool.t
          , Transaction_commitment.t
          , failure_status )
          Mina_transaction_logic.Parties_logic.Local_state.t

        let add_check (t : t) _failure b =
          { t with success = Bool.(t.success &&& b) }

        let update_failure_status (t : t) _failure_status b =
          add_check (t : t) () b
      end
    end

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
            Option.iter snapp_statement ~f:(fun (tag, _) ->
                let vk =
                  exists Side_loaded_verification_key.typ ~compute:(fun () ->
                      Option.value_exn
                        (As_prover.Ref.get
                           (Data_as_hash.ref a.snapp.verification_key.data))
                          .data)
                in
                let expected_hash =
                  Data_as_hash.hash a.snapp.verification_key.data
                in
                let actual_hash = Snapp_account.Checked.digest_vk vk in
                Field.Assert.equal expected_hash actual_hash ;
                Pickles.Side_loaded.in_circuit (side_loaded tag) vk)
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

          let if_ b ~then_:(xt, rt) ~else_:(xe, re) =
            ( run_checked (Ledger_hash.if_ b ~then_:xt ~else_:xe)
            , V.if_ b ~then_:rt ~else_:re )

          let empty ~depth () : t =
            let t = Sparse_ledger.empty ~depth () in
            ( Ledger_hash.var_of_t (Sparse_ledger.merkle_root t)
            , V.create (fun () -> t) )

          let idx ledger id = Sparse_ledger.find_index_exn ledger id

          let body_id (body : Party.Body.Checked.t) =
            let open As_prover in
            Mina_base.Account_id.create
              (read Signature_lib.Public_key.Compressed.typ body.public_key)
              (read Mina_base.Token_id.typ body.token_id)

          let get_account { party; _ } (_root, ledger) =
            let idx =
              V.map ledger ~f:(fun l -> idx l (body_id party.data.body))
            in
            let account =
              exists Mina_base.Account.Checked.Unhashed.typ ~compute:(fun () ->
                  Sparse_ledger.get_exn (V.get ledger) (V.get idx))
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
                          (true, h)))
            in
            (account, incl)

          let set_account (_root, ledger) (a, incl) =
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

          let check_inclusion (root, _) (account, incl) =
            with_label __LOC__
              (fun () -> Field.Assert.equal (implied_root account incl))
              (Ledger_hash.var_to_hash_packed root)

          let check_account public_key token_id
              (({ data = account; _ }, _) : Account.t * _) =
            let is_new =
              run_checked
                (Signature_lib.Public_key.Compressed.Checked.equal
                   account.public_key
                   Signature_lib.Public_key.Compressed.(var_of_t empty))
            in
            with_label __LOC__ (fun () ->
                Boolean.Assert.any
                  [ is_new
                  ; run_checked
                      (Signature_lib.Public_key.Compressed.Checked.equal
                         public_key account.public_key)
                  ]) ;
            with_label __LOC__ (fun () ->
                Boolean.Assert.any
                  [ is_new; Token_id.equal token_id account.token_id ]) ;
            `Is_new is_new
        end

        module Party = struct
          type t = party

          type parties = Parties.t

          type transaction_commitment = Transaction_commitment.t

          let balance_change (t : t) = t.party.data.body.balance_change

          let protocol_state (t : t) = t.party.data.body.protocol_state

          let token_id (t : t) = t.party.data.body.token_id

          let public_key (t : t) = t.party.data.body.public_key

          let caller (t : t) = t.party.data.caller

          let account_id (t : t) = Account_id.create (public_key t) (token_id t)

          let use_full_commitment (t : t) =
            t.party.data.body.use_full_commitment

          let increment_nonce (t : t) = t.party.data.body.increment_nonce

          let check_authorization ~commitment
              ~at_party:({ hash = at_party; _ } : Parties.t)
              ({ party; control; _ } : t) =
            let proof_verifies =
              match (auth_type, snapp_statement) with
              | Proof, Some (_i, s) ->
                  with_label __LOC__ (fun () ->
                      Snapp_statement.Checked.Assert.equal
                        { transaction = commitment; at_party }
                        s) ;
                  Boolean.true_
              | (Signature | None_given), None ->
                  Boolean.false_
              | Proof, None | (Signature | None_given), Some _ ->
                  assert false
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
                            assert false)
                  in
                  run_checked
                    (let%bind (module S) =
                       Tick.Inner_curve.Checked.Shifted.create ()
                     in
                     signature_verifies
                       ~shifted:(module S)
                       ~payload_digest:commitment signature
                       party.data.body.public_key)
            in
            ( `Proof_verifies proof_verifies
            , `Signature_verifies signature_verifies )

          module Update = struct
            open Snapp_basic

            type 'a set_or_keep = 'a Set_or_keep.Checked.t

            let timing ({ party; _ } : t) : Account.timing set_or_keep =
              Set_or_keep.Checked.map
                ~f:Party.Update.Timing_info.Checked.to_account_timing
                party.data.body.update.timing

            let app_state ({ party; _ } : t) = party.data.body.update.app_state

            let verification_key ({ party; _ } : t) =
              party.data.body.update.verification_key

            let sequence_events ({ party; _ } : t) =
              party.data.body.sequence_events

            let snapp_uri ({ party; _ } : t) = party.data.body.update.snapp_uri

            let token_symbol ({ party; _ } : t) =
              party.data.body.update.token_symbol

            let delegate ({ party; _ } : t) = party.data.body.update.delegate

            let voting_for ({ party; _ } : t) =
              party.data.body.update.voting_for

            let permissions ({ party; _ } : t) =
              party.data.body.update.permissions
          end
        end

        module Set_or_keep = struct
          include Snapp_basic.Set_or_keep.Checked
        end

        module Global_state = struct
          type t = Global_state.t =
            { ledger : Ledger_hash.var * Sparse_ledger.t Prover_value.t
            ; fee_excess : Amount.Signed.t
            ; protocol_state : Snapp_predicate.Protocol_state.View.Checked.t
            }

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
      end

      module Env = struct
        open Inputs

        type t =
          < party : Party.t
          ; account : Account.t
          ; ledger : Ledger.t
          ; amount : Amount.t
          ; signed_amount : Amount.Signed.t
          ; bool : Bool.t
          ; token_id : Token_id.t
          ; global_state : Global_state.t
          ; inclusion_proof : (Bool.t * Field.t) list
          ; parties : Parties.t
          ; local_state :
              ( Stack_frame.t
              , Call_stack.t
              , Token_id.t
              , Amount.t
              , Ledger.t
              , Bool.t
              , Transaction_commitment.t
              , unit )
              Mina_transaction_logic.Parties_logic.Local_state.t
          ; protocol_state_predicate : Snapp_predicate.Protocol_state.Checked.t
          ; transaction_commitment : Transaction_commitment.t
          ; full_transaction_commitment : Transaction_commitment.t
          ; field : Field.t
          ; failure : unit >
      end

      include Mina_transaction_logic.Parties_logic.Make (Inputs)

      let perform (type r)
          (eff : (r, Env.t) Mina_transaction_logic.Parties_logic.Eff.t) : r =
        match eff with
        | Check_protocol_state_predicate (protocol_state_predicate, global_state)
          ->
            Snapp_predicate.Protocol_state.Checked.check
              protocol_state_predicate global_state.protocol_state
        | Check_predicate (_is_start, { party; _ }, account, _global) ->
            Snapp_predicate.Account.Checked.check party.data.predicate
              account.data
        | Check_auth { is_start; party = { party; _ }; account } ->
            (* If there's a valid signature, it must increment the nonce or use full commitment *)
            let account', `proof_must_verify proof_must_verify =
              apply_body ~is_start party.data account.data
            in
            let proof_must_verify = proof_must_verify () in
            let success =
              match auth_type with
              | None_given | Signature ->
                  Boolean.(not proof_must_verify)
              | Proof ->
                  (* We always assert that the proof verifies. *)
                  Boolean.true_
            in
            (* omit failure status here, unlike `Mina_transaction_logic` *)
            (Inputs.Account.account_with_hash account', success, ())
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
              Pending_coinbase.Stack.equal_var pending_coinbase_stack_init
                pending_coinbase_stack_before
            in
            Boolean.Assert.all
              [ correct_coinbase_target_stack; valid_init_state ]))

    let main ?(witness : Witness.t option) (spec : Spec.t) ~constraint_constants
        snapp_statements (statement : Statement.With_sok.Checked.t) =
      let open Impl in
      run_checked (dummy_constraints ()) ;
      let ( ! ) x = Option.value_exn x in
      let state_body =
        exists (Mina_state.Protocol_state.Body.typ ~constraint_constants)
          ~compute:(fun () -> !witness.state_body)
      in
      let pending_coinbase_stack_init =
        exists Pending_coinbase.Stack.typ ~compute:(fun () ->
            !witness.init_stack)
      in
      let module V = Prover_value in
      run_checked
        (check_protocol_state ~pending_coinbase_stack_init
           ~pending_coinbase_stack_before:
             statement.source.pending_coinbase_stack
           ~pending_coinbase_stack_after:statement.target.pending_coinbase_stack
           state_body) ;
      let init :
          Global_state.t * _ Mina_transaction_logic.Parties_logic.Local_state.t
          =
        let g : Global_state.t =
          { ledger =
              ( statement.source.ledger
              , V.create (fun () -> !witness.global_ledger) )
          ; fee_excess = Amount.Signed.(Checked.constant zero)
          ; protocol_state =
              Mina_state.Protocol_state.Body.view_checked state_body
          }
        in
        let l : _ Mina_transaction_logic.Parties_logic.Local_state.t =
          { frame =
              Inputs.Stack_frame.unhash statement.source.local_state.frame
                (V.create (fun () -> !witness.local_state_init.frame))
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
          ; failure_status = ()
          }
        in
        (g, l)
      in
      let start_parties =
        As_prover.Ref.create (fun () -> !witness.start_parties)
      in
      let (global, local), snapp_statements =
        List.fold_left spec ~init:(init, snapp_statements)
          ~f:(fun (((_, local) as acc), statements) party_spec ->
            let snapp_statement, statements =
              match party_spec.auth_type with
              | Signature | None_given ->
                  (None, statements)
              | Proof -> (
                  match statements with
                  | [] ->
                      assert false
                  | s :: ss ->
                      (Some s, ss) )
            in
            let module S = Single (struct
              let constraint_constants = constraint_constants

              let spec = party_spec

              let snapp_statement = snapp_statement
            end) in
            let finish v =
              let open Mina_transaction_logic.Parties_logic.Start_data in
              let ps =
                V.map v ~f:(function
                  | `Skip ->
                      []
                  | `Start p ->
                      Parties.parties p.parties
                      |> Parties.Call_forest.map ~f:(fun party -> (party, ())))
              in
              let h =
                exists Field.typ ~compute:(fun () ->
                    Parties.Call_forest.hash (V.get ps))
              in
              let start_data =
                { Mina_transaction_logic.Parties_logic.Start_data.parties =
                    { With_hash.hash = h; data = ps }
                ; memo_hash =
                    exists Field.typ ~compute:(fun () ->
                        match V.get v with
                        | `Skip ->
                            Field.Constant.zero
                        | `Start p ->
                            p.memo_hash)
                }
              in
              let global_state, local_state =
                S.apply ~constraint_constants
                  ~is_start:
                    ( match party_spec.is_start with
                    | `No ->
                        `No
                    | `Yes ->
                        `Yes start_data
                    | `Compute_in_circuit ->
                        `Compute start_data )
                  S.{ perform }
                  acc
              in
              (* replace any transaction failure with unit value *)
              (global_state, { local_state with failure_status = () })
            in
            let acc' =
              match party_spec.is_start with
              | `No ->
                  let global_state, local_state =
                    S.apply ~constraint_constants ~is_start:`No
                      S.{ perform }
                      acc
                  in
                  (* replace any transaction failure with unit value *)
                  (global_state, { local_state with failure_status = () })
              | `Compute_in_circuit ->
                  V.create (fun () ->
                      match As_prover.Ref.get start_parties with
                      | [] ->
                          `Skip
                      | p :: ps ->
                          let should_pop =
                            Mina_base.Parties.Call_forest.is_empty
                              (V.get local.frame.data.calls.data)
                          in
                          if should_pop then (
                            As_prover.Ref.set start_parties ps ;
                            `Start p )
                          else `Skip)
                  |> finish
              | `Yes ->
                  as_prover (fun () ->
                      assert (
                        Mina_base.Parties.Call_forest.is_empty
                          (V.get local.frame.data.calls.data) )) ;
                  V.create (fun () ->
                      match As_prover.Ref.get start_parties with
                      | [] ->
                          assert false
                      | p :: ps ->
                          As_prover.Ref.set start_parties ps ;
                          `Start p)
                  |> finish
            in
            (acc', statements))
      in
      with_label __LOC__ (fun () -> assert (List.is_empty snapp_statements)) ;
      let local_state_ledger =
        (* The actual output ledger may differ from the one generated by
           transaction logic, because we handle failures differently between
           the two. However, in the case of failure, we never use this ledger:
           it will never be upgraded to the global ledger. If we have such a
           failure, we just pretend we achieved the target hash.
        *)
        Field.if_ local.success
          ~then_:(Inputs.Stack_frame.hash local.frame)
          ~else_:statement.target.local_state.frame
      in
      with_label __LOC__ (fun () ->
          Local_state.Checked.assert_equal statement.target.local_state
            { local with
              frame = local_state_ledger
            ; call_stack = local.call_stack.hash
            ; ledger = fst local.ledger
            }) ;
      with_label __LOC__ (fun () ->
          run_checked
            (Frozen_ledger_hash.assert_equal (fst global.ledger)
               statement.target.ledger)) ;
      with_label __LOC__ (fun () ->
          run_checked
            (Amount.Checked.assert_equal statement.supply_increase
               Amount.(var_of_t zero))) ;
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
             Fee_excess.assert_equal_checked expected got)) ;
      let `Needs_some_work_for_snapps_on_mainnet = Mina_base.Util.todo_snapps in
      (* TODO: Check various consistency equalities between local and global and the statement *)
      ()

    (* Horrible hack :( *)
    let witness : Witness.t option ref = ref None

    let rule (type a b c d) ~constraint_constants ~proof_level
        (t : (a, b, c, d) Basic.t_typed) :
        ( a
        , b
        , c
        , d
        , Statement.With_sok.var
        , Statement.With_sok.t )
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
          ; main_value = (fun [ _ ] _ -> [ prev_should_verify ])
          ; main =
              (fun [ snapp_statement ] stmt ->
                main ?witness:!witness s ~constraint_constants
                  (List.mapi [ snapp_statement ] ~f:(fun i x -> (i, x)))
                  stmt ;
                [ b ])
          }
      | Opt_signed_unsigned ->
          { identifier = "opt_signed-unsigned"
          ; prevs = M.[]
          ; main_value = (fun [] _ -> [])
          ; main =
              (fun [] stmt ->
                main ?witness:!witness s ~constraint_constants [] stmt ;
                [])
          }
      | Opt_signed_opt_signed ->
          { identifier = "opt_signed-opt_signed"
          ; prevs = M.[]
          ; main_value = (fun [] _ -> [])
          ; main =
              (fun [] stmt ->
                main ?witness:!witness s ~constraint_constants [] stmt ;
                [])
          }
      | Opt_signed ->
          { identifier = "opt_signed"
          ; prevs = M.[]
          ; main_value = (fun [] _ -> [])
          ; main =
              (fun [] stmt ->
                main ?witness:!witness s ~constraint_constants [] stmt ;
                [])
          }
  end

  type _ Snarky_backendless.Request.t +=
    | Transaction : Transaction_union.t Snarky_backendless.Request.t
    | State_body :
        Mina_state.Protocol_state.Body.Value.t Snarky_backendless.Request.t
    | Init_stack : Pending_coinbase.Stack.t Snarky_backendless.Request.t

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
           payload.common.fee_payer_pk)
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
          Token_id.(Checked.equal fee_token (Checked.constant default)))
    in
    let token = payload.body.token_id in
    let%bind token_default =
      make_checked (fun () ->
          Token_id.(Checked.equal token (Checked.constant default)))
    in
    let%bind () =
      Checked.all_unit
        [ [%with_label
            "Token_locked value is compatible with the transaction kind"]
            (Boolean.Assert.any
               [ Boolean.not payload.body.token_locked; is_create_account ])
        ; [%with_label "Token_locked cannot be used with the default token"]
            (Boolean.Assert.any
               [ Boolean.not payload.body.token_locked
               ; Boolean.not token_default
               ])
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
                  ])
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
           ])
    in
    let current_global_slot =
      Mina_state.Protocol_state.Body.consensus_state state_body
      |> Consensus.Data.Consensus_state.global_slot_since_genesis_var
    in
    (* Query user command predicted failure/success. *)
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
                 [ correct_coinbase_target_stack; valid_init_state ])))
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
      (* Predicate check is to be performed later if this is true. *)
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
      [%with_label "Check predicate failure against predicted"]
        (let%bind predicate_failed =
           Boolean.((not predicate_result) &&& not predicate_deferred)
         in
         assert_r1cs
           (predicate_failed :> Field.Var.t)
           (is_user_command :> Field.Var.t)
           (user_command_failure.predicate_failed :> Field.Var.t))
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
                    [ Boolean.not is_user_command; nonce_matches ])
             in
             let%bind receipt_chain_hash =
               let current = account.receipt_chain_hash in
               let%bind r =
                 Receipt.Chain_hash.Checked.cons (Signed_command payload)
                   current
               in
               Receipt.Chain_hash.Checked.if_ is_user_command ~then_:r
                 ~else_:current
             in
             let%bind is_empty_and_writeable =
               (* If this is a coinbase with zero fee, do not create the
                  account, since the fee amount won't be enough to pay for it.
               *)
               Boolean.(is_empty_and_writeable &&& not is_zero_fee)
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
                    add fee_payer_amount account_creation_fee))
             in
             let txn_global_slot = current_global_slot in
             let%bind `Min_balance _, timing =
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
                  check_timing ~balance_check ~timed_balance_check ~account
                    ~txn_amount:(Some txn_amount) ~txn_global_slot)
             in
             let%bind balance =
               [%with_label "Check payer balance"]
                 (Balance.Checked.add_signed_amount account.balance amount)
             in
             let%map public_key =
               Public_key.Compressed.Checked.if_ is_empty_and_writeable
                 ~then_:(Account_id.Checked.public_key fee_payer)
                 ~else_:account.public_key
             and token_id =
               make_checked (fun () ->
                   Token_id.Checked.if_ is_empty_and_writeable
                     ~then_:(Account_id.Checked.token_id fee_payer)
                     ~else_:account.token_id)
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
             ; snapp = account.snapp
             ; snapp_uri = account.snapp_uri
             }))
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
         Amount.Checked.sub base_amount coinbase_receiver_fee)
    in
    let receiver_overflow = ref Boolean.false_ in
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
             let%bind is_empty_failure =
               let%bind must_not_be_empty =
                 Boolean.(is_stake_delegation ||| is_mint_tokens)
               in
               Boolean.(is_empty_and_writeable &&& must_not_be_empty)
             in
             let%bind () =
               [%with_label "Receiver existence failure matches predicted"]
                 (Boolean.Assert.( = ) is_empty_failure
                    user_command_failure.receiver_not_present)
             in
             let is_empty_and_writeable =
               (* is_empty_and_writable && not is_empty_failure *)
               Boolean.Unsafe.of_cvar
               @@ Field.Var.(
                    sub (is_empty_and_writeable :> t) (is_empty_failure :> t))
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
                         token_cannot_create)
                  in
                  [%with_label "equal token_cannot_create"]
                    (Boolean.Assert.( = ) token_cannot_create
                       user_command_failure.token_cannot_create))
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
                        user_command_failure.amount_insufficient_to_create)
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
             let%bind user_command_fails =
               Boolean.(!receiver_overflow ||| user_command_fails)
             in
             let%bind is_empty_and_writeable =
               (* Do not create a new account if the user command will fail. *)
               Boolean.(is_empty_and_writeable &&& not user_command_fails)
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
                     ~else_:account.token_id)
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
             ; snapp = account.snapp
             ; snapp_uri = account.snapp_uri
             }))
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
                    user_command_failure.source_not_present)
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
                       num_failures))
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
                      (let%bind not_ok =
                         Boolean.(
                           (not ok)
                           &&& not
                                 user_command_failure
                                   .source_insufficient_balance)
                       in
                       Boolean.Assert.( = ) not_ok
                         user_command_failure.source_bad_timing)
                  in
                  check_timing ~balance_check ~timed_balance_check ~account
                    ~txn_amount:(Some amount) ~txn_global_slot)
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
             ; snapp = account.snapp
             ; snapp_uri = account.snapp_uri
             }))
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
        supply_increase : Amount.t
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
              ~else_:t.payload.common.fee_token)
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
               statement.target.local_state))
    in
    Checked.all_unit
      [ [%with_label "equal roots"]
          (Frozen_ledger_hash.assert_equal root_after statement.target.ledger)
      ; [%with_label "equal supply_increases"]
          (Currency.Amount.Checked.assert_equal supply_increase
             statement.supply_increase)
      ; [%with_label "equal fee excesses"]
          (Fee_excess.assert_equal_checked fee_excess statement.fee_excess)
      ]

  let rule ~constraint_constants : _ Pickles.Inductive_rule.t =
    { identifier = "transaction"
    ; prevs = []
    ; main =
        (fun [] x ->
          Run.run_checked (main ~constraint_constants x) ;
          [])
    ; main_value = (fun [] _ -> [])
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
    ; supply_increase : Amount.t
    ; fee_excess : Fee_excess.t
    ; sok_digest : Sok_message.Digest.t
    ; pending_coinbase_stack_state : Pending_coinbase_stack_state.t
    }
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
  let%snarkydef main
      ([ s1; s2 ] :
        (Statement.With_sok.var * (Statement.With_sok.var * _))
        Pickles_types.Hlist.HlistId.t) (s : Statement.With_sok.Checked.t) =
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
         Boolean.Assert.is_true valid_pending_coinbase_stack_transition)
    in
    let%bind supply_increase =
      Amount.Checked.add s1.supply_increase s2.supply_increase
    in
    let%bind () =
      make_checked (fun () ->
          Local_state.Checked.assert_equal s.source.local_state
            s1.source.local_state ;
          Local_state.Checked.assert_equal s.target.local_state
            s2.target.local_state)
    in
    Checked.all_unit
      [ [%with_label "equal fee excesses"]
          (Fee_excess.assert_equal_checked fee_excess s.fee_excess)
      ; [%with_label "equal supply increases"]
          (Amount.Checked.assert_equal supply_increase s.supply_increase)
      ; [%with_label "equal source ledger hashes"]
          (Frozen_ledger_hash.assert_equal s.source.ledger s1.source.ledger)
      ; [%with_label "equal target, source ledger hashes"]
          (Frozen_ledger_hash.assert_equal s1.target.ledger s2.source.ledger)
      ; [%with_label "equal target ledger hashes"]
          (Frozen_ledger_hash.assert_equal s2.target.ledger s.target.ledger)
      ]

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
        (fun ps x ->
          Run.run_checked (main ps x) ;
          [ b; b ])
    ; main_value = (fun _ _ -> [ prev_should_verify; prev_should_verify ])
    }
end

open Pickles_types

type tag =
  ( Statement.With_sok.Checked.t
  , Statement.With_sok.t
  , Nat.N2.n
  , Nat.N6.n )
  Pickles.Tag.t

let time lab f =
  let start = Time.now () in
  let x = f () in
  let stop = Time.now () in
  printf "%s: %s\n%!" lab (Time.Span.to_string_hum (Time.diff stop start)) ;
  x

let system ~proof_level ~constraint_constants =
  time "Transaction_snark.system" (fun () ->
      Pickles.compile ~cache:Cache_dir.cache
        (module Statement.With_sok.Checked)
        (module Statement.With_sok)
        ~typ:Statement.With_sok.typ
        ~branches:(module Nat.N6)
        ~max_branching:(module Nat.N2)
        ~name:"transaction-snark"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants)
        ~choices:(fun ~self ->
          let parties x =
            Base.Parties_snark.rule ~constraint_constants ~proof_level x
          in
          [ Base.rule ~constraint_constants
          ; Merge.rule ~proof_level self
          ; parties Opt_signed_unsigned
          ; parties Opt_signed_opt_signed
          ; parties Opt_signed
          ; parties Proved
          ]))

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

  val of_non_parties_transaction :
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

  val of_parties_segment_exn :
       statement:Statement.With_sok.t
    -> snapp_statement:(int * Snapp_statement.t) option
    -> witness:Parties_segment.Witness.t
    -> spec:Parties_segment.Basic.t
    -> t Async.Deferred.t

  val merge :
    t -> t -> sok_digest:Sok_message.Digest.t -> t Async.Deferred.Or_error.t
end

let check_transaction_union ?(preeval = false) ~constraint_constants sok_message
    source target init_stack pending_coinbase_stack_state transaction state_body
    handler =
  if preeval then failwith "preeval currently disabled" ;
  let sok_digest = Sok_message.digest sok_message in
  let handler =
    Base.transaction_union_handler handler transaction state_body init_stack
  in
  let statement : Statement.With_sok.t =
    Statement.Poly.with_empty_local_state ~source ~target
      ~supply_increase:(Transaction_union.supply_increase transaction)
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
                 >>= Base.main ~constraint_constants))
              handler)
           ())
      : unit * unit )

let check_transaction ?preeval ~constraint_constants ~sok_message ~source
    ~target ~init_stack ~pending_coinbase_stack_state ~snapp_account1:_
    ~snapp_account2:_
    (transaction_in_block : Transaction.Valid.t Transaction_protocol_state.t)
    handler =
  let transaction =
    Transaction_protocol_state.transaction transaction_in_block
  in
  let state_body = Transaction_protocol_state.block_data transaction_in_block in
  match to_preunion (transaction :> Transaction.t) with
  | `Parties _ ->
      failwith "Called non-party transaction with parties transaction"
  | `Transaction t ->
      check_transaction_union ?preeval ~constraint_constants sok_message source
        target init_stack pending_coinbase_stack_state
        (Transaction_union.of_transaction t)
        state_body handler

let check_user_command ~constraint_constants ~sok_message ~source ~target
    ~init_stack ~pending_coinbase_stack_state t_in_block handler =
  let user_command = Transaction_protocol_state.transaction t_in_block in
  check_transaction ~constraint_constants ~sok_message ~source ~target
    ~init_stack ~pending_coinbase_stack_state ~snapp_account1:None
    ~snapp_account2:None
    { t_in_block with transaction = Command (Signed_command user_command) }
    handler

let generate_transaction_union_witness ?(preeval = false) ~constraint_constants
    sok_message source target transaction_in_block init_stack
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
    Statement.Poly.with_empty_local_state ~source ~target
      ~supply_increase:(Transaction_union.supply_increase transaction)
      ~pending_coinbase_stack_state
      ~fee_excess:(Transaction_union.fee_excess transaction)
      ~sok_digest
  in
  let open Tick in
  let main x = handle (Base.main ~constraint_constants x) handler in
  generate_auxiliary_input [ Statement.With_sok.typ ] () main statement

let generate_transaction_witness ?preeval ~constraint_constants ~sok_message
    ~source ~target ~init_stack ~pending_coinbase_stack_state ~snapp_account1:_
    ~snapp_account2:_
    (transaction_in_block : Transaction.Valid.t Transaction_protocol_state.t)
    handler =
  match
    to_preunion
      ( Transaction_protocol_state.transaction transaction_in_block
        :> Transaction.t )
  with
  | `Parties _ ->
      failwith "Called non-party transaction with parties transaction"
  | `Transaction t ->
      generate_transaction_union_witness ?preeval ~constraint_constants
        sok_message source target
        { transaction_in_block with
          transaction = Transaction_union.of_transaction t
        }
        init_stack pending_coinbase_stack_state handler

let verify (ts : (t * _) list) ~key =
  if
    List.for_all ts ~f:(fun ({ statement; _ }, message) ->
        Sok_message.Digest.equal
          (Sok_message.digest message)
          statement.sok_digest)
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
          Tick.constraint_system ~exposing:[ Statement.With_sok.typ ] (fun x ->
              let open Tick in
              let%bind x1 = exists Statement.With_sok.typ in
              let%bind x2 = exists Statement.With_sok.typ in
              main [ x1; x2 ] x)) )
  ; ( "transaction-base"
    , digest
        Base.(
          Tick.constraint_system ~exposing:[ Statement.With_sok.typ ]
            (main ~constraint_constants)) )
  ]

type local_state =
  ( Stack_frame.value
  , Stack_frame.value list
  , Token_id.t
  , Currency.Amount.t
  , Sparse_ledger.t
  , bool
  , unit
  , Transaction_status.Failure.t option )
  Mina_transaction_logic.Parties_logic.Local_state.t

type global_state = Sparse_ledger.Global_state.t

module Parties_intermediate_state = struct
  type state = { global : global_state; local : local_state }

  type t =
    { kind : [ `Same | `New | `Two_new ]
    ; spec : Parties_segment.Basic.t
    ; state_before : state
    ; state_after : state
    ; use_full_commitment : [ `Others | `Proved_use_full_commitment of bool ]
    }
end

(** [group_by_parties_rev partiess stmtss] identifies before/after pairs of
    statements, corresponding to parties in [partiess] which minimize the
    number of snark proofs needed to prove all of the parties.

    This function is intended to take the parties from multiple transactions as
    its input, which may be converted from a [Parties.t list] using
    [List.map ~f:Parties.parties]. The [stmtss] argument should be a list of
    the same length, with 1 more state than the number of parties for each
    transaction.

    For example, two transactions made up of parties [[p1; p2; p3]] and
    [[p4; p5]] should have the statements [[[s0; s1; s2; s3]; [s3; s4; s5]]],
    where each [s_n] is the state after applying [p_n] on top of [s_{n-1}], and
    where [s0] is the initial state before any of the transactions have been
    applied.

    Each pair is also identified with one of [`Same], [`New], or [`Two_new],
    indicating that the next one ([`New]) or next two ([`Two_new]) [Parties.t]s
    will need to be passed as part of the snark witness while applying that
    pair.
*)
let group_by_parties_rev (partiess : Party.t list list)
    (stmtss : (global_state * local_state) list list) :
    Parties_intermediate_state.t list =
  let open Party.Poly in
  let use_full_commitment (p : Party.t) =
    match p.authorization with
    | Proof _ ->
        `Proved_use_full_commitment p.data.body.use_full_commitment
    | _ ->
        `Others
  in
  let intermediate_state p ~kind ~spec ~before ~after =
    { Parties_intermediate_state.kind
    ; spec
    ; state_before = { global = fst before; local = snd before }
    ; state_after = { global = fst after; local = snd after }
    ; use_full_commitment = use_full_commitment p
    }
  in
  let rec group_by_parties_rev (partiess : Party.t list list) stmtss acc =
    match (partiess, stmtss) with
    | ([] | [ [] ]), [ _ ] ->
        (* We've associated statements with all given parties. *)
        acc
    | [ [ ({ authorization = a1; _ } as p) ] ], [ [ before; after ] ] ->
        (* There are no later parties to pair this one with. Prove it on its
           own.
        *)
        intermediate_state p ~kind:`Same
          ~spec:(Parties_segment.Basic.of_controls [ a1 ])
          ~before ~after
        :: acc
    | [ []; [ ({ authorization = a1; _ } as p) ] ], [ [ _ ]; [ before; after ] ]
      ->
        (* This party is part of a new transaction, and there are no later
           parties to pair it with. Prove it on its own.
        *)
        intermediate_state p ~kind:`New
          ~spec:(Parties_segment.Basic.of_controls [ a1 ])
          ~before ~after
        :: acc
    | ( (({ authorization = Proof _ as a1; _ } as p) :: parties) :: partiess
      , (before :: (after :: _ as stmts)) :: stmtss ) ->
        (* This party contains a proof, don't pair it with other parties. *)
        group_by_parties_rev (parties :: partiess) (stmts :: stmtss)
          ( intermediate_state p ~kind:`Same
              ~spec:(Parties_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( []
        :: (({ authorization = Proof _ as a1; _ } as p) :: parties) :: partiess
      , [ _ ] :: (before :: (after :: _ as stmts)) :: stmtss ) ->
        (* This party is part of a new transaction, and contains a proof, don't
           pair it with other parties.
        *)
        group_by_parties_rev (parties :: partiess) (stmts :: stmtss)
          ( intermediate_state p ~kind:`New
              ~spec:(Parties_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( (({ authorization = a1; _ } as p)
        :: ({ authorization = Proof _; _ } :: _ as parties))
        :: partiess
      , (before :: (after :: _ as stmts)) :: stmtss ) ->
        (* The next party contains a proof, don't pair it with this party. *)
        group_by_parties_rev (parties :: partiess) (stmts :: stmtss)
          ( intermediate_state p ~kind:`Same
              ~spec:(Parties_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( (({ authorization = a1; _ } as p) :: ([] as parties))
        :: (({ authorization = Proof _; _ } :: _) :: _ as partiess)
      , (before :: (after :: _ as stmts)) :: stmtss ) ->
        (* The next party is in the next transaction and contains a proof,
           don't pair it with this party.
        *)
        group_by_parties_rev (parties :: partiess) (stmts :: stmtss)
          ( intermediate_state p ~kind:`Same
              ~spec:(Parties_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( (({ authorization = a1; _ } as p)
        :: { authorization = a2; _ } :: parties)
        :: partiess
      , (before :: _ :: (after :: _ as stmts)) :: stmtss ) ->
        (* The next two parties do not contain proofs, and are within the same
           transaction. Pair them.
           Ok to get "use_full_commitment" of [a1] because neither of them
           contain a proof.
        *)
        group_by_parties_rev (parties :: partiess) (stmts :: stmtss)
          ( intermediate_state p ~kind:`Same
              ~spec:(Parties_segment.Basic.of_controls [ a1; a2 ])
              ~before ~after
          :: acc )
    | ( []
        :: (({ authorization = a1; _ } as p)
           :: ({ authorization = Proof _; _ } :: _ as parties))
           :: partiess
      , [ _ ] :: (before :: (after :: _ as stmts)) :: stmtss ) ->
        (* This party is in the next transaction, and the next party contains a
           proof, don't pair it with this party.
        *)
        group_by_parties_rev (parties :: partiess) (stmts :: stmtss)
          ( intermediate_state p ~kind:`New
              ~spec:(Parties_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( []
        :: (({ authorization = a1; _ } as p)
           :: { authorization = a2; _ } :: parties)
           :: partiess
      , [ _ ] :: (before :: _ :: (after :: _ as stmts)) :: stmtss ) ->
        (* The next two parties do not contain proofs, and are within the same
           new transaction. Pair them.
           Ok to get "use_full_commitment" of [a1] because neither of them
           contain a proof.
        *)
        group_by_parties_rev (parties :: partiess) (stmts :: stmtss)
          ( intermediate_state p ~kind:`New
              ~spec:(Parties_segment.Basic.of_controls [ a1; a2 ])
              ~before ~after
          :: acc )
    | ( [ ({ authorization = a1; _ } as p) ]
        :: ({ authorization = a2; _ } :: parties) :: partiess
      , (before :: _after1) :: (_before2 :: (after :: _ as stmts)) :: stmtss )
      ->
        (* The next two parties do not contain proofs, and the second is within
           a new transaction. Pair them.
           Ok to get "use_full_commitment" of [a1] because neither of them
           contain a proof.
        *)
        group_by_parties_rev (parties :: partiess) (stmts :: stmtss)
          ( intermediate_state p ~kind:`New
              ~spec:(Parties_segment.Basic.of_controls [ a1; a2 ])
              ~before ~after
          :: acc )
    | ( []
        :: (({ authorization = a1; _ } as p) :: parties)
           :: (({ authorization = Proof _; _ } :: _) :: _ as partiess)
      , [ _ ] :: (before :: ([ after ] as stmts)) :: (_ :: _ as stmtss) ) ->
        (* The next transaction contains a proof, and this party is in a new
           transaction, don't pair it with the next party.
        *)
        group_by_parties_rev (parties :: partiess) (stmts :: stmtss)
          ( intermediate_state p ~kind:`New
              ~spec:(Parties_segment.Basic.of_controls [ a1 ])
              ~before ~after
          :: acc )
    | ( []
        :: [ ({ authorization = a1; _ } as p) ]
           :: ({ authorization = a2; _ } :: parties) :: partiess
      , [ _ ]
        :: [ before; _after1 ] :: (_before2 :: (after :: _ as stmts)) :: stmtss
      ) ->
        (* The next two parties do not contain proofs, the first is within a
           new transaction, and the second is within another new transaction.
           Pair them.
           Ok to get "use_full_commitment" of [a1] because neither of them
           contain a proof.
        *)
        group_by_parties_rev (parties :: partiess) (stmts :: stmtss)
          ( intermediate_state p ~kind:`Two_new
              ~spec:(Parties_segment.Basic.of_controls [ a1; a2 ])
              ~before ~after
          :: acc )
    | [ [ ({ authorization = a1; _ } as p) ] ], (before :: after :: _) :: _ ->
        (* This party is the final party given. Prove it on its own. *)
        intermediate_state p ~kind:`Same
          ~spec:(Parties_segment.Basic.of_controls [ a1 ])
          ~before ~after
        :: acc
    | ( [] :: [ ({ authorization = a1; _ } as p) ] :: [] :: _
      , [ _ ] :: (before :: after :: _) :: _ ) ->
        (* This party is the final party given, in a new transaction. Prove it
           on its own.
        *)
        intermediate_state p ~kind:`New
          ~spec:(Parties_segment.Basic.of_controls [ a1 ])
          ~before ~after
        :: acc
    | _, [] ->
        failwith "group_by_parties_rev: No statements remaining"
    | ([] | [ [] ]), _ ->
        failwith "group_by_parties_rev: Unmatched statements remaining"
    | [] :: _, [] :: _ ->
        failwith
          "group_by_parties_rev: No final statement for current transaction"
    | [] :: _, (_ :: _ :: _) :: _ ->
        failwith
          "group_by_parties_rev: Unmatched statements for current transaction"
    | [] :: [ _ ] :: _, [ _ ] :: (_ :: _ :: _ :: _) :: _ ->
        failwith
          "group_by_parties_rev: Unmatched statements for next transaction"
    | [ []; [ _ ] ], [ _ ] :: [ _; _ ] :: _ :: _ ->
        failwith
          "group_by_parties_rev: Unmatched statements after next transaction"
    | (_ :: _) :: _, ([] | [ _ ]) :: _ | (_ :: _ :: _) :: _, [ _; _ ] :: _ ->
        failwith
          "group_by_parties_rev: Too few statements remaining for the current \
           transaction"
    | ([] | [ _ ]) :: [] :: _, _ ->
        failwith "group_by_parties_rev: The next transaction has no parties"
    | [] :: (_ :: _) :: _, _ :: ([] | [ _ ]) :: _
    | [] :: (_ :: _ :: _) :: _, _ :: [ _; _ ] :: _ ->
        failwith
          "group_by_parties_rev: Too few statements remaining for the next \
           transaction"
    | [ _ ] :: (_ :: _) :: _, _ :: ([] | [ _ ]) :: _ ->
        failwith
          "group_by_parties_rev: Too few statements remaining for the next \
           transaction"
    | [] :: [ _ ] :: (_ :: _) :: _, _ :: _ :: ([] | [ _ ]) :: _ ->
        failwith
          "group_by_parties_rev: Too few statements remaining for the \
           transaction after next"
    | ([] | [ _ ]) :: (_ :: _) :: _, [ _ ] ->
        failwith
          "group_by_parties_rev: No statements given for the next transaction"
    | [] :: [ _ ] :: (_ :: _) :: _, [ _; (_ :: _ :: _) ] ->
        failwith
          "group_by_parties_rev: No statements given for transaction after next"
  in
  group_by_parties_rev partiess stmtss []

let rec accumulate_call_stack_hashes ~(hash_frame : 'frame -> field)
    (frames : 'frame list) : ('frame, field) With_stack_hash.t list =
  match frames with
  | [] ->
      []
  | f :: fs ->
      let h_f = hash_frame f in
      let tl = accumulate_call_stack_hashes ~hash_frame fs in
      let h_tl =
        match tl with [] -> Parties.Call_forest.empty | t :: _ -> t.stack_hash
      in
      { stack_hash = Parties.Call_forest.hash_cons h_f h_tl; elt = f } :: tl

let parties_witnesses_exn ~constraint_constants ~state_body ~fee_excess
    ~pending_coinbase_init_stack ledger (partiess : Parties.t list) =
  let sparse_ledger =
    match ledger with
    | `Ledger ledger ->
        Sparse_ledger.of_ledger_subset_exn ledger
          (List.concat_map ~f:Parties.accounts_accessed partiess)
    | `Sparse_ledger sparse_ledger ->
        sparse_ledger
  in
  let state_body_hash = Mina_state.Protocol_state.Body.hash state_body in
  let state_view = Mina_state.Protocol_state.Body.view state_body in
  let _, _, states_rev =
    List.fold_left ~init:(fee_excess, sparse_ledger, []) partiess
      ~f:(fun (fee_excess, sparse_ledger, statess_rev) parties ->
        let _, states =
          Sparse_ledger.apply_parties_unchecked_with_states sparse_ledger
            ~constraint_constants ~state_view ~fee_excess parties
          |> Or_error.ok_exn
        in
        let final_state = fst (List.last_exn states) in
        (final_state.fee_excess, final_state.ledger, states :: statess_rev))
  in
  let states = List.rev states_rev in
  let states_rev =
    group_by_parties_rev
      ([] :: List.map ~f:Parties.parties_list partiess)
      ([ List.hd_exn (List.hd_exn states) ] :: states)
  in
  let tx_statement commitment full_commitment use_full_commitment
      (remaining_parties : (Party.t, _) Parties.Call_forest.t) :
      Snapp_statement.t =
    let at_party =
      Parties.Call_forest.(hash (accumulate_hashes' remaining_parties))
    in
    let transaction =
      match use_full_commitment with
      | `Proved_use_full_commitment b ->
          if b then full_commitment else commitment
      | _ ->
          failwith "Expected `Proof for party that has a proof"
    in
    { transaction; at_party }
  in
  let commitment = ref Local_state.dummy.transaction_commitment in
  let full_commitment = ref Local_state.dummy.full_transaction_commitment in
  let remaining_parties =
    let partiess =
      List.map partiess
        ~f:(fun parties : _ Mina_transaction_logic.Parties_logic.Start_data.t ->
          { parties; memo_hash = Signed_command_memo.hash parties.memo })
    in
    ref partiess
  in
  List.fold_right states_rev ~init:[]
    ~f:(fun
         { Parties_intermediate_state.kind
         ; spec
         ; state_before = { global = source_global; local = source_local }
         ; state_after = { global = target_global; local = target_local }
         ; use_full_commitment
         }
         witnesses
       ->
      let current_commitment = !commitment in
      let current_full_commitment = !full_commitment in
      let snapp_stmt =
        match spec with
        | Proved ->
            (* NB: This is only correct if we assume that a proved party will
               never appear first in a transaction.
            *)
            Some
              ( 0
              , tx_statement current_commitment current_full_commitment
                  use_full_commitment source_local.frame.calls )
        | _ ->
            None
      in
      let start_parties, next_commitment, next_full_commitment =
        let empty_if_last (mk : unit -> field * field) : field * field =
          match (target_local.frame.calls, target_local.call_stack) with
          | [], [] ->
              (* The commitment will be cleared, because this is the last
                 party.
              *)
              Parties.Transaction_commitment.(empty, empty)
          | _ ->
              mk ()
        in
        let mk_next_commitments (parties : Parties.t) =
          empty_if_last (fun () ->
              let next_commitment = Parties.commitment parties in
              let fee_payer_hash =
                Party.Predicated.(digest @@ of_fee_payer parties.fee_payer.data)
              in
              let next_full_commitment =
                Parties.Transaction_commitment.with_fee_payer next_commitment
                  ~fee_payer_hash
              in
              (next_commitment, next_full_commitment))
        in
        match kind with
        | `Same ->
            let next_commitment, next_full_commitment =
              empty_if_last (fun () ->
                  (current_commitment, current_full_commitment))
            in
            ([], next_commitment, next_full_commitment)
        | `New -> (
            match !remaining_parties with
            | parties :: rest ->
                let commitment', full_commitment' =
                  mk_next_commitments parties.parties
                in
                remaining_parties := rest ;
                commitment := commitment' ;
                full_commitment := full_commitment' ;
                ([ parties ], commitment', full_commitment')
            | _ ->
                failwith "Not enough remaining parties" )
        | `Two_new -> (
            match !remaining_parties with
            | parties1 :: parties2 :: rest ->
                let commitment', full_commitment' =
                  mk_next_commitments parties2.parties
                in
                remaining_parties := rest ;
                commitment := commitment' ;
                full_commitment := full_commitment' ;
                ([ parties1; parties2 ], commitment', full_commitment')
            | _ ->
                failwith "Not enough remaining parties" )
      in
      let hash_local_state (local : _ Mina_transaction_logic.Parties_logic.Local_state.t) =
        let frame (frame : Stack_frame.value) =
          { frame with
            calls = Parties.Call_forest.map frame.calls ~f:(fun p -> (p, ()))
          }
        in
        { local with
          frame = frame local.frame
        ; call_stack =
            List.map
              ~f:
                (With_stack_hash.map ~f:(fun f ->
                     With_hash.of_data (frame f) ~hash_data:Stack_frame.hash))
              (accumulate_call_stack_hashes ~hash_frame:Stack_frame.hash
                 local.call_stack)
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
      let w : Parties_segment.Witness.t =
        { global_ledger = source_global.ledger
        ; local_state_init = source_local
        ; start_parties
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
                   target_global.fee_excess source_global.fee_excess)
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
        |> Option.value_map ~default:Parties.Call_forest.empty
             ~f:With_stack_hash.stack_hash
      in
      let statement : Statement.With_sok.t =
        (* empty ledger hash in the local state at the beginning of each
           transaction
           `parties` in local state is empty for the first segment*)
        let source_local_ledger =
          if Parties.Call_forest.is_empty source_local.frame.calls then
            Frozen_ledger_hash.empty_hash
          else Sparse_ledger.merkle_root source_local.ledger
        in
        { source =
            { ledger = Sparse_ledger.merkle_root source_global.ledger
            ; pending_coinbase_stack = pending_coinbase_init_stack
            ; local_state =
                { source_local with
                  frame = Stack_frame.hash source_local.frame
                ; call_stack = call_stack_hash source_local.call_stack
                ; ledger = source_local_ledger
                }
            }
        ; target =
            { ledger = Sparse_ledger.merkle_root target_global.ledger
            ; pending_coinbase_stack =
                Pending_coinbase.Stack.push_state state_body_hash
                  pending_coinbase_init_stack
            ; local_state =
                { target_local with
                  frame = Stack_frame.hash target_local.frame
                ; call_stack = call_stack_hash target_local.call_stack
                ; ledger = Sparse_ledger.merkle_root target_local.ledger
                }
            }
        ; supply_increase = Amount.zero
        ; fee_excess
        ; sok_digest = Sok_message.Digest.default
        }
      in
      (w, spec, statement, snapp_stmt) :: witnesses)

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
          [ base
          ; merge
          ; opt_signed_unsigned
          ; opt_signed_opt_signed
          ; opt_signed
          ; proved
          ] ) =
    system ~proof_level ~constraint_constants

  module Proof = (val p)

  let id = Proof.id

  let verification_key = Proof.verification_key

  let verify_against_digest { statement; proof } =
    Proof.verify [ (statement, proof) ]

  let verify ts =
    if
      List.for_all ts ~f:(fun (p, m) ->
          Sok_message.Digest.equal (Sok_message.digest m) p.statement.sok_digest)
    then
      Proof.verify
        (List.map ts ~f:(fun ({ statement; proof }, _) -> (statement, proof)))
    else Async.return false

  let of_parties_segment_exn ~statement ~snapp_statement ~witness
      ~(spec : Parties_segment.Basic.t) : t Async.Deferred.t =
    Base.Parties_snark.witness := Some witness ;
    let res =
      match spec with
      | Opt_signed ->
          opt_signed [] statement
      | Opt_signed_unsigned ->
          opt_signed_unsigned [] statement
      | Opt_signed_opt_signed ->
          opt_signed_opt_signed [] statement
      | Proved ->
          let proofs =
            let party_proof (p : Party.t) =
              match p.authorization with
              | Proof p ->
                  Some p
              | Signature _ | None_given ->
                  None
            in
            let open Option.Let_syntax in
            let parties : Party.t list =
              match witness.local_state_init.frame.calls with
              | [] ->
                  List.concat_map witness.start_parties ~f:(fun s ->
                      Parties.Call_forest.to_list s.parties.other_parties)
              | xs ->
                  Parties.Call_forest.to_parties_list xs |> List.map ~f:fst
            in
            List.filter_map parties ~f:(fun p ->
                let%bind tag, snapp_statement = snapp_statement in
                let%map pi = party_proof p in
                let vk =
                  let account_id =
                    Account_id.create p.data.body.public_key
                      p.data.body.token_id
                  in
                  let account : Account.t =
                    Sparse_ledger.(
                      get_exn witness.local_state_init.ledger
                        (find_index_exn witness.local_state_init.ledger
                           account_id))
                  in
                  match
                    Option.value_map ~default:None account.snapp ~f:(fun s ->
                        s.verification_key)
                  with
                  | None ->
                      failwith "No verification key found in the account"
                  | Some s ->
                      s
                in
                (snapp_statement, pi, vk, tag))
          in
          proved
            ( match proofs with
            | [ (s, p, v, tag) ] ->
                Pickles.Side_loaded.in_prover (Base.side_loaded tag) v.data ;
                (* TODO: We should not have to pass the statement in here. *)
                [ (s, p) ]
            | [] | _ :: _ :: _ ->
                failwith "of_parties_segment: Expected exactly one proof" )
            statement
    in
    let open Async in
    let%map proof = res in
    Base.Parties_snark.witness := None ;
    { proof; statement }

  let of_transaction_union ~statement ~init_stack transaction state_body handler
      =
    let open Async in
    let%map proof =
      base []
        ~handler:
          (Base.transaction_union_handler handler transaction state_body
             init_stack)
        statement
    in
    { statement; proof }

  let of_non_parties_transaction ~statement ~init_stack transaction_in_block
      handler =
    let transaction : Transaction.t =
      Transaction.forget
        (Transaction_protocol_state.transaction transaction_in_block)
    in
    let state_body =
      Transaction_protocol_state.block_data transaction_in_block
    in
    match to_preunion transaction with
    | `Parties _ ->
        failwith "Called Non-parties transaction with parties transaction"
    | `Transaction t ->
        of_transaction_union ~statement ~init_stack
          (Transaction_union.of_transaction t)
          state_body handler

  let of_user_command ~statement ~init_stack user_command_in_block handler =
    of_non_parties_transaction ~statement ~init_stack
      { user_command_in_block with
        transaction =
          Command
            (Signed_command
               (Transaction_protocol_state.transaction user_command_in_block))
      }
      handler

  let of_fee_transfer ~statement ~init_stack transfer_in_block handler =
    of_non_parties_transaction ~statement ~init_stack
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
    let%map proof =
      merge [ (x12.statement, x12.proof); (x23.statement, x23.proof) ] s
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
      ; receivers :
          (Signature_lib.Public_key.Compressed.t * Currency.Amount.t) list
      ; amount : Currency.Amount.t
      ; snapp_account_keypairs : Signature_lib.Keypair.t list
      ; memo : Signed_command_memo.t
      ; new_snapp_account : bool
      ; snapp_update : Party.Update.t
            (* Authorization for the update being performed *)
      ; current_auth : Permissions.Auth_required.t
      ; sequence_events : Tick.Field.t array list
      ; events : Tick.Field.t array list
      ; call_data : Tick.Field.t
      }
    [@@deriving sexp]
  end

  let create_trivial_snapp ~constraint_constants () =
    let tag, _, (module P), Pickles.Provers.[ trivial_prover; _ ] =
      let trivial_rule : _ Pickles.Inductive_rule.t =
        let trivial_main (tx_commitment : Snapp_statement.Checked.t) :
            (unit, _) Checked.t =
          Impl.run_checked (dummy_constraints ())
          |> fun () ->
          Snapp_statement.Checked.Assert.equal tx_commitment tx_commitment
          |> return
        in
        { identifier = "trivial-rule"
        ; prevs = []
        ; main =
            (fun [] x ->
              trivial_main x |> Run.run_checked
              |> fun _ :
                     unit
                     Pickles_types.Hlist0.H1
                       (Pickles_types.Hlist.E01(Pickles.Inductive_rule.B))
                     .t ->
              [])
        ; main_value = (fun [] _ -> [])
        }
      in
      Pickles.compile ~cache:Cache_dir.cache
        (module Snapp_statement.Checked)
        (module Snapp_statement)
        ~typ:Snapp_statement.typ
        ~branches:(module Nat.N2)
        ~max_branching:(module Nat.N2) (* You have to put 2 here... *)
        ~name:"trivial"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants)
        ~choices:(fun ~self ->
          [ trivial_rule
          ; { identifier = "dummy"
            ; prevs = [ self; self ]
            ; main_value = (fun [ _; _ ] _ -> [ true; true ])
            ; main =
                (fun [ _; _ ] _ ->
                  Impl.run_checked (dummy_constraints ())
                  |> fun () ->
                  (* Unsatisfiable. *)
                  Run.exists Field.typ ~compute:(fun () ->
                      Run.Field.Constant.zero)
                  |> fun s ->
                  Run.Field.(Assert.equal s (s + one))
                  |> fun () :
                         ( Snapp_statement.Checked.t
                         * (Snapp_statement.Checked.t * unit) )
                         Pickles_types.Hlist0.H1
                           (Pickles_types.Hlist.E01(Pickles.Inductive_rule.B))
                         .t ->
                  [ Boolean.true_; Boolean.true_ ])
            }
          ])
    in
    let vk = Pickles.Side_loaded.Verification_key.of_compiled tag in
    ( `VK (With_hash.of_data ~hash_data:Snapp_account.digest_vk vk)
    , `Prover trivial_prover )

  let create_parties spec ~update ~predicate =
    let { Spec.fee
        ; sender = sender, sender_nonce
        ; receivers
        ; amount
        ; new_snapp_account
        ; snapp_account_keypairs
        ; memo
        ; sequence_events
        ; events
        ; call_data
        ; _
        } =
      spec
    in
    let sender_pk = sender.public_key |> Public_key.compress in
    let fee_payer : Party.Fee_payer.t =
      { data =
          { body =
              { public_key = sender_pk
              ; update = Party.Update.noop
              ; token_id = ()
              ; balance_change = fee
              ; increment_nonce = ()
              ; events = []
              ; sequence_events = []
              ; call_data = Field.zero
              ; call_depth = 0
              ; protocol_state = Snapp_predicate.Protocol_state.accept
              ; use_full_commitment = ()
              }
          ; predicate = sender_nonce
          ; caller = ()
          }
          (*To be updated later*)
      ; authorization = Signature.dummy
      }
    in
    let sender_party : Party.Wire.t option =
      let sender_party_data : Party.Predicated.Wire.t =
        { body =
            { public_key = sender_pk
            ; update = Party.Update.noop
            ; token_id = Token_id.default
            ; balance_change = Amount.(Signed.(negate (of_unsigned amount)))
            ; increment_nonce = true
            ; events = []
            ; sequence_events = []
            ; call_data = Field.zero
            ; call_depth = 0
            ; protocol_state = Snapp_predicate.Protocol_state.accept
            ; use_full_commitment = false
            }
        ; predicate = Nonce (Account.Nonce.succ sender_nonce)
        ; caller = Call
        }
      in
      Option.some_if
        ((not (List.is_empty receivers)) || new_snapp_account)
        { Party.Poly.data = sender_party_data
        ; authorization =
            Control.Signature Signature.dummy (*To be updated later*)
        }
    in
    let snapp_parties : Party.Wire.t list =
      let num_keypairs = List.length snapp_account_keypairs in
      let account_creation_fee =
        Amount.of_fee
          Genesis_constants.Constraint_constants.compiled.account_creation_fee
      in
      (* if creating new snapp accounts, amount must be enough for account creation fees for each *)
      assert (
        (not new_snapp_account) || num_keypairs = 0
        ||
        match Currency.Amount.scale account_creation_fee num_keypairs with
        | None ->
            false
        | Some product ->
            Currency.Amount.( >= ) amount product ) ;
      (* "fudge factor" so that balances sum to zero *)
      let zeroing_allotment =
        if new_snapp_account then
          (* value doesn't matter when num_keypairs = 0 *)
          if num_keypairs <= 1 then amount
          else
            let otherwise_allotted =
              Option.value_exn
                (Currency.Amount.scale account_creation_fee (num_keypairs - 1))
            in
            Option.value_exn (Currency.Amount.sub amount otherwise_allotted)
        else Currency.Amount.zero
      in
      List.mapi snapp_account_keypairs ~f:(fun ndx snapp_account_keypair ->
          let public_key =
            Signature_lib.Public_key.compress snapp_account_keypair.public_key
          in
          let delta =
            if new_snapp_account then
              if ndx = 0 then Amount.Signed.(of_unsigned zeroing_allotment)
              else Amount.Signed.(of_unsigned account_creation_fee)
            else Amount.Signed.zero
          in
          ( { data =
                { body =
                    { public_key
                    ; update
                    ; token_id = Token_id.default
                    ; balance_change = delta
                    ; increment_nonce = false
                    ; events
                    ; sequence_events
                    ; call_data
                    ; call_depth = 0
                    ; protocol_state = Snapp_predicate.Protocol_state.accept
                    ; use_full_commitment = true
                    }
                ; predicate
                ; caller = Call
                }
            ; authorization =
                Control.Signature Signature.dummy (*To be updated later*)
            }
            : Party.Wire.t ))
    in
    let other_receivers =
      List.map receivers ~f:(fun (receiver, amt) : Party.Wire.t ->
          { data =
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
                  ; protocol_state = Snapp_predicate.Protocol_state.accept
                  ; use_full_commitment = false
                  }
              ; predicate = Accept
              ; caller = Call
              }
          ; authorization = Control.None_given
          })
    in
    let protocol_state = Snapp_predicate.Protocol_state.accept in
    let other_parties_data =
      Option.value_map ~default:[] sender_party ~f:(fun p -> [ p.data ])
      @ List.map snapp_parties ~f:(fun p -> p.data)
      @ List.map other_receivers ~f:(fun p -> p.data)
    in
    let protocol_state_predicate_hash =
      Snapp_predicate.Protocol_state.digest protocol_state
    in
    let ps = Parties.of_predicated_list other_parties_data in
    let other_parties_hash = Parties.Call_forest.hash ps in
    let commitment : Parties.Transaction_commitment.t =
      Parties.Transaction_commitment.create ~other_parties_hash
        ~protocol_state_predicate_hash
        ~memo_hash:(Signed_command_memo.hash memo)
    in
    let full_commitment =
      Parties.Transaction_commitment.with_fee_payer commitment
        ~fee_payer_hash:Party.Predicated.(digest (of_fee_payer fee_payer.data))
    in
    let fee_payer =
      let fee_payer_signature_auth =
        Signature_lib.Schnorr.Chunked.sign sender.private_key
          (Random_oracle.Input.Chunked.field full_commitment)
      in
      { fee_payer with authorization = fee_payer_signature_auth }
    in
    let sender_party =
      Option.map sender_party ~f:(fun s : Party.Wire.t ->
          let commitment =
            if s.data.body.use_full_commitment then full_commitment
            else commitment
          in
          let sender_signature_auth =
            Signature_lib.Schnorr.Chunked.sign sender.private_key
              (Random_oracle.Input.Chunked.field commitment)
          in
          { data = s.data; authorization = Signature sender_signature_auth })
    in
    ( `Parties
        (Parties.of_wire { fee_payer; other_parties = other_receivers; memo })
    , `Sender_party sender_party
    , `Proof_parties snapp_parties
    , `Txn_commitment commitment
    , `Full_txn_commitment full_commitment )

  let deploy_snapp ~constraint_constants (spec : Spec.t) =
    let `VK vk, `Prover _trivial_prover =
      create_trivial_snapp ~constraint_constants ()
    in
    (* only allow timing on a single new snapp account
       balance changes for other new snapp accounts are just the account creation fee
    *)
    assert (
      Snapp_basic.Set_or_keep.is_keep spec.snapp_update.timing
      || (spec.new_snapp_account && List.length spec.snapp_account_keypairs = 1)
    ) ;
    let update_vk =
      let update = spec.snapp_update in
      { update with
        verification_key = Snapp_basic.Set_or_keep.Set vk
      ; permissions =
          Snapp_basic.Set_or_keep.Set
            { Permissions.user_default with
              edit_state = Permissions.Auth_required.Proof
            ; edit_sequence_state = Proof
            }
      }
    in
    let ( `Parties { Parties.fee_payer; other_parties; memo }
        , `Sender_party sender_party
        , `Proof_parties snapp_parties
        , `Txn_commitment commitment
        , `Full_txn_commitment full_commitment ) =
      create_parties spec ~update:update_vk ~predicate:Party.Predicate.Accept
    in
    assert (List.is_empty other_parties) ;
    (* invariant: same number of keypairs, snapp_parties *)
    let snapp_parties_keypairs =
      List.zip_exn snapp_parties spec.snapp_account_keypairs
    in
    let snapp_parties =
      List.map snapp_parties_keypairs ~f:(fun (snapp_party, keypair) ->
          let commitment =
            if snapp_party.data.body.use_full_commitment then full_commitment
            else commitment
          in
          let signature =
            Signature_lib.Schnorr.Chunked.sign keypair.private_key
              (Random_oracle.Input.Chunked.field commitment)
          in
          ( { data = snapp_party.data; authorization = Signature signature }
            : Party.Wire.t ))
    in
    let other_parties = [ Option.value_exn sender_party ] @ snapp_parties in
    let parties : Parties.t =
      Parties.of_wire { fee_payer; other_parties; memo }
    in
    parties

  let update_states ?snapp_prover ~constraint_constants (spec : Spec.t) =
    let ( `Parties { Parties.fee_payer; other_parties; memo }
        , `Sender_party sender_party
        , `Proof_parties snapp_parties
        , `Txn_commitment commitment
        , `Full_txn_commitment full_commitment ) =
      create_parties spec ~update:spec.snapp_update
        ~predicate:Party.Predicate.Accept
    in
    assert (List.is_empty other_parties) ;
    assert (Option.is_none sender_party) ;
    assert (not @@ List.is_empty snapp_parties) ;
    let snapp_parties_keypairs =
      List.zip_exn snapp_parties spec.snapp_account_keypairs
    in
    let%map.Async.Deferred snapp_parties =
      Async.Deferred.List.mapi snapp_parties_keypairs
        ~f:(fun ndx (snapp_party, snapp_keypair) ->
          match spec.current_auth with
          | Permissions.Auth_required.Proof ->
              let proof_party =
                let ps =
                  Parties.of_predicated_list
                    (List.map (List.drop snapp_parties ndx) ~f:(fun p -> p.data))
                in
                Parties.Call_forest.hash ps
              in
              let tx_statement : Snapp_statement.t =
                let commitment =
                  if snapp_party.data.body.use_full_commitment then
                    full_commitment
                  else commitment
                in
                { transaction = commitment; at_party = proof_party }
              in
              let handler (Snarky_backendless.Request.With { request; respond })
                  =
                match request with _ -> respond Unhandled
              in
              let prover =
                match snapp_prover with
                | Some prover ->
                    prover
                | None ->
                    let _, `Prover p =
                      create_trivial_snapp ~constraint_constants ()
                    in
                    p
              in
              let%map.Async.Deferred (pi : Pickles.Side_loaded.Proof.t) =
                prover ~handler [] tx_statement
              in
              ( { data = snapp_party.data; authorization = Proof pi }
                : Party.Wire.t )
          | Signature ->
              let commitment =
                if snapp_party.data.body.use_full_commitment then
                  full_commitment
                else commitment
              in
              let signature =
                Signature_lib.Schnorr.Chunked.sign snapp_keypair.private_key
                  (Random_oracle.Input.Chunked.field commitment)
              in
              Async.Deferred.return
                ( { data = snapp_party.data
                  ; authorization = Signature signature
                  }
                  : Party.Wire.t )
          | None ->
              Async.Deferred.return
                ( { data = snapp_party.data; authorization = None_given }
                  : Party.Wire.t )
          | _ ->
              failwith
                "Current authorization not Proof or Signature or None_given")
    in
    let other_parties = snapp_parties in
    let parties : Parties.t =
      Parties.of_wire { fee_payer; other_parties; memo }
    in
    parties

  let multiple_transfers (spec : Spec.t) =
    let ( `Parties parties
        , `Sender_party sender_party
        , `Proof_parties snapp_parties
        , `Txn_commitment _commitment
        , `Full_txn_commitment _full_commitment ) =
      create_parties spec ~update:spec.snapp_update
        ~predicate:Party.Predicate.Accept
    in
    assert (Option.is_some sender_party) ;
    assert (List.is_empty snapp_parties) ;
    let other_parties =
      let sender_party = Option.value_exn sender_party in
      Parties.Call_forest.cons
        { sender_party with
          data = { sender_party.data with caller = Token_id.invalid }
        }
        parties.other_parties
    in
    { parties with other_parties }

  let create_trivial_snapp_account ?(permissions = Permissions.user_default) ~vk
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
    let account : Account.t =
      { (Account.create id Balance.(of_int 1_000_000_000_000_000)) with
        permissions
      ; snapp = Some { Snapp_account.default with verification_key = Some vk }
      }
    in
    create ledger id account

  let create_trivial_predicate_snapp ~constraint_constants
      ?(protocol_state_predicate = Snapp_predicate.Protocol_state.accept)
      ~(snapp_kp : Signature_lib.Keypair.t) spec ledger =
    let { Mina_transaction_logic.For_tests.Transaction_spec.fee
        ; sender = sender, sender_nonce
        ; receiver = _
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
      create_trivial_snapp_account trivial_account_pk ~ledger ~vk
        ~permissions:{ Permissions.user_default with set_permissions = Proof }
    in
    let update_empty_permissions =
      let permissions =
        { Permissions.user_default with send = Permissions.Auth_required.Proof }
        |> Snapp_basic.Set_or_keep.Set
      in
      { Party.Update.dummy with permissions }
    in
    let sender_pk = sender.public_key |> Public_key.compress in
    let fee_payer : Party.Fee_payer.t =
      { data =
          { body =
              { public_key = sender_pk
              ; update = Party.Update.noop
              ; token_id = ()
              ; balance_change = fee
              ; increment_nonce = ()
              ; events = []
              ; sequence_events = []
              ; call_data = Field.zero
              ; call_depth = 0
              ; protocol_state = protocol_state_predicate
              ; use_full_commitment = ()
              }
          ; predicate = sender_nonce
          ; caller = ()
          }
          (* Real signature added in below *)
      ; authorization = Signature.dummy
      }
    in
    let sender_party_data : Party.Predicated.Wire.t =
      { body =
          { public_key = sender_pk
          ; update = Party.Update.noop
          ; token_id = Token_id.default
          ; balance_change = Amount.(Signed.(negate (of_unsigned amount)))
          ; increment_nonce = true
          ; events = []
          ; sequence_events = []
          ; call_data = Field.zero
          ; call_depth = 0
          ; protocol_state = protocol_state_predicate
          ; use_full_commitment = false
          }
      ; predicate = Nonce (Account.Nonce.succ sender_nonce)
      ; caller = Call
      }
    in
    let snapp_party_data : Party.Predicated.Wire.t =
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
          ; protocol_state = protocol_state_predicate
          ; use_full_commitment = false
          }
      ; caller = Call
      ; predicate = Full Snapp_predicate.Account.accept
      }
    in
    let memo = Signed_command_memo.empty in
    let ps =
      Parties.of_predicated_list [ sender_party_data; snapp_party_data ]
    in
    let other_parties_hash = Parties.Call_forest.hash ps in
    let protocol_state_predicate_hash =
      (*FIXME: is this ok? *)
      Snapp_predicate.Protocol_state.digest protocol_state_predicate
    in
    let transaction : Parties.Transaction_commitment.t =
      (*FIXME: is this correct? *)
      Parties.Transaction_commitment.create ~other_parties_hash
        ~protocol_state_predicate_hash
        ~memo_hash:(Signed_command_memo.hash memo)
    in
    let proof_party =
      let ps = Parties.of_predicated_list [ snapp_party_data ] in
      Parties.Call_forest.hash ps
    in
    let tx_statement : Snapp_statement.t =
      { transaction; at_party = proof_party }
    in
    let handler (Snarky_backendless.Request.With { request; respond }) =
      match request with _ -> respond Unhandled
    in
    let%map.Async.Deferred (pi : Pickles.Side_loaded.Proof.t) =
      trivial_prover ~handler [] tx_statement
    in
    let fee_payer_signature_auth =
      let txn_comm =
        Parties.Transaction_commitment.with_fee_payer transaction
          ~fee_payer_hash:
            Party.Predicated.(digest (of_fee_payer fee_payer.data))
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
    let sender : Party.Wire.t =
      { data = sender_party_data
      ; authorization = Signature sender_signature_auth
      }
    in
    let other_parties =
      [ sender; { data = snapp_party_data; authorization = Proof pi } ]
    in
    let parties : Parties.t =
      Parties.of_wire { fee_payer; other_parties; memo }
    in
    parties
end
