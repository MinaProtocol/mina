(* zkapp_command_generators -- Quickcheck generators for zkApp transactions *)

open Core_kernel
open Mina_base
module Ledger = Mina_ledger.Ledger

type failure =
  | Invalid_account_precondition
  | Invalid_protocol_state_precondition
  | Update_not_permitted of
      [ `Delegate
      | `App_state
      | `Voting_for
      | `Verification_key
      | `Zkapp_uri
      | `Token_symbol
      | `Send
      | `Receive ]

type role =
  [ `Fee_payer | `New_account | `Ordinary_participant | `New_token_account ]

let gen_account_precondition_from_account ?failure ~first_use_of_account account
    =
  let open Quickcheck.Let_syntax in
  let { Account.Poly.balance; nonce; delegate; receipt_chain_hash; zkapp; _ } =
    account
  in
  (* choose constructor *)
  let%bind b = Quickcheck.Generator.bool in
  if b then
    (* Full *)
    let open Zkapp_basic in
    let%bind (predicate_account : Zkapp_precondition.Account.t) =
      let%bind balance =
        let%bind balance_change_int = Int.gen_uniform_incl 1 10_000_000 in
        let balance_change =
          Currency.Amount.nanomina_of_int_exn balance_change_int
        in
        let lower =
          match Currency.Balance.sub_amount balance balance_change with
          | None ->
              Currency.Balance.zero
          | Some bal ->
              bal
        in
        let upper =
          match Currency.Balance.add_amount balance balance_change with
          | None ->
              Currency.Balance.max_int
          | Some bal ->
              bal
        in
        Or_ignore.gen
          (return { Zkapp_precondition.Closed_interval.lower; upper })
      in
      let%bind nonce =
        let%bind nonce_change_int = Int.gen_uniform_incl 1 100 in
        let nonce_change = Account.Nonce.of_int nonce_change_int in
        let lower =
          match Account.Nonce.sub nonce nonce_change with
          | None ->
              Account.Nonce.zero
          | Some nonce ->
              nonce
        in
        let upper =
          (* Nonce.add doesn't check for overflow, so check here *)
          match Account.Nonce.(sub max_value) nonce_change with
          | None ->
              (* unreachable *)
              failwith
                "gen_account_precondition_from: nonce subtraction failed \
                 unexpectedly"
          | Some n ->
              if Account.Nonce.( < ) n nonce then Account.Nonce.max_value
              else Account.Nonce.add nonce nonce_change
        in
        Or_ignore.gen
          (return { Zkapp_precondition.Closed_interval.lower; upper })
      in
      let receipt_chain_hash =
        if first_use_of_account then Or_ignore.Check receipt_chain_hash
        else Or_ignore.Ignore
      in
      let%bind delegate =
        match delegate with
        | None ->
            return Or_ignore.Ignore
        | Some pk ->
            Or_ignore.gen (return pk)
      in
      let%bind state, sequence_state, proved_state, is_new =
        match zkapp with
        | None ->
            let len = Pickles_types.Nat.to_int Zkapp_state.Max_state_size.n in
            (* won't raise, correct length given *)
            let state =
              Zkapp_state.V.of_list_exn
                (List.init len ~f:(fun _ -> Or_ignore.Ignore))
            in
            let sequence_state = Or_ignore.Ignore in
            let proved_state = Or_ignore.Ignore in
            let is_new = Or_ignore.Ignore in
            return (state, sequence_state, proved_state, is_new)
        | Some { Zkapp_account.app_state; sequence_state; proved_state; _ } ->
            let state =
              Zkapp_state.V.map app_state ~f:(fun field ->
                  Quickcheck.random_value (Or_ignore.gen (return field)) )
            in
            let%bind sequence_state =
              (* choose a value from account sequence state *)
              let fields =
                Pickles_types.Vector.Vector_5.to_list sequence_state
              in
              let%bind ndx = Int.gen_uniform_incl 0 (List.length fields - 1) in
              return (Or_ignore.Check (List.nth_exn fields ndx))
            in
            let proved_state = Or_ignore.Check proved_state in
            let is_new =
              (* when we apply the generated Zkapp_command.t, the account is always in the ledger
              *)
              Or_ignore.Check false
            in
            return (state, sequence_state, proved_state, is_new)
      in
      return
        { Zkapp_precondition.Account.balance
        ; nonce
        ; receipt_chain_hash
        ; delegate
        ; state
        ; sequence_state
        ; proved_state
        ; is_new
        }
    in
    match failure with
    | Some Invalid_account_precondition ->
        let module Tamperable = struct
          type t =
            | Balance
            | Nonce
            | Receipt_chain_hash
            | Delegate
            | State
            | Sequence_state
            | Proved_state
        end in
        let%bind faulty_predicate_account =
          (* tamper with account using randomly chosen item *)
          let tamperable : Tamperable.t list =
            [ Balance
            ; Nonce
            ; Receipt_chain_hash
            ; Delegate
            ; State
            ; Sequence_state
            ; Proved_state
            ]
          in
          match%bind Quickcheck.Generator.of_list tamperable with
          | Balance ->
              let new_balance =
                if Currency.Balance.equal balance Currency.Balance.zero then
                  Currency.Balance.max_int
                else Currency.Balance.zero
              in
              let balance =
                Or_ignore.Check
                  { Zkapp_precondition.Closed_interval.lower = new_balance
                  ; upper = new_balance
                  }
              in
              return { predicate_account with balance }
          | Nonce ->
              let new_nonce =
                if Account.Nonce.equal nonce Account.Nonce.zero then
                  Account.Nonce.max_value
                else Account.Nonce.zero
              in
              let%bind nonce =
                Zkapp_precondition.Numeric.gen (return new_nonce)
                  Account.Nonce.compare
              in
              return { predicate_account with nonce }
          | Receipt_chain_hash ->
              let%bind new_receipt_chain_hash = Receipt.Chain_hash.gen in
              let%bind receipt_chain_hash =
                Or_ignore.gen (return new_receipt_chain_hash)
              in
              return { predicate_account with receipt_chain_hash }
          | Delegate ->
              let%bind delegate =
                Or_ignore.gen Signature_lib.Public_key.Compressed.gen
              in
              return { predicate_account with delegate }
          | State ->
              let fields =
                Zkapp_state.V.to_list predicate_account.state |> Array.of_list
              in
              let%bind ndx = Int.gen_incl 0 (Array.length fields - 1) in
              let%bind field = Snark_params.Tick.Field.gen in
              fields.(ndx) <- Or_ignore.Check field ;
              let state = Zkapp_state.V.of_list_exn (Array.to_list fields) in
              return { predicate_account with state }
          | Sequence_state ->
              let%bind field = Snark_params.Tick.Field.gen in
              let sequence_state = Or_ignore.Check field in
              return { predicate_account with sequence_state }
          | Proved_state ->
              let%bind proved_state =
                match predicate_account.proved_state with
                | Check b ->
                    return (Or_ignore.Check (not b))
                | Ignore ->
                    return (Or_ignore.Check true)
              in
              return { predicate_account with proved_state }
        in
        return
          (Account_update.Account_precondition.Full faulty_predicate_account)
    | _ ->
        return (Account_update.Account_precondition.Full predicate_account)
  else
    (* Nonce *)
    let { Account.Poly.nonce; _ } = account in
    match failure with
    | Some Invalid_account_precondition ->
        return
          (Account_update.Account_precondition.Nonce (Account.Nonce.succ nonce))
    | _ ->
        return (Account_update.Account_precondition.Nonce nonce)

let gen_fee (account : Account.t) =
  let balance = account.balance in
  let lo_fee = Mina_compile_config.minimum_user_command_fee in
  let hi_fee =
    Option.value_exn
      Currency.Fee.(scale Mina_compile_config.minimum_user_command_fee 2)
  in
  assert (
    Currency.(
      Fee.(hi_fee <= (Balance.to_amount balance |> Currency.Amount.to_fee))) ) ;
  Currency.Fee.gen_incl lo_fee hi_fee

(*Fee payer balance change is Neg*)
let fee_to_amt fee =
  Currency.Amount.(Signed.of_unsigned (of_fee fee) |> Signed.negate)

let gen_balance_change ?permissions_auth (account : Account.t) ?failure
    ~new_account =
  let open Quickcheck.Let_syntax in
  let%bind sgn =
    if new_account then return Sgn.Pos
    else
      match (failure, permissions_auth) with
      | Some (Update_not_permitted `Send), _ ->
          return Sgn.Neg
      | Some (Update_not_permitted `Receive), _ ->
          return Sgn.Pos
      | _, Some auth -> (
          match auth with
          | Control.Tag.None_given ->
              return Sgn.Pos
          | _ ->
              Quickcheck.Generator.of_list [ Sgn.Pos; Neg ] )
      | _, None ->
          Quickcheck.Generator.of_list [ Sgn.Pos; Neg ]
  in
  (* if negative, magnitude constrained to balance in account
     the effective balance is what's in the account state table,
  *)
  let effective_balance = account.balance in
  let small_balance_change =
    (*make small transfers to allow generating large number of zkapp_command without an overflow*)
    let open Currency in
    if
      Balance.(effective_balance < of_formatted_string "1.0") && not new_account
    then failwith "account has low balance"
    else Balance.of_formatted_string "0.000001"
  in
  let%map (magnitude : Currency.Amount.t) =
    if new_account then
      Currency.Amount.gen_incl
        (Currency.Amount.of_formatted_string "50.0")
        (Currency.Amount.of_formatted_string "100.0")
    else
      Currency.Amount.gen_incl Currency.Amount.zero
        (Currency.Balance.to_amount small_balance_change)
  in
  match sgn with
  | Pos ->
      ({ magnitude; sgn = Sgn.Pos } : Currency.Amount.Signed.t)
  | Neg ->
      ({ magnitude; sgn = Sgn.Neg } : Currency.Amount.Signed.t)

let gen_use_full_commitment ~increment_nonce ~account_precondition
    ~authorization () : bool Base_quickcheck.Generator.t =
  (* check conditions to avoid replays*)
  let incr_nonce_and_constrains_nonce =
    increment_nonce
    && Zkapp_precondition.Numeric.is_constant
         Zkapp_precondition.Numeric.Tc.nonce
         (Account_update.Account_precondition.to_full account_precondition)
           .Zkapp_precondition.Account.nonce
  in
  let does_not_use_a_signature =
    Control.(not (Tag.equal (tag authorization) Tag.Signature))
  in
  if incr_nonce_and_constrains_nonce || does_not_use_a_signature then
    Bool.quickcheck_generator
  else Quickcheck.Generator.return true

let closed_interval_exact value =
  Zkapp_precondition.Closed_interval.{ lower = value; upper = value }

let gen_epoch_data_predicate
    (epoch_data :
      ( ( Frozen_ledger_hash.Stable.V1.t
        , Currency.Amount.Stable.V1.t )
        Epoch_ledger.Poly.Stable.V1.t
      , Epoch_seed.Stable.V1.t
      , State_hash.Stable.V1.t
      , State_hash.Stable.V1.t
      , Mina_numbers.Length.Stable.V1.t )
      Zkapp_precondition.Protocol_state.Epoch_data.Poly.t ) :
    Zkapp_precondition.Protocol_state.Epoch_data.t Base_quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let%bind ledger =
    let%bind hash =
      Zkapp_basic.Or_ignore.gen @@ return epoch_data.ledger.hash
    in
    let%map total_currency =
      closed_interval_exact epoch_data.ledger.total_currency
      |> return |> Zkapp_basic.Or_ignore.gen
    in
    { Epoch_ledger.Poly.hash; total_currency }
  in
  let%bind seed = Zkapp_basic.Or_ignore.gen @@ return epoch_data.seed in
  let%bind start_checkpoint =
    Zkapp_basic.Or_ignore.gen @@ return epoch_data.start_checkpoint
  in
  let%bind lock_checkpoint =
    Zkapp_basic.Or_ignore.gen @@ return epoch_data.lock_checkpoint
  in
  let%map epoch_length =
    let open Mina_numbers in
    let%bind epsilon1 = Length.gen_incl (Length.of_int 0) (Length.of_int 10) in
    let%bind epsilon2 = Length.gen_incl (Length.of_int 0) (Length.of_int 10) in
    Zkapp_precondition.Closed_interval.
      { lower =
          Length.sub epoch_data.epoch_length epsilon1
          |> Option.value ~default:Length.zero
      ; upper = Length.add epoch_data.epoch_length epsilon2
      }
    |> return |> Zkapp_basic.Or_ignore.gen
  in
  { Epoch_data.Poly.ledger
  ; seed
  ; start_checkpoint
  ; lock_checkpoint
  ; epoch_length
  }

let gen_protocol_state_precondition
    (psv : Zkapp_precondition.Protocol_state.View.t) :
    Zkapp_precondition.Protocol_state.t Base_quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let open Zkapp_precondition.Closed_interval in
  let%bind snarked_ledger_hash =
    Zkapp_basic.Or_ignore.gen @@ return psv.snarked_ledger_hash
  in
  let%bind timestamp =
    let%bind epsilon1 =
      Int64.gen_incl 0L 60_000_000L >>| Block_time.Span.of_ms
    in
    let%bind epsilon2 =
      Int64.gen_incl 0L 60_000_000L >>| Block_time.Span.of_ms
    in
    { lower = Block_time.sub psv.timestamp epsilon1
    ; upper = Block_time.add psv.timestamp epsilon2
    }
    |> return |> Zkapp_basic.Or_ignore.gen
  in
  let%bind blockchain_length =
    let open Mina_numbers in
    let%bind epsilon1 = Length.gen_incl (Length.of_int 0) (Length.of_int 10) in
    let%bind epsilon2 = Length.gen_incl (Length.of_int 0) (Length.of_int 10) in
    { lower =
        Length.sub psv.blockchain_length epsilon1
        |> Option.value ~default:Length.zero
    ; upper = Length.add psv.blockchain_length epsilon2
    }
    |> return |> Zkapp_basic.Or_ignore.gen
  in
  let%bind min_window_density =
    let open Mina_numbers in
    let%bind epsilon1 = Length.gen_incl (Length.of_int 0) (Length.of_int 10) in
    let%bind epsilon2 = Length.gen_incl (Length.of_int 0) (Length.of_int 10) in
    { lower =
        Length.sub psv.min_window_density epsilon1
        |> Option.value ~default:Length.zero
    ; upper = Length.add psv.min_window_density epsilon2
    }
    |> return |> Zkapp_basic.Or_ignore.gen
  in
  let%bind total_currency =
    let open Currency in
    let%bind epsilon1 =
      Amount.gen_incl Amount.zero (Amount.mina_of_int_exn 1)
    in
    let%bind epsilon2 =
      Amount.gen_incl Amount.zero (Amount.mina_of_int_exn 1)
    in
    { lower =
        Amount.sub psv.total_currency epsilon1
        |> Option.value ~default:Amount.zero
    ; upper =
        Amount.add psv.total_currency epsilon2
        |> Option.value ~default:psv.total_currency
    }
    |> return |> Zkapp_basic.Or_ignore.gen
  in
  let%bind global_slot_since_hard_fork =
    let open Mina_numbers in
    let%bind epsilon1 =
      Global_slot.gen_incl (Global_slot.of_int 0) (Global_slot.of_int 10)
    in
    let%bind epsilon2 =
      Global_slot.gen_incl (Global_slot.of_int 0) (Global_slot.of_int 10)
    in
    { lower =
        Global_slot.sub psv.global_slot_since_hard_fork epsilon1
        |> Option.value ~default:Global_slot.zero
    ; upper = Global_slot.add psv.global_slot_since_hard_fork epsilon2
    }
    |> return |> Zkapp_basic.Or_ignore.gen
  in
  let%bind global_slot_since_genesis =
    let open Mina_numbers in
    let%bind epsilon1 =
      Global_slot.gen_incl (Global_slot.of_int 0) (Global_slot.of_int 10)
    in
    let%bind epsilon2 =
      Global_slot.gen_incl (Global_slot.of_int 0) (Global_slot.of_int 10)
    in
    { lower =
        Global_slot.sub psv.global_slot_since_genesis epsilon1
        |> Option.value ~default:Global_slot.zero
    ; upper = Global_slot.add psv.global_slot_since_genesis epsilon2
    }
    |> return |> Zkapp_basic.Or_ignore.gen
  in
  let%bind staking_epoch_data =
    gen_epoch_data_predicate psv.staking_epoch_data
  in
  let%map next_epoch_data = gen_epoch_data_predicate psv.next_epoch_data in
  { Zkapp_precondition.Protocol_state.Poly.snarked_ledger_hash
  ; timestamp
  ; blockchain_length
  ; min_window_density
  ; last_vrf_output = ()
  ; total_currency
  ; global_slot_since_hard_fork
  ; global_slot_since_genesis
  ; staking_epoch_data
  ; next_epoch_data
  }

let gen_invalid_protocol_state_precondition
    (psv : Zkapp_precondition.Protocol_state.View.t) :
    Zkapp_precondition.Protocol_state.t Base_quickcheck.Generator.t =
  let module Tamperable = struct
    type t =
      | Timestamp
      | Blockchain_length
      | Min_window_density
      | Total_currency
      | Global_slot_since_hard_fork
      | Global_slot_since_genesis
  end in
  let open Quickcheck.Let_syntax in
  let open Zkapp_precondition.Closed_interval in
  let protocol_state_precondition = Zkapp_precondition.Protocol_state.accept in
  let%bind lower = Bool.quickcheck_generator in
  match%bind
    Quickcheck.Generator.of_list
      ( [ Timestamp
        ; Blockchain_length
        ; Min_window_density
        ; Total_currency
        ; Global_slot_since_hard_fork
        ; Global_slot_since_genesis
        ]
        : Tamperable.t list )
  with
  | Timestamp ->
      let%map timestamp =
        let%map epsilon =
          Int64.gen_incl 1_000_000L 60_000_000L >>| Block_time.Span.of_ms
        in
        if lower || Block_time.(psv.timestamp > add zero epsilon) then
          { lower = Block_time.zero
          ; upper = Block_time.sub psv.timestamp epsilon
          }
        else
          { lower = Block_time.add psv.timestamp epsilon
          ; upper = Block_time.max_value
          }
      in
      { protocol_state_precondition with
        timestamp = Zkapp_basic.Or_ignore.Check timestamp
      }
  | Blockchain_length ->
      let open Mina_numbers in
      let%map blockchain_length =
        let%map epsilon = Length.(gen_incl (of_int 1) (of_int 10)) in
        if lower || Length.(psv.blockchain_length > epsilon) then
          { lower = Length.zero
          ; upper =
              Length.sub psv.blockchain_length epsilon
              |> Option.value ~default:Length.zero
          }
        else
          { lower = Length.add psv.blockchain_length epsilon
          ; upper = Length.max_value
          }
      in
      { protocol_state_precondition with
        blockchain_length = Zkapp_basic.Or_ignore.Check blockchain_length
      }
  | Min_window_density ->
      let open Mina_numbers in
      let%map min_window_density =
        let%map epsilon = Length.(gen_incl (of_int 1) (of_int 10)) in
        if lower || Length.(psv.min_window_density > epsilon) then
          { lower = Length.zero
          ; upper =
              Length.sub psv.min_window_density epsilon
              |> Option.value ~default:Length.zero
          }
        else
          { lower = Length.add psv.blockchain_length epsilon
          ; upper = Length.max_value
          }
      in
      { protocol_state_precondition with
        min_window_density = Zkapp_basic.Or_ignore.Check min_window_density
      }
  | Total_currency ->
      let open Currency in
      let%map total_currency =
        let%map epsilon =
          Amount.(gen_incl (nanomina_of_int_exn 1_000) (mina_of_int_exn 1))
        in
        if lower || Amount.(psv.total_currency > epsilon) then
          { lower = Amount.zero
          ; upper =
              Amount.sub psv.total_currency epsilon
              |> Option.value ~default:Amount.zero
          }
        else
          { lower =
              Amount.add psv.total_currency epsilon
              |> Option.value ~default:Amount.max_int
          ; upper = Amount.max_int
          }
      in
      { protocol_state_precondition with
        total_currency = Zkapp_basic.Or_ignore.Check total_currency
      }
  | Global_slot_since_hard_fork ->
      let open Mina_numbers in
      let%map global_slot_since_hard_fork =
        let%map epsilon = Global_slot.(gen_incl (of_int 1) (of_int 10)) in
        if lower || Global_slot.(psv.global_slot_since_hard_fork > epsilon) then
          { lower = Global_slot.zero
          ; upper =
              Global_slot.sub psv.global_slot_since_hard_fork epsilon
              |> Option.value ~default:Global_slot.zero
          }
        else
          { lower = Global_slot.add psv.global_slot_since_hard_fork epsilon
          ; upper = Global_slot.max_value
          }
      in
      { protocol_state_precondition with
        global_slot_since_hard_fork =
          Zkapp_basic.Or_ignore.Check global_slot_since_hard_fork
      }
  | Global_slot_since_genesis ->
      let open Mina_numbers in
      let%map global_slot_since_genesis =
        let%map epsilon = Global_slot.(gen_incl (of_int 1) (of_int 10)) in
        if lower || Global_slot.(psv.global_slot_since_genesis > epsilon) then
          { lower = Global_slot.zero
          ; upper =
              Global_slot.sub psv.global_slot_since_genesis epsilon
              |> Option.value ~default:Global_slot.zero
          }
        else
          { lower = Global_slot.add psv.global_slot_since_genesis epsilon
          ; upper = Global_slot.max_value
          }
      in
      { protocol_state_precondition with
        global_slot_since_genesis =
          Zkapp_basic.Or_ignore.Check global_slot_since_genesis
      }

module Account_update_body_components = struct
  type ( 'pk
       , 'update
       , 'token_id
       , 'amount
       , 'events
       , 'call_data
       , 'int
       , 'bool
       , 'protocol_state_precondition
       , 'account_precondition
       , 'caller
       , 'authorization_kind )
       t =
    { public_key : 'pk
    ; update : 'update
    ; token_id : 'token_id
    ; balance_change : 'amount
    ; increment_nonce : 'bool
    ; events : 'events
    ; sequence_events : 'events
    ; call_data : 'call_data
    ; call_depth : 'int
    ; protocol_state_precondition : 'protocol_state_precondition
    ; account_precondition : 'account_precondition
    ; use_full_commitment : 'bool
    ; caller : 'caller
    ; authorization_kind : 'authorization_kind
    }

  let to_fee_payer t : Account_update.Body.Fee_payer.t =
    { public_key = t.public_key
    ; fee = t.balance_change
    ; valid_until =
        ( match
            t.protocol_state_precondition
              .Zkapp_precondition.Protocol_state.Poly.global_slot_since_genesis
          with
        | Zkapp_basic.Or_ignore.Ignore ->
            None
        | Zkapp_basic.Or_ignore.Check
            { Zkapp_precondition.Closed_interval.upper; _ } ->
            Some upper )
    ; nonce = t.account_precondition
    }

  let to_typical_account_update t : Account_update.Body.Simple.t =
    { public_key = t.public_key
    ; update = t.update
    ; token_id = t.token_id
    ; balance_change = t.balance_change
    ; increment_nonce = t.increment_nonce
    ; events = t.events
    ; sequence_events = t.sequence_events
    ; call_data = t.call_data
    ; call_depth = t.call_depth
    ; preconditions =
        { Account_update.Preconditions.network = t.protocol_state_precondition
        ; account = t.account_precondition
        }
    ; use_full_commitment = t.use_full_commitment
    ; caller = t.caller
    ; authorization_kind = t.authorization_kind
    }
end

(* The type `a` is associated with the `delta` field, which is an unsigned fee
   for the fee payer, and a signed amount for other zkapp_command.
   The type `b` is associated with the `use_full_commitment` field, which is
   `unit` for the fee payer, and `bool` for other zkapp_command.
   The type `c` is associated with the `token_id` field, which is `unit` for the
   fee payer, and `Token_id.t` for other zkapp_command.
   The type `d` is associated with the `account_precondition` field, which is
   a nonce for the fee payer, and `Account_precondition.t` for other zkapp_command
*)
let gen_account_update_body_components (type a b c d) ?(update = None)
    ?account_id ?token_id ?caller ?account_ids_seen ~account_state_tbl ?vk
    ?failure ?(new_account = false) ?(zkapp_account = false)
    ?(is_fee_payer = false) ?available_public_keys ?permissions_auth
    ?(required_balance_change : a option) ?protocol_state_view
    ~zkapp_account_ids
    ~(gen_balance_change : Account.t -> a Quickcheck.Generator.t)
    ~(gen_use_full_commitment :
          account_precondition:Account_update.Account_precondition.t
       -> b Quickcheck.Generator.t )
    ~(f_balance_change : a -> Currency.Amount.Signed.t)
    ~(increment_nonce : b * bool) ~(f_token_id : Token_id.t -> c)
    ~(f_account_precondition :
       first_use_of_account:bool -> Account.t -> d Quickcheck.Generator.t )
    ~(f_account_update_account_precondition :
       d -> Account_update.Account_precondition.t ) ~authorization_tag () :
    (_, _, _, a, _, _, _, b, _, d, _, _) Account_update_body_components.t
    Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  (* fee payers have to be in the ledger *)
  assert (not (is_fee_payer && new_account)) ;
  let token_account = match token_id with None -> false | Some _ -> true in
  let%bind update =
    match update with
    | None ->
        Account_update.Update.gen ?permissions_auth ?vk ~zkapp_account
          ~token_account ()
    | Some update ->
        return update
  in
  (* account_update_increment_nonce for fee payer is unit and increment_nonce is true *)
  let account_update_increment_nonce, increment_nonce = increment_nonce in
  let verification_key =
    Option.value vk
      ~default:
        With_hash.
          { data = Pickles.Side_loaded.Verification_key.dummy
          ; hash = Zkapp_account.dummy_vk_hash ()
          }
  in
  let%bind account =
    if new_account then (
      if Option.is_some account_id then
        failwith
          "gen_account_update_body: new account_update is true, but an account \
           id, presumably from an existing account, was supplied" ;
      match available_public_keys with
      | None ->
          failwith
            "gen_account_update_body: new_account is true, but \
             available_public_keys not provided"
      | Some available_pks ->
          let available_pk =
            match
              Signature_lib.Public_key.Compressed.Table.choose available_pks
            with
            | None ->
                failwith "gen_account_update_body: no available public keys"
            | Some (pk, ()) ->
                pk
          in
          (* available public key no longer available *)
          Signature_lib.Public_key.Compressed.Table.remove available_pks
            available_pk ;
          let account_id =
            match token_id with
            | Some custom_token_id ->
                Account_id.create available_pk custom_token_id
            | None ->
                Account_id.create available_pk Token_id.default
          in
          let account_with_pk =
            Account.create account_id Currency.Balance.zero
          in
          let account =
            if zkapp_account then
              { account_with_pk with
                zkapp =
                  Some
                    { Zkapp_account.default with
                      verification_key = Some verification_key
                    }
              }
            else account_with_pk
          in
          return account )
    else
      match account_id with
      | None ->
          if zkapp_account then
            let%map zkapp_account_id =
              Quickcheck.Generator.of_list zkapp_account_ids
            in
            match Account_id.Table.find account_state_tbl zkapp_account_id with
            | None ->
                failwith "gen_account_update_body: fail to find zkapp account"
            | Some (_, `Fee_payer)
            | Some (_, `New_account)
            | Some (_, `New_token_account) ->
                failwith
                  "gen_account_update_body: all zkapp accounts were new \
                   accounts or used as fee_payer accounts"
            | Some (acct, `Ordinary_participant) ->
                acct
          else
            let accts =
              Account_id.Table.filteri account_state_tbl
                ~f:(fun ~key:_ ~data:(_, role) ->
                  match (authorization_tag, role) with
                  | _, `Fee_payer ->
                      false
                  | Control.Tag.Proof, `New_account ->
                      false
                  | _, `New_token_account ->
                      false
                  | _, `New_account ->
                      (* `required_balance_change` is only for balancing account_update. Newly created account
                         should not be used in balancing account_update *)
                      Option.is_none required_balance_change
                  | _, `Ordinary_participant ->
                      true )
              |> Account_id.Table.data
            in
            Quickcheck.Generator.of_list accts >>| fst
      | Some account_id ->
          (*get the latest state of the account*)
          let acct =
            Account_id.Table.find_exn account_state_tbl account_id |> fst
          in
          if zkapp_account && Option.is_none acct.zkapp then
            failwith
              "gen_account_update_body: provided account has no zkapp field" ;
          return acct
  in
  let public_key = account.public_key in
  let token_id = account.token_id in
  let%bind balance_change =
    match required_balance_change with
    | Some bal_change ->
        return bal_change
    | None ->
        gen_balance_change account
  in
  let field_array_list_gen ~max_array_len ~max_list_len =
    let array_gen =
      let%bind array_len = Int.gen_uniform_incl 0 max_array_len in
      let%map fields =
        Quickcheck.Generator.list_with_length array_len
          Snark_params.Tick.Field.gen
      in
      Array.of_list fields
    in
    let%bind list_len = Int.gen_uniform_incl 0 max_list_len in
    Quickcheck.Generator.list_with_length list_len array_gen
  in
  let%bind events = field_array_list_gen ~max_array_len:2 ~max_list_len:1 in
  let%bind sequence_events =
    field_array_list_gen ~max_array_len:2 ~max_list_len:1
  in
  let%bind call_data = Snark_params.Tick.Field.gen in
  let first_use_of_account =
    let account_id = Account_id.create public_key token_id in
    match account_ids_seen with
    | None ->
        (* fee payer *)
        true
    | Some hash_set ->
        (* other account_updates *)
        not @@ Hash_set.mem hash_set account_id
  in
  let%bind account_precondition =
    f_account_precondition ~first_use_of_account account
  in
  (* update the depth when generating `account_updates` in Zkapp_command.t *)
  let call_depth = 0 in
  let%bind use_full_commitment =
    let full_account_precondition =
      f_account_update_account_precondition account_precondition
    in
    gen_use_full_commitment ~account_precondition:full_account_precondition
  in
  let%map protocol_state_precondition =
    Option.value_map protocol_state_view
      ~f:
        ( match failure with
        | Some Invalid_protocol_state_precondition ->
            gen_invalid_protocol_state_precondition
        | _ ->
            gen_protocol_state_precondition )
      ~default:(return Zkapp_precondition.Protocol_state.accept)
  and caller =
    match caller with
    | None ->
        Account_update.Call_type.quickcheck_generator
    | Some caller ->
        return caller
  in
  let token_id = f_token_id token_id in
  let authorization_kind =
    match authorization_tag with
    | Control.Tag.None_given ->
        Account_update.Authorization_kind.None_given
    | Signature ->
        Signature
    | Proof ->
        Proof
  in
  (* update account state table with all the changes*)
  (let add_balance_and_balance_change balance
       (balance_change : (Currency.Amount.t, Sgn.t) Currency.Signed_poly.t) =
     match balance_change.sgn with
     | Pos -> (
         match Currency.Balance.add_amount balance balance_change.magnitude with
         | Some bal ->
             bal
         | None ->
             failwith "add_balance_and_balance_change: overflow for sum" )
     | Neg -> (
         match Currency.Balance.sub_amount balance balance_change.magnitude with
         | Some bal ->
             bal
         | None ->
             failwith "add_balance_and_balance_change: underflow for difference"
         )
   in
   let balance_change = f_balance_change balance_change in
   let nonce_incr n = if increment_nonce then Account.Nonce.succ n else n in
   let value_to_be_updated (type a) (c : a Zkapp_basic.Set_or_keep.t)
       ~(default : a) : a =
     match c with Zkapp_basic.Set_or_keep.Set x -> x | Keep -> default
   in
   let delegate (account : Account.t) =
     if is_fee_payer then account.delegate
     else
       Option.map
         ~f:(fun delegate ->
           value_to_be_updated update.delegate ~default:delegate )
         account.delegate
   in
   let zkapp (account : Account.t) =
     if is_fee_payer then account.zkapp
     else
       match account.zkapp with
       | None ->
           None
       | Some zk ->
           let app_state =
             let account_app_state = zk.app_state in
             List.zip_exn
               (Zkapp_state.V.to_list update.app_state)
               (Zkapp_state.V.to_list account_app_state)
             |> List.map ~f:(fun (to_be_updated, current) ->
                    value_to_be_updated to_be_updated ~default:current )
             |> Zkapp_state.V.of_list_exn
           in
           let sequence_state =
             let last_sequence_slot = zk.last_sequence_slot in
             let txn_global_slot =
               Option.value_map protocol_state_view ~default:last_sequence_slot
                 ~f:(fun ps ->
                   ps
                     .Zkapp_precondition.Protocol_state.Poly
                      .global_slot_since_genesis )
             in
             let sequence_state, _last_sequence_slot =
               Mina_ledger.Ledger.update_sequence_state zk.sequence_state
                 sequence_events ~txn_global_slot ~last_sequence_slot
             in
             sequence_state
           in
           let proved_state =
             let keeping_app_state =
               List.for_all ~f:Fn.id
                 (List.map ~f:Zkapp_basic.Set_or_keep.is_keep
                    (Pickles_types.Vector.to_list update.app_state) )
             in
             let changing_entire_app_state =
               List.for_all ~f:Fn.id
                 (List.map ~f:Zkapp_basic.Set_or_keep.is_set
                    (Pickles_types.Vector.to_list update.app_state) )
             in
             let proof_verifies = Control.Tag.(equal Proof authorization_tag) in
             if keeping_app_state then zk.proved_state
             else if proof_verifies then
               if changing_entire_app_state then true else zk.proved_state
             else false
           in
           Some { zk with app_state; sequence_state; proved_state }
   in
   Account_id.Table.update account_state_tbl (Account.identifier account)
     ~f:(function
     | None ->
         (* new entry in table *)
         ( { account with
             balance =
               add_balance_and_balance_change account.balance balance_change
           ; nonce = nonce_incr account.nonce
           ; delegate = delegate account
           ; zkapp = zkapp account
           }
         , if token_account then `New_token_account else `New_account )
     | Some (updated_account, role) ->
         (* update entry in table *)
         ( { updated_account with
             balance =
               add_balance_and_balance_change updated_account.balance
                 balance_change
           ; nonce = nonce_incr updated_account.nonce
           ; delegate = delegate updated_account
           ; zkapp = zkapp updated_account
           }
         , role ) ) ) ;
  { Account_update_body_components.public_key
  ; update =
      ( if new_account then
        { update with
          verification_key = Zkapp_basic.Set_or_keep.Set verification_key
        }
      else update )
  ; token_id
  ; balance_change
  ; increment_nonce = account_update_increment_nonce
  ; events
  ; sequence_events
  ; call_data
  ; call_depth
  ; protocol_state_precondition
  ; account_precondition
  ; use_full_commitment
  ; caller
  ; authorization_kind
  }

let gen_account_update_from ?(update = None) ?failure ?(new_account = false)
    ?(zkapp_account = false) ?account_id ?token_id ?caller ?permissions_auth
    ?required_balance_change ~zkapp_account_ids ~authorization ~account_ids_seen
    ~available_public_keys ~account_state_tbl ?protocol_state_view ?vk () =
  let open Quickcheck.Let_syntax in
  let increment_nonce =
    (* permissions_auth is used to generate updated permissions consistent with a contemplated authorization;
       allow incrementing the nonce only if we know the authorization will be Signature
    *)
    match permissions_auth with
    | Some tag -> (
        match tag with
        | Control.Tag.Signature ->
            true
        | Proof | None_given ->
            false )
    | None ->
        false
  in
  let%bind body_components =
    gen_account_update_body_components ~update ?failure ~new_account
      ~zkapp_account
      ~increment_nonce:(increment_nonce, increment_nonce)
      ?permissions_auth ?account_id ?token_id ?caller ?protocol_state_view ?vk
      ~zkapp_account_ids ~account_ids_seen ~available_public_keys
      ?required_balance_change ~account_state_tbl
      ~gen_balance_change:
        (gen_balance_change ?permissions_auth ~new_account ?failure)
      ~f_balance_change:Fn.id () ~f_token_id:Fn.id
      ~f_account_precondition:(fun ~first_use_of_account acct ->
        gen_account_precondition_from_account ~first_use_of_account acct )
      ~f_account_update_account_precondition:Fn.id
      ~gen_use_full_commitment:(fun ~account_precondition ->
        gen_use_full_commitment ~increment_nonce ~account_precondition
          ~authorization () )
      ~authorization_tag:(Control.tag authorization)
  in
  let body =
    Account_update_body_components.to_typical_account_update body_components
  in
  let account_id = Account_id.create body.public_key body.token_id in
  Hash_set.add account_ids_seen account_id ;
  return { Account_update.Simple.body; authorization }

(* takes an account id, if we want to sign this data *)
let gen_account_update_body_fee_payer ?failure ?permissions_auth ~account_id ?vk
    ?protocol_state_view ~account_state_tbl () :
    Account_update.Body.Fee_payer.t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let account_precondition_gen (account : Account.t) =
    Quickcheck.Generator.return account.nonce
  in
  let%map body_components =
    gen_account_update_body_components ?failure ?permissions_auth ~account_id
      ~account_state_tbl ?vk ~zkapp_account_ids:[] ~is_fee_payer:true
      ~increment_nonce:((), true) ~gen_balance_change:gen_fee
      ~f_balance_change:fee_to_amt
      ~f_token_id:(fun token_id ->
        (* make sure the fee payer's token id is the default,
           which is represented by the unit value in the body
        *)
        assert (Token_id.equal token_id Token_id.default) ;
        () )
      ~f_account_precondition:(fun ~first_use_of_account:_ acct ->
        account_precondition_gen acct )
      ~f_account_update_account_precondition:(fun nonce -> Nonce nonce)
      ~gen_use_full_commitment:(fun ~account_precondition:_ -> return ())
      ?protocol_state_view ~authorization_tag:Control.Tag.Signature ()
  in
  Account_update_body_components.to_fee_payer body_components

let gen_fee_payer ?failure ?permissions_auth ~account_id ?protocol_state_view
    ?vk ~account_state_tbl () :
    Account_update.Fee_payer.t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let%map body =
    gen_account_update_body_fee_payer ?failure ?permissions_auth ~account_id ?vk
      ?protocol_state_view ~account_state_tbl ()
  in
  (* real signature to be added when this data inserted into a Zkapp_command.t *)
  let authorization = Signature.dummy in
  ({ body; authorization } : Account_update.Fee_payer.t)

(* keep max_account_updates small, so zkApp integration tests don't need lots
   of block producers

   because the other zkapp_command are split into a permissions-setter
   and another account_update, the actual number of other zkapp_command is
   twice this value, plus one, for the "balancing" account_update

   when we have separate transaction accounts in integration tests
   this number can be increased
*)
let max_account_updates = 2

let max_token_updates = 2

let gen_zkapp_command_from ?failure ?(max_account_updates = max_account_updates)
    ?(max_token_updates = max_token_updates)
    ~(fee_payer_keypair : Signature_lib.Keypair.t)
    ~(keymap :
       Signature_lib.Private_key.t Signature_lib.Public_key.Compressed.Map.t )
    ?account_state_tbl ~ledger ?protocol_state_view ?vk () =
  let open Quickcheck.Let_syntax in
  let fee_payer_pk =
    Signature_lib.Public_key.compress fee_payer_keypair.public_key
  in
  let fee_payer_acct_id = Account_id.create fee_payer_pk Token_id.default in
  let ledger_accounts = Ledger.to_list ledger in
  (* table of public keys to accounts, updated when generating each account_update

     a Map would be more principled, but threading that map through the code
     adds complexity
  *)
  let account_state_tbl =
    Option.value account_state_tbl ~default:(Account_id.Table.create ())
  in
  (* make sure all ledger keys are in the keymap *)
  List.iter ledger_accounts ~f:(fun acct ->
      let acct_id = Account.identifier acct in
      let pk = Account_id.public_key acct_id in
      (*Initialize account states*)
      Account_id.Table.update account_state_tbl acct_id ~f:(function
        | None ->
            if Account_id.equal acct_id fee_payer_acct_id then (acct, `Fee_payer)
            else (acct, `Ordinary_participant)
        | Some a ->
            a ) ;
      if Option.is_none (Signature_lib.Public_key.Compressed.Map.find keymap pk)
      then
        failwithf
          "gen_zkapp_command_from: public key %s is in ledger, but not keymap"
          (Signature_lib.Public_key.Compressed.to_base58_check pk)
          () ) ;
  (* table of public keys not in the ledger, to be used for new zkapp_command
     we have the corresponding private keys, so we can create signatures for those new zkapp_command
  *)
  let ledger_account_list =
    Account_id.Set.union_list
      [ Ledger.accounts ledger
      ; Account_id.Set.of_hashtbl_keys account_state_tbl
      ]
    |> Account_id.Set.to_list
  in
  let ledger_pk_list =
    List.map ledger_account_list ~f:(fun account_id ->
        Account_id.public_key account_id )
  in
  let ledger_pk_set =
    Signature_lib.Public_key.Compressed.Set.of_list ledger_pk_list
  in
  let available_public_keys =
    let tbl = Signature_lib.Public_key.Compressed.Table.create () in
    Signature_lib.Public_key.Compressed.Map.iter_keys keymap ~f:(fun pk ->
        if not (Signature_lib.Public_key.Compressed.Set.mem ledger_pk_set pk)
        then
          Signature_lib.Public_key.Compressed.Table.add_exn tbl ~key:pk ~data:() ) ;
    tbl
  in
  (* account ids seen, to generate receipt chain hash precondition only if
     a account_update with a given account id has not been encountered before
  *)
  let account_ids_seen = Account_id.Hash_set.create () in
  let%bind fee_payer =
    gen_fee_payer ?failure ~permissions_auth:Control.Tag.Signature
      ~account_id:fee_payer_acct_id ?vk ~account_state_tbl ()
  in
  let zkapp_account_ids =
    Account_id.Table.filteri account_state_tbl ~f:(fun ~key:_ ~data:(a, role) ->
        match role with
        | `Fee_payer | `New_account | `New_token_account ->
            false
        | `Ordinary_participant ->
            Option.is_some a.zkapp )
    |> Account_id.Table.keys
  in
  Hash_set.add account_ids_seen fee_payer_acct_id ;
  let mk_forest ps =
    List.map ps ~f:(fun p -> { With_stack_hash.elt = p; stack_hash = () })
  in
  let mk_node p calls =
    { Zkapp_command.Call_forest.Tree.account_update = p
    ; account_update_digest = ()
    ; calls = mk_forest calls
    }
  in
  let gen_zkapp_command_with_dynamic_balance ~new_account num_zkapp_command =
    let rec go acc n =
      let open Zkapp_basic in
      let open Permissions in
      if n <= 0 then return (List.rev acc)
      else
        (* choose a random authorization

           first Account_update.t updates the permissions, using the Signature authorization,
            according the random authorization

           second Account_update.t uses the random authorization
        *)
        let%bind permissions_auth, update =
          match failure with
          | Some (Update_not_permitted update_type) ->
              let%bind is_proof = Bool.quickcheck_generator in
              let auth_tag =
                if is_proof then Control.Tag.Proof else Control.Tag.Signature
              in
              let%map perm = Permissions.gen ~auth_tag in
              let update =
                match update_type with
                | `Delegate ->
                    { Account_update.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            set_delegate = Auth_required.from ~auth_tag
                          }
                    }
                | `App_state ->
                    { Account_update.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            edit_state = Auth_required.from ~auth_tag
                          }
                    }
                | `Verification_key ->
                    { Account_update.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            set_verification_key = Auth_required.from ~auth_tag
                          }
                    }
                | `Zkapp_uri ->
                    { Account_update.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            set_zkapp_uri = Auth_required.from ~auth_tag
                          }
                    }
                | `Token_symbol ->
                    { Account_update.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            set_token_symbol = Auth_required.from ~auth_tag
                          }
                    }
                | `Voting_for ->
                    { Account_update.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            set_voting_for = Auth_required.from ~auth_tag
                          }
                    }
                | `Send ->
                    { Account_update.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with send = Auth_required.from ~auth_tag }
                    }
                | `Receive ->
                    { Account_update.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with receive = Auth_required.from ~auth_tag }
                    }
              in
              (auth_tag, Some update)
          | _ ->
              let%map tag =
                if new_account then
                  Quickcheck.Generator.of_list
                    [ Control.Tag.Signature; None_given ]
                else Control.Tag.gen
              in
              (tag, None)
        in
        let zkapp_account =
          match permissions_auth with
          | Proof ->
              true
          | Signature | None_given ->
              false
        in
        let%bind account_update0 =
          (* Signature authorization to start *)
          let authorization = Control.Signature Signature.dummy in
          gen_account_update_from ~zkapp_account_ids ~account_ids_seen ~update
            ?failure ~authorization ~new_account ~permissions_auth
            ~zkapp_account ~available_public_keys ~account_state_tbl
            ?protocol_state_view ?vk ()
        in
        let%bind account_update =
          (* authorization according to chosen permissions auth *)
          let%bind authorization, update =
            match failure with
            | Some (Update_not_permitted update_type) ->
                let auth =
                  match permissions_auth with
                  | Proof ->
                      Control.(dummy_of_tag Signature)
                  | Signature ->
                      Control.(dummy_of_tag Proof)
                  | _ ->
                      Control.(dummy_of_tag None_given)
                in
                let%bind update =
                  match update_type with
                  | `Delegate ->
                      let%map delegate =
                        Signature_lib.Public_key.Compressed.gen
                      in
                      { Account_update.Update.dummy with
                        delegate = Set_or_keep.Set delegate
                      }
                  | `App_state ->
                      let%map app_state =
                        let%map fields =
                          let field_gen =
                            Snark_params.Tick.Field.gen
                            >>| fun x -> Set_or_keep.Set x
                          in
                          Quickcheck.Generator.list_with_length 8 field_gen
                        in
                        Zkapp_state.V.of_list_exn fields
                      in
                      { Account_update.Update.dummy with app_state }
                  | `Verification_key ->
                      let data = Pickles.Side_loaded.Verification_key.dummy in
                      let hash = Zkapp_account.digest_vk data in
                      let verification_key =
                        Set_or_keep.Set { With_hash.data; hash }
                      in
                      return
                        { Account_update.Update.dummy with verification_key }
                  | `Zkapp_uri ->
                      let zkapp_uri = Set_or_keep.Set "https://o1labs.org" in
                      return { Account_update.Update.dummy with zkapp_uri }
                  | `Token_symbol ->
                      let token_symbol = Set_or_keep.Set "CODA" in
                      return { Account_update.Update.dummy with token_symbol }
                  | `Voting_for ->
                      let%map field = Snark_params.Tick.Field.gen in
                      let voting_for = Set_or_keep.Set field in
                      { Account_update.Update.dummy with voting_for }
                  | `Send | `Receive ->
                      return Account_update.Update.dummy
                in
                let%map new_perm =
                  Permissions.gen ~auth_tag:Control.Tag.Signature
                in
                ( auth
                , Some { update with permissions = Set_or_keep.Set new_perm } )
            | _ ->
                return (Control.dummy_of_tag permissions_auth, None)
          in
          let account_id =
            Account_id.create account_update0.body.public_key
              account_update0.body.token_id
          in
          let permissions_auth = Control.Tag.Signature in
          gen_account_update_from ~update ?failure ~zkapp_account_ids
            ~account_ids_seen ~account_id ~authorization ~permissions_auth
            ~zkapp_account ~available_public_keys ~account_state_tbl
            ?protocol_state_view ?vk ()
        in
        (* this list will be reversed, so `account_update0` will execute before `account_update` *)
        go
          (mk_node account_update [] :: mk_node account_update0 [] :: acc)
          (n - 1)
    in
    go [] num_zkapp_command
  in
  (* at least 1 account_update *)
  let%bind num_zkapp_command = Int.gen_uniform_incl 1 max_account_updates in
  let%bind num_new_accounts = Int.gen_uniform_incl 0 num_zkapp_command in
  let num_old_zkapp_command = num_zkapp_command - num_new_accounts in
  let%bind old_zkapp_command =
    gen_zkapp_command_with_dynamic_balance ~new_account:false
      num_old_zkapp_command
  in
  let%bind new_zkapp_command =
    gen_zkapp_command_with_dynamic_balance ~new_account:true num_new_accounts
  in
  let account_updates0 = old_zkapp_command @ new_zkapp_command in
  let balance_change_sum =
    List.fold account_updates0
      ~init:
        ( if num_new_accounts = 0 then Currency.Amount.Signed.zero
        else
          Currency.Amount.(
            Signed.of_unsigned
              ( scale
                  (of_fee
                     Genesis_constants.Constraint_constants.compiled
                       .account_creation_fee )
                  num_new_accounts
              |> Option.value_exn )) )
      ~f:(fun acc node ->
        match
          Currency.Amount.Signed.add acc node.account_update.body.balance_change
        with
        | Some sum ->
            sum
        | None ->
            failwith "Overflow adding other zkapp_command balances" )
  in

  (* modify the balancing account_update with balance change to yield a zero sum

     balancing account_update is created immediately after the fee payer
     account_update is created. This is because the preconditions generation
     is sensitive to the order of account_update generation.
  *)
  let balance_change = Currency.Amount.Signed.negate balance_change_sum in
  let%bind balancing_account_update =
    let authorization = Control.Signature Signature.dummy in
    gen_account_update_from ?failure ~permissions_auth:Control.Tag.Signature
      ~zkapp_account_ids ~account_ids_seen ~authorization ~new_account:false
      ~available_public_keys ~account_state_tbl
      ~required_balance_change:balance_change ?protocol_state_view ?vk ()
  in
  let gen_zkapp_command_with_token_accounts ~num_zkapp_command =
    let authorization = Control.Signature Signature.dummy in
    let permissions_auth = Control.Tag.Signature in
    let caller = Account_update.Call_type.Call in
    let rec gen_tree acc n =
      if n <= 0 then return (List.rev acc)
      else
        let%bind parent =
          let required_balance_change =
            Currency.Amount.(
              Signed.negate
                (Signed.of_unsigned
                   (of_fee
                      Genesis_constants.Constraint_constants.compiled
                        .account_creation_fee ) ))
          in
          gen_account_update_from ~zkapp_account_ids ~account_ids_seen
            ~authorization ~permissions_auth ~available_public_keys ~caller
            ~account_state_tbl ~required_balance_change ?protocol_state_view ?vk
            ()
        in
        let token_id =
          Account_id.derive_token_id
            ~owner:
              (Account_id.create parent.body.public_key parent.body.token_id)
        in
        let%bind child =
          gen_account_update_from ~zkapp_account_ids ~account_ids_seen
            ~new_account:true ~token_id ~caller ~authorization ~permissions_auth
            ~available_public_keys ~account_state_tbl ?protocol_state_view ?vk
            ()
        in
        gen_tree (mk_node parent [ mk_node child [] ] :: acc) (n - 1)
    in
    gen_tree [] num_zkapp_command
  in
  let%bind num_new_token_zkapp_command =
    Int.gen_uniform_incl 0 max_token_updates
  in
  let%bind new_token_zkapp_command =
    gen_zkapp_command_with_token_accounts
      ~num_zkapp_command:num_new_token_zkapp_command
  in
  let account_updates =
    account_updates0
    @ [ mk_node balancing_account_update [] ]
    @ new_token_zkapp_command
    |> mk_forest
  in
  let%map memo = Signed_command_memo.gen in
  let zkapp_command_dummy_authorizations : Zkapp_command.t =
    { fee_payer
    ; account_updates =
        account_updates |> Zkapp_command.Call_forest.add_callers_simple
        |> Zkapp_command.Call_forest.accumulate_hashes_predicated
    ; memo
    }
  in
  (* update receipt chain hashes in accounts table *)
  let receipt_elt =
    let _txn_commitment, full_txn_commitment =
      (* also computed in replace_authorizations, but easier just to re-compute here *)
      Zkapp_command_builder.get_transaction_commitments
        zkapp_command_dummy_authorizations
    in
    Receipt.Zkapp_command_elt.Zkapp_command_commitment full_txn_commitment
  in
  Account_id.Table.update account_state_tbl fee_payer_acct_id ~f:(function
    | None ->
        failwith "Expected fee payer account id to be in table"
    | Some (account, _) ->
        let receipt_chain_hash =
          Receipt.Chain_hash.cons_zkapp_command_commitment
            Mina_numbers.Index.zero receipt_elt
            account.Account.Poly.receipt_chain_hash
        in
        ({ account with receipt_chain_hash }, `Fee_payer) ) ;
  let account_updates =
    Zkapp_command.Call_forest.to_account_updates
      zkapp_command_dummy_authorizations.account_updates
  in
  List.iteri account_updates ~f:(fun ndx account_update ->
      (* update receipt chain hash only for signature, proof authorizations *)
      match Account_update.authorization account_update with
      | Control.Proof _ | Control.Signature _ ->
          let acct_id = Account_update.account_id account_update in
          Account_id.Table.update account_state_tbl acct_id ~f:(function
            | None ->
                failwith
                  "Expected other account_update account id to be in table"
            | Some (account, role) ->
                let receipt_chain_hash =
                  let account_update_index =
                    Mina_numbers.Index.of_int (ndx + 1)
                  in
                  Receipt.Chain_hash.cons_zkapp_command_commitment
                    account_update_index receipt_elt
                    account.Account.Poly.receipt_chain_hash
                in
                ({ account with receipt_chain_hash }, role) )
      | Control.None_given ->
          () ) ;
  zkapp_command_dummy_authorizations

