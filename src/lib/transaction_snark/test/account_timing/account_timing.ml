open Core
open Currency
open Snark_params
open Tick
open Signature_lib
open Mina_base

let%test_module "account timing check" =
  ( module struct
    open Transaction_snark.Transaction_validator.For_tests

    (* test that unchecked and checked calculations for timing agree *)

    let checked_min_balance_and_timing account txn_amount txn_global_slot =
      let account = Account.var_of_t account in
      let txn_amount = Amount.var_of_t txn_amount in
      let txn_global_slot =
        Mina_numbers.Global_slot.Checked.constant txn_global_slot
      in
      let%map `Min_balance min_balance, timing =
        Transaction_snark.Base.check_timing
          ~balance_check:Tick.Boolean.Assert.is_true
          ~timed_balance_check:Tick.Boolean.Assert.is_true ~account
          ~txn_amount:(Some txn_amount) ~txn_global_slot
      in
      (min_balance, timing)

    let make_checked_timing_computation account txn_amount txn_global_slot =
      let%map _min_balance, timing =
        checked_min_balance_and_timing account txn_amount txn_global_slot
      in
      timing

    let make_checked_min_balance_computation account txn_amount txn_global_slot
        =
      let%map min_balance, _timing =
        checked_min_balance_and_timing account txn_amount txn_global_slot
      in
      min_balance

    let run_checked_timing_and_compare account txn_amount txn_global_slot
        unchecked_timing unchecked_min_balance =
      let equal_balances_computation =
        let open Snarky_backendless.Checked in
        let%bind checked_timing =
          make_checked_timing_computation account txn_amount txn_global_slot
        in
        (* check agreement of timings produced by checked, unchecked validations *)
        let%bind () =
          as_prover
            As_prover.(
              let%map checked_timing = read Account.Timing.typ checked_timing in
              assert (Account.Timing.equal checked_timing unchecked_timing))
        in
        let%bind checked_min_balance =
          make_checked_min_balance_computation account txn_amount
            txn_global_slot
        in
        let%map equal_balances_checked =
          Balance.Checked.equal checked_min_balance
            (Balance.var_of_t unchecked_min_balance)
        in
        Snarky_backendless.As_prover.read Tick.Boolean.typ
          equal_balances_checked
      in
      let equal_balances =
        Or_error.ok_exn @@ Tick.run_and_check equal_balances_computation
      in
      equal_balances

    (* confirm the checked computation fails *)
    let checked_timing_should_fail account txn_amount txn_global_slot =
      let checked_timing_computation =
        let%map checked_timing =
          make_checked_timing_computation account txn_amount txn_global_slot
        in
        As_prover.read Account.Timing.typ checked_timing
      in
      Or_error.is_error @@ Tick.run_and_check checked_timing_computation

    let%test "before_cliff_time" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 80_000_000_000_000 in
      let cliff_time = Mina_numbers.Global_slot.of_int 1000 in
      let cliff_amount = Amount.of_int 500_000_000 in
      let vesting_period = Mina_numbers.Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 1_000_000_000 in
      let txn_amount = Currency.Amount.of_int 100_000_000_000 in
      let txn_global_slot = Mina_numbers.Global_slot.of_int 45 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
      in
      let timing_with_min_balance =
        validate_timing_with_min_balance ~txn_amount ~txn_global_slot ~account
      in
      match timing_with_min_balance with
      | Ok ((Timed _ as unchecked_timing), `Min_balance unchecked_min_balance)
        ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing unchecked_min_balance
      | _ ->
          false

    let%test "positive min balance" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Mina_numbers.Global_slot.of_int 1000 in
      let cliff_amount = Amount.zero in
      let vesting_period = Mina_numbers.Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 100_000_000_000 in
      let txn_global_slot = Mina_numbers.Global_slot.of_int 1_900 in
      let timing_with_min_balance =
        validate_timing_with_min_balance ~account
          ~txn_amount:(Currency.Amount.of_int 100_000_000_000)
          ~txn_global_slot:(Mina_numbers.Global_slot.of_int 1_900)
      in
      (* we're 900 slots past the cliff, which is 90 vesting periods
          subtract 90 * 100 = 9,000 from init min balance of 10,000 to get 1000
          so we should still be timed
      *)
      match timing_with_min_balance with
      | Ok ((Timed _ as unchecked_timing), `Min_balance unchecked_min_balance)
        ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing unchecked_min_balance
      | _ ->
          false

    let%test "curr min balance of zero" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Mina_numbers.Global_slot.of_int 1_000 in
      let cliff_amount = Amount.of_int 900_000_000 in
      let vesting_period = Mina_numbers.Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 100_000_000_000 in
      let txn_global_slot = Mina_numbers.Global_slot.of_int 2_000 in
      let timing_with_min_balance =
        validate_timing_with_min_balance ~txn_amount ~txn_global_slot ~account
      in
      (* we're 2_000 - 1_000 = 1_000 slots past the cliff, which is 100 vesting periods
          subtract 100 * 100_000_000_000 = 10_000_000_000_000 from init min balance
          of 10_000_000_000 to get zero, so we should be untimed now
      *)
      match timing_with_min_balance with
      | Ok ((Untimed as unchecked_timing), `Min_balance unchecked_min_balance)
        ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing unchecked_min_balance
      | _ ->
          false

    let%test "below calculated min balance" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 10_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Mina_numbers.Global_slot.of_int 1_000 in
      let cliff_amount = Amount.zero in
      let vesting_period = Mina_numbers.Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 101_000_000_000 in
      let txn_global_slot = Mina_numbers.Global_slot.of_int 1_010 in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      match timing with
      | Error err ->
          assert (
            Transaction_status.Failure.equal
              (Mina_transaction_logic.timing_error_to_user_command_status err)
              Transaction_status.Failure.Source_minimum_balance_violation ) ;
          checked_timing_should_fail account txn_amount txn_global_slot
      | _ ->
          false

    let%test "insufficient balance" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Mina_numbers.Global_slot.of_int 1000 in
      let cliff_amount = Amount.zero in
      let vesting_period = Mina_numbers.Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 100_001_000_000_000 in
      let txn_global_slot = Mina_numbers.Global_slot.of_int 2000_000_000_000 in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      match timing with
      | Error err ->
          assert (
            Transaction_status.Failure.equal
              (Mina_transaction_logic.timing_error_to_user_command_status err)
              Transaction_status.Failure.Source_insufficient_balance ) ;
          checked_timing_should_fail account txn_amount txn_global_slot
      | _ ->
          false

    let%test "past full vesting" =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Mina_numbers.Global_slot.of_int 1000 in
      let cliff_amount = Amount.zero in
      let vesting_period = Mina_numbers.Global_slot.of_int 10 in
      let vesting_increment = Amount.of_int 100_000_000_000 in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
      in
      (* fully vested, curr min balance = 0, so we can spend the whole balance *)
      let txn_amount = Currency.Amount.of_int 100_000_000_000_000 in
      let txn_global_slot = Mina_numbers.Global_slot.of_int 3000 in
      let timing_with_min_balance =
        validate_timing_with_min_balance ~txn_amount ~txn_global_slot ~account
      in
      match timing_with_min_balance with
      | Ok ((Untimed as unchecked_timing), `Min_balance unchecked_min_balance)
        ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing unchecked_min_balance
      | _ ->
          false

    let make_cliff_amount_test slot =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk Token_id.default in
      let balance = Balance.of_int 100_000_000_000_000 in
      let initial_minimum_balance = Balance.of_int 10_000_000_000_000 in
      let cliff_time = Mina_numbers.Global_slot.of_int 1000 in
      let cliff_amount =
        Balance.to_uint64 initial_minimum_balance |> Amount.of_uint64
      in
      let vesting_period = Mina_numbers.Global_slot.of_int 1 in
      let vesting_increment = Amount.zero in
      let account =
        Or_error.ok_exn
        @@ Account.create_timed account_id balance ~initial_minimum_balance
             ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
      in
      let txn_amount = Currency.Amount.of_int 100_000_000_000_000 in
      let txn_global_slot = Mina_numbers.Global_slot.of_int slot in
      (txn_amount, txn_global_slot, account)

    let%test "before cliff, cliff_amount doesn't affect min balance" =
      let txn_amount, txn_global_slot, account = make_cliff_amount_test 999 in
      let timing = validate_timing ~txn_amount ~txn_global_slot ~account in
      match timing with
      | Error err ->
          assert (
            Transaction_status.Failure.equal
              (Mina_transaction_logic.timing_error_to_user_command_status err)
              Transaction_status.Failure.Source_minimum_balance_violation ) ;
          checked_timing_should_fail account txn_amount txn_global_slot
      | Ok _ ->
          false

    let%test "at exactly cliff time, cliff amount allows spending" =
      let txn_amount, txn_global_slot, account = make_cliff_amount_test 1000 in
      let timing_with_min_balance =
        validate_timing_with_min_balance ~txn_amount ~txn_global_slot ~account
      in
      match timing_with_min_balance with
      | Ok ((Untimed as unchecked_timing), `Min_balance unchecked_min_balance)
        ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing unchecked_min_balance
      | _ ->
          false

    (* user commands with timings *)

    let constraint_constants = Genesis_constants.Constraint_constants.compiled

    let keypairss, keypairs =
      (* these tests are based on relative balance/payment amounts, don't need to
         run on multiple keypairs
      *)
      let length = 1 in
      (* keypair pair (for payment sender/receiver)  *)
      let keypairss =
        List.init length ~f:(fun _ ->
            (Signature_lib.Keypair.create (), Signature_lib.Keypair.create ()))
      in
      (* list of keypairs *)
      let keypairs =
        List.map keypairss ~f:(fun (kp1, kp2) -> [ kp1; kp2 ]) |> List.concat
      in
      (keypairss, keypairs)

    (* we're testing timings, not signatures *)
    let validate_user_command uc =
      let (`If_this_is_used_it_should_have_a_comment_justifying_it validated_uc)
          =
        Signed_command.to_valid_unsafe uc
      in
      validated_uc

    (* Mina_ledger.Ledger.copy does not actually copy *)
    let copy_ledger (ledger : Mina_ledger.Ledger.t) =
      let ledger_copy =
        Mina_ledger.Ledger.create ~depth:(Mina_ledger.Ledger.depth ledger) ()
      in
      let accounts = Mina_ledger.Ledger.to_list ledger in
      List.iter accounts ~f:(fun account ->
          let pk = Account.public_key account in
          let token = Account.token account in
          let account_id = Account_id.create pk token in
          match
            Mina_ledger.Ledger.get_or_create_account ledger_copy account_id
              account
          with
          | Ok (`Added, _loc) ->
              ()
          | Ok (`Existed, _loc) ->
              failwithf
                "When creating ledger, account with public key %s and token %s \
                 already existed"
                (Signature_lib.Public_key.Compressed.to_string pk)
                (Token_id.to_string token) ()
          | Error err ->
              failwithf
                "When creating ledger, error adding account with public key %s \
                 and token %s: %s"
                (Signature_lib.Public_key.Compressed.to_string pk)
                (Token_id.to_string token) (Error.to_string_hum err) ()) ;
      ledger_copy

    let check_transaction_snark ~(txn_global_slot : Mina_numbers.Global_slot.t)
        (ledger : Mina_ledger.Ledger.t)
        (transaction : Mina_transaction.Transaction.t) =
      let sok_message =
        Sok_message.create ~fee:Currency.Fee.zero
          ~prover:
            Public_key.(compress (of_private_key_exn (Private_key.create ())))
      in
      let precomputed_values = Lazy.force Precomputed_values.compiled_inputs in
      let state_body0 =
        Mina_state.(
          With_hash.data precomputed_values.protocol_state_with_hashes
          |> Protocol_state.body)
      in
      let consensus_state0 =
        Mina_state.Protocol_state.Body.consensus_state state_body0
      in
      let txn_state_view0 = Mina_state.Protocol_state.Body.view state_body0 in
      let validated_transaction =
        match transaction with
        | Command (Signed_command uc) ->
            Mina_transaction.Transaction.Command
              (User_command.Signed_command (validate_user_command uc))
        | _ ->
            failwith "Expected signed user command"
      in
      (* use given slot *)
      let consensus_state =
        Consensus.Data.Consensus_state.Value.For_tests
        .with_global_slot_since_genesis consensus_state0 txn_global_slot
      in
      let state_body =
        Mina_state.Protocol_state.Body.For_tests.with_consensus_state
          state_body0 consensus_state
      in
      let state_body_hash = Mina_state.Protocol_state.Body.hash state_body in
      let txn_state_view =
        { txn_state_view0 with global_slot_since_genesis = txn_global_slot }
      in
      let account_ids =
        Mina_ledger.Ledger.to_list ledger
        |> List.map ~f:(fun acct ->
               Account_id.create acct.public_key acct.token_id)
      in
      let sparse_ledger_before =
        Mina_ledger.Sparse_ledger.of_ledger_subset_exn ledger account_ids
      in
      let sparse_ledger_after, _ =
        Mina_ledger.Sparse_ledger.apply_transaction ~constraint_constants
          ~txn_state_view sparse_ledger_before transaction
        |> Or_error.ok_exn
      in
      let coinbase_stack_target =
        let stack_with_state =
          Pending_coinbase.Stack.(
            push_state state_body_hash Pending_coinbase.Stack.empty)
        in
        match transaction with
        | Coinbase c ->
            Pending_coinbase.(Stack.push_coinbase c stack_with_state)
        | _ ->
            stack_with_state
      in
      Transaction_snark.check_transaction ~constraint_constants ~sok_message
        ~source:(Mina_ledger.Sparse_ledger.merkle_root sparse_ledger_before)
        ~target:(Mina_ledger.Sparse_ledger.merkle_root sparse_ledger_after)
        ~init_stack:Pending_coinbase.Stack.empty
        ~pending_coinbase_stack_state:
          { source = Pending_coinbase.Stack.empty
          ; target = coinbase_stack_target
          }
        ~snapp_account1:None ~snapp_account2:None
        { Transaction_protocol_state.Poly.block_data = state_body
        ; transaction = validated_transaction
        }
        (unstage (Mina_ledger.Sparse_ledger.handler sparse_ledger_before))

    let apply_user_commands_at_slot ledger slot
        (txns : Mina_transaction.Transaction.t list) =
      ignore
        ( List.map txns ~f:(fun txn ->
              let uc =
                match txn with
                | Command (Signed_command uc) ->
                    uc
                | _ ->
                    failwith "Expected signed user command"
              in
              let validated_uc = validate_user_command uc in
              let ledger_copy = copy_ledger ledger in
              match
                Mina_ledger.Ledger.apply_user_command ~constraint_constants
                  ~txn_global_slot:slot ledger validated_uc
              with
              | Ok txn_applied ->
                  ( match With_status.status txn_applied.common.user_command with
                  | Applied _ ->
                      ()
                  | Failed (failures, _balance_data) ->
                      failwithf "Transaction failed: %s"
                        ( List.map (List.concat failures) ~f:(fun failure ->
                              Transaction_status.Failure.to_string failure)
                        |> String.concat ~sep:"," )
                        () ) ;
                  check_transaction_snark ~txn_global_slot:slot ledger_copy txn
              | Error err ->
                  failwithf "Error when applying transaction: %s"
                    (Error.to_string_hum err) ())
          : unit list )

    (* for tests where we expect payments to succeed, use real signature, fake otherwise *)

    let%test_unit "user commands, before cliff time, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int 10_000_000_000_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int 50_000_000_000
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                  ; cliff_amount = Currency.Amount.of_int 100
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing))
          |> Array.of_list
        in
        (* small payment amount, relative to balances *)
        let amount = 10_000_000_000 in
        let%map user_commands =
          Quickcheck.Generator.all
          @@ List.map keypairss ~f:(fun (kp1, kp2) ->
                 let%map payment =
                   Signed_command.Gen.payment ~sign_type:`Real
                     ~key_gen:(return (kp1, kp2))
                     ~min_amount:amount ~max_amount:amount ~fee_range:0 ()
                 in
                 ( Mina_transaction.Transaction.Command (Signed_command payment)
                   : Mina_transaction.Transaction.t ))
        in
        (ledger_init_state, user_commands)
      in
      (* slot 1, well before cliffs *)
      Quickcheck.test ~seed:(`Deterministic "user command, before cliff")
        ~sexp_of:
          [%sexp_of:
            Mina_ledger.Ledger.init_state * Mina_transaction.Transaction.t list]
        ~trials:2 gen ~f:(fun (ledger_init_state, user_commands) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_user_commands_at_slot ledger
                Mina_numbers.Global_slot.(succ zero)
                user_commands))

    let%test_unit "user command, before cliff time, min balance violation" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        (* high init min balances, payment amount enough to violate *)
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int 10_000_000_000_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int 9_995_000_000_000
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                  ; cliff_amount = Currency.Amount.of_int 100
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing))
          |> Array.of_list
        in
        let amount = 100_000_000_000 in
        let%map user_command =
          let%map payment =
            Signed_command.Gen.payment ~sign_type:`Fake
              ~key_gen:(return @@ List.hd_exn keypairss)
              ~min_amount:amount ~max_amount:amount ~fee_range:0 ()
          in
          ( Mina_transaction.Transaction.Command (Signed_command payment)
            : Mina_transaction.Transaction.t )
        in
        (ledger_init_state, user_command)
      in
      Quickcheck.test ~seed:(`Deterministic "user command, before cliff")
        ~trials:1 gen ~f:(fun (ledger_init_state, user_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              let uc =
                match user_command with
                | Command (Signed_command uc) ->
                    uc
                | _ ->
                    failwith "Expected signed user command"
              in
              let validated_uc = validate_user_command uc in
              match
                Mina_ledger.Ledger.apply_user_command ~constraint_constants
                  ~txn_global_slot:Mina_numbers.Global_slot.(succ zero)
                  ledger validated_uc
              with
              | Ok _txn_applied ->
                  failwith "Should have failed with min balance violation"
              | Error err ->
                  let err_str = Error.to_string_hum err in
                  if
                    not
                      (String.equal err_str
                         Transaction_status.Failure.(
                           describe Source_minimum_balance_violation))
                  then failwithf "Unexpected transaction error: %s" err_str ()))

    let%test_unit "user command, just before cliff time, insufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int 10_000_000_000_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int 9_995_000_000_000
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                  ; cliff_amount = Currency.Amount.of_int 9_995_000_000_000
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing))
          |> Array.of_list
        in
        let amount = 100_000_000_000 in
        let%map user_command =
          Signed_command.Gen.payment ~sign_type:`Fake
            ~key_gen:(return @@ List.hd_exn keypairss)
            ~min_amount:amount ~max_amount:amount ~fee_range:0 ()
        in
        (ledger_init_state, user_command)
      in
      Quickcheck.test ~seed:(`Deterministic "user command, at cliff") ~trials:1
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Signed_command.t]
        gen ~f:(fun (ledger_init_state, user_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              let validated_uc = validate_user_command user_command in
              match
                Mina_ledger.Ledger.apply_user_command ~constraint_constants
                  ~txn_global_slot:(Mina_numbers.Global_slot.of_int 9999)
                  ledger validated_uc
              with
              | Ok _txn_applied ->
                  failwith "Expected failure to insufficient balance"
              | Error err ->
                  let err_str = Error.to_string_hum err in
                  if
                    not
                      (String.equal err_str
                         Transaction_status.Failure.(
                           describe Source_minimum_balance_violation))
                  then failwithf "Unexpected transaction error: %s" err_str ()))

    let%test_unit "user command, at cliff time, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int 10_000_000_000_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int 9_995_000_000_000
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                  ; cliff_amount = Currency.Amount.of_int 9_995_000_000_000
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing))
          |> Array.of_list
        in
        let amount = 100_000_000_000 in
        let%map user_command =
          let%map payment =
            Signed_command.Gen.payment ~sign_type:`Real
              ~key_gen:(return @@ List.hd_exn keypairss)
              ~min_amount:amount ~max_amount:amount ~fee_range:0 ()
          in
          ( Mina_transaction.Transaction.Command (Signed_command payment)
            : Mina_transaction.Transaction.t )
        in
        (ledger_init_state, user_command)
      in
      Quickcheck.test ~seed:(`Deterministic "user command, at cliff") ~trials:1
        ~sexp_of:
          [%sexp_of:
            Mina_ledger.Ledger.init_state * Mina_transaction.Transaction.t] gen
        ~f:(fun (ledger_init_state, user_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_user_commands_at_slot ledger
                (Mina_numbers.Global_slot.of_int 10000)
                [ user_command ]))

    let%test_unit "user command, while vesting, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let init_min_bal_int = 9_995_000_000_000 in
        let balance_int = 10_000_000_000_000 in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int balance_int in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int init_min_bal_int
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                  ; cliff_amount = Currency.Amount.zero
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing))
          |> Array.of_list
        in
        (* initial min balance - 100 slots * increment *)
        let min_bal_100_slots = init_min_bal_int - (100 * 10) in
        let liquid_bal_100_slots = balance_int - min_bal_100_slots in
        (* we can't transfer the whole liquid balance, because fee also is considered
           when checking for min balance violations
        *)
        let amount =
          liquid_bal_100_slots
          - Fee.to_int Mina_compile_config.minimum_user_command_fee
        in
        let%map user_command =
          let%map payment =
            Signed_command.Gen.payment ~sign_type:`Real
              ~key_gen:(return @@ List.hd_exn keypairss)
              ~min_amount:amount ~max_amount:amount ~fee_range:0 ()
          in
          ( Mina_transaction.Transaction.Command (Signed_command payment)
            : Mina_transaction.Transaction.t )
        in
        (ledger_init_state, user_command)
      in
      Quickcheck.test ~seed:(`Deterministic "user command, while vesting")
        ~trials:1
        ~sexp_of:
          [%sexp_of:
            Mina_ledger.Ledger.init_state * Mina_transaction.Transaction.t] gen
        ~f:(fun (ledger_init_state, user_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              (* 100 vesting periods after cliff *)
              apply_user_commands_at_slot ledger
                (Mina_numbers.Global_slot.of_int 10100)
                [ user_command ]))

    let%test_unit "user command, after vesting, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int 10_000_000_000_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int 9_995_000_000_000
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                  ; cliff_amount = Currency.Amount.of_int 9_995_000_000_000
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing))
          |> Array.of_list
        in
        (* small amount, relative to balance *)
        let amount = 100_000 in
        let%map user_command =
          let%map payment =
            Signed_command.Gen.payment ~sign_type:`Real
              ~key_gen:(return @@ List.hd_exn keypairss)
              ~min_amount:amount ~max_amount:amount ~fee_range:0 ()
          in
          ( Mina_transaction.Transaction.Command (Signed_command payment)
            : Mina_transaction.Transaction.t )
        in
        (ledger_init_state, user_command)
      in
      Quickcheck.test ~seed:(`Deterministic "user command, while vesting")
        ~trials:1
        ~sexp_of:
          [%sexp_of:
            Mina_ledger.Ledger.init_state * Mina_transaction.Transaction.t] gen
        ~f:(fun (ledger_init_state, user_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_user_commands_at_slot ledger
                Mina_numbers.Global_slot.(succ zero)
                [ user_command ]))

    let%test_unit "user command, after vesting, insufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int 10_000_000_000_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int 9_995_000_000_000
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                  ; cliff_amount = Currency.Amount.of_int 9_995_000_000_000
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing))
          |> Array.of_list
        in
        let amount = 100_000_000_000_000 in
        let%map user_command =
          Signed_command.Gen.payment ~sign_type:`Fake
            ~key_gen:(return @@ List.hd_exn keypairss)
            ~min_amount:amount ~max_amount:amount ~fee_range:0 ()
        in
        (ledger_init_state, user_command)
      in
      Quickcheck.test ~seed:(`Deterministic "user command, after vesting")
        ~trials:1 gen ~f:(fun (ledger_init_state, user_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              let validated_uc = validate_user_command user_command in
              (* slot well past cliff *)
              match
                Mina_ledger.Ledger.apply_user_command ~constraint_constants
                  ~txn_global_slot:(Mina_numbers.Global_slot.of_int 200000)
                  ledger validated_uc
              with
              | Ok _txn_applied ->
                  failwith "Expected failure to insufficient balance"
              | Error err ->
                  let err_str = Error.to_string_hum err in
                  if
                    not
                      (String.equal err_str
                         Transaction_status.Failure.(
                           describe Source_insufficient_balance))
                  then failwithf "Unexpected transaction error: %s" err_str ()))
  end )
