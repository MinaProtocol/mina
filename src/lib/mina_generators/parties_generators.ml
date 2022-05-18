(* snapp_generators -- Quickcheck generators for Snapp transactions *)

(* Ledger depends on Party, so Party generators can't refer back to Ledger
   so we put the generators that rely on Ledger and Party here
*)

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
      | `Balance ]

let gen_account_precondition_from_account ?failure account =
  let open Quickcheck.Let_syntax in
  let%bind b = Quickcheck.Generator.bool in
  let { Account.Poly.balance; nonce; receipt_chain_hash; delegate; zkapp; _ } =
    account
  in
  (* choose constructor *)
  if b then
    (* Full *)
    let open Zkapp_basic in
    let%bind (predicate_account : Zkapp_precondition.Account.t) =
      let%bind balance =
        let%bind balance_change_int = Int.gen_uniform_incl 1 10_000_000 in
        let balance_change = Currency.Amount.of_int balance_change_int in
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
        let%bind balance_change_int = Int.gen_uniform_incl 1 100 in
        let balance_change = Account.Nonce.of_int balance_change_int in
        let lower =
          match Account.Nonce.sub nonce balance_change with
          | None ->
              Account.Nonce.zero
          | Some nonce ->
              nonce
        in
        let upper =
          (* Nonce.add doesn't check for overflow, so check here *)
          match Account.Nonce.(sub max_value) balance_change with
          | None ->
              (* unreachable *)
              failwith
                "gen_account_precondition_from: nonce subtraction failed \
                 unexpectedly"
          | Some n ->
              if Account.Nonce.( < ) n nonce then Account.Nonce.max_value
              else Account.Nonce.add nonce balance_change
        in
        Or_ignore.gen
          (return { Zkapp_precondition.Closed_interval.lower; upper })
      in
      let receipt_chain_hash = Or_ignore.Check receipt_chain_hash in
      let%bind delegate =
        match delegate with
        | None ->
            return Or_ignore.Ignore
        | Some pk ->
            Or_ignore.gen (return pk)
      in
      let%bind state, sequence_state, proved_state =
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
            return (state, sequence_state, proved_state)
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
            return (state, sequence_state, proved_state)
      in
      return
        { Zkapp_precondition.Account.balance
        ; nonce
        ; receipt_chain_hash
        ; delegate
        ; state
        ; sequence_state
        ; proved_state
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
        return (Party.Account_precondition.Full faulty_predicate_account)
    | _ ->
        return (Party.Account_precondition.Full predicate_account)
  else
    (* Nonce *)
    let { Account.Poly.nonce; _ } = account in
    match failure with
    | Some Invalid_account_precondition ->
        return (Party.Account_precondition.Nonce (Account.Nonce.succ nonce))
    | _ ->
        return (Party.Account_precondition.Nonce nonce)

let gen_account_precondition_from ?failure ~account_id ~ledger () =
  (* construct account_precondition using pk and ledger
     don't return Accept, which would ignore those inputs
  *)
  let open Quickcheck.Let_syntax in
  match Ledger.location_of_account ledger account_id with
  | None -> (
      (* account not in the ledger, can't create meaningful Full or Nonce *)
      match failure with
      | Some Invalid_account_precondition ->
          let%map nonce = Account.Nonce.gen in
          Party.Account_precondition.Nonce nonce
      | _ ->
          failwithf
            "gen_account_precondition_from: account id with public key %s and \
             token id %s not in ledger"
            (Signature_lib.Public_key.Compressed.to_base58_check
               (Account_id.public_key account_id) )
            (Account_id.token_id account_id |> Token_id.to_string)
            () )
  | Some loc -> (
      match Ledger.get ledger loc with
      | None ->
          failwith
            "gen_account_precondition_from: could not find account with known \
             location"
      | Some account ->
          gen_account_precondition_from_account ~failure account )

let gen_fee (account : Account.t) =
  let lo_fee = Mina_compile_config.minimum_user_command_fee in
  let hi_fee =
    Currency.(
      Fee.min
        (Option.value_exn (Currency.Fee.scale lo_fee 5))
        (Amount.to_fee (Balance.to_amount account.balance)))
  in
  Currency.Fee.gen_incl lo_fee hi_fee

let fee_to_amt fee = Currency.Amount.(Signed.of_unsigned (of_fee fee))

let gen_balance_change ?balances_tbl ?permissions_auth (account : Account.t) =
  let open Quickcheck.Let_syntax in
  let pk = account.public_key in
  let%bind sgn =
    match permissions_auth with
    | Some auth -> (
        match auth with
        | Control.Tag.None_given ->
            return Sgn.Pos
        | _ ->
            Quickcheck.Generator.of_list [ Sgn.Pos; Neg ] )
    | None ->
        Quickcheck.Generator.of_list [ Sgn.Pos; Neg ]
  in
  match sgn with
  | Pos ->
      (* if positive, the account balance does not impose a constraint on the magnitude; but
         to avoid overflow over several Party.t, we'll limit the value
      *)
      let%map (magnitude : Currency.Amount.t) =
        Currency.Amount.gen_incl Currency.Amount.zero
          (Currency.Amount.of_int 10_000_000_000)
      in
      ({ magnitude; sgn = Sgn.Pos } : Currency.Amount.Signed.t)
  | Neg ->
      (* if negative, magnitude constrained to balance in account
         the effective balance is either what's in the balances table,
         if provided, or what's in the ledger
      *)
      let effective_balance =
        match balances_tbl with
        | Some tbl -> (
            match Signature_lib.Public_key.Compressed.Table.find tbl pk with
            | None ->
                account.balance
            | Some balance ->
                balance )
        | None ->
            account.balance
      in
      let%map magnitude =
        Currency.Amount.gen_incl Currency.Amount.zero
          (Currency.Balance.to_amount effective_balance)
      in
      ({ magnitude; sgn = Sgn.Neg } : Currency.Amount.Signed.t)

let gen_use_full_commitment ~increment_nonce () :
    bool Base_quickcheck.Generator.t =
  (* to avoid replays, either increment_nonce or use_full_commitment must be true;
     we never generate Accept as the predicate,
  *)
  if increment_nonce then Bool.quickcheck_generator
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
      Amount.gen_incl (Amount.of_int 0) (Amount.of_int 1_000_000_000)
    in
    let%bind epsilon2 =
      Amount.gen_incl (Amount.of_int 0) (Amount.of_int 1_000_000_000)
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
          Amount.(gen_incl (of_int 1_000) (of_int 1_000_000_000))
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

module Party_body_components = struct
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
       , 'caller )
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
    }

  let to_fee_payer t : Party.Body.Fee_payer.t =
    { public_key = t.public_key
    ; update = t.update
    ; fee = t.balance_change
    ; events = t.events
    ; sequence_events = t.sequence_events
    ; protocol_state_precondition = t.protocol_state_precondition
    ; nonce = t.account_precondition
    }

  let to_typical_party t : Party.Body.Wire.t =
    { public_key = t.public_key
    ; update = t.update
    ; token_id = t.token_id
    ; balance_change = t.balance_change
    ; increment_nonce = t.increment_nonce
    ; events = t.events
    ; sequence_events = t.sequence_events
    ; call_data = t.call_data
    ; call_depth = t.call_depth
    ; protocol_state_precondition = t.protocol_state_precondition
    ; account_precondition = t.account_precondition
    ; use_full_commitment = t.use_full_commitment
    ; caller = t.caller
    }
end

(* The type `a` is associated with the `delta` field, which is an unsigned fee
   for the fee payer, and a signed amount for other parties.
   The type `b` is associated with the `use_full_commitment` field, which is
   `unit` for the fee payer, and `bool` for other parties.
   The type `c` is associated with the `token_id` field, which is `unit` for the
   fee payer, and `Token_id.t` for other parties.
*)
let gen_party_body_components (type a b c d) ?(update = None) ?account_id
    ?balances_tbl ?vk ?failure ?(new_account = false) ?(zkapp_account = false)
    ?(is_fee_payer = false) ?available_public_keys ?permissions_auth
    ?(required_balance_change : a option)
    ?(required_balance : Currency.Balance.t option) ?protocol_state_view
    ~(gen_balance_change : Account.t -> a Quickcheck.Generator.t)
    ~(gen_use_full_commitment : b Quickcheck.Generator.t)
    ~(f_balance_change : a -> Currency.Amount.Signed.t) ~(increment_nonce : b)
    ~(f_token_id : Token_id.t -> c) ~f_account_predcondition ~ledger () :
    (_, _, _, a, _, _, _, b, _, d, _) Party_body_components.t
    Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  (* fee payers have to be in the ledger *)
  assert (not (is_fee_payer && new_account)) ;
  (* if it's a Snapp account, and we haven't provided an account id, then
     we have to create a new account; not all ledger accounts are Snapp accounts,
     so we can't just pick a ledger account
  *)
  let new_account =
    new_account || (zkapp_account && Option.is_none account_id)
  in
  (* a required balance is associated with a new account *)
  ( match (required_balance, new_account) with
  | Some _, false ->
      failwith "Required balance, but not new account"
  | _ ->
      () ) ;
  let%bind update =
    match update with
    | None ->
        Party.Update.gen ?permissions_auth ?vk ~zkapp_account ()
    | Some update ->
        return update
  in
  let%bind account =
    if new_account then (
      if Option.is_some account_id then
        failwith
          "gen_party_body: new party is true, but an account id, presumably \
           from an existing account, was supplied" ;
      match available_public_keys with
      | None ->
          failwith
            "gen_party_body: new_account is true, but available_public_keys \
             not provided"
      | Some available_pks ->
          let low, high =
            match required_balance with
            | Some bal ->
                (bal, bal)
            | _ ->
                ( Currency.Balance.of_int 10_000_000_000
                , Currency.Balance.of_int 500_000_000_000 )
          in
          let%map account_with_gen_pk =
            Account.gen_with_constrained_balance ~low ~high
          in
          let available_pk =
            match
              Signature_lib.Public_key.Compressed.Table.choose available_pks
            with
            | None ->
                failwith "gen_party_body: no available public keys"
            | Some (pk, ()) ->
                pk
          in
          (* available public key no longer available *)
          Signature_lib.Public_key.Compressed.Table.remove available_pks
            available_pk ;
          let account_with_pk =
            { account_with_gen_pk with
              public_key = available_pk
            ; token_id = Token_id.default
            }
          in
          let account =
            if zkapp_account then
              { account_with_pk with
                zkapp =
                  (let vk =
                     match vk with
                     | None ->
                         With_hash.
                           { data = Pickles.Side_loaded.Verification_key.dummy
                           ; hash = Zkapp_account.dummy_vk_hash ()
                           }
                     | Some vk ->
                         vk
                   in
                   Some
                     { Zkapp_account.default with verification_key = Some vk }
                  )
              }
            else account_with_pk
          in
          (* add new account to ledger *)
          ( match
              Ledger.get_or_create_account ledger
                (Account_id.create account.public_key account.token_id)
                account
            with
          | Ok (`Added, _) ->
              ()
          | Ok (`Existed, _) ->
              failwith "gen_party_body: account for new party already in ledger"
          | Error err ->
              failwithf
                "gen_party_body: could not add account to ledger new party: %s"
                (Error.to_string_hum err) () ) ;
          account )
    else
      match account_id with
      | None ->
          (* choose an account from the ledger *)
          let%map index =
            Int.gen_uniform_incl 0 (Ledger.num_accounts ledger - 1)
          in
          let account = Ledger.get_at_index_exn ledger index in
          if zkapp_account && Option.is_none account.zkapp then
            failwith "gen_party_body: chosen account has no snapp field" ;
          account
      | Some account_id -> (
          (* use given account from the ledger *)
          match Ledger.location_of_account ledger account_id with
          | None ->
              failwithf
                "gen_party_body: could not find account location for passed \
                 account id with public key %s and token_id %s"
                (Signature_lib.Public_key.Compressed.to_base58_check
                   (Account_id.public_key account_id) )
                (Account_id.token_id account_id |> Token_id.to_string)
                ()
          | Some location -> (
              match Ledger.get ledger location with
              | None ->
                  (* should be unreachable *)
                  failwithf
                    "gen_party_body: could not find account for passed account \
                     id with public key %s and token id %s"
                    (Signature_lib.Public_key.Compressed.to_base58_check
                       (Account_id.public_key account_id) )
                    (Account_id.token_id account_id |> Token_id.to_string)
                    ()
              | Some acct ->
                  if zkapp_account && Option.is_none acct.zkapp then
                    failwith
                      "gen_party_body: provided account has no snapp field" ;
                  return acct ) )
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
  (* update balances table, if provided, with balance_change *)
  ( match balances_tbl with
  | None ->
      ()
  | Some tbl ->
      let add_balance_and_balance_change balance
          (balance_change : (Currency.Amount.t, Sgn.t) Currency.Signed_poly.t) =
        match balance_change.sgn with
        | Pos -> (
            match
              Currency.Balance.add_amount balance balance_change.magnitude
            with
            | Some bal ->
                bal
            | None ->
                failwith "add_balance_and_balance_change: overflow for sum" )
        | Neg -> (
            match
              Currency.Balance.sub_amount balance balance_change.magnitude
            with
            | Some bal ->
                bal
            | None ->
                failwith
                  "add_balance_and_balance_change: underflow for difference" )
      in
      let balance_change = f_balance_change balance_change in
      Signature_lib.Public_key.Compressed.Table.change tbl public_key
        ~f:(function
        | None ->
            (* new entry in table *)
            Some (add_balance_and_balance_change account.balance balance_change)
        | Some balance ->
            (* update entry in table *)
            Some (add_balance_and_balance_change balance balance_change) ) ) ;
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
  (* TODO: are these lengths reasonable? *)
  let%bind events = field_array_list_gen ~max_array_len:8 ~max_list_len:12 in
  let%bind sequence_events =
    field_array_list_gen ~max_array_len:4 ~max_list_len:6
  in
  let%bind call_data = Snark_params.Tick.Field.gen in
  let%bind account_precondition =
    f_account_predcondition (Account.identifier account) ledger ()
  in
  (* update the depth when generating `other_parties` in Parties.t *)
  let call_depth = 0 in
  let%bind protocol_state_precondition =
    Option.value_map protocol_state_view
      ~f:
        ( match failure with
        | Some Invalid_protocol_state_precondition ->
            gen_invalid_protocol_state_precondition
        | _ ->
            gen_protocol_state_precondition )
      ~default:(return Zkapp_precondition.Protocol_state.accept)
  in
  let%map use_full_commitment = gen_use_full_commitment
  and caller = Party.Call_type.quickcheck_generator in
  let token_id = f_token_id token_id in
  { Party_body_components.public_key
  ; update
  ; token_id
  ; balance_change
  ; increment_nonce
  ; events
  ; sequence_events
  ; call_data
  ; call_depth
  ; protocol_state_precondition
  ; account_precondition
  ; use_full_commitment
  ; caller
  }

let gen_party_from ?(update = None) ?failure ?(new_account = false)
    ?(zkapp_account = false) ?account_id ?permissions_auth
    ?required_balance_change ?required_balance ~authorization
    ~available_public_keys ~ledger ~balances_tbl ?vk () =
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
    gen_party_body_components ~update ~failure ~new_account ~zkapp_account
      ~increment_nonce ?permissions_auth ?account_id ?vk ~available_public_keys
      ?required_balance_change ?required_balance ~ledger ~balances_tbl
      ~gen_balance_change:(gen_balance_change ?permissions_auth ~balances_tbl)
      ~f_balance_change:Fn.id () ~f_token_id:Fn.id
      ~f_account_predcondition:(fun account_id ledger ->
        gen_account_precondition_from ~failure ~account_id ~ledger )
      ~gen_use_full_commitment:(gen_use_full_commitment ~increment_nonce ())
  in
  let body = Party_body_components.to_typical_party body_components in
  return { Party.Wire.body; authorization }

(* takes an account id, if we want to sign this data *)
let gen_party_body_fee_payer ?failure ?permissions_auth ~account_id ~ledger ?vk
    ?protocol_state_view () : Party.Body.Fee_payer.t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let account_precondition_gen account_id ledger () =
    let account =
      match Ledger.location_of_account ledger account_id with
      | None ->
          failwith
            "gen_party_predicated_fee_payer: expected account to be in ledger"
      | Some loc -> (
          match Ledger.get ledger loc with
          | None ->
              failwith "gen_party_predicated_fee_payer: no account at location"
          | Some account ->
              account )
    in
    Quickcheck.Generator.return account.nonce
  in
  let%map body_components =
    gen_party_body_components ~failure ?permissions_auth ~account_id ?vk
      ~is_fee_payer:true ~increment_nonce:() ~gen_balance_change:gen_fee
      ~f_balance_change:fee_to_amt
      ~f_token_id:(fun token_id ->
        (* make sure the fee payer's token id is the default,
           which is represented by the unit value in the body
        *)
        assert (Token_id.equal token_id Token_id.default) ;
        () )
      ~f_account_predcondition:account_precondition_gen
      ~gen_use_full_commitment:(return ()) ~ledger ?protocol_state_view ()
  in
  Party_body_components.to_fee_payer body_components

let gen_fee_payer ?failure ?permissions_auth ~account_id ~ledger
    ?protocol_state_view ?vk () : Party.Fee_payer.t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let%map body =
    gen_party_body_fee_payer ~failure ?permissions_auth ~account_id ~ledger ?vk
      ?protocol_state_view ()
  in
  (* real signature to be added when this data inserted into a Parties.t *)
  let authorization = Signature.dummy in
  ({ body; authorization } : Party.Fee_payer.t)

(* keep max_other_parties small, so snapp integration tests don't need lots
   of block producers

   because the other parties are split into a permissions-setter
   and another party, the actual number of other parties is
   twice this value, plus one, for the "balancing" party

   when we have separate transaction accounts in integration tests
   this number can be increased
*)
let max_other_parties = 2

let gen_parties_from ?(failure = None)
    ~(fee_payer_keypair : Signature_lib.Keypair.t)
    ~(keymap :
       Signature_lib.Private_key.t Signature_lib.Public_key.Compressed.Map.t )
    ~ledger ?protocol_state_view ?vk ?prover () =
  let open Quickcheck.Let_syntax in
  let fee_payer_pk =
    Signature_lib.Public_key.compress fee_payer_keypair.public_key
  in
  let fee_payer_account_id = Account_id.create fee_payer_pk Token_id.default in
  let ledger_accounts = Ledger.accounts ledger in
  (* make sure all ledger keys are in the keymap *)
  Account_id.Set.iter ledger_accounts ~f:(fun acct_id ->
      let pk = Account_id.public_key acct_id in
      if Option.is_none (Signature_lib.Public_key.Compressed.Map.find keymap pk)
      then
        failwithf "gen_parties_from: public key %s is in ledger, but not keymap"
          (Signature_lib.Public_key.Compressed.to_base58_check pk)
          () ) ;
  (* table of public keys not in the ledger, to be used for new parties
     we have the corresponding private keys, so we can create signatures for those new parties
  *)
  let available_public_keys =
    let tbl = Signature_lib.Public_key.Compressed.Table.create () in
    Signature_lib.Public_key.Compressed.Map.iter_keys keymap ~f:(fun pk ->
        let account_id = Account_id.create pk Token_id.default in
        if not (Account_id.Set.mem ledger_accounts account_id) then
          Signature_lib.Public_key.Compressed.Table.add_exn tbl ~key:pk ~data:() ) ;
    tbl
  in
  let%bind fee_payer =
    gen_fee_payer ~failure ~permissions_auth:Control.Tag.Signature
      ~account_id:fee_payer_account_id ~ledger ?protocol_state_view ?vk ()
  in

  (* table of public keys to balances, updated when generating each party

     a Map would be more principled, but threading that map through the code
     adds complexity
  *)
  let balances_tbl = Signature_lib.Public_key.Compressed.Table.create () in
  let gen_parties_with_dynamic_balance ~new_parties num_parties =
    (* add fee payer account, in case same account used again *)
    let fee_payer_pk = fee_payer.body.public_key in
    let fee_payer_balance =
      (* if we've done things right, all the options here are Some *)
      let fee =
        fee_payer.body.fee |> Currency.Fee.to_uint64
        |> Currency.Amount.of_uint64
      in
      let ledger_balance =
        let account_id = Account_id.create fee_payer_pk Token_id.default in
        let loc =
          Option.value_exn (Ledger.location_of_account ledger account_id)
        in
        let fee_payer_account = Option.value_exn (Ledger.get ledger loc) in
        fee_payer_account.balance
      in
      Option.value_exn (Currency.Balance.sub_amount ledger_balance fee)
    in
    ignore
      ( Signature_lib.Public_key.Compressed.Table.add balances_tbl
          ~key:fee_payer_pk ~data:fee_payer_balance
        : [ `Duplicate | `Ok ] ) ;
    let rec go acc n =
      let open Zkapp_basic in
      let open Permissions in
      if n <= 0 then return (List.rev acc)
      else
        (* choose a random authorization

           first Party.t updates the permissions, using the Signature authorization,
            according the random authorization

           second Party.t uses the random authorization
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
                    { Party.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            set_delegate = Auth_required.from ~auth_tag
                          }
                    }
                | `App_state ->
                    { Party.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            edit_state = Auth_required.from ~auth_tag
                          }
                    }
                | `Verification_key ->
                    { Party.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            set_verification_key = Auth_required.from ~auth_tag
                          }
                    }
                | `Zkapp_uri ->
                    { Party.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            set_zkapp_uri = Auth_required.from ~auth_tag
                          }
                    }
                | `Token_symbol ->
                    { Party.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            set_token_symbol = Auth_required.from ~auth_tag
                          }
                    }
                | `Voting_for ->
                    { Party.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with
                            set_voting_for = Auth_required.from ~auth_tag
                          }
                    }
                | `Balance ->
                    { Party.Update.dummy with
                      permissions =
                        Set_or_keep.Set
                          { perm with send = Auth_required.from ~auth_tag }
                    }
              in
              (auth_tag, Some update)
          | _ ->
              let%map tag = Control.Tag.gen in
              (tag, None)
        in
        let zkapp_account =
          match permissions_auth with
          | Proof ->
              true
          | Signature | None_given ->
              false
        in
        let%bind party0 =
          (* Signature authorization to start *)
          let authorization = Control.Signature Signature.dummy in
          let required_balance_change = Currency.Amount.Signed.zero in
          gen_party_from ~update ~failure ~authorization
            ~new_account:new_parties ~permissions_auth ~zkapp_account
            ~available_public_keys ~required_balance_change ~ledger
            ~balances_tbl ?vk ()
        in
        let%bind party =
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
                      { Party.Update.dummy with
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
                      { Party.Update.dummy with app_state }
                  | `Verification_key ->
                      let data = Pickles.Side_loaded.Verification_key.dummy in
                      let hash = Zkapp_account.digest_vk data in
                      let verification_key =
                        Set_or_keep.Set { With_hash.data; hash }
                      in
                      return { Party.Update.dummy with verification_key }
                  | `Zkapp_uri ->
                      let zkapp_uri = Set_or_keep.Set "https://o1labs.org" in
                      return { Party.Update.dummy with zkapp_uri }
                  | `Token_symbol ->
                      let token_symbol = Set_or_keep.Set "CODA" in
                      return { Party.Update.dummy with token_symbol }
                  | `Voting_for ->
                      let%map field = Snark_params.Tick.Field.gen in
                      let voting_for = Set_or_keep.Set field in
                      { Party.Update.dummy with voting_for }
                  | `Balance ->
                      return Party.Update.dummy
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
            Account_id.create party0.body.public_key party0.body.token_id
          in
          (* if we use this account again, it will have a Signature authorization *)
          let permissions_auth = Control.Tag.Signature in
          gen_party_from ~update ~failure ~account_id ~authorization
            ~permissions_auth ~zkapp_account ~available_public_keys ~ledger
            ~balances_tbl ?vk ()
        in
        (* this list will be reversed, so `party0` will execute before `party` *)
        go (party :: party0 :: acc) (n - 1)
    in
    go [] num_parties
  in
  (* at least 1 party, so that `succeed` affects at least one predicate *)
  let%bind num_parties = Int.gen_uniform_incl 1 max_other_parties in
  let%bind num_new_accounts = Int.gen_uniform_incl 0 num_parties in
  let num_old_parties = num_parties - num_new_accounts in
  let%bind old_parties =
    gen_parties_with_dynamic_balance ~new_parties:false num_old_parties
  in
  let%bind new_parties =
    gen_parties_with_dynamic_balance ~new_parties:true num_new_accounts
  in
  let other_parties0 = old_parties @ new_parties in
  let balance_change_sum =
    List.fold other_parties0 ~init:Currency.Amount.Signed.zero
      ~f:(fun acc party ->
        match Currency.Amount.Signed.add acc party.body.balance_change with
        | Some sum ->
            sum
        | None ->
            failwith "Overflow adding other parties balances" )
  in

  (* create a party with balance change to yield a zero sum

     a new account, because the balance change for an existing
     account might be constrained by its balance
  *)
  let%bind balancing_party =
    let required_balance_change =
      Currency.Amount.Signed.negate balance_change_sum
    in
    let required_balance =
      match required_balance_change with
      | { magnitude; sgn = Sgn.Neg } ->
          (* put in enough balance so we can subtract it all *)
          Some
            (Currency.Amount.to_uint64 magnitude |> Currency.Balance.of_uint64)
      | { sgn = Sgn.Pos; _ } ->
          (* we're adding to the account, so no required balance *)
          None
    in
    let authorization = Control.Signature Signature.dummy in
    gen_party_from ~failure ~authorization ~new_account:true
      ~available_public_keys ~ledger ~required_balance_change ?required_balance
      ~balances_tbl ?vk ()
  in
  let other_parties = balancing_party :: other_parties0 in
  let%bind memo = Signed_command_memo.gen in
  let memo_hash = Signed_command_memo.hash memo in
  let parties_dummy_signatures : Parties.t =
    Parties.of_wire { fee_payer; other_parties; memo }
  in
  (* replace dummy signature in fee payer *)
  let fee_payer_hash =
    Party.of_fee_payer parties_dummy_signatures.fee_payer
    |> Parties.Digest.Party.create
  in
  let fee_payer_signature =
    Signature_lib.Schnorr.Chunked.sign fee_payer_keypair.private_key
      (Random_oracle.Input.Chunked.field
         ( Parties.commitment parties_dummy_signatures
         |> Parties.Transaction_commitment.create_complete ~memo_hash
              ~fee_payer_hash ) )
  in
  let fee_payer_with_valid_signature =
    { parties_dummy_signatures.fee_payer with
      authorization = fee_payer_signature
    }
  in
  let other_parties_hash =
    Parties.other_parties_hash parties_dummy_signatures
  in
  let tx_commitment =
    Parties.Transaction_commitment.create ~other_parties_hash
  in
  let full_tx_commitment =
    Parties.Transaction_commitment.create_complete tx_commitment ~memo_hash
      ~fee_payer_hash
  in
  let sign_for_other_party ~use_full_commitment sk =
    let commitment =
      if use_full_commitment then full_tx_commitment else tx_commitment
    in
    Signature_lib.Schnorr.Chunked.sign sk
      (Random_oracle.Input.Chunked.field commitment)
  in
  (* replace dummy signatures and dummy proofs in other parties *)
  let other_parties_with_valid_signatures =
    Parties.Call_forest.mapi parties_dummy_signatures.other_parties
      ~f:(fun idx ({ body; authorization } : Party.t) ->
        let valid_authorization =
          match authorization with
          | Control.Signature _dummy ->
              let pk = body.public_key in
              let sk =
                match
                  Signature_lib.Public_key.Compressed.Map.find keymap pk
                with
                | Some sk ->
                    sk
                | None ->
                    failwithf
                      "gen_from: Could not find secret key for public key %s \
                       in keymap"
                      (Signature_lib.Public_key.Compressed.to_base58_check pk)
                      ()
              in
              let use_full_commitment = body.use_full_commitment in
              let signature = sign_for_other_party ~use_full_commitment sk in
              Control.Signature signature
          | Proof _dummy -> (
              match prover with
              | None ->
                  authorization
              | Some prover ->
                  let proof_party =
                    Parties.Call_forest.hash
                      (List.drop parties_dummy_signatures.other_parties idx)
                  in
                  let txn_stmt : Zkapp_statement.t =
                    let commitment =
                      if body.use_full_commitment then full_tx_commitment
                      else tx_commitment
                    in
                    { transaction = commitment
                    ; at_party = (proof_party :> Snark_params.Tick.Field.t)
                    }
                  in
                  let handler
                      (Snarky_backendless.Request.With { request; respond }) =
                    match request with _ -> respond Unhandled
                  in
                  let proof =
                    Async.Thread_safe.block_on_async_exn (fun () ->
                        prover ?handler:(Some handler)
                          ( []
                            : ( unit
                              , unit
                              , unit )
                              Pickles_types.Hlist.H3.T
                                (Pickles.Statement_with_proof)
                              .t )
                          txn_stmt )
                  in
                  Control.Proof proof )
          | None_given ->
              authorization
        in
        { Party.body; authorization = valid_authorization } )
  in
  return
    { parties_dummy_signatures with
      fee_payer = fee_payer_with_valid_signature
    ; other_parties = other_parties_with_valid_signatures
    }
