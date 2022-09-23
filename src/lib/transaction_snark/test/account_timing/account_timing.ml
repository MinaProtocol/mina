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
            (Signature_lib.Keypair.create (), Signature_lib.Keypair.create ()) )
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

    let state_body_and_view_at_slot txn_global_slot =
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
      let consensus_state =
        Consensus.Data.Consensus_state.Value.For_tests
        .with_global_slot_since_genesis consensus_state0 txn_global_slot
      in
      let state_body =
        Mina_state.Protocol_state.Body.For_tests.with_consensus_state
          state_body0 consensus_state
      in
      let txn_state_view =
        { txn_state_view0 with global_slot_since_genesis = txn_global_slot }
      in
      (state_body, txn_state_view)

    let check_transaction_snark ~(txn_global_slot : Mina_numbers.Global_slot.t)
        (sparse_ledger_before : Mina_ledger.Sparse_ledger.t)
        (transaction : Mina_transaction.Transaction.t) =
      let sok_message =
        Sok_message.create ~fee:Currency.Fee.zero
          ~prover:
            Public_key.(compress (of_private_key_exn (Private_key.create ())))
      in
      let state_body, txn_state_view =
        state_body_and_view_at_slot txn_global_slot
      in
      let validated_transaction : Mina_transaction.Transaction.Valid.t =
        match transaction with
        | Command (Signed_command uc) ->
            Mina_transaction.Transaction.Command
              (User_command.Signed_command (validate_user_command uc))
        | _ ->
            failwith "Expected signed user command"
      in
      let state_body_hash = Mina_state.Protocol_state.Body.hash state_body in
      let sparse_ledger_after, txn_applied =
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
      let supply_increase =
        Mina_ledger.Ledger.Transaction_applied.supply_increase txn_applied
        |> Or_error.ok_exn
      in
      Transaction_snark.check_transaction ~constraint_constants ~sok_message
        ~source:(Mina_ledger.Sparse_ledger.merkle_root sparse_ledger_before)
        ~target:(Mina_ledger.Sparse_ledger.merkle_root sparse_ledger_after)
        ~init_stack:Pending_coinbase.Stack.empty
        ~pending_coinbase_stack_state:
          { source = Pending_coinbase.Stack.empty
          ; target = coinbase_stack_target
          }
        ~zkapp_account1:None ~zkapp_account2:None ~supply_increase
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
              let account_ids =
                Mina_transaction.Transaction.accounts_accessed txn
              in
              let sparse_ledger_before =
                Mina_ledger.Sparse_ledger.of_ledger_subset_exn ledger
                  account_ids
              in
              match
                Mina_ledger.Ledger.apply_user_command ~constraint_constants
                  ~txn_global_slot:slot ledger validated_uc
              with
              | Ok txn_applied ->
                  ( match With_status.status txn_applied.common.user_command with
                  | Applied ->
                      ()
                  | Failed failuress ->
                      failwithf "Transaction failed: %s"
                        ( List.map (List.concat failuress) ~f:(fun failure ->
                              Transaction_status.Failure.to_string failure )
                        |> String.concat ~sep:"," )
                        () ) ;
                  check_transaction_snark ~txn_global_slot:slot
                    sparse_ledger_before txn
              | Error err ->
                  failwithf "Error when applying transaction: %s"
                    (Error.to_string_hum err) () )
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
              (keypair, balance_as_amount, nonce, timing) )
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
                   : Mina_transaction.Transaction.t ) )
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
                user_commands ) )

    let%test_unit "user command, before cliff time, min balance violation" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        (* high init min balance, payment amount enough to violate *)
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
              (keypair, balance_as_amount, nonce, timing) )
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
                           describe Source_minimum_balance_violation) )
                  then failwithf "Unexpected transaction error: %s" err_str () ) )

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
              (keypair, balance_as_amount, nonce, timing) )
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
      Quickcheck.test ~seed:(`Deterministic "user command, just before cliff")
        ~trials:1
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
                           describe Source_minimum_balance_violation) )
                  then failwithf "Unexpected transaction error: %s" err_str () ) )

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
              (keypair, balance_as_amount, nonce, timing) )
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
                [ user_command ] ) )

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
              (keypair, balance_as_amount, nonce, timing) )
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
                [ user_command ] ) )

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
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let amount = 9_000_000_000_000 in
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
      Quickcheck.test ~seed:(`Deterministic "user command, after vesting")
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
                Mina_numbers.Global_slot.(of_int 20_000)
                [ user_command ] ) )

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
              (keypair, balance_as_amount, nonce, timing) )
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
                  ~txn_global_slot:(Mina_numbers.Global_slot.of_int 200_000)
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
                           describe Source_insufficient_balance) )
                  then failwithf "Unexpected transaction error: %s" err_str () ) )

    (* zkApps with timings *)
    let apply_zkapp_commands_at_slot ledger slot
        (zkapp_commands : Zkapp_command.t list) =
      let state_body, _state_view = state_body_and_view_at_slot slot in
      Async.Deferred.List.iter zkapp_commands ~f:(fun zkapp_command ->
          Transaction_snark_tests.Util.check_zkapp_command_with_merges_exn
            ~state_body ledger [ zkapp_command ] )
      |> Fn.flip Async.upon (fun () -> ())

    let check_zkapp_failure expected_failure = function
      | Ok
          ( (zkapp_command_applied :
              Mina_transaction_logic.Transaction_applied.Zkapp_command_applied.t
              )
          , ( (local_state :
                _ Mina_transaction_logic.Zkapp_command_logic.Local_state.t )
            , _amount ) ) -> (
          (* we expect a Failed status, and the failure to appear in
             the failure status table
          *)
          let failure_statuses =
            local_state.failure_status_tbl |> List.concat
          in
          match With_status.status zkapp_command_applied.command with
          | Applied ->
              failwithf "Expected transaction failure: %s"
                (Transaction_status.Failure.to_string expected_failure)
                ()
          | Failed failuress ->
              let failures = List.concat failuress in
              if
                not
                  (List.equal Transaction_status.Failure.equal failures
                     [ expected_failure ] )
              then
                failwithf
                  "Got unxpected transaction failure(s): %s, expected failure: \
                   %s"
                  ( List.map failures ~f:Transaction_status.Failure.to_string
                  |> String.concat ~sep:"," )
                  (Transaction_status.Failure.to_string expected_failure)
                  () ;
              assert (
                List.equal Transaction_status.Failure.equal failures
                  failure_statuses ) )
      | Error err ->
          let err_str = Error.to_string_hum err in
          failwithf "Unexpected transaction error: %s" err_str ()

    let%test_unit "zkApp command, before cliff time, sufficient balance" =
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
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_int 1_000_000 in
          let amount = Currency.Amount.of_int 1_500_000 in
          let nonce = Account.Nonce.zero in
          let memo =
            Signed_command_memo.create_from_string_exn
              "zkApp transfer, timed account"
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let receiver_key =
            zkapp_keypair.public_key |> Signature_lib.Public_key.compress
          in
          let (zkapp_command_spec : Transaction_snark.For_tests.Spec.t) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          Transaction_snark.For_tests.multiple_transfers zkapp_command_spec
        in
        return (ledger_init_state, zkapp_command)
      in
      (* slot 1, well before cliff *)
      Quickcheck.test ~seed:(`Deterministic "zkapp command, before cliff")
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:2 gen ~f:(fun (ledger_init_state, txn) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_zkapp_commands_at_slot ledger
                Mina_numbers.Global_slot.(succ zero)
                [ txn ] ) )

    let%test_unit "zkApp command, before cliff time, min balance violation" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int 100_000_000_000_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              (* high init min balance, payment amount enough to violate *)
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int 99_000_000_000_000
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                  ; cliff_amount = Currency.Amount.of_int 100
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_int 1_000_000 in
          let amount = Currency.Amount.of_int 10_000_000_000_000 in
          let nonce = Account.Nonce.zero in
          let memo =
            Signed_command_memo.create_from_string_exn
              "zkApp transfer, timed account"
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let receiver_key =
            zkapp_keypair.public_key |> Signature_lib.Public_key.compress
          in
          let (zkapp_command_spec : Transaction_snark.For_tests.Spec.t) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          Transaction_snark.For_tests.multiple_transfers zkapp_command_spec
        in
        return (ledger_init_state, zkapp_command)
      in
      (* slot 1, well before cliffs *)
      Quickcheck.test ~seed:(`Deterministic "zkapp command, before cliff")
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:1 gen ~f:(fun (ledger_init_state, zkapp_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              let _state_body, state_view =
                state_body_and_view_at_slot Mina_numbers.Global_slot.(succ zero)
              in
              let result =
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants ~state_view ledger zkapp_command
              in
              check_zkapp_failure
                Transaction_status.Failure.Source_minimum_balance_violation
                result ) )

    let%test_unit "zkApp command, before cliff time, fee payer fails" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int 100_000_000_000_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              (* high init min balance, payment amount enough to violate *)
              let (timing : Account_timing.t) =
                (* init min balance same as balance, so can't even pay a
                   fee, before considering transfer
                *)
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int 100_000_000_000_000
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                  ; cliff_amount = Currency.Amount.of_int 100
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_int 1_000_000 in
          let amount = Currency.Amount.of_int 10_000_000_000_000 in
          let nonce = Account.Nonce.zero in
          let memo =
            Signed_command_memo.create_from_string_exn
              "zkApp transfer, timed account"
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let receiver_key =
            zkapp_keypair.public_key |> Signature_lib.Public_key.compress
          in
          let (zkapp_command_spec : Transaction_snark.For_tests.Spec.t) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          Transaction_snark.For_tests.multiple_transfers zkapp_command_spec
        in
        return (ledger_init_state, zkapp_command)
      in
      (* slot 1, well before cliffs *)
      Quickcheck.test ~seed:(`Deterministic "zkapp command, before cliff")
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:1 gen ~f:(fun (ledger_init_state, zkapp_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              let _state_body, state_view =
                state_body_and_view_at_slot Mina_numbers.Global_slot.(succ zero)
              in
              match
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants ~state_view ledger zkapp_command
              with
              | Ok _txn_applied ->
                  failwith "Should have failed with min balance violation"
              | Error err ->
                  let err_str = Error.to_string_hum err in
                  (* error is tagged *)
                  if
                    not
                      (String.is_substring err_str
                         ~substring:
                           (Transaction_status.Failure.to_string
                              Source_minimum_balance_violation ) )
                  then failwithf "Unexpected transaction error: %s" err_str () ) )

    let gen_untimed_account_and_create_timed_account ~balance ~min_balance =
      let open Quickcheck.Generator.Let_syntax in
      let untimed =
        let keypair = List.nth_exn keypairs 0 in
        let balance = Currency.Balance.of_int 200_000_000_000_000 in
        let nonce = Mina_numbers.Account_nonce.zero in
        let balance_as_amount = Currency.Balance.to_amount balance in
        (keypair, balance_as_amount, nonce, Account_timing.Untimed)
      in
      let ledger_init_state = Array.of_list [ untimed ] in
      let sender_keypair = List.nth_exn keypairs 0 in
      let zkapp_keypair = Signature_lib.Keypair.create () in
      let fee = 1_000_000 in
      let (create_timed_account_spec : Transaction_snark.For_tests.Spec.t) =
        { sender = (sender_keypair, Account.Nonce.zero)
        ; fee = Currency.Fee.of_int fee
        ; fee_payer = None
        ; receivers = []
        ; amount =
            Option.value_exn
              Currency.Amount.(
                add (of_int balance)
                  (of_fee constraint_constants.account_creation_fee))
        ; zkapp_account_keypairs = [ zkapp_keypair ]
        ; memo =
            Signed_command_memo.create_from_string_exn
              "zkApp create timed account"
        ; new_zkapp_account = true
        ; snapp_update =
            (let timing =
               Zkapp_basic.Set_or_keep.Set
                 ( { initial_minimum_balance =
                       Currency.Balance.of_int min_balance
                   ; cliff_time = Mina_numbers.Global_slot.of_int 1000
                   ; cliff_amount = Currency.Amount.of_int 100_000_000
                   ; vesting_period = Mina_numbers.Global_slot.of_int 10
                   ; vesting_increment = Currency.Amount.of_int 100_000_000
                   }
                   : Account_update.Update.Timing_info.value )
             in
             { Account_update.Update.dummy with timing } )
        ; current_auth = Permissions.Auth_required.Proof
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        ; preconditions = None
        }
      in
      let timed_account_id =
        Account_id.create
          (zkapp_keypair.public_key |> Signature_lib.Public_key.compress)
          Token_id.default
      in
      let zkapp_command, _, _, _ =
        ( Transaction_snark.For_tests.deploy_snapp ~constraint_constants
            create_timed_account_spec
        , timed_account_id
        , create_timed_account_spec.snapp_update
        , zkapp_keypair )
      in
      return (ledger_init_state, zkapp_command)

    let%test_unit "zkApp command, timed account creation, min_balance > balance"
        =
      Quickcheck.test
        ~seed:
          (`Deterministic
            "zkapp command, timed account creation, min_balance > balance" )
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:1
        (gen_untimed_account_and_create_timed_account ~balance:100_000_000
           ~min_balance:100_000_000_000_000 )
        ~f:(fun (ledger_init_state, zkapp_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              let _state_body, state_view =
                state_body_and_view_at_slot Mina_numbers.Global_slot.(succ zero)
              in
              let result =
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants ~state_view ledger zkapp_command
              in
              check_zkapp_failure
                Transaction_status.Failure.Source_minimum_balance_violation
                result ) )

    let%test_unit "zkApp command, account creation, min_balance = balance" =
      Quickcheck.test
        ~seed:
          (`Deterministic
            "zkApp command, account creation, min_balance = balance" )
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:1
        (gen_untimed_account_and_create_timed_account
           ~balance:100_000_000_000_000 ~min_balance:100_000_000_000_000 )
        ~f:(fun (ledger_init_state, zkapp_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_zkapp_commands_at_slot ledger
                Mina_numbers.Global_slot.(succ zero)
                [ zkapp_command ] ) )

    let%test_unit "zkApp command, account creation, min_balance < balance" =
      Quickcheck.test
        ~seed:
          (`Deterministic
            "zkapp command, account creation, min_balance < balace" )
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:1
        (gen_untimed_account_and_create_timed_account
           ~balance:150_000_000_000_000 ~min_balance:100_000_000_000_000 )
        ~f:(fun (ledger_init_state, zkapp_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_zkapp_commands_at_slot ledger
                Mina_numbers.Global_slot.(succ zero)
                [ zkapp_command ] ) )

    let%test_unit "zkApp command, just before cliff time, insufficient balance"
        =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int 100_000_000_000_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int 100_000_000_000_000
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                  ; cliff_amount = Currency.Amount.of_int 100_000_000_000_000
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        (* min balance = balance, spending anything before cliff should trigger min balance violation *)
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_int 1_000_000 in
          let amount = Currency.Amount.of_int 10_000_000_000_000 in
          let nonce = Account.Nonce.zero in
          let memo =
            Signed_command_memo.create_from_string_exn
              "zkApp transfer, timed account"
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let receiver_key =
            zkapp_keypair.public_key |> Signature_lib.Public_key.compress
          in
          let (zkapp_command_spec : Transaction_snark.For_tests.Spec.t) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          Transaction_snark.For_tests.multiple_transfers zkapp_command_spec
        in
        return (ledger_init_state, zkapp_command)
      in
      Quickcheck.test ~seed:(`Deterministic "zkapp command, just before cliff")
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:1 gen ~f:(fun (ledger_init_state, zkapp_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              let _state_body, state_view =
                state_body_and_view_at_slot
                  Mina_numbers.Global_slot.(of_int 9999)
              in
              match
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants ~state_view ledger zkapp_command
              with
              | Ok _txn_applied ->
                  failwith "Should have failed with min balance violation"
              | Error err ->
                  let err_str = Error.to_string_hum err in
                  (* error is tagged *)
                  if
                    not
                      (String.is_substring err_str
                         ~substring:"Source_minimum_balance_violation" )
                  then failwithf "Unexpected transaction error: %s" err_str () ) )

    (* this test is same as last one, except it's exactly at the cliff, and we expect it to succeed
       because the cliff amount makes the whole balance liquid
    *)
    let%test_unit "zkApp command, at cliff time, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int 100_000_000_000_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int 100_000_000_000_000
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                  ; cliff_amount = Currency.Amount.of_int 100_000_000_000_000
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_int 1_000_000 in
          let amount = Currency.Amount.of_int 10_000_000_000_000 in
          let nonce = Account.Nonce.zero in
          let memo =
            Signed_command_memo.create_from_string_exn
              "zkApp transfer, timed account"
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let receiver_key =
            zkapp_keypair.public_key |> Signature_lib.Public_key.compress
          in
          let (zkapp_command_spec : Transaction_snark.For_tests.Spec.t) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          Transaction_snark.For_tests.multiple_transfers zkapp_command_spec
        in
        return (ledger_init_state, zkapp_command)
      in
      Quickcheck.test ~seed:(`Deterministic "zkapp command, at cliff time")
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:1 gen ~f:(fun (ledger_init_state, zkapp_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_zkapp_commands_at_slot ledger
                Mina_numbers.Global_slot.(of_int 10000)
                [ zkapp_command ] ) )

    let%test_unit "zkApp command, while vesting, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let balance_int = 100_000_000_000_000 in
        let init_min_balance_int = 100_000_000_000_000 in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int balance_int in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int init_min_balance_int
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10_000
                  ; cliff_amount = Currency.Amount.zero
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 100_000
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let liquid_balance =
          balance_int - (init_min_balance_int - (100 * 100_000))
        in
        let fee_int = 1_000_000 in
        let amount_int = liquid_balance - fee_int in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_int 1_000_000 in
          let amount = Currency.Amount.of_int amount_int in
          let nonce = Account.Nonce.zero in
          let memo =
            Signed_command_memo.create_from_string_exn
              "zkApp transfer, timed account"
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let receiver_key =
            zkapp_keypair.public_key |> Signature_lib.Public_key.compress
          in
          let (zkapp_command_spec : Transaction_snark.For_tests.Spec.t) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          Transaction_snark.For_tests.multiple_transfers zkapp_command_spec
        in
        return (ledger_init_state, zkapp_command)
      in
      Quickcheck.test ~seed:(`Deterministic "zkapp command, while vesting")
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:1 gen ~f:(fun (ledger_init_state, zkapp_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_zkapp_commands_at_slot ledger
                Mina_numbers.Global_slot.(of_int 10_100)
                [ zkapp_command ] ) )

    let%test_unit "zkApp command, while vesting, insufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let balance_int = 100_000_000_000_000 in
        let init_min_balance_int = 100_000_000_000_000 in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int balance_int in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int init_min_balance_int
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10_000
                  ; cliff_amount = Currency.Amount.zero
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 100_000
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let liquid_balance =
          balance_int - (init_min_balance_int - (100 * 100_000))
        in
        let fee_int = 1_000_000 in
        (* the + 1 breaks the min balance requirement *)
        let amount_int = liquid_balance - fee_int + 1 in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_int 1_000_000 in
          let amount = Currency.Amount.of_int amount_int in
          let nonce = Account.Nonce.zero in
          let memo =
            Signed_command_memo.create_from_string_exn
              "zkApps transfer, timed account"
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let receiver_key =
            zkapp_keypair.public_key |> Signature_lib.Public_key.compress
          in
          let (zkapp_command_spec : Transaction_snark.For_tests.Spec.t) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          Transaction_snark.For_tests.multiple_transfers zkapp_command_spec
        in
        return (ledger_init_state, zkapp_command)
      in
      Quickcheck.test ~seed:(`Deterministic "zkapp command, while vesting")
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:1 gen ~f:(fun (ledger_init_state, zkapp_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              let _state_body, state_view =
                state_body_and_view_at_slot
                  Mina_numbers.Global_slot.(of_int 10_100)
              in
              let result =
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants ~state_view ledger zkapp_command
              in
              check_zkapp_failure
                Transaction_status.Failure.Source_minimum_balance_violation
                result ) )

    let%test_unit "zkApp command, after vesting, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let balance_int = 100_000_000_000_000 in
        let init_min_balance_int = 100_000_000_000_000 in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int balance_int in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int init_min_balance_int
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10_000
                  ; cliff_amount = Currency.Amount.zero
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 1_000_000_000
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let fee_int = 1_000_000 in
        let amount_int = balance_int - fee_int in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_int fee_int in
          let amount = Currency.Amount.of_int amount_int in
          let nonce = Account.Nonce.zero in
          let memo =
            Signed_command_memo.create_from_string_exn
              "zkApp transfer, timed account"
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let receiver_key =
            zkapp_keypair.public_key |> Signature_lib.Public_key.compress
          in
          let (zkapp_command_spec : Transaction_snark.For_tests.Spec.t) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          Transaction_snark.For_tests.multiple_transfers zkapp_command_spec
        in
        return (ledger_init_state, zkapp_command)
      in
      Quickcheck.test ~seed:(`Deterministic "zkapp command, after vesting")
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:1 gen ~f:(fun (ledger_init_state, zkapp_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_zkapp_commands_at_slot ledger
                Mina_numbers.Global_slot.(of_int (100_000 + 10_000))
                [ zkapp_command ] ) )

    (* same as previous test, amount is incremented by 1 *)
    let%test_unit "zkApp command, after vesting, insufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let balance_int = 100_000_000_000_000 in
        let init_min_balance_int = 100_000_000_000_000 in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_int balance_int in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_int init_min_balance_int
                  ; cliff_time = Mina_numbers.Global_slot.of_int 10_000
                  ; cliff_amount = Currency.Amount.zero
                  ; vesting_period = Mina_numbers.Global_slot.of_int 1
                  ; vesting_increment = Currency.Amount.of_int 1_000_000_000
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let fee_int = 1_000_000 in
        (* the + 1 makes the balance insufficient *)
        let amount_int = balance_int - fee_int + 1 in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_int fee_int in
          let amount = Currency.Amount.of_int amount_int in
          let nonce = Account.Nonce.zero in
          let memo =
            Signed_command_memo.create_from_string_exn
              "zkApp transfer, timed account"
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let receiver_key =
            zkapp_keypair.public_key |> Signature_lib.Public_key.compress
          in
          let (zkapp_command_spec : Transaction_snark.For_tests.Spec.t) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          Transaction_snark.For_tests.multiple_transfers zkapp_command_spec
        in
        return (ledger_init_state, zkapp_command)
      in
      Quickcheck.test ~seed:(`Deterministic "zkapp command, after vesting")
        ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
        ~trials:1 gen ~f:(fun (ledger_init_state, zkapp_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              (* slot is cliff + 100,000 slots *)
              let _state_body, state_view =
                state_body_and_view_at_slot
                  Mina_numbers.Global_slot.(of_int (100_000 + 10_000))
              in
              let result =
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants ~state_view ledger zkapp_command
              in
              check_zkapp_failure Transaction_status.Failure.Overflow result ) )

    let%test_unit "zkApp command, create timed account with wrong authorization"
        =
      let ledger_init_state =
        List.map keypairs ~f:(fun keypair ->
            let balance = Currency.Amount.of_int 100_000_000_000_000 in
            let nonce = Mina_numbers.Account_nonce.zero in
            (keypair, balance, nonce, Account_timing.Untimed) )
        |> Array.of_list
      in
      let sender_keypair = List.hd_exn keypairs in
      let zkapp_keypair = Signature_lib.Keypair.create () in
      let (create_timed_account_spec : Transaction_snark.For_tests.Spec.t) =
        { sender = (sender_keypair, Account.Nonce.zero)
        ; fee = Currency.Fee.of_int 1_000_000
        ; fee_payer = None
        ; receivers = []
        ; amount = Currency.Amount.of_int 50_000_000_000_000
        ; zkapp_account_keypairs = [ zkapp_keypair ]
        ; memo =
            Signed_command_memo.create_from_string_exn
              "zkApp create timed account"
        ; new_zkapp_account = true
        ; snapp_update =
            (let timing =
               Zkapp_basic.Set_or_keep.Set
                 ( { initial_minimum_balance =
                       Currency.Balance.of_int 1_000_000_000
                   ; cliff_time = Mina_numbers.Global_slot.of_int 10
                   ; cliff_amount = Currency.Amount.of_int 1_000_000_000
                   ; vesting_period = Mina_numbers.Global_slot.of_int 10
                   ; vesting_increment = Currency.Amount.of_int 1_000_000_000
                   }
                   : Account_update.Update.Timing_info.value )
             in
             { Account_update.Update.dummy with timing } )
        ; current_auth = Permissions.Auth_required.Proof
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        ; preconditions = None
        }
      in
      let timing_account_id =
        Account_id.create
          (zkapp_keypair.public_key |> Signature_lib.Public_key.compress)
          Token_id.default
      in
      let create_timed_account_zkapp_command, _, _, _ =
        ( Transaction_snark.For_tests.deploy_snapp ~no_auth:true
            ~constraint_constants create_timed_account_spec
        , timing_account_id
        , create_timed_account_spec.snapp_update
        , zkapp_keypair )
      in
      let gen =
        Quickcheck.Generator.return
          (ledger_init_state, create_timed_account_zkapp_command)
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          Async.Quickcheck.async_test
            ~seed:
              (`Deterministic
                "zkapp command, create timed account with wrong authorization"
                )
            ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
            ~trials:1 gen
            ~f:(fun (ledger_init_state, create_timed_account_zkapp_command) ->
              let ledger =
                Mina_ledger.Ledger.create
                  ~depth:constraint_constants.ledger_depth ()
              in
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              Transaction_snark_tests.Util.check_zkapp_command_with_merges_exn
                ~expected_failure:
                  Transaction_status.Failure
                  .Update_not_permitted_timing_existing_account ledger
                [ create_timed_account_zkapp_command ] ) )

    let%test_unit "zkApp command, change untimed account to timed" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Backtrace.elide := false ;
          let ledger_init_state =
            List.map keypairs ~f:(fun keypair ->
                let balance = Currency.Amount.of_int 100_000_000_000_000 in
                let nonce = Mina_numbers.Account_nonce.zero in
                (keypair, balance, nonce, Account_timing.Untimed) )
            |> Array.of_list
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let (update_timing_spec : Transaction_snark.For_tests.Spec.t) =
            { sender = (sender_keypair, Account.Nonce.zero)
            ; fee = Currency.Fee.of_int 1_000_000
            ; fee_payer = None
            ; receivers = []
            ; amount = Currency.Amount.zero
            ; zkapp_account_keypairs = [ zkapp_keypair ]
            ; memo =
                Signed_command_memo.create_from_string_exn "zkApp update timing"
            ; new_zkapp_account = false
            ; snapp_update =
                (let timing =
                   Zkapp_basic.Set_or_keep.Set
                     ( { initial_minimum_balance =
                           Currency.Balance.of_int 1_000_000_000
                       ; cliff_time = Mina_numbers.Global_slot.of_int 10
                       ; cliff_amount = Currency.Amount.of_int 1_000_000_000
                       ; vesting_period = Mina_numbers.Global_slot.of_int 10
                       ; vesting_increment =
                           Currency.Amount.of_int 1_000_000_000
                       }
                       : Account_update.Update.Timing_info.value )
                 in
                 { Account_update.Update.dummy with timing } )
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          let open Async.Deferred.Let_syntax in
          let%bind update_timing_zkapp_command =
            Transaction_snark.For_tests.update_states ~constraint_constants
              update_timing_spec
          in
          let gen =
            Quickcheck.Generator.return
              (ledger_init_state, update_timing_zkapp_command)
          in
          Async.Quickcheck.async_test
            ~seed:
              (`Deterministic
                "zkapp command, change untimed account to timed account" )
            ~sexp_of:[%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
            ~trials:1 gen
            ~f:(fun (ledger_init_state, update_timing_zkapp_command) ->
              let ledger =
                Mina_ledger.Ledger.create
                  ~depth:constraint_constants.ledger_depth ()
              in
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              Transaction_snark_tests.Util.check_zkapp_command_with_merges_exn
                ledger
                [ update_timing_zkapp_command ] ) )

    let%test_unit "zkApp command, invalid update for timed account" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let ledger_init_state =
            List.mapi keypairs ~f:(fun i keypair ->
                let balance = Currency.Amount.of_int 100_000_000_000_000 in
                let nonce = Mina_numbers.Account_nonce.zero in
                ( keypair
                , balance
                , nonce
                , if i = 1 then
                    Account_timing.Timed
                      { initial_minimum_balance =
                          Currency.Balance.of_int 10_000_000_000
                      ; cliff_time = Mina_numbers.Global_slot.of_int 10_000
                      ; cliff_amount = Currency.Amount.zero
                      ; vesting_period = Mina_numbers.Global_slot.of_int 1
                      ; vesting_increment = Currency.Amount.of_int 100_000
                      }
                  else Account_timing.Untimed ) )
            |> Array.of_list
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let (update_timing_spec : Transaction_snark.For_tests.Spec.t) =
            { sender = (sender_keypair, Account.Nonce.zero)
            ; fee = Currency.Fee.of_int 1_000_000
            ; fee_payer = None
            ; receivers = []
            ; amount = Currency.Amount.zero
            ; zkapp_account_keypairs = [ zkapp_keypair ]
            ; memo =
                Signed_command_memo.create_from_string_exn "zkApp update timing"
            ; new_zkapp_account = false
            ; snapp_update =
                (let timing =
                   Zkapp_basic.Set_or_keep.Set
                     ( { initial_minimum_balance =
                           Currency.Balance.of_int 1_000_000_000
                       ; cliff_time = Mina_numbers.Global_slot.of_int 10
                       ; cliff_amount = Currency.Amount.of_int 1_000_000_000
                       ; vesting_period = Mina_numbers.Global_slot.of_int 10
                       ; vesting_increment =
                           Currency.Amount.of_int 1_000_000_000
                       }
                       : Account_update.Update.Timing_info.value )
                 in
                 { Account_update.Update.dummy with timing } )
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          let open Async.Deferred.Let_syntax in
          let%map update_timing_zkapp_command =
            Transaction_snark.For_tests.update_states ~constraint_constants
              update_timing_spec
          in
          let gen =
            Quickcheck.Generator.return
              (ledger_init_state, update_timing_zkapp_command)
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              Async.Quickcheck.async_test
                ~seed:
                  (`Deterministic
                    "zkapp command, invalid update for timed account" )
                ~sexp_of:
                  [%sexp_of: Mina_ledger.Ledger.init_state * Zkapp_command.t]
                ~trials:1 gen
                ~f:(fun (ledger_init_state, update_timing_zkapp_command) ->
                  let ledger =
                    Mina_ledger.Ledger.create
                      ~depth:constraint_constants.ledger_depth ()
                  in
                  Mina_ledger.Ledger.apply_initial_ledger_state ledger
                    ledger_init_state ;

                  Transaction_snark_tests.Util
                  .check_zkapp_command_with_merges_exn
                    ~expected_failure:
                      Transaction_status.Failure
                      .Update_not_permitted_timing_existing_account ledger
                    [ update_timing_zkapp_command ] ) ) )
  end )
