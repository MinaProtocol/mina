open Core
open Signature_lib
open Mina_base
module U = Transaction_snark_tests.Util

let logger = Logger.create ()

let mk_ledgers_and_fee_payers ?(is_timed = false) ~num_of_fee_payers () =
  let fee_payer_keypairs =
    Array.init (num_of_fee_payers * 2) ~f:(fun _ -> Keypair.create ())
  in
  let fee_payer_pks =
    Array.map fee_payer_keypairs ~f:(fun fee_payer_keypair ->
        Public_key.compress fee_payer_keypair.public_key )
  in
  let fee_payer_account_ids =
    Array.map fee_payer_pks ~f:(fun fee_payer_pk ->
        Account_id.create fee_payer_pk Token_id.default )
  in
  let (initial_balance : Currency.Balance.t) =
    Currency.Balance.of_int 1_000_000_000_000_000
  in
  let (fee_payer_accounts : Account.t array) =
    if is_timed then
      let initial_minimum_balance =
        Currency.Balance.of_int 1_000_000_000_000_000
      in
      let cliff_time = Mina_numbers.Global_slot.of_int 1_000 in
      let cliff_amount = Currency.Amount.zero in
      let vesting_period = Mina_numbers.Global_slot.of_int 10 in
      let vesting_increment = Currency.Amount.of_int 100_000_000_000 in
      Array.map fee_payer_account_ids ~f:(fun fee_payer_account_id ->
          Account.create_timed fee_payer_account_id initial_balance
            ~initial_minimum_balance ~cliff_time ~cliff_amount ~vesting_period
            ~vesting_increment
          |> Or_error.ok_exn )
    else
      Array.map fee_payer_account_ids ~f:(fun fee_payer_account_id ->
          Account.create fee_payer_account_id initial_balance )
  in
  let ledger = Mina_ledger.Ledger.create ~depth:10 () in
  Array.iter2_exn fee_payer_accounts fee_payer_account_ids
    ~f:(fun fee_payer_account fee_payer_account_id ->
      Mina_ledger.Ledger.get_or_create_account ledger fee_payer_account_id
        fee_payer_account
      |> Or_error.ok_exn
      |> fun _ -> () ) ;
  let keys = List.init 1000 ~f:(fun _ -> Keypair.create ()) in
  let keymap =
    List.map
      (List.drop (Array.to_list fee_payer_keypairs) num_of_fee_payers @ keys)
      ~f:(fun { public_key; private_key } ->
        (Public_key.compress public_key, private_key) )
    |> Public_key.Compressed.Map.of_alist_exn
  in
  (ledger, fee_payer_keypairs, keymap)

let `VK vk, `Prover prover = Lazy.force U.trivial_zkapp

