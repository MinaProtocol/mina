open Core
open Async
open Signature_lib
open Mina_base
module U = Transaction_snark_tests.Util

let logger = Logger.create ()

let `VK vk, `Prover prover = Lazy.force U.trivial_zkapp

let vk = Async.Thread_safe.block_on_async_exn (fun () -> vk)

let mk_ledgers_and_fee_payers ?(is_timed = false) ~num_of_fee_payers () =
  let fee_payer_keypairs =
    Array.init num_of_fee_payers ~f:(fun _ -> Keypair.create ())
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
    Currency.Balance.of_mina_int_exn 1_000_000
  in
  let (fee_payer_accounts : Account.t array) =
    if is_timed then
      let initial_minimum_balance =
        Currency.Balance.of_mina_int_exn 1_000_000
      in
      let cliff_time = Mina_numbers.Global_slot_since_genesis.of_int 1_000 in
      let cliff_amount = Currency.Amount.zero in
      let vesting_period = Mina_numbers.Global_slot_span.of_int 10 in
      let vesting_increment = Currency.Amount.of_mina_int_exn 100 in
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
  let normal_keys = List.init 200 ~f:(fun _ -> Keypair.create ()) in
  let zkapp_keys = List.init 200 ~f:(fun _ -> Keypair.create ()) in
  let extra_keys = List.init 200 ~f:(fun _ -> Keypair.create ()) in
  let normal_account_ids =
    List.map normal_keys ~f:(fun key ->
        Account_id.create
          (Signature_lib.Public_key.compress key.public_key)
          Token_id.default )
  in
  let zkapp_account_ids =
    List.map zkapp_keys ~f:(fun key ->
        Account_id.create
          (Signature_lib.Public_key.compress key.public_key)
          Token_id.default )
  in
  let normal_accounts =
    List.map normal_account_ids ~f:(fun id ->
        Account.create id initial_balance )
  in
  let zkapp_accounts =
    List.map zkapp_account_ids ~f:(fun id ->
        let account = Account.create id initial_balance in
        let verification_key = Some vk in
        let zkapp = Some { Zkapp_account.default with verification_key } in
        { account with zkapp } )
  in
  List.iter
    (List.zip_exn
       (normal_account_ids @ zkapp_account_ids)
       (normal_accounts @ zkapp_accounts) )
    ~f:(fun (account_id, account) ->
      Mina_ledger.Ledger.get_or_create_account ledger account_id account
      |> Or_error.ok_exn
      |> fun _ -> () ) ;
  let keys = normal_keys @ zkapp_keys @ extra_keys in
  let keymap =
    List.map
      (Array.to_list fee_payer_keypairs @ keys)
      ~f:(fun { public_key; private_key } ->
        (Public_key.compress public_key, private_key) )
    |> Public_key.Compressed.Map.of_alist_exn
  in
  (ledger, fee_payer_keypairs, keymap)

