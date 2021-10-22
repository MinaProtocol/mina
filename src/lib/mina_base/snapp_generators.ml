open Mina_base_base

(* snapp_generators -- Quickcheck generators for Snapp transactions *)

(* Ledger depends on Party, so Party generators can't refer back to Ledger
   so we put the generators that rely on Ledger and Party here
*)

open Core_kernel

let gen_predicate_from ?(succeed = true) ~pk ~ledger =
  (* construct predicate using pk and ledger
     don't return Accept, which would ignore those inputs
  *)
  let open Quickcheck.Let_syntax in
  let acct_id = Account_id.create pk Token_id.default in
  match Ledger.location_of_account ledger acct_id with
  | None ->
      (* account not in the ledger, can't create a meaningful Full or Nonce *)
      if succeed then
        failwithf "gen_from: account with public key %s not in ledger"
          (Signature_lib.Public_key.Compressed.to_base58_check pk)
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
                let%bind delta_int = Int.gen_uniform_incl 1 10_000_000 in
                let delta = Currency.Amount.of_int delta_int in
                let lower =
                  match Currency.Balance.sub_amount balance delta with
                  | None ->
                      Currency.Balance.zero
                  | Some bal ->
                      bal
                in
                let upper =
                  match Currency.Balance.add_amount balance delta with
                  | None ->
                      Currency.Balance.max_int
                  | Some bal ->
                      bal
                in
                Or_ignore.gen
                  (return { Snapp_predicate.Closed_interval.lower; upper })
              in
              let%bind nonce =
                let%bind delta_int = Int.gen_uniform_incl 1 100 in
                let delta = Account.Nonce.of_int delta_int in
                let lower =
                  match Account.Nonce.sub nonce delta with
                  | None ->
                      Account.Nonce.zero
                  | Some nonce ->
                      nonce
                in
                let upper =
                  (* Nonce.add doesn't check for overflow, so check here *)
                  match Account.Nonce.(sub max_value) delta with
                  | None ->
                      (* unreachable *)
                      failwith
                        "gen_predicate_from: nonce subtraction failed \
                         unexpectedly"
                  | Some n ->
                      if Account.Nonce.( < ) n nonce then
                        Account.Nonce.max_value
                      else Account.Nonce.add nonce delta
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
              let%bind state, rollup_state, proved_state =
                match snapp with
                | None ->
                    (* won't raise, correct length given *)
                    let state =
                      Snapp_state.V.of_list_exn
                        (List.init 8 ~f:(fun _ -> Or_ignore.Ignore))
                    in
                    let rollup_state = Or_ignore.Ignore in
                    let proved_state = Or_ignore.Ignore in
                    return (state, rollup_state, proved_state)
                | Some { app_state; rollup_state; proved_state; _ } ->
                    let state =
                      Snapp_state.V.map app_state ~f:(fun field ->
                          Quickcheck.random_value (Or_ignore.gen (return field)))
                    in
                    let%bind rollup_state =
                      (* choose a value from account rollup state *)
                      let fields =
                        Pickles_types.Vector.Vector_5.to_list rollup_state
                      in
                      let%bind ndx =
                        Int.gen_uniform_incl 0 (List.length fields - 1)
                      in
                      return (Or_ignore.Check (List.nth_exn fields ndx))
                    in
                    let proved_state = Or_ignore.Check proved_state in
                    return (state, rollup_state, proved_state)
              in
              return
                { Snapp_predicate.Account.Poly.balance
                ; nonce
                ; receipt_chain_hash
                ; public_key
                ; delegate
                ; state
                ; rollup_state
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
                  | Rollup_state
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
                  ; Rollup_state
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
                | Rollup_state ->
                    let%bind field = Snark_params.Tick.Field.gen in
                    let rollup_state = Or_ignore.Check field in
                    return { predicate_account with rollup_state }
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

let gen_party_body ?pk ?balances_tbl ?(new_party = false) ~ledger () :
    Party.Body.t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let%bind update = Party.Update.gen ~new_party () in
  let%bind token_id = Token_id.gen in
  let%bind account =
    if new_party then (
      if Option.is_some pk then
        failwith
          "gen_party_body: new party is true, but a public key, presumably \
           from an existing account, was supplied" ;
      Account.gen )
    else
      match pk with
      | None ->
          (* choose an account from the ledger *)
          let%map index =
            Int.gen_uniform_incl 0 (Ledger.num_accounts ledger - 1)
          in
          Ledger.get_at_index_exn ledger index
      | Some pk -> (
          (* use given account from the ledger *)
          let account_id = Account_id.create pk Token_id.default in
          match Ledger.location_of_account ledger account_id with
          | None ->
              failwithf
                "gen_party_body: could not find account location for passed \
                 public key %s"
                (Signature_lib.Public_key.Compressed.to_base58_check pk)
                ()
          | Some location -> (
              match Ledger.get ledger location with
              | None ->
                  (* should be unreachable *)
                  failwithf
                    "gen_party_body: could not find account for passed public \
                     key %s"
                    (Signature_lib.Public_key.Compressed.to_base58_check pk)
                    ()
              | Some acct ->
                  return acct ) )
  in
  let pk = account.public_key in
  let%bind delta =
    match%bind Quickcheck.Generator.of_list [ Sgn.Pos; Neg ] with
    | Pos ->
        (* if positive, the account balance does not impose a constraint on the magnitude; but
           to avoid overflow over several Party.t, we'll limit the value
        *)
        let%map magnitude =
          Currency.Amount.gen_incl Currency.Amount.zero
            (Currency.Amount.of_int 100_000_000_000_000)
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
  in
  (* update balances table, if provided, with generated delta *)
  ( match balances_tbl with
  | None ->
      ()
  | Some tbl ->
      let add_balance_and_delta balance
          (delta : (Currency.Amount.t, Sgn.t) Currency.Signed_poly.t) =
        match delta.sgn with
        | Pos -> (
            match Currency.Balance.add_amount balance delta.magnitude with
            | Some bal ->
                bal
            | None ->
                failwith "add_balance_and_delta: overflow for sum" )
        | Neg -> (
            match Currency.Balance.sub_amount balance delta.magnitude with
            | Some bal ->
                bal
            | None ->
                failwith "add_balance_and_delta: underflow for difference" )
      in
      Signature_lib.Public_key.Compressed.Table.change tbl pk ~f:(function
        | None ->
            (* new entry in table *)
            Some (add_balance_and_delta account.balance delta)
        | Some balance ->
            (* update entry in table *)
            Some (add_balance_and_delta balance delta)) ) ;
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
  let%bind rollup_events =
    field_array_list_gen ~max_array_len:4 ~max_list_len:6
  in
  let%map call_data = Snark_params.Tick.Field.gen in
  (* update the depth when generating `other_parties` in Parties.t *)
  let depth = 0 in
  { Party.Body.Poly.pk
  ; update
  ; token_id
  ; delta
  ; events
  ; rollup_events
  ; call_data
  ; depth
  }

let gen_predicated_from ?(succeed = true) ?(new_party = false) ~ledger
    ~balances_tbl =
  let open Quickcheck.Let_syntax in
  let%bind body = gen_party_body ~new_party ~ledger ~balances_tbl () in
  let pk = body.Party.Body.Poly.pk in
  let%map predicate = gen_predicate_from ~succeed ~pk ~ledger in
  Party.Predicated.Poly.{ body; predicate }

let gen_party_from ?(succeed = true) ?(new_party = false) ~ledger ~balances_tbl
    =
  let open Quickcheck.Let_syntax in
  let%bind data =
    gen_predicated_from ~succeed ~new_party ~ledger ~balances_tbl
  in
  let%map authorization = Lazy.force Control.gen_with_dummies in
  { Party.data; authorization }

(* takes an optional public key, if we want to sign this data *)
let gen_party_predicated_signed ?pk ~ledger :
    Party.Predicated.Signed.t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let%bind body = gen_party_body ?pk ~ledger () in
  let%map predicate = Account.Nonce.gen in
  Party.Predicated.Poly.{ body; predicate }

let gen_party_signed ?pk ~ledger : Party.Signed.t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let%map data = gen_party_predicated_signed ?pk ~ledger in
  (* real signature to be added when this data inserted into a Parties.t *)
  let authorization = Signature.dummy in
  Party.Signed.{ data; authorization }

let gen_parties_from ?(succeed = true) ~(keypair : Signature_lib.Keypair.t)
    ~ledger ~protocol_state =
  let max_parties = 6 in
  let open Quickcheck.Let_syntax in
  let pk = Signature_lib.Public_key.compress keypair.public_key in
  let%bind fee_payer = gen_party_signed ~pk ~ledger in
  let gen_parties_with_dynamic_balance ~new_parties num_parties =
    (* table of public keys to balances, updated when generating each party
       a Map would be more principled, but threading that map through the code adds complexity
    *)
    let balances_tbl = Signature_lib.Public_key.Compressed.Table.create () in
    let rec go acc n =
      if n <= 0 then return (List.rev acc)
      else
        let%bind party =
          gen_party_from ~new_party:new_parties ~succeed ~ledger ~balances_tbl
        in
        go (party :: acc) (n - 1)
    in
    go [] num_parties
  in
  (* at least 1 party, so that `succeed` affects at least one predicate *)
  let%bind num_parties = Int.gen_uniform_incl 1 max_parties in
  let%bind num_new_parties = Int.gen_uniform_incl 0 num_parties in
  let num_old_parties = num_parties - num_new_parties in
  let%bind old_parties =
    gen_parties_with_dynamic_balance ~new_parties:false num_old_parties
  in
  let%bind new_parties =
    gen_parties_with_dynamic_balance ~new_parties:true num_new_parties
  in
  let other_parties = old_parties @ new_parties in
  let parties : Parties.t = { fee_payer; other_parties; protocol_state } in
  (* replace dummy signature in fee payer *)
  let signature =
    Signature_lib.Schnorr.sign keypair.private_key
      (Random_oracle.Input.field
         ( Parties.commitment parties
         |> Parties.Transaction_commitment.with_fee_payer
              ~fee_payer_hash:
                (Party.Predicated.digest
                   (Party.Predicated.of_signed parties.fee_payer.data)) ))
  in
  return
    { parties with
      fee_payer = { parties.fee_payer with authorization = signature }
    }
