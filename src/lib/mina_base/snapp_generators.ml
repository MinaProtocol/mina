(* snapp_generators -- Quickcheck generators for Snapp transactions *)

(* Ledger depends on Party, so Party generators can't refer back to Ledger
   so we put the generators that rely on Ledger and Party here
*)

open Core_kernel

let gen_predicate_from ?(succeed = true) ~account_id ~ledger () =
  (* construct predicate using pk and ledger
     don't return Accept, which would ignore those inputs
  *)
  let open Quickcheck.Let_syntax in
  match Ledger.location_of_account ledger account_id with
  | None ->
      (* account not in the ledger, can't create meaningful Full or Nonce *)
      if succeed then
        failwithf
          "gen_predicate_from: account id with public key %s and token id %s \
           not in ledger"
          (Signature_lib.Public_key.Compressed.to_base58_check
             (Account_id.public_key account_id))
          (Account_id.token_id account_id |> Token_id.to_string)
          ()
      else
        (* nonce not connected with any particular account *)
        let%map nonce = Account.Nonce.gen in
        Party.Predicate.Nonce nonce
  | Some loc -> (
      match Ledger.get ledger loc with
      | None ->
          failwith
            "gen_predicate_from: could not find account with known location"
      | Some account ->
          let%bind b = Quickcheck.Generator.bool in
          let { Account.Poly.public_key
              ; balance
              ; nonce
              ; receipt_chain_hash
              ; delegate
              ; snapp
              ; _
              } =
            account
          in
          (* choose constructor *)
          if b then
            (* Full *)
            let open Snapp_basic in
            let%bind (predicate_account : Snapp_predicate.Account.t) =
              let%bind balance =
                let%bind balance_change_int =
                  Int.gen_uniform_incl 1 10_000_000
                in
                let balance_change =
                  Currency.Amount.of_int balance_change_int
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
                  (return { Snapp_predicate.Closed_interval.lower; upper })
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
                        "gen_predicate_from: nonce subtraction failed \
                         unexpectedly"
                  | Some n ->
                      if Account.Nonce.( < ) n nonce then
                        Account.Nonce.max_value
                      else Account.Nonce.add nonce balance_change
                in
                Or_ignore.gen
                  (return { Snapp_predicate.Closed_interval.lower; upper })
              in
              let receipt_chain_hash = Or_ignore.Check receipt_chain_hash in
              let public_key = Or_ignore.Check public_key in
              let%bind delegate =
                match delegate with
                | None ->
                    return Or_ignore.Ignore
                | Some pk ->
                    Or_ignore.gen (return pk)
              in
              let%bind state, sequence_state, proved_state =
                match snapp with
                | None ->
                    (* won't raise, correct length given *)
                    let state =
                      Snapp_state.V.of_list_exn
                        (List.init 8 ~f:(fun _ -> Or_ignore.Ignore))
                    in
                    let sequence_state = Or_ignore.Ignore in
                    let proved_state = Or_ignore.Ignore in
                    return (state, sequence_state, proved_state)
                | Some { app_state; sequence_state; proved_state; _ } ->
                    let state =
                      Snapp_state.V.map app_state ~f:(fun field ->
                          Quickcheck.random_value (Or_ignore.gen (return field)))
                    in
                    let%bind sequence_state =
                      (* choose a value from account sequence state *)
                      let fields =
                        Pickles_types.Vector.Vector_5.to_list sequence_state
                      in
                      let%bind ndx =
                        Int.gen_uniform_incl 0 (List.length fields - 1)
                      in
                      return (Or_ignore.Check (List.nth_exn fields ndx))
                    in
                    let proved_state = Or_ignore.Check proved_state in
                    return (state, sequence_state, proved_state)
              in
              return
                { Snapp_predicate.Account.Poly.balance
                ; nonce
                ; receipt_chain_hash
                ; public_key
                ; delegate
                ; state
                ; sequence_state
                ; proved_state
                }
            in
            if succeed then return (Party.Predicate.Full predicate_account)
            else
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
                      if Currency.Balance.equal balance Currency.Balance.zero
                      then Currency.Balance.max_int
                      else Currency.Balance.zero
                    in
                    let balance =
                      Or_ignore.Check
                        { Snapp_predicate.Closed_interval.lower = new_balance
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
                      Snapp_predicate.Numeric.gen (return new_nonce)
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
                      Snapp_state.V.to_list predicate_account.state
                      |> Array.of_list
                    in
                    let%bind ndx = Int.gen_incl 0 (Array.length fields - 1) in
                    let%bind field = Snark_params.Tick.Field.gen in
                    fields.(ndx) <- Or_ignore.Check field ;
                    let state =
                      Snapp_state.V.of_list_exn (Array.to_list fields)
                    in
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
              return (Party.Predicate.Full faulty_predicate_account)
          else
            (* Nonce *)
            let { Account.Poly.nonce; _ } = account in
            if succeed then return (Party.Predicate.Nonce nonce)
            else return (Party.Predicate.Nonce (Account.Nonce.succ nonce)) )

let gen_fee (account : Account.t) =
  let lo_fee = Mina_compile_config.minimum_user_command_fee in
  let hi_fee = Currency.(Amount.to_fee (Balance.to_amount account.balance)) in
  Currency.Fee.gen_incl lo_fee hi_fee

let fee_to_amt fee = Currency.Amount.(Signed.of_unsigned (of_fee fee))

let gen_balance_change ?balances_tbl (account : Account.t) =
  let open Quickcheck.Let_syntax in
  let pk = account.public_key in
  (* TODO: the authorization is Signature for new accounts only
     this will change when we split party's into two
  *)
  let authorization = Control.Tag.Signature in
  let%bind sgn =
    match authorization with
    | Control.Tag.None_given ->
        return Sgn.Pos
    | _ ->
        Quickcheck.Generator.of_list [ Sgn.Pos; Neg ]
  in
  match sgn with
  | Pos ->
      (* if positive, the account balance does not impose a constraint on the magnitude; but
         to avoid overflow over several Party.t, we'll limit the value
      *)
      let%map magnitude =
        Currency.Amount.gen_incl Currency.Amount.zero
          (Currency.Amount.of_int 100_000_000_000)
      in
      Currency.Signed_poly.{ magnitude; sgn = Sgn.Pos }
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
      Currency.Signed_poly.{ magnitude; sgn = Sgn.Neg }

let gen_use_full_commitment : bool Base_quickcheck.Generator.t =
  Bool.quickcheck_generator

(* The type `a` is associated with the `delta` field, which is an unsigned fee
   for the fee payer, and a signed amount for other parties.
   The type `b` is associated with the `use_full_commitment` field, which is
   `unit` for the fee payer, and `bool` for other parties.
*)
let gen_party_body (type a b) ?account_id ?balances_tbl ?(new_account = false)
    ?(snapp_account = false) ?(is_fee_payer = false) ?available_public_keys
    ?permissions_auth ?(required_balance_change : a option)
    ?(required_balance : Currency.Balance.t option)
    ~(gen_balance_change : Account.t -> a Quickcheck.Generator.t)
    ~(gen_use_full_commitment : b Quickcheck.Generator.t)
    ~(f_balance_change : a -> Currency.Amount.Signed.t) ~(increment_nonce : b)
    ~ledger () :
    (_, _, _, a, _, _, _, b, _) Party.Body.Poly.t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  (* ledger may contain non-Snapp accounts, so if we need a Snapp account,
     must generate a new one
  *)
  if snapp_account && not new_account then
    failwith "gen_party_body: snapp_account but not new_account" ;
  (* fee payers have to be in the ledger *)
  assert (not (is_fee_payer && new_account)) ;
  assert (
    Bool.equal
      (Option.is_some required_balance_change)
      (Option.is_some required_balance) ) ;
  let%bind update =
    Party.Update.gen ?permissions_auth ~snapp_account ~new_account ()
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
            if snapp_account then
              { account_with_pk with
                snapp =
                  Some
                    { Snapp_account.default with
                      verification_key =
                        Some
                          With_hash.
                            { data = Pickles.Side_loaded.Verification_key.dummy
                            ; hash = Snapp_account.dummy_vk_hash ()
                            }
                    }
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
          Ledger.get_at_index_exn ledger index
      | Some account_id -> (
          (* use given account from the ledger *)
          match Ledger.location_of_account ledger account_id with
          | None ->
              failwithf
                "gen_party_body: could not find account location for passed \
                 account id with public key %s and token id %s"
                (Signature_lib.Public_key.Compressed.to_base58_check
                   (Account_id.public_key account_id))
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
                       (Account_id.public_key account_id))
                    (Account_id.token_id account_id |> Token_id.to_string)
                    ()
              | Some acct ->
                  return acct ) )
  in
  let pk = account.public_key in
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
      Signature_lib.Public_key.Compressed.Table.change tbl pk ~f:(function
        | None ->
            (* new entry in table *)
            Some (add_balance_and_balance_change account.balance balance_change)
        | Some balance ->
            (* update entry in table *)
            Some (add_balance_and_balance_change balance balance_change)) ) ;
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
  (* update the depth when generating `other_parties` in Parties.t *)
  let call_depth = 0 in
  let protocol_state = Snapp_predicate.Protocol_state.accept in

  let%map use_full_commitment = gen_use_full_commitment in
  { Party.Body.Poly.pk
  ; update
  ; token_id
  ; balance_change
  ; increment_nonce
  ; events
  ; sequence_events
  ; call_data
  ; call_depth
  ; protocol_state
  ; use_full_commitment
  }

let gen_predicated_from ?(succeed = true) ?(new_account = false)
    ?(snapp_account = false) ?(increment_nonce = false) ?available_public_keys
    ?permissions_auth ?required_balance_change ?required_balance ~ledger
    ~balances_tbl =
  let open Quickcheck.Let_syntax in
  let%bind body =
    gen_party_body ~new_account ~snapp_account ~increment_nonce
      ?permissions_auth ?available_public_keys ?required_balance_change
      ?required_balance ~ledger ~balances_tbl
      ~gen_balance_change:(gen_balance_change ~balances_tbl)
      ~f_balance_change:Fn.id () ~gen_use_full_commitment
  in
  let account_id =
    Account_id.create body.Party.Body.Poly.pk body.Party.Body.Poly.token_id
  in
  let%map predicate = gen_predicate_from ~succeed ~account_id ~ledger () in
  Party.Predicated.Poly.{ body; predicate }

let gen_party_from ?(succeed = true) ?(new_account = false) ?permissions_auth
    ?required_balance_change ?required_balance ~available_public_keys ~ledger
    ~balances_tbl () =
  let open Quickcheck.Let_syntax in
  (* see TODO below about splitting a Party.t; we'll want to choose
     an authorization
  *)
  let authorization = Control.Signature Signature.dummy in
  let snapp_account =
    match authorization with
    | Control.Proof _ ->
        true
    | Signature _ | None_given ->
        false
  in
  let increment_nonce =
    match authorization with
    | Signature _ ->
        true
    | Proof _ | None_given ->
        false
  in
  (* if it's a Snapp account, generate a new account, since existing accounts in
     ledger may not be Snapp accounts
  *)
  let new_account = new_account || snapp_account in
  let%bind data =
    gen_predicated_from ?permissions_auth ?required_balance_change
      ?required_balance ~succeed ~new_account ~snapp_account ~increment_nonce
      ~available_public_keys ~ledger ~balances_tbl
  in
  return { Party.data; authorization }

(* takes an account id, if we want to sign this data *)
let gen_party_predicated_fee_payer ?permissions_auth ~account_id ~ledger :
    Party.Predicated.Fee_payer.t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let%map body0 =
    gen_party_body ?permissions_auth ~account_id ~is_fee_payer:true
      ~increment_nonce:() ~gen_balance_change:gen_fee
      ~f_balance_change:fee_to_amt ~gen_use_full_commitment:(return ()) ~ledger
      ()
  in
  (* make sure the fee payer's token id is the default,
     which is represented by the unit value in the body
  *)
  assert (Token_id.equal body0.token_id Token_id.default) ;
  let body = { body0 with token_id = () } in
  (* use nonce from account in ledger *)
  let pk = body.pk in
  let account_id = Account_id.create pk Token_id.default in
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
  let predicate = account.nonce in
  Party.Predicated.Poly.{ body; predicate }

let gen_fee_payer ?permissions_auth ~account_id ~ledger () :
    Party.Fee_payer.t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let%map data =
    gen_party_predicated_fee_payer ?permissions_auth ~account_id ~ledger
  in
  (* real signature to be added when this data inserted into a Parties.t *)
  let authorization = Signature.dummy in
  Party.Fee_payer.{ data; authorization }

let max_other_parties = 5

let gen_parties_from ?(succeed = true)
    ~(fee_payer_keypair : Signature_lib.Keypair.t)
    ~(keymap :
       Signature_lib.Private_key.t Signature_lib.Public_key.Compressed.Map.t)
    ~ledger () =
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
          ()) ;
  (* table of public keys not in the ledger, to be used for new parties
     we have the corresponding private keys, so we can create signatures for those new parties
  *)
  let available_public_keys =
    let tbl = Signature_lib.Public_key.Compressed.Table.create () in
    Signature_lib.Public_key.Compressed.Map.iter_keys keymap ~f:(fun pk ->
        let account_id = Account_id.create pk Token_id.default in
        if not (Account_id.Set.mem ledger_accounts account_id) then
          Signature_lib.Public_key.Compressed.Table.add_exn tbl ~key:pk ~data:()) ;
    tbl
  in
  let permissions_auth = Control.Tag.Signature in
  (* permissions_auth is Signature, for now, because permissions on new accounts are compatible with it
     TODO: split Party.ts into two:
     - the first sets permissions and vk using Signature authorization,
     - the second uses an authorization compatible with the new permissions
     N.B.: the given authorization constrains the generated permissions for the
      fee payer and other parties; those are not the permissions used
      when applying those parties, the existing permissions are used;
      instead, those generated permissions are used in later transactions
  *)
  let%bind fee_payer =
    gen_fee_payer ~permissions_auth ~account_id:fee_payer_account_id ~ledger ()
  in
  (* table of public keys to balances, updated when generating each party
     a Map would be more principled, but threading that map through the code
       adds complexity
  *)
  let balances_tbl = Signature_lib.Public_key.Compressed.Table.create () in
  let gen_parties_with_dynamic_balance ~new_parties num_parties =
    (* add fee payer account, in case same account used again *)
    let fee_payer_pk = fee_payer.data.body.pk in
    let fee_payer_balance =
      (* if we've done things right, all the options here are Some *)
      let fee =
        fee_payer.data.body.balance_change |> Currency.Fee.to_uint64
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
      if n <= 0 then return (List.rev acc)
      else
        let%bind party =
          gen_party_from ~permissions_auth ~new_account:new_parties
            ~available_public_keys ~succeed ~ledger ~balances_tbl ()
        in
        go (party :: acc) (n - 1)
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
        match Currency.Amount.Signed.add acc party.data.body.balance_change with
        | Some sum ->
            sum
        | None ->
            failwith "Overflow adding other parties balances")
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
          Currency.Amount.to_uint64 magnitude |> Currency.Balance.of_uint64
      | { sgn = Sgn.Pos; _ } ->
          (* we're adding to the account, so it can have a zero balance *)
          Currency.Balance.zero
    in
    gen_party_from ~permissions_auth ~new_account:true ~available_public_keys
      ~succeed ~ledger ~required_balance_change ~required_balance ~balances_tbl
      ()
  in
  let other_parties = balancing_party :: other_parties0 in
  let%bind memo = Signed_command_memo.gen in
  let memo_hash = Signed_command_memo.hash memo in
  let parties_dummy_signatures : Parties.t =
    { fee_payer; other_parties; memo }
  in
  (* replace dummy signature in fee payer *)
  let fee_payer_signature =
    Signature_lib.Schnorr.sign fee_payer_keypair.private_key
      (Random_oracle.Input.field
         ( Parties.commitment parties_dummy_signatures
         |> Parties.Transaction_commitment.with_fee_payer
              ~fee_payer_hash:
                (Party.Predicated.digest
                   (Party.Predicated.of_fee_payer
                      parties_dummy_signatures.fee_payer.data)) ))
  in
  let fee_payer_with_valid_signature =
    { parties_dummy_signatures.fee_payer with
      authorization = fee_payer_signature
    }
  in
  let other_parties_hash =
    Parties.Party_or_stack.With_hashes.other_parties_hash
      parties_dummy_signatures.other_parties
  in
  let protocol_state_predicate_hash =
    Snapp_predicate.Protocol_state.digest
      parties_dummy_signatures.fee_payer.data.body.protocol_state
  in
  let sign_for_other_party sk =
    Signature_lib.Schnorr.sign sk
      (Random_oracle.Input.field
         (Parties.Transaction_commitment.create ~memo_hash ~other_parties_hash
            ~protocol_state_predicate_hash))
  in
  (* replace dummy signatures in other parties *)
  let other_parties_with_valid_signatures =
    List.map parties_dummy_signatures.other_parties
      ~f:(fun { data; authorization } ->
        let authorization_with_valid_signature =
          match authorization with
          | Control.Signature _dummy ->
              let pk = data.body.pk in
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
              let signature = sign_for_other_party sk in
              Control.Signature signature
          | Proof _ | None_given ->
              authorization
        in
        { Party.data; authorization = authorization_with_valid_signature })
  in
  return
    { parties_dummy_signatures with
      fee_payer = fee_payer_with_valid_signature
    ; other_parties = other_parties_with_valid_signatures
    }
