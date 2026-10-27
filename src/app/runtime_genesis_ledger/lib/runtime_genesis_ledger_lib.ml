open Mina_base

let convert_account ~identity_conversion ~hardfork_slot (account : Account.t) :
    Account.t =
  if identity_conversion then account
  else
    match hardfork_slot with
    | None ->
        account
    | Some hardfork_slot ->
        Account.slot_reduction_update ~hardfork_slot account

let logger = Logger.create ()

let ledger_of_accounts ~depth accounts =
  let packed =
    Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts ~logger
      ~depth ~genesis_backing_type:Stable_db
      (lazy (Core_kernel.List.map accounts ~f:(fun account -> (None, account))))
  in
  Lazy.force (Genesis_ledger.Packed.t packed)

(* [expected_hash] is the [hash] the config gives for [accounts]: the root of
   the accounts as listed, before padding. A tool that rewrote account data on
   the way (e.g. jq replacing a non-UTF-8 token symbol with U+FFFD) makes it
   disagree, so a mismatch is fatal. Only an identity (Mesa -> Mesa) fork lists
   accounts in this binary's account format; the root of a Berkeley ledger
   cannot be recomputed here, so that case is not checked. *)
let load_ledger ~ignore_missing_fields ~pad_app_state ~identity_conversion
    ~hardfork_slot ~depth ~name ?expected_hash
    (accounts : Runtime_config.Accounts.t) =
  let open Core_kernel in
  let to_account ~pad_app_state =
    Runtime_config.Accounts.Single.to_account ~ignore_missing_fields
      ~pad_app_state
  in
  let converted =
    List.map accounts ~f:(fun account ->
        to_account ~pad_app_state account
        |> convert_account ~identity_conversion ~hardfork_slot )
  in
  let ledger = ledger_of_accounts ~depth converted in
  match expected_hash with
  | Some expected_hash when identity_conversion ->
      let open Or_error.Let_syntax in
      let%bind expected =
        Or_error.try_with (fun () ->
            Ledger_hash.of_base58_check_exn expected_hash )
        |> Or_error.tag ~tag:(sprintf "%s: invalid hash %s" name expected_hash)
      in
      let%bind actual =
        let%map source =
          Or_error.try_with (fun () ->
              List.map accounts ~f:(to_account ~pad_app_state:false) )
          |> Or_error.tag
               ~tag:(sprintf "%s: accounts are not in the target format" name)
        in
        Mina_ledger.Ledger.merkle_root
          ( if List.equal Account.equal source converted then ledger
          else ledger_of_accounts ~depth source )
      in
      if Ledger_hash.equal expected actual then Ok ledger
      else
        Or_error.errorf
          "%s: the config gives hash %s, but its accounts hash to %s; the \
           account data is not the source ledger"
          name expected_hash
          (Ledger_hash.to_base58_check actual)
  | Some _ | None ->
      Ok ledger

let%test_module "vesting conversion" =
  ( module struct
    let hardfork_slot = Mina_numbers.Global_slot_since_genesis.of_int 10

    (* A timed account whose cliff is in the future relative to [hardfork_slot]
       ("not yet vesting"), so it is actively vesting and
       [slot_reduction_update] is guaranteed to re-base its timing (doubling the
       vesting period and pushing the cliff). Balances are irrelevant to this
       branch, so they are left at zero. *)
    let timed_account =
      { Account.empty with
        timing =
          Account.Timing.Timed
            { initial_minimum_balance = Currency.Balance.zero
            ; cliff_time = Mina_numbers.Global_slot_since_genesis.of_int 100
            ; cliff_amount = Currency.Amount.zero
            ; vesting_period = Mina_numbers.Global_slot_span.of_int 10
            ; vesting_increment = Currency.Amount.zero
            }
      }

    let berkeley = Account.slot_reduction_update ~hardfork_slot timed_account

    (* Guards the rest of the suite: the Berkeley -> Mesa re-base must actually
       change this account, otherwise the identity-vs-berkeley assertions below
       would pass vacuously. *)
    let%test "slot_reduction_update is non-trivial on a vesting account" =
      not (Account.equal timed_account berkeley)

    (* Mesa -> Mesa: identity, even though a hardfork slot is supplied. *)
    let%test "identity conversion leaves the account untouched" =
      Account.equal timed_account
        (convert_account ~identity_conversion:true
           ~hardfork_slot:(Some hardfork_slot) timed_account )

    (* Berkeley -> Mesa: applies the slot-reduction re-base. *)
    let%test "berkeley conversion re-bases the account" =
      Account.equal berkeley
        (convert_account ~identity_conversion:false
           ~hardfork_slot:(Some hardfork_slot) timed_account )

    (* The flag actually matters for a vesting account. *)
    let%test "identity and berkeley results differ" =
      not
        (Account.equal
           (convert_account ~identity_conversion:true
              ~hardfork_slot:(Some hardfork_slot) timed_account )
           (convert_account ~identity_conversion:false
              ~hardfork_slot:(Some hardfork_slot) timed_account ) )

    (* Without a hardfork slot the (default) Berkeley path is already identity. *)
    let%test "no hardfork slot is identity" =
      Account.equal timed_account
        (convert_account ~identity_conversion:false ~hardfork_slot:None
           timed_account )
  end )

