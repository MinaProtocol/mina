open Core
open Signature_lib
open Mina_base

let () = Key_cache_native.linkme (* Ensure that we use the native key cache. *)

module Accounts = struct
  module Single = struct
    let to_account_with_pk :
        Runtime_config.Accounts.Single.t -> Mina_base.Account.t Or_error.t =
     fun t ->
      let open Or_error.Let_syntax in
      let pk = Signature_lib.Public_key.Compressed.of_base58_check_exn t.pk in
      let delegate =
        Option.map ~f:Signature_lib.Public_key.Compressed.of_base58_check_exn
          t.delegate
      in
      let token_id =
        Option.value_map t.token ~default:Token_id.default
          ~f:Mina_base.Token_id.of_string
      in
      let account_id = Mina_base.Account_id.create pk token_id in
      let account =
        match t.timing with
        | Some
            { initial_minimum_balance
            ; cliff_time
            ; cliff_amount
            ; vesting_period
            ; vesting_increment
            } ->
            Mina_base.Account.create_timed account_id t.balance
              ~initial_minimum_balance ~cliff_time ~cliff_amount ~vesting_period
              ~vesting_increment
            |> Or_error.ok_exn
        | None ->
            Mina_base.Account.create account_id t.balance
      in
      let permissions =
        match t.permissions with
        | None ->
            account.permissions
        | Some
            { edit_state
            ; send
            ; receive
            ; access
            ; set_delegate
            ; set_permissions
            ; set_verification_key
            ; set_zkapp_uri
            ; edit_action_state
            ; set_token_symbol
            ; increment_nonce
            ; set_voting_for
            ; set_timing
            } ->
            let auth_required a =
              match a with
              | Runtime_config.Accounts.Single.Permissions.Auth_required.None ->
                  Mina_base.Permissions.Auth_required.None
              | Either ->
                  Either
              | Proof ->
                  Proof
              | Signature ->
                  Signature
              | Impossible ->
                  Impossible
            in
            let verification_key_perm
                { Runtime_config.Accounts.Single.Permissions
                  .Verification_key_perm
                  .auth
                ; txn_version
                } =
              (auth_required auth, txn_version)
            in
            { Mina_base.Permissions.Poly.edit_state = auth_required edit_state
            ; access = auth_required access
            ; send = auth_required send
            ; receive = auth_required receive
            ; set_delegate = auth_required set_delegate
            ; set_permissions = auth_required set_permissions
            ; set_verification_key = verification_key_perm set_verification_key
            ; set_zkapp_uri = auth_required set_zkapp_uri
            ; edit_action_state = auth_required edit_action_state
            ; set_token_symbol = auth_required set_token_symbol
            ; increment_nonce = auth_required increment_nonce
            ; set_voting_for = auth_required set_voting_for
            ; set_timing = auth_required set_timing
            }
      in
      let%bind token_symbol =
        try
          let token_symbol =
            Option.value ~default:Mina_base.Account.Token_symbol.default
              t.token_symbol
          in
          Mina_base.Account.Token_symbol.check token_symbol ;
          return token_symbol
        with _ ->
          Or_error.errorf "Token symbol exceeds max length: %d > %d"
            (String.length (Option.value_exn t.token_symbol))
            Mina_base.Account.Token_symbol.max_length
      in
      let%map zkapp =
        match t.zkapp with
        | None ->
            Ok None
        | Some
            { app_state
            ; verification_key
            ; zkapp_version
            ; action_state
            ; last_action_slot
            ; proved_state
            ; zkapp_uri
            } ->
            let%bind () =
              let zkapp_uri_length = String.length zkapp_uri in
              if zkapp_uri_length > Zkapp_account.Zkapp_uri.max_length then
                Or_error.errorf "zkApp URI \"%s\" exceeds max length: %d > %d"
                  zkapp_uri zkapp_uri_length Zkapp_account.Zkapp_uri.max_length
              else Or_error.return ()
            in
            let%bind app_state =
              if
                Mina_stdlib.List.Length.Compare.(
                  app_state
                  = Pickles_types.Nat.to_int Zkapp_state.Max_state_size.n)
              then Ok (Zkapp_state.V.of_list_exn app_state)
              else
                Or_error.errorf
                  !"Snap account state has invalid length %{sexp: \
                    Runtime_config.Accounts.Single.t} length: %d"
                  t (List.length app_state)
            in

            let verification_key =
              Option.map verification_key
                ~f:(With_hash.of_data ~hash_data:Zkapp_account.digest_vk)
            in
            let%map action_state =
              if
                Mina_stdlib.List.Length.Compare.(
                  action_state = Pickles_types.Nat.to_int Pickles_types.Nat.N5.n)
              then Ok (Pickles_types.Vector.Vector_5.of_list_exn action_state)
              else
                Or_error.errorf
                  !"zkApp account action_state has invalid length %{sexp: \
                    Runtime_config.Accounts.Single.t} length: %d"
                  t (List.length action_state)
            in

            let last_action_slot =
              Mina_numbers.Global_slot_since_genesis.of_int last_action_slot
            in
            Some
              { Zkapp_account.verification_key
              ; app_state
              ; zkapp_version
              ; action_state
              ; last_action_slot
              ; proved_state
              ; zkapp_uri
              }
      in
      ( { public_key = account.public_key
        ; balance = account.balance
        ; timing = account.timing
        ; token_symbol
        ; delegate =
            (if Option.is_some delegate then delegate else account.delegate)
        ; token_id
        ; nonce = Account.Nonce.of_uint32 t.nonce
        ; receipt_chain_hash =
            Option.value_map t.receipt_chain_hash
              ~default:account.receipt_chain_hash
              ~f:Mina_base.Receipt.Chain_hash.of_base58_check_exn
        ; voting_for =
            Option.value_map ~default:account.voting_for
              ~f:Mina_base.State_hash.of_base58_check_exn t.voting_for
        ; zkapp
        ; permissions
        }
        : Mina_base.Account.t )

    let of_account :
           Mina_base.Account.t
        -> Signature_lib.Private_key.t option
        -> Runtime_config.Accounts.Single.t =
     fun account sk ->
      let timing =
        match account.timing with
        | Account.Timing.Untimed ->
            None
        | Timed t ->
            Some
              { Runtime_config.Accounts.Single.Timed.initial_minimum_balance =
                  t.initial_minimum_balance
              ; cliff_time = t.cliff_time
              ; cliff_amount = t.cliff_amount
              ; vesting_period = t.vesting_period
              ; vesting_increment = t.vesting_increment
              }
      in
      let permissions =
        let auth_required a =
          match a with
          | Mina_base.Permissions.Auth_required.None ->
              Runtime_config.Accounts.Single.Permissions.Auth_required.None
          | Either ->
              Either
          | Proof ->
              Proof
          | Signature ->
              Signature
          | Impossible ->
              Impossible
        in
        let { Mina_base.Permissions.Poly.edit_state
            ; send
            ; receive
            ; access
            ; set_delegate
            ; set_permissions
            ; set_verification_key
            ; set_zkapp_uri
            ; edit_action_state
            ; set_token_symbol
            ; increment_nonce
            ; set_voting_for
            ; set_timing
            } =
          account.permissions
        in
        let verification_key_perm (auth, txn_version) =
          { Runtime_config.Accounts.Single.Permissions.Verification_key_perm
            .auth = auth_required auth
          ; txn_version
          }
        in
        Some
          { Runtime_config.Accounts.Single.Permissions.edit_state =
              auth_required edit_state
          ; send = auth_required send
          ; receive = auth_required receive
          ; access = auth_required access
          ; set_delegate = auth_required set_delegate
          ; set_permissions = auth_required set_permissions
          ; set_verification_key = verification_key_perm set_verification_key
          ; set_zkapp_uri = auth_required set_zkapp_uri
          ; edit_action_state = auth_required edit_action_state
          ; set_token_symbol = auth_required set_token_symbol
          ; increment_nonce = auth_required increment_nonce
          ; set_voting_for = auth_required set_voting_for
          ; set_timing = auth_required set_timing
          }
      in
      let zkapp =
        Option.map account.zkapp
          ~f:(fun
               { app_state
               ; verification_key
               ; zkapp_version
               ; action_state
               ; last_action_slot
               ; proved_state
               ; zkapp_uri
               }
             ->
            let app_state = Zkapp_state.V.to_list app_state in
            let verification_key =
              Option.map verification_key ~f:With_hash.data
            in
            let action_state = Pickles_types.Vector.to_list action_state in
            let last_action_slot =
              Mina_numbers.Global_slot_since_genesis.to_int last_action_slot
            in
            { Runtime_config.Accounts.Single.Zkapp_account.app_state
            ; verification_key
            ; zkapp_version
            ; action_state
            ; last_action_slot
            ; proved_state
            ; zkapp_uri
            } )
      in
      { pk =
          Signature_lib.Public_key.Compressed.to_base58_check account.public_key
      ; sk = Option.map ~f:Signature_lib.Private_key.to_base58_check sk
      ; balance = account.balance
      ; delegate =
          Option.map ~f:Signature_lib.Public_key.Compressed.to_base58_check
            account.delegate
      ; timing
      ; token = Some (Mina_base.Token_id.to_string account.token_id)
      ; nonce = account.nonce
      ; receipt_chain_hash =
          Some
            (Mina_base.Receipt.Chain_hash.to_base58_check
               account.receipt_chain_hash )
      ; voting_for =
          Some (Mina_base.State_hash.to_base58_check account.voting_for)
      ; zkapp
      ; permissions
      ; token_symbol = Some account.token_symbol
      }
  end

  let to_full :
      Runtime_config.Accounts.t -> (Private_key.t option * Account.t) list =
    List.map
      ~f:(fun ({ Runtime_config.Accounts.pk; sk; _ } as account_config) ->
        let sk =
          match sk with
          | Some sk -> (
              match Private_key.of_yojson (`String sk) with
              | Ok sk ->
                  Some sk
              | Error err ->
                  Error.(raise (of_string err)) )
          | None ->
              None
        in
        let account =
          Single.to_account_with_pk { account_config with pk }
          |> Or_error.ok_exn
        in
        (sk, account) )

  let gen_with_balance balance :
      (Private_key.t option * Account.t) Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%map pk = Signature_lib.Public_key.Compressed.gen in
    (None, Account.create (Account_id.create pk Token_id.default) balance)

  let gen : (Private_key.t option * Account.t) Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%bind balance =
      Int.gen_incl 10 500 >>| Currency.Balance.of_nanomina_int_exn
    in
    gen_with_balance balance

  let generate n : (Private_key.t option * Account.t) list =
    let open Quickcheck in
    random_value ~seed:(`Deterministic "fake accounts for genesis ledger")
      (Generator.list_with_length n gen)

  (* This implements a tail-recursive generator using the low-level primitives
     so that we don't blow out the stack.
  *)
  let gen_balances_rev balances :
      (Private_key.t option * Account.t) list Quickcheck.Generator.t =
    match balances with
    | [] ->
        Quickcheck.Generator.return []
    | (n, balance) :: balances_tl ->
        Quickcheck.Generator.create (fun ~size ~random ->
            let rec gen_balances_rev n balance balances_tl accounts =
              if n > 0 then
                let new_random = Splittable_random.State.split random in
                let account =
                  (* Manually generate an account using the [generate] primitive. *)
                  Quickcheck.Generator.generate ~size ~random:new_random
                    (gen_with_balance balance)
                in
                gen_balances_rev (n - 1) balance balances_tl
                  (account :: accounts)
              else
                match balances_tl with
                | [] ->
                    accounts
                | (n, balance) :: balances_tl ->
                    gen_balances_rev n balance balances_tl accounts
            in
            gen_balances_rev n balance balances_tl [] )

  let pad_with_rev_balances balances accounts =
    let balances_accounts =
      Quickcheck.random_value
        ~seed:(`Deterministic "fake accounts with balances for genesis ledger")
        (gen_balances_rev balances)
    in
    List.append accounts balances_accounts

  (* NOTE: When modifying this function, be very careful to ensure that all
     operations are tail-recursive, otherwise a sufficiently large genesis
     ledger will blow the stack.
     In particular, do not use any functions that return values of the form
     [_ :: _], since this construction is NOT tail-recursive.
  *)
  let pad_to n accounts =
    if n <= 0 then accounts
    else
      let exception Stop in
      try
        (* Count accounts and reverse the list while we're doing so to avoid
           re-traversing the list.
        *)
        let rev_accounts, count =
          List.fold ~init:([], 0) accounts ~f:(fun (acc, count) account ->
              let count = count + 1 in
              if count >= n then raise Stop ;
              (account :: acc, count + 1) )
        in
        (* [rev_append] is tail-recursive, and we've already reversed the list,
           so we can avoid calling [append] which may internally reverse the
           list again where it is sufficiently long.
        *)
        List.rev_append rev_accounts (generate (n - count))
      with Stop -> accounts
end

let%test_module "Runtime config" =
  ( module struct
    [@@@warning "-32"]

    let logger = Logger.null ()

    let pk = "B62qk8p3nBVdtVRVsBGiSanoHBV8KrSGv4Gnxbm2jtj6xrvhFqa5SqU"

    let non_zkapp_ledger =
      (* only required fields are `pk and `balance` *)
      let s =
        sprintf
          {json| {"accounts": [ { "pk": "%s",
                                  "balance": "42.999999999"
                                }
                              ]
                 }
          |json}
          pk
      in
      let json = Yojson.Safe.from_string s in
      Runtime_config.Ledger.of_yojson json |> Result.ok_or_failwith

    let nondefault_token =
      let owner =
        Account_id.create
          (Signature_lib.Public_key.Compressed.of_base58_check_exn pk)
          Token_id.default
      in
      Account_id.derive_token_id ~owner

    let non_zkapp_ledger_nondefault_token =
      (* only required fields are `pk and `balance` *)
      let token_id = Token_id.to_string nondefault_token in
      let s =
        sprintf
          {json| {"accounts": [ { "pk": "%s",
                                  "balance": "1023.893",
                                  "token": "%s"
                                }
                              ]
                 }
          |json}
          pk token_id
      in
      let json = Yojson.Safe.from_string s in
      Runtime_config.Ledger.of_yojson json |> Result.ok_or_failwith

    let zkapp_ledger =
      (* in zkApp account, all fields are required *)
      let s =
        sprintf
          {json| {"accounts": [ { "pk": "%s",
                                  "balance": "1087.37",
                                  "zkapp": { "app_state": [ "14", "0", "0", "0", "0", "0", "0", "0" ],
                                             "verification_key": null,
                                             "zkapp_version": "0",
                                             "action_state": [ "0", "0", "0", "0", "0" ],
                                             "last_action_slot": 0,
                                             "proved_state": false,
                                             "zkapp_uri": "http://zkapps_r_us.com"
                                           }
                                }
                              ]
                 }
          |json}
          pk
      in
      let json = Yojson.Safe.from_string s in
      Runtime_config.Ledger.of_yojson json |> Result.ok_or_failwith

    (* omitted account fields in runtime config same as those given by `Account.create` on same public key *)
    let%test_unit "non-zkApp ledger" =
      let runtime_accounts =
        match non_zkapp_ledger.base with
        | Runtime_config.Ledger.Accounts accts ->
            accts
        | _ ->
            failwith "Expected accounts in ledger"
      in
      let accounts =
        Accounts.to_full runtime_accounts
        |> List.map ~f:(fun (_sk, account) -> account)
      in
      assert (List.length accounts = 1) ;
      let account = List.hd_exn accounts in
      let test_account =
        let account_id =
          Mina_base.Account_id.create
            (Public_key.Compressed.of_base58_check_exn pk)
            Token_id.default
        in
        (* balance not the same as in the runtime config; it's required there, so not testing that *)
        let balance = Currency.Balance.of_mina_int_exn 5_000 in
        Mina_base.Account.create account_id balance
      in
      (* test field-by-field, to track down any errors *)
      assert (
        Public_key.Compressed.equal account.public_key test_account.public_key ) ;
      assert (Token_id.equal account.token_id test_account.token_id) ;
      assert (
        Account.Token_symbol.equal account.token_symbol
          test_account.token_symbol ) ;
      assert (Account.Nonce.equal account.nonce test_account.nonce) ;
      assert (
        Receipt.Chain_hash.equal account.receipt_chain_hash
          test_account.receipt_chain_hash ) ;
      assert (Option.is_some account.delegate) ;
      assert (
        Option.equal Public_key.Compressed.equal account.delegate
          test_account.delegate ) ;
      assert (State_hash.equal account.voting_for test_account.voting_for) ;
      assert (Account.Timing.equal account.timing test_account.timing) ;
      assert (Permissions.equal account.permissions test_account.permissions) ;
      assert (Option.equal Zkapp_account.equal account.zkapp test_account.zkapp)

    (* if nondefault token, no delegate created from runtime config *)
    let%test_unit "non-zkApp ledger, nondefault token" =
      let runtime_accounts =
        match non_zkapp_ledger_nondefault_token.base with
        | Runtime_config.Ledger.Accounts accts ->
            accts
        | _ ->
            failwith "Expected accounts in ledger"
      in
      let accounts =
        Accounts.to_full runtime_accounts
        |> List.map ~f:(fun (_sk, account) -> account)
      in
      assert (List.length accounts = 1) ;
      let account = List.hd_exn accounts in
      let test_account =
        let account_id =
          Mina_base.Account_id.create
            (Public_key.Compressed.of_base58_check_exn pk)
            nondefault_token
        in
        let balance = Currency.Balance.of_mina_int_exn 49_000_000 in
        Mina_base.Account.create account_id balance
      in
      assert (Option.is_none test_account.delegate) ;
      assert (Option.is_none account.delegate)

    (* zkApp account fields in runtime config are all required, but we can make verification key `null` *)
    let%test_unit "zkApp ledger" =
      let runtime_accounts =
        match zkapp_ledger.base with
        | Runtime_config.Ledger.Accounts accts ->
            accts
        | _ ->
            failwith "Expected accounts in ledger"
      in
      let accounts =
        Accounts.to_full runtime_accounts
        |> List.map ~f:(fun (_sk, account) -> account)
      in
      assert (List.length accounts = 1) ;
      let account = List.hd_exn accounts in
      let default = Mina_base.Zkapp_account.default in
      let zkapp_account =
        match account.zkapp with
        | None ->
            failwith "Expected zkApp account in account"
        | Some zkapp ->
            zkapp
      in
      assert (
        Option.equal Verification_key_wire.equal zkapp_account.verification_key
          default.verification_key )
  end )