let generate_parties_and_apply_them_consecutively () =
  let num_of_fee_payers = 5 in
  let trials = 6 in
  let ledger, _fee_payer_keypairs, keymap =
    mk_ledgers_and_fee_payers ~num_of_fee_payers ()
  in
  let account_state_tbl = Account_id.Table.create () in
  Test_util.with_randomness 123456789 (fun () ->
      let test _i =
        Quickcheck.test ~trials:1
          (Mina_generators.Parties_generators.gen_parties_with_limited_keys
             ~protocol_state_view:U.genesis_state_view ~keymap ~ledger ~vk
             ~prover ~account_state_tbl () ) ~f:(fun parties ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                [%log info]
                  ~metadata:
                    [ ("parties", Parties.to_yojson parties)
                    ; ( "accounts"
                      , `List
                          (List.map
                             (Mina_ledger.Ledger.accounts ledger |> Set.to_list)
                             ~f:(fun account_id ->
                               Mina_ledger.Ledger.location_of_account ledger
                                 account_id
                               |> Option.value_exn
                               |> Mina_ledger.Ledger.get ledger
                               |> Option.value_exn |> Account.to_yojson ) ) )
                    ]
                  "generated parties" ;
                U.check_parties_with_merges_exn ledger [ parties ] ) )
      in
      for i = 0 to trials - 1 do
        test i
      done )

let generate_parties_and_apply_them_freshly () =
  let num_of_fee_payers = 5 in
  let trials = 6 in
  Test_util.with_randomness 123456789 (fun () ->
      let test _i =
        let ledger, _fee_payer_keypairs, keymap =
          mk_ledgers_and_fee_payers ~num_of_fee_payers ()
        in
        Quickcheck.test ~trials:1
          (Mina_generators.Parties_generators.gen_parties_with_limited_keys
             ~protocol_state_view:U.genesis_state_view ~keymap ~ledger ~vk
             ~prover () ) ~f:(fun parties ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                U.check_parties_with_merges_exn ledger [ parties ] ) )
      in
      for i = 0 to trials - 1 do
        test i
      done )

let mk_invalid_test ~num_of_fee_payers ~trials ~type_of_failure
    ~expected_failure_status =
  Test_util.with_randomness 123456789 (fun () ->
      let test _i =
        let ledger, _fee_payer_keypairs, keymap =
          mk_ledgers_and_fee_payers ~num_of_fee_payers ()
        in
        Quickcheck.test ~trials:1
          (Mina_generators.Parties_generators.gen_parties_with_limited_keys
             ~failure:type_of_failure ~protocol_state_view:U.genesis_state_view
             ~keymap ~ledger ~vk ~prover () ) ~f:(fun parties ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                [%log info]
                  ~metadata:[ ("parties", Parties.to_yojson parties) ]
                  "generated parties" ;
                U.check_parties_with_merges_exn
                  ~expected_failure:expected_failure_status ledger [ parties ]
                  ~state_body:U.genesis_state_body ) )
      in
      for i = 0 to trials - 1 do
        test i
      done )

let test_timed_account () =
  let num_of_fee_payers = 5 in
  let trials = 1 in
  Test_util.with_randomness 123456789 (fun () ->
      let test _i =
        let ledger, _fee_payer_keypairs, keymap =
          mk_ledgers_and_fee_payers ~is_timed:true ~num_of_fee_payers ()
        in
        Quickcheck.test ~trials:1
          (Mina_generators.Parties_generators.gen_parties_with_limited_keys
             ~protocol_state_view:U.genesis_state_view ~keymap ~ledger ~vk
             ~prover () ) ~f:(fun parties ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                [%log info]
                  ~metadata:[ ("parties", Parties.to_yojson parties) ]
                  "generated parties" ;
                U.check_parties_with_merges_exn
                  ~expected_failure:
                    Transaction_status.Failure.Source_minimum_balance_violation
                  ledger [ parties ] ~state_body:U.genesis_state_body ) )
      in
      for i = 0 to trials - 1 do
        test i
      done )

let () =
  let num_of_fee_payers = 5 in
  let trials = 2 in
  generate_parties_and_apply_them_consecutively () ;
  generate_parties_and_apply_them_freshly () ;
  let open Mina_generators.Parties_generators in
  let open Transaction_status.Failure in
  mk_invalid_test ~num_of_fee_payers ~trials
    ~type_of_failure:Invalid_protocol_state_precondition
    ~expected_failure_status:Protocol_state_precondition_unsatisfied ;
  mk_invalid_test ~num_of_fee_payers ~trials
    ~type_of_failure:(Update_not_permitted `App_state)
    ~expected_failure_status:Update_not_permitted_app_state ;
  mk_invalid_test ~num_of_fee_payers ~trials
    ~type_of_failure:(Update_not_permitted `Verification_key)
    ~expected_failure_status:Update_not_permitted_verification_key ;
  mk_invalid_test ~num_of_fee_payers ~trials
    ~type_of_failure:(Update_not_permitted `Zkapp_uri)
    ~expected_failure_status:Update_not_permitted_zkapp_uri ;
  mk_invalid_test ~num_of_fee_payers ~trials
    ~type_of_failure:(Update_not_permitted `Token_symbol)
    ~expected_failure_status:Update_not_permitted_token_symbol ;
  mk_invalid_test ~num_of_fee_payers ~trials
    ~type_of_failure:(Update_not_permitted `Voting_for)
    ~expected_failure_status:Update_not_permitted_voting_for ;
  mk_invalid_test ~num_of_fee_payers ~trials
    ~type_of_failure:(Update_not_permitted `Balance)
    ~expected_failure_status:Update_not_permitted_balance ;
  test_timed_account ()