let generate_zkapp_commands_and_apply_them_consecutively_5_times ~successful
    ~max_account_updates ~individual_test_timeout random =
  let ledger, fee_payer_keypairs, keymap =
    mk_ledgers_and_fee_payers ~num_of_fee_payers:5 ()
  in
  let account_state_tbl = Account_id.Table.create () in
  let global_slot = Mina_numbers.Global_slot_since_genesis.one in
  let test i random =
    let zkapp_command_dummy_auths =
      Quickcheck.Generator.generate ~size:10 ~random
        (Mina_generators.Zkapp_command_generators.gen_zkapp_command_from
           ~global_slot ~protocol_state_view:U.genesis_state_view
           ~account_state_tbl ~fee_payer_keypair:fee_payer_keypairs.(i)
           ~max_account_updates ~keymap ~ledger ~vk () )
    in
    let%bind.Deferred zkapp_command =
      Zkapp_command_builder.replace_authorizations ~prover ~keymap
        zkapp_command_dummy_auths
    in
    let%map () =
      match%map
        try_with (fun () ->
            with_timeout (Time.Span.of_int_sec individual_test_timeout)
            @@ U.check_zkapp_command_with_merges_exn ~logger ~global_slot ledger
                 [ zkapp_command ] )
      with
      | Ok (`Result ()) ->
          ()
      | Ok `Timeout ->
          [%log error]
            ~metadata:
              [ ("zkapp_command", Zkapp_command.to_yojson zkapp_command)
              ; ("individual_test_timeout", `Int individual_test_timeout)
              ]
            "Consecutive zkApp application test timed out, see $zkapp_command \
             for details" ;
          successful := false
      | Error e ->
          [%log error]
            ~metadata:
              [ ("exn", `String (Exn.to_string e))
              ; ("zkapp_command", Zkapp_command.to_yojson zkapp_command)
              ]
            "Consecutive zkApp application test failed, see $exn and \
             $zkapp_command for details" ;
          successful := false
    in
    Splittable_random.State.split random
  in
  let tests = List.init 5 ~f:(fun i -> test i) in
  Deferred.List.fold tests ~init:random ~f:(fun random test -> test random)

let generate_zkapp_commands_and_apply_them_freshly ~successful
    ~max_account_updates ~individual_test_timeout random =
  let ledger, fee_payer_keypairs, keymap =
    mk_ledgers_and_fee_payers ~num_of_fee_payers:3 ()
  in
  let global_slot = Mina_numbers.Global_slot_since_genesis.of_int 2 in
  let zkapp_command_dummy_auths =
    Quickcheck.Generator.generate ~size:10 ~random
      (Mina_generators.Zkapp_command_generators.gen_zkapp_command_from
         ~global_slot ~protocol_state_view:U.genesis_state_view
         ~fee_payer_keypair:fee_payer_keypairs.(0) ~max_account_updates ~keymap
         ~ledger ~vk () )
  in
  let%bind.Deferred zkapp_command =
    Zkapp_command_builder.replace_authorizations ~prover ~keymap
      zkapp_command_dummy_auths
  in
  let%map () =
    match%map
      try_with (fun () ->
          with_timeout (Time.Span.of_int_sec individual_test_timeout)
          @@ U.check_zkapp_command_with_merges_exn ~logger ~global_slot ledger
               [ zkapp_command ] )
    with
    | Ok (`Result ()) ->
        ()
    | Ok `Timeout ->
        [%log error]
          ~metadata:
            [ ("zkapp_command", Zkapp_command.to_yojson zkapp_command)
            ; ("individual_test_timeout", `Int individual_test_timeout)
            ]
          "zkApp application test timed out, see $zkapp_command for details" ;
        successful := false
    | Error e ->
        [%log error]
          ~metadata:
            [ ("exn", `String (Exn.to_string e))
            ; ("zkapp_command", Zkapp_command.to_yojson zkapp_command)
            ]
          "zkApp application test failed, see $exn and $zkapp_command for \
           details" ;
        successful := false
  in
  Splittable_random.State.split random

let mk_invalid_test ~successful ~max_account_updates ~type_of_failure
    ~expected_failure_status ~individual_test_timeout random =
  let ledger, fee_payer_keypairs, keymap =
    mk_ledgers_and_fee_payers ~num_of_fee_payers:3 ()
  in
  let global_slot = Mina_numbers.Global_slot_since_genesis.of_int 3 in
  let zkapp_command_dummy_auths =
    Quickcheck.Generator.generate ~size:10 ~random
      (Mina_generators.Zkapp_command_generators.gen_zkapp_command_from
         ~global_slot ~failure:type_of_failure
         ~protocol_state_view:U.genesis_state_view
         ~fee_payer_keypair:fee_payer_keypairs.(0) ~max_account_updates ~keymap
         ~ledger ~vk () )
  in

  let%bind.Deferred zkapp_command =
    Zkapp_command_builder.replace_authorizations ~prover ~keymap
      zkapp_command_dummy_auths
  in
  let%map () =
    match%map
      try_with (fun () ->
          with_timeout (Time.Span.of_int_sec individual_test_timeout)
          @@ U.check_zkapp_command_with_merges_exn ~logger
               ~expected_failure:expected_failure_status ledger
               [ zkapp_command ] ~global_slot )
    with
    | Ok (`Result ()) ->
        ()
    | Ok `Timeout ->
        [%log error]
          ~metadata:
            [ ( "expected_failure"
              , Mina_generators.Zkapp_command_generators.failure_to_yojson
                  type_of_failure )
            ; ("zkapp_command", Zkapp_command.to_yojson zkapp_command)
            ; ("individual_test_timeout", `Int individual_test_timeout)
            ]
          "Invalid test timed out, see $expected_failure and $zkapp_command \
           for details" ;
        successful := false
    | Error e ->
        [%log error]
          ~metadata:
            [ ("exn", `String (Exn.to_string e))
            ; ("zkapp_command", Zkapp_command.to_yojson zkapp_command)
            ; ( "expected_failure"
              , Mina_generators.Zkapp_command_generators.failure_to_yojson
                  type_of_failure )
            ]
          "Invalid test failed, see $exn, $expected_failure and $zkapp_command \
           for details" ;
        successful := false
  in
  Splittable_random.State.split random

let test_timed_account ~successful ~max_account_updates ~individual_test_timeout
    random =
  let ledger, fee_payer_keypairs, keymap =
    mk_ledgers_and_fee_payers ~is_timed:true ~num_of_fee_payers:3 ()
  in
  let zkapp_command_dummy_auths =
    Quickcheck.Generator.generate ~size:10 ~random
      (Mina_generators.Zkapp_command_generators.gen_zkapp_command_from
         ~protocol_state_view:U.genesis_state_view
         ~fee_payer_keypair:fee_payer_keypairs.(0) ~max_account_updates ~keymap
         ~ledger ~vk () )
  in
  let%bind zkapp_command =
    Zkapp_command_builder.replace_authorizations ~prover ~keymap
      zkapp_command_dummy_auths
  in
  let%map () =
    match%map
      try_with (fun () ->
          with_timeout (Time.Span.of_int_sec individual_test_timeout)
          @@ U.check_zkapp_command_with_merges_exn ~logger
               ~expected_failure:
                 ( Transaction_status.Failure.Source_minimum_balance_violation
                 , Pass_1 )
               ledger [ zkapp_command ] ~state_body:U.genesis_state_body )
    with
    | Ok (`Result ()) ->
        ()
    | Ok `Timeout ->
        [%log error]
          ~metadata:
            [ ("zkapp_command", Zkapp_command.to_yojson zkapp_command)
            ; ("individual_test_timeout", `Int individual_test_timeout)
            ]
          "Timed account test timed out, see $zkapp_command for details" ;
        successful := false
    | Error e ->
        [%log error]
          ~metadata:
            [ ("exn", `String (Exn.to_string e))
            ; ("zkapp_command", Zkapp_command.to_yojson zkapp_command)
            ]
          "Timed account test failed, see $exn and $zkapp_command for details" ;
        successful := false
  in
  Splittable_random.State.split random

let () =
  Command.run
  @@ Command.async ~summary:"fuzzy zkapp tests"
       (let open Command.Let_syntax in
       let%map timeout =
         Command.Param.(
           flag "--timeout"
             ~doc:
               "NUM total seconds that we want the tests to run, failures \
                would be collected and reported along the way"
             (required int))
       and individual_test_timeout =
         Command.Param.(
           flag "--individual-test-timeout"
             ~doc:"NUM seconds that we allow an individual test to run at most"
             (required int))
       and seed =
         Command.Param.(
           flag "--seed"
             ~doc:"NUM a random number that used as a seed for this test"
             (required int))
       in
       fun () ->
         let open Mina_generators.Zkapp_command_generators in
         let open Transaction_status.Failure in
         let max_account_updates = 3 in
         let random = Splittable_random.State.of_int seed in
         let successful = ref true in
         let rec loop random =
           generate_zkapp_commands_and_apply_them_consecutively_5_times
             ~successful ~max_account_updates
             ~individual_test_timeout:(individual_test_timeout * 2)
             random
           >>= generate_zkapp_commands_and_apply_them_freshly ~successful
                 ~max_account_updates ~individual_test_timeout
           >>= mk_invalid_test ~successful ~max_account_updates
                 ~type_of_failure:Invalid_protocol_state_precondition
                 ~expected_failure_status:
                   (Protocol_state_precondition_unsatisfied, Pass_2)
                 ~individual_test_timeout
           >>= mk_invalid_test ~successful ~max_account_updates
                 ~type_of_failure:(Update_not_permitted `App_state)
                 ~expected_failure_status:
                   (Update_not_permitted_app_state, Pass_2)
                 ~individual_test_timeout:(individual_test_timeout * 2)
           >>= mk_invalid_test ~successful ~max_account_updates
                 ~type_of_failure:(Update_not_permitted `Verification_key)
                 ~expected_failure_status:
                   (Update_not_permitted_verification_key, Pass_2)
                 ~individual_test_timeout
           >>= mk_invalid_test ~successful ~max_account_updates
                 ~type_of_failure:(Update_not_permitted `Zkapp_uri)
                 ~expected_failure_status:
                   (Update_not_permitted_zkapp_uri, Pass_2)
                 ~individual_test_timeout
           >>= mk_invalid_test ~successful ~max_account_updates
                 ~type_of_failure:(Update_not_permitted `Token_symbol)
                 ~expected_failure_status:
                   (Update_not_permitted_token_symbol, Pass_2)
                 ~individual_test_timeout
           >>= mk_invalid_test ~successful ~max_account_updates
                 ~type_of_failure:(Update_not_permitted `Voting_for)
                 ~expected_failure_status:
                   (Update_not_permitted_voting_for, Pass_2)
                 ~individual_test_timeout
           >>= mk_invalid_test ~successful ~max_account_updates
                 ~type_of_failure:(Update_not_permitted `Send)
                 ~expected_failure_status:(Update_not_permitted_balance, Pass_2)
                 ~individual_test_timeout
           >>= mk_invalid_test ~successful ~max_account_updates
                 ~type_of_failure:(Update_not_permitted `Receive)
                 ~expected_failure_status:(Update_not_permitted_balance, Pass_2)
                 ~individual_test_timeout
           >>= test_timed_account ~successful ~max_account_updates
                 ~individual_test_timeout
           >>= loop
         in
         with_timeout (Core.Time.Span.of_int_sec timeout) (loop random)
         >>= function
         | `Result _ ->
             exit 1
         | `Timeout ->
             if !successful then Deferred.return () else exit 1)