let%test_module "source ledger hash" =
  ( module struct
    open Core_kernel

    let depth = 10

    let pk () =
      Signature_lib.Public_key.compress
        (Signature_lib.Keypair.create ()).public_key

    (* Mainnet block 565083 sets this token symbol: one byte, not UTF-8. *)
    let account_with_symbol token_symbol =
      let account =
        Account.create
          (Account_id.create (pk ()) Token_id.default)
          (Currency.Balance.of_nanomina_int_exn 1_000)
      in
      { account with token_symbol }

    let accounts = [ account_with_symbol "\xff"; account_with_symbol "" ]

    let root accounts =
      Ledger_hash.to_base58_check
        (Mina_ledger.Ledger.merkle_root (ledger_of_accounts ~depth accounts))

    let config accounts =
      List.map accounts ~f:(fun a ->
          Runtime_config.Accounts.Single.of_account a |> Or_error.ok_exn )

    let load ?expected_hash ?(identity_conversion = true) ?hardfork_slot
        accounts =
      load_ledger ~ignore_missing_fields:false ~pad_app_state:false
        ~identity_conversion ~hardfork_slot ~depth ~name:"ledger" ?expected_hash
        accounts

    let%test "accounts that hash to the given hash load" =
      Or_error.is_ok (load ~expected_hash:(root accounts) (config accounts))

    let%test "a token symbol rewritten to U+FFFD is rejected" =
      let rewritten =
        List.map accounts ~f:(fun a ->
            if String.equal a.token_symbol "\xff" then
              { a with token_symbol = "\xef\xbf\xbd" }
            else a )
      in
      Or_error.is_error (load ~expected_hash:(root accounts) (config rewritten))

    let%test "without a hash nothing is checked" =
      Or_error.is_ok (load (config accounts))

    let%test "an invalid hash is rejected" =
      Or_error.is_error (load ~expected_hash:"not-a-hash" (config accounts))

    (* A Berkeley ledger's root cannot be recomputed by this binary. *)
    let%test "a Berkeley -> Mesa conversion is not checked" =
      Or_error.is_ok
        (load
           ~expected_hash:(root [ account_with_symbol "" ])
           ~identity_conversion:false
           ~hardfork_slot:(Mina_numbers.Global_slot_since_genesis.of_int 10)
           (config accounts) )

    (* Berkeley zkApp accounts have 8 state elements; only padding makes them
       Mesa accounts, so the unpadded list must not be built for them. *)
    let%test "a Berkeley zkApp account with a hash loads when padded" =
      let berkeley_zkapp =
        let single =
          Runtime_config.Accounts.Single.of_account
            { (account_with_symbol "") with zkapp = Some Zkapp_account.default }
          |> Or_error.ok_exn
        in
        { single with
          zkapp =
            Option.map single.zkapp ~f:(fun zkapp ->
                { zkapp with app_state = List.take zkapp.app_state 8 } )
        }
      in
      Or_error.is_ok
        (load_ledger ~ignore_missing_fields:false ~pad_app_state:true
           ~identity_conversion:false
           ~hardfork_slot:
             (Some (Mina_numbers.Global_slot_since_genesis.of_int 10))
           ~depth ~name:"ledger" ~expected_hash:(root accounts)
           [ berkeley_zkapp ] )
  end )