let gen_list_of_zkapp_command_from ?failure ?max_account_updates
    ?max_token_updates ~(fee_payer_keypairs : Signature_lib.Keypair.t list)
    ~keymap ?account_state_tbl ~ledger ?protocol_state_view ?vk ?length () =
  (* Since when generating multiple zkapp_command the fee payer's nonce should only
     be incremented as the `Fee_payer` role, this is why we pre-computed the
     `account_state_tbl` here.
  *)
  let account_state_tbl =
    match account_state_tbl with
    | None ->
        let tbl = Account_id.Table.create () in
        let accounts = Ledger.to_list ledger in
        List.iter accounts ~f:(fun acct ->
            let acct_id = Account.identifier acct in
            Account_id.Table.update tbl acct_id ~f:(function
              | None ->
                  (acct, `Ordinary_participant)
              | Some a ->
                  a ) ) ;
        List.iter fee_payer_keypairs ~f:(fun fee_payer_keypair ->
            let acct_id =
              Account_id.create
                (Signature_lib.Public_key.compress fee_payer_keypair.public_key)
                Token_id.default
            in
            Account_id.Table.update tbl acct_id ~f:(function
              | None ->
                  failwith "fee_payer not in ledger"
              | Some (a, _) ->
                  (a, `Fee_payer) ) ) ;
        tbl
    | Some tbl ->
        tbl
  in
  let open Quickcheck.Generator.Let_syntax in
  let%bind length =
    match length with None -> Int.gen_uniform_incl 1 10 | Some n -> return n
  in
  let rec go n acc =
    if n > 0 then
      let%bind fee_payer_keypair =
        Quickcheck.Generator.of_list fee_payer_keypairs
      in
      let%bind new_zkapp_command =
        gen_zkapp_command_from ?failure ?max_account_updates ?max_token_updates
          ~fee_payer_keypair ~keymap ~account_state_tbl ~ledger
          ?protocol_state_view ?vk ()
      in
      go (n - 1) (new_zkapp_command :: acc)
    else return (List.rev acc)
  in
  go length []
