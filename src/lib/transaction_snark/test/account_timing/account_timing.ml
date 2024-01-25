open Core
open Currency
open Snark_params
open Tick
open Signature_lib
open Mina_base

(* Timed accounts start with some amount of funds frozen and release them
   gradually over time according to the vesting schedule. See
   mina_base/account_timing.ml module for details.

   This module tests that checked and unchecked computations for timed
   accounts always yield the same results. *)
let%test_module "account timing check" =
  ( module struct
    open Mina_ledger.Ledger.For_tests

    let account_with_default_vesting_schedule ?(token = Token_id.default)
        ?(initial_minimum_balance = Balance.of_mina_int_exn 10_000)
        ?(cliff_amount = Amount.zero)
        ?(cliff_time = Mina_numbers.Global_slot_since_genesis.of_int 1000)
        ?(vesting_period = Mina_numbers.Global_slot_span.of_int 10)
        ?(vesting_increment = Amount.of_mina_int_exn 100) balance =
      let pk = Public_key.Compressed.empty in
      let account_id = Account_id.create pk token in
      Or_error.ok_exn
      @@ Account.create_timed account_id balance ~initial_minimum_balance
           ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment

    let checked_min_balance_and_timing account txn_amount txn_global_slot =
      let account = Account.var_of_t account in
      let txn_amount = Amount.var_of_t txn_amount in
      let txn_global_slot =
        Mina_numbers.Global_slot_since_genesis.Checked.constant txn_global_slot
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

    let run_checked_timing_and_compare account txn_amount txn_global_slot
        unchecked_timing unchecked_min_balance =
      let equal_balances_computation =
        let%bind checked_min_balance, checked_timing =
          checked_min_balance_and_timing account txn_amount txn_global_slot
        in
        (* check agreement of timings produced by checked, unchecked validations *)
        let%bind () =
          as_prover
            As_prover.(
              let%map checked_timing = read Account.Timing.typ checked_timing in
              assert (Account.Timing.equal checked_timing unchecked_timing))
        in
        let%map equal_balances_checked =
          Balance.Checked.equal checked_min_balance
            (Balance.var_of_t unchecked_min_balance)
        in
        Snarky_backendless.As_prover0.read Tick.Boolean.typ
          equal_balances_checked
      in
      Or_error.ok_exn @@ Tick.run_and_check equal_balances_computation

    (* confirm the checked computation fails *)
    let checked_timing_should_fail account txn_amount txn_global_slot =
      let checked_timing_computation =
        let%map checked_timing =
          make_checked_timing_computation account txn_amount txn_global_slot
        in
        As_prover.read Account.Timing.typ checked_timing
      in
      Or_error.is_error @@ Tick.run_and_check checked_timing_computation

    (* Funds above the current minimum balance may be spent.

       Check a transaction of 100 mina from a timed account whose
       cliff time has not yet passed, but which still has 20_000 mina
       available. Since the deduced amount is less than available
       funds, this transaction is expected to succeed. *)
    let%test "before_cliff_time" =
      let txn_amount = Currency.Amount.of_mina_int_exn 100 in
      let txn_global_slot = Mina_numbers.Global_slot_since_genesis.of_int 45 in
      let account =
        account_with_default_vesting_schedule
          ~initial_minimum_balance:(Balance.of_mina_int_exn 80_000)
          ~cliff_amount:(Amount.of_nanomina_int_exn 500_000_000)
          (Balance.of_mina_int_exn 100_000)
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

    (* Account remains timed until the vesting schedule is complete.

       Set up an account with a vesting period of 10 slots and a cliff
       time of 1,000 slots. The initial minimum balance is 10,000 mina
       and at each vesting period 100 mina is released, which means
       the account takes 100 vesting periods, i.e. 1,000 slots to
       unlock all its funds. Verify that at slot 1,900, which is 90
       vesting periods after the cliff time, the account is still
       timed. The account's funds are far more than sufficient to make
       a transaction of 100 mina, even disregarding the vesting
       schedule. *)
    let%test "positive min balance" =
      let account =
        account_with_default_vesting_schedule (Balance.of_mina_int_exn 100_000)
      in
      let txn_amount = Currency.Amount.of_mina_int_exn 100 in
      let txn_global_slot =
        Mina_numbers.Global_slot_since_genesis.of_int 1_900
      in
      let timing_with_min_balance =
        validate_timing_with_min_balance ~account
          ~txn_amount:(Currency.Amount.of_mina_int_exn 100)
          ~txn_global_slot:(Mina_numbers.Global_slot_since_genesis.of_int 1_900)
      in
      match timing_with_min_balance with
      | Ok ((Timed _ as unchecked_timing), `Min_balance unchecked_min_balance)
        ->
          run_checked_timing_and_compare account txn_amount txn_global_slot
            unchecked_timing unchecked_min_balance
      | _ ->
          false

    (* Account becomes untimed after vesting schedule is complete.

       Create a timed account with cliff time of 1,000 slots and a
       vesting period of 10 slots. Initial minimum balance is 10,000
       mina and the account releases 0.9 mina at the cliff time and
       additional 100 mina at each vesting period. This means all
       funds should be released at slot 2,000. Verify that after slot
       2,000 the account is untimed. The funds are far more than
       sufficient to perform the transaction of 100 mina, even
       disregarding the vesting schedule. *)
    let%test "curr min balance of zero" =
      let account =
        account_with_default_vesting_schedule
          ~cliff_amount:(Amount.of_nanomina_int_exn 900_000_000)
          (Balance.of_mina_int_exn 100_000)
      in
      let txn_amount = Currency.Amount.of_mina_int_exn 100 in
      let txn_global_slot =
        Mina_numbers.Global_slot_since_genesis.of_int 2_000
      in
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

    (* Timed account's balance cannot fall below current minimum.

       Vesting schedule begins at slot 1,000 and releases 100 mina
       every 10 slots. With minimum initial balance of 10,000 mina and
       the total balance of 10,000 mina also this means at slot 1,010
       the account has only 100 mina available. Therefore a
       transaction of 101 mina is expected to fail. *)
    let%test "below calculated min balance" =
      let account =
        account_with_default_vesting_schedule (Balance.of_mina_int_exn 10_000)
      in
      let txn_amount = Currency.Amount.of_mina_int_exn 101 in
      let txn_global_slot =
        Mina_numbers.Global_slot_since_genesis.of_int 1_010
      in
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

    (* Balance cannot fall below 0.

       From a timed account with balance of 100,000 mina make a transaction
       of 100,001 mina. This cannot succeed, even if the vesting schedule was
       over. *)
    let%test "insufficient balance" =
      let account =
        account_with_default_vesting_schedule (Balance.of_mina_int_exn 100_000)
      in
      let txn_amount = Currency.Amount.of_mina_int_exn 100_001 in
      let txn_global_slot =
        Mina_numbers.Global_slot_since_genesis.of_int 2_000_000_000_000
      in
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

    (* When vesting schedule is complete, all funds may be spent freely.

       Set up an account with initial minimum balance of 10,000 mina,
       which releases 100 mina every 10 slots. Since cliff time is 1,000
       slots, this means that all funds become available at slot 2,000.
       Verify that at slot 3,000 all 100,000 mina of the account's balance
       may be spent successfully. *)
    let%test "past full vesting" =
      let account =
        account_with_default_vesting_schedule (Balance.of_mina_int_exn 100_000)
      in
      let txn_amount = Currency.Amount.of_mina_int_exn 100_000 in
      let txn_global_slot =
        Mina_numbers.Global_slot_since_genesis.of_int 3000
      in
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
      let account =
        account_with_default_vesting_schedule
          ~cliff_amount:(Amount.of_mina_int_exn 10_000)
            (* The same as initial minimum balance. *)
          ~vesting_period:(Mina_numbers.Global_slot_span.of_int 1)
          ~vesting_increment:Amount.zero
          (Balance.of_mina_int_exn 100_000)
      in
      let txn_amount = Currency.Amount.of_mina_int_exn 100_000 in
      let txn_global_slot =
        Mina_numbers.Global_slot_since_genesis.of_int slot
      in
      (txn_amount, txn_global_slot, account)

    (* Before the cliff, only the initial_minimum_balance matters.

       Assert that before the cliff, the neither cliff_amount nor
       any vesting increments are released from the timed account. *)
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

    (* Exactly at cliff_time, the cliff amount is released.

       At the cliff_time slot, the cliff_amount and only the cliff_amount
       is released and can be spent.*)
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

    let check_transaction_snark
        ~(txn_global_slot : Mina_numbers.Global_slot_since_genesis.t)
        (sparse_ledger_before : Mina_ledger.Sparse_ledger.t)
        (transaction : Mina_transaction.Transaction.t) =
      let sok_message =
        Sok_message.create ~fee:Currency.Fee.zero
          ~prover:
            Public_key.(compress (of_private_key_exn (Private_key.create ())))
      in
      let state_body = Transaction_snark_tests.Util.genesis_state_body in
      let txn_state_view = Transaction_snark_tests.Util.genesis_state_view in
      let validated_transaction : Mina_transaction.Transaction.Valid.t =
        match transaction with
        | Command (Signed_command uc) ->
            Mina_transaction.Transaction.Command
              (User_command.Signed_command (validate_user_command uc))
        | _ ->
            failwith "Expected signed user command"
      in
      let state_body_hash = Mina_state.Protocol_state.Body.hash state_body in
      let sparse_ledger_after, txns_applied =
        Mina_ledger.Sparse_ledger.apply_transactions ~constraint_constants
          ~global_slot:txn_global_slot ~txn_state_view sparse_ledger_before
          [ transaction ]
        |> Or_error.ok_exn
      in
      let txn_applied = List.hd_exn txns_applied in
      let coinbase_stack_target =
        let stack_with_state =
          Pending_coinbase.Stack.(
            push_state state_body_hash txn_global_slot
              Pending_coinbase.Stack.empty)
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
        ~source_first_pass_ledger:
          (Mina_ledger.Sparse_ledger.merkle_root sparse_ledger_before)
        ~target_first_pass_ledger:
          (Mina_ledger.Sparse_ledger.merkle_root sparse_ledger_after)
        ~init_stack:Pending_coinbase.Stack.empty
        ~pending_coinbase_stack_state:
          { source = Pending_coinbase.Stack.empty
          ; target = coinbase_stack_target
          }
        ~supply_increase
        { Transaction_protocol_state.Poly.block_data = state_body
        ; transaction = validated_transaction
        ; global_slot = txn_global_slot
        }
        (unstage (Mina_ledger.Sparse_ledger.handler sparse_ledger_before))

    let apply_user_commands_at_slot ledger slot ?expected_failure_status
        ?(expected_rejection = false)
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
                Mina_transaction.Transaction.accounts_referenced txn
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
                  | Applied -> (
                      match expected_failure_status with
                      | None ->
                          ()
                      | Some failure ->
                          failwithf
                            "Transaction applied without failures but expected \
                             to failwith with %s"
                            (Transaction_status.Failure.to_string failure)
                            () )
                  | Failed failuress -> (
                      let failures_str =
                        List.map (List.concat failuress) ~f:(fun failure ->
                            Transaction_status.Failure.to_string failure )
                        |> String.concat ~sep:","
                      in
                      match expected_failure_status with
                      | Some expected_failure ->
                          if
                            not
                              Transaction_status.Failure.(
                                equal
                                  (List.concat failuress |> List.hd_exn)
                                  expected_failure)
                          then
                            failwithf
                              "Expected transaction to fail with %s but failed \
                               with %s"
                              Transaction_status.Failure.(
                                to_string expected_failure)
                              failures_str ()
                      | None ->
                          failwithf
                            "Transaction expected to be applied successfully \
                             but failed with %s"
                            failures_str () ) ) ;
                  check_transaction_snark ~txn_global_slot:slot
                    sparse_ledger_before txn
              | Error err -> (
                  (*transaction snark should fail as well*)
                  try
                    check_transaction_snark ~txn_global_slot:slot
                      sparse_ledger_before txn ;
                    failwith
                      "transaction snark successful for a failing transaction"
                  with _exn ->
                    () ;
                    if not expected_rejection then
                      failwithf "Error when applying transaction: %s"
                        (Error.to_string_hum err) () ) )
          : unit list )

    (* In tests below: where we expect payments to succeed, we use real
       signatures (`Real). Otherwise we use fake signatures. *)

    (* Before cliff time transactions succeed when there's enough funds.

       Generate a bunch of transactions of 10 mina (see amount below) from accounts
       with 10,000 mina balance and 50 mina minimum balance. Use real key pairs
       to sign transactions (see ~sign_type:`Real below) so that they succeed. *)
    let%test_unit "user commands, before cliff time, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_mina_int_exn 10_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 50
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.of_nanomina_int_exn 100
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
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
                Mina_numbers.Global_slot_since_genesis.(succ zero)
                user_commands ) )

    (* Before cliff, transactions fail if they would have to violate minimum
       balance.

       Generate a bunch of transactions of 100 mina from accounts with
       balance of 10,000 mina and initial minimum balance of 9,995
       mina before their cliff time (5 mina is available for spending).
       We expect these transactions to fail, so we use fake signatures,
       but still we check the error to make sure transactions failed
       because of the balance issue. *)
    let%test_unit "user command, before cliff time, min balance violation" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        (* high init min balance, payment amount enough to violate *)
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_mina_int_exn 10_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 9_995
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.of_nanomina_int_exn 100
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
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
              apply_user_commands_at_slot ledger
                Mina_numbers.Global_slot_since_genesis.(succ zero)
                ~expected_rejection:true
                [ Mina_transaction.Transaction.Command (Signed_command uc) ] ) )

    (* Just before cliff, transactions still fail if they'd violate minimum
       balance.

       Just as above create a bunch of transactions of 100 mina from accounts
       having only 5 mina available. Because it's slot 9_999, while the cliff
       time is 10,000, this results in
       Source_minimum_balance_violation error. Using fake signatures. *)
    let%test_unit "user command, just before cliff time, insufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_mina_int_exn 10_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 9_995
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.of_mina_int_exn 9_995
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let amount = 100_000_000_000 in
        let%map user_command =
          Signed_command.Gen.payment ~sign_type:`Real
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
              apply_user_commands_at_slot ledger
                (Mina_numbers.Global_slot_since_genesis.of_int 9999)
                ~expected_rejection:true
                [ Mina_transaction.Transaction.Command
                    (Signed_command user_command)
                ] ) )

    (* At cliff time, the cliff amount is released and may be immediately
       spent.

       Transactions of 100 mina from accounts having 10,000 mina, 9,995
       of which is vested immediately at cliff time. Therefore these
       transactions made at cliff slot are expected to succeed. *)
    let%test_unit "user command, at cliff time, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_mina_int_exn 10_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 9_995
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10000
                  ; cliff_amount = Currency.Amount.of_mina_int_exn 9_995
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
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
                (Mina_numbers.Global_slot_since_genesis.of_int 10000)
                [ user_command ] ) )

    let%test_unit "user command, while vesting, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let init_min_bal_int = 9_995_000_000_000 in
        let balance_int = 10_000_000_000_000 in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_nanomina_int_exn balance_int in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_nanomina_int_exn init_min_bal_int
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.zero
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
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
          - Fee.to_nanomina_int Currency.Fee.minimum_user_command_fee
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
                (Mina_numbers.Global_slot_since_genesis.of_int 10100)
                [ user_command ] ) )

    let%test_unit "user command, after vesting, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_mina_int_exn 10_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 9_995
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10000
                  ; cliff_amount = Currency.Amount.of_mina_int_exn 9_995
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
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
                Mina_numbers.Global_slot_since_genesis.(of_int 20_000)
                [ user_command ] ) )

    let%test_unit "user command, after vesting, insufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_mina_int_exn 10_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 9_995
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10000
                  ; cliff_amount = Currency.Amount.of_mina_int_exn 9_995
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let amount = 100_000_000_000_000 in
        let%map user_command =
          Signed_command.Gen.payment ~sign_type:`Real
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
              (* slot well past cliff *)
              apply_user_commands_at_slot ledger
                (Mina_numbers.Global_slot_since_genesis.of_int 200_000)
                ~expected_rejection:true
                [ Mina_transaction.Transaction.Command
                    (Signed_command user_command)
                ] ) )

    let%test_unit "Payment- fee more than available min balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_mina_int_exn 10_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 10_000
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.of_mina_int_exn 9_995
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let amount = 20 in
        let%map user_command =
          Signed_command.Gen.payment ~sign_type:`Real
            ~key_gen:(return @@ List.hd_exn keypairss)
            ~min_amount:amount ~max_amount:amount ~fee_range:5 ()
        in
        (ledger_init_state, user_command)
      in
      Quickcheck.test
        ~seed:(`Deterministic "Payment- fee more than available min balance")
        ~trials:1 gen ~f:(fun (ledger_init_state, user_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              (* slot before cliff, insufficient fund to pay fee *)
              apply_user_commands_at_slot ledger
                (Mina_numbers.Global_slot_since_genesis.of_int 9_000)
                ~expected_rejection:true
                [ Mina_transaction.Transaction.Command
                    (Signed_command user_command)
                ] ) )

    let%test_unit "Payment- amount more than available min balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_mina_int_exn 0 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 10_000
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.of_mina_int_exn 9_995
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let amount = 10_000_000_000_000 in
        let%map user_command =
          Signed_command.Gen.payment ~sign_type:`Real
            ~key_gen:(return @@ List.hd_exn keypairss)
            ~min_amount:amount ~max_amount:amount ~fee_range:0 ()
        in
        (ledger_init_state, user_command)
      in
      Quickcheck.test
        ~seed:(`Deterministic "Payment- amount more than available min balance")
        ~trials:1 gen ~f:(fun (ledger_init_state, user_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_user_commands_at_slot ledger
                (Mina_numbers.Global_slot_since_genesis.of_int 10_000)
                ~expected_rejection:true
                [ Mina_transaction.Transaction.Command
                    (Signed_command user_command)
                ] ) )

    let%test_unit "Payment- sufficient amount; fee payer goes from timed to \
                   untimed; receiver remains untimed" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let sender_index = 0 in
        let ledger_init_state =
          List.mapi keypairs ~f:(fun i keypair ->
              let balance = Currency.Balance.of_mina_int_exn 9_995 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                if i = sender_index then
                  Timed
                    { initial_minimum_balance =
                        Currency.Balance.of_mina_int_exn 10_000
                    ; cliff_time =
                        Mina_numbers.Global_slot_since_genesis.of_int 10_000
                    ; cliff_amount = Currency.Amount.of_mina_int_exn 9_995
                    ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                    ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
                    }
                else Untimed
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let amount = 1_000 in
        let%map user_command =
          Signed_command.Gen.payment ~sign_type:`Real
            ~key_gen:(return @@ List.hd_exn keypairss)
            ~min_amount:amount ~max_amount:amount ~fee_range:0 ()
        in
        (ledger_init_state, user_command)
      in
      Quickcheck.test
        ~seed:
          (`Deterministic
            "Payment- sufficient amount; fee payer goes from timed to untimed; \
             receiver remains untimed" ) ~trials:1 gen
        ~f:(fun (ledger_init_state, user_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_user_commands_at_slot ledger
                (Mina_numbers.Global_slot_since_genesis.of_int 11_000)
                [ Mina_transaction.Transaction.Command
                    (Signed_command user_command)
                ] ) )

    let%test_unit "Payment- sufficient amount; receiver goes from timed to \
                   untimed; fee payer remains untimed" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let receiver_index = 1 in
        let ledger_init_state =
          List.mapi keypairs ~f:(fun i keypair ->
              let balance = Currency.Balance.of_mina_int_exn 9_995 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                if i = receiver_index then
                  Timed
                    { initial_minimum_balance =
                        Currency.Balance.of_mina_int_exn 10_000
                    ; cliff_time =
                        Mina_numbers.Global_slot_since_genesis.of_int 10_000
                    ; cliff_amount = Currency.Amount.of_mina_int_exn 9_995
                    ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                    ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
                    }
                else Untimed
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let amount = 1_000 in
        let%map user_command =
          Signed_command.Gen.payment ~sign_type:`Real
            ~key_gen:(return @@ List.hd_exn keypairss)
            ~min_amount:amount ~max_amount:amount ~fee_range:0 ()
        in
        (ledger_init_state, user_command)
      in
      Quickcheck.test
        ~seed:
          (`Deterministic
            "Payment- sufficient amount; receiver goes from timed to untimed; \
             fee payer remains untimed" ) ~trials:1 gen
        ~f:(fun (ledger_init_state, user_command) ->
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              apply_user_commands_at_slot ledger
                (Mina_numbers.Global_slot_since_genesis.of_int 11_000)
                [ Mina_transaction.Transaction.Command
                    (Signed_command user_command)
                ] ) )

    let%test_module "test user commands on timed accounts" =
      ( module struct
        (* This represents the initial conditions of a test
           scenario. Defines the account's timing and the transaction
           details. This is generally randomised by Quickcheck, but
           there are also a couple of fixed cases.

           Check out how available_funds are computed in order to learn
           the mechanics of a timed account.

           The module Account_timing in transaction_lib tests tests the
           raw rules of account timing. See that for the invariants that
           should hold. Here, timed accounts' behaviour is tested within
           a ledger building actual transactions. *)
        type t =
          { balance : Currency.Balance.t
          ; init_min_bal : Currency.Balance.t
          ; cliff_time : Mina_numbers.Global_slot_since_genesis.t
          ; cliff_amt : Currency.Amount.t
          ; vest_period : Mina_numbers.Global_slot_span.t
          ; vest_incr : Currency.Amount.t
          ; slot : Mina_numbers.Global_slot_since_genesis.t
          ; available_funds : Currency.Amount.t
          ; cmd : Signed_command.t
          }
        [@@deriving sexp]

        let gen ?balance ?init_min_bal ?cliff_time ?cliff_amt ?vest_period
            ?vest_incr ?slot ?amount () : t Quickcheck.Generator.t =
          let open Mina_numbers in
          let open Currency in
          let open Quickcheck.Generator.Let_syntax in
          let unless_fixed (type a) ?(fixed : a option)
              (gen : a Quickcheck.Generator.t) =
            match fixed with Some value -> return value | None -> gen
          in
          let%bind balance =
            unless_fixed ?fixed:balance
              Balance.(
                gen_incl (of_mina_int_exn 1_000) (of_mina_int_exn 50_000))
          in
          let%bind init_min_bal =
            unless_fixed ?fixed:init_min_bal
              Balance.(gen_incl (of_mina_int_exn 1_000) balance)
          in
          let init_min_amt = Currency.Balance.to_amount init_min_bal in
          let%bind cliff_time =
            unless_fixed ?fixed:cliff_time
              Global_slot_since_genesis.(gen_incl (of_int 100) (of_int 1_000))
          in
          let%bind cliff_amt =
            unless_fixed ?fixed:cliff_amt Amount.(gen_incl zero init_min_amt)
          in
          let%bind vest_period =
            unless_fixed ?fixed:vest_period
              Global_slot_span.(gen_incl (of_int 1) (of_int 20))
          in
          let to_vest =
            Amount.(
              Option.value ~default:zero @@ (init_min_amt - cliff_amt)
              |> to_nanomina_int)
          in
          (* A numeric trick to get the division result rounded up instead of down. *)
          let div_rnd_up num denom = (num + denom - 1) / denom in
          let%bind vest_incr =
            unless_fixed ?fixed:vest_incr
              Amount.(
                gen_incl
                  (of_nanomina_int_exn @@ div_rnd_up to_vest 100)
                  (of_nanomina_int_exn @@ div_rnd_up to_vest 10))
          in
          let vest_time =
            if Amount.(vest_incr > zero) then
              Global_slot_span.to_int vest_period
              * (to_vest / Amount.to_nanomina_int vest_incr)
            else 0
          in
          let%bind slot =
            unless_fixed ?fixed:slot
              Global_slot_since_genesis.(
                gen_incl
                  (of_int @@ Int.max 0 (to_int cliff_time - vest_time))
                  (of_int @@ (to_int cliff_time + (2 * vest_time))))
          in
          let available_funds =
            let open Currency in
            let slot_int = Mina_numbers.Global_slot_since_genesis.to_int slot in
            let cliff_int =
              Mina_numbers.Global_slot_since_genesis.to_int cliff_time
            in
            let vested_cliff_amt =
              if slot_int < cliff_int then Amount.zero else cliff_amt
            in
            let vested =
              max 0 (slot_int - cliff_int)
              / Mina_numbers.Global_slot_span.to_int vest_period
              |> Amount.scale vest_incr
              |> Option.value ~default:Amount.max_int
            in
            let total =
              let open Option.Let_syntax in
              let open Amount in
              let%bind init = Balance.to_amount balance - init_min_amt in
              let%bind with_cliff = init + vested_cliff_amt in
              with_cliff + vested
            in
            Amount.min
              (Balance.to_amount balance)
              (Option.value ~default:Amount.zero total)
          in
          let min_amount, max_amount =
            match amount with
            | None ->
                Amount.
                  ( available_funds - of_mina_int_exn 100
                    |> Option.value ~default:zero |> to_nanomina_int
                  , available_funds + of_mina_int_exn 100
                    |> Option.value ~default:zero |> to_nanomina_int )
            | Some a ->
                let i = Amount.to_nanomina_int a in
                (i, i)
          in
          let%bind cmd =
            Signed_command.Gen.payment ~sign_type:`Real
              ~key_gen:(return @@ List.hd_exn keypairss)
              ~min_amount ~max_amount ~fee_range:0 ()
          in
          return
            { balance
            ; init_min_bal
            ; cliff_time
            ; cliff_amt
            ; vest_period
            ; vest_incr
            ; slot
            ; available_funds
            ; cmd
            }

        (* We want to preset a couple of specific testing scenarios to
           be extra sure that everything is working. *)
        let examples =
          let open Mina_numbers in
          let balance = Balance.of_mina_int_exn 10_000 in
          let cliff_time = Global_slot_since_genesis.of_int 10_000 in
          [ (* Before cliff only balance in excess of the initial minimum may be spent. *)
            Quickcheck.random_value
            @@ gen ~balance ~cliff_time
                 ~init_min_bal:(Balance.of_mina_int_exn 50)
                 ~slot:(Global_slot_since_genesis.of_int 1)
                 ~amount:(Amount.of_mina_int_exn 10)
                 ()
          ; (* Before cliff time funds below the minimum balance cannot be spent. *)
            Quickcheck.random_value
            @@ gen ~balance ~cliff_time
                 ~init_min_bal:(Balance.of_mina_int_exn 9_995)
                 ~slot:(Global_slot_since_genesis.of_int 1)
                 ~amount:(Amount.of_mina_int_exn 100)
                 ()
          ; (* Just before cliff the balance still can't fall below the minimum. *)
            Quickcheck.random_value
            @@ gen ~balance ~cliff_time
                 ~init_min_bal:(Balance.of_mina_int_exn 9_995)
                 ~slot:(Global_slot_since_genesis.of_int 9_999)
                 ~amount:(Amount.of_mina_int_exn 100)
                 ()
          ; (* At cliff time the cliff amount may immediately be spent. *)
            Quickcheck.random_value
            @@ gen ~balance ~cliff_time
                 ~cliff_amt:(Amount.of_mina_int_exn 9_995)
                 ~init_min_bal:(Balance.of_mina_int_exn 9_995)
                 ~slot:cliff_time
                 ~amount:(Amount.of_mina_int_exn 100)
                 ()
          ; (* After vesting is finished, everything may be spent. *)
            Quickcheck.random_value
            @@ gen ~balance ~cliff_time
                 ~cliff_amt:(Amount.of_mina_int_exn 9_995)
                 ~init_min_bal:(Balance.of_mina_int_exn 9_995)
                 ~slot:(Global_slot_since_genesis.of_int 20_000)
                 ~amount:(Amount.of_mina_int_exn 9_000)
                 ()
          ; (* After vesting, still can't spend more than the current balance. *)
            Quickcheck.random_value
            @@ gen ~balance ~cliff_time
                 ~cliff_amt:(Amount.of_mina_int_exn 9_995)
                 ~init_min_bal:(Balance.of_mina_int_exn 9_995)
                 ~slot:(Global_slot_since_genesis.of_int 200_000)
                 ~amount:(Amount.of_mina_int_exn 100_000)
                 ()
          ]

        (* Examine the initial conditions in order to determine
           whether we should expect the transaction to succeed or
           fail. Note that we first check that the fee alone can be
           spent and only then we check the amount + fee. This is
           because apparently the fee gets spent first and can fail
           independently from the main transaction amount (which
           results in a different error message). *)
        let expected_failure { available_funds; balance; cmd; _ } =
          let open Currency.Amount in
          let amount =
            Option.value ~default:zero @@ Signed_command.amount cmd
          in
          let fee =
            Currency.Fee.to_uint64 Currency.Fee.minimum_user_command_fee
            |> of_uint64
          in
          let total = Option.value ~default:max_int (amount + fee) in
          let bal = Balance.to_amount balance in
          if fee > bal || total > bal then
            Some Transaction_status.Failure.Source_insufficient_balance
          else if fee > available_funds || total > available_funds then
            Some Transaction_status.Failure.Source_minimum_balance_violation
          else None

        (* A dirty hack to unify different errors being thrown from different
           locations in the codebase. *)
        let extract_error_message e =
          try
            Mina_transaction_logic.timing_error_to_user_command_status e
            |> Transaction_status.Failure.describe
          with _ -> Error.to_string_hum e

        (* Execute a transaction based on initial conditions given by input.
           Check transaction status and compare to the expectation. *)
        let execute_test (input : t) =
          let nonce = Mina_numbers.Account_nonce.zero in
          let ledger_init_state =
            List.map keypairs ~f:(fun keypair ->
                let (timing : Account_timing.t) =
                  Timed
                    { initial_minimum_balance = input.init_min_bal
                    ; cliff_time = input.cliff_time
                    ; cliff_amount = input.cliff_amt
                    ; vesting_period = input.vest_period
                    ; vesting_increment = input.vest_incr
                    }
                in
                ( keypair
                , Currency.Balance.to_amount input.balance
                , nonce
                , timing ) )
            |> Array.of_list
          in
          Mina_ledger.Ledger.with_ephemeral_ledger
            ~depth:constraint_constants.ledger_depth ~f:(fun ledger ->
              Mina_ledger.Ledger.apply_initial_ledger_state ledger
                ledger_init_state ;
              let validated_uc = validate_user_command input.cmd in
              (* slot well past cliff *)
              match
                ( expected_failure input
                , Mina_ledger.Ledger.apply_user_command ~constraint_constants
                    ~txn_global_slot:input.slot ledger validated_uc )
              with
              | None, Ok _txn_applied ->
                  ()
              | expected, Ok txn_applied -> (
                  let expected_err_str =
                    Option.value_map ~default:""
                      ~f:Transaction_status.Failure.describe expected
                  in
                  match txn_applied.common.user_command.status with
                  | Applied ->
                      failwith
                        "Transaction succeeded where it was expected to fail."
                  | Failed failuress ->
                      let failure_str =
                        List.map (List.concat failuress) ~f:(fun failure ->
                            Transaction_status.Failure.to_string failure )
                        |> String.concat ~sep:","
                      in
                      if not (String.equal expected_err_str failure_str) then
                        failwithf "Transaction failure expected: %s got %s"
                          expected_err_str failure_str () )
              | expected, Error err ->
                  let err_str = extract_error_message err in
                  let expected_err_str =
                    Option.value_map ~default:""
                      ~f:Transaction_status.Failure.describe expected
                  in
                  if not (String.equal err_str expected_err_str) then
                    failwithf
                      "Unexpected transaction error: %s.\nExpected error: %s"
                      err_str expected_err_str () )

        let%test_unit "generic user transaction" =
          Quickcheck.test ~seed:(`Deterministic "generic, timed account")
            ~sexp_of:sexp_of_t ~examples ~trials:1000 (gen ()) ~f:execute_test
      end )

    (* zkApps with timings *)
    let apply_zkapp_commands_at_slot ledger slot
        (zkapp_commands : Zkapp_command.t list) =
      Async.Thread_safe.block_on_async_exn
      @@ fun () ->
      Async.Deferred.List.iter zkapp_commands ~f:(fun zkapp_command ->
          Transaction_snark_tests.Util.check_zkapp_command_with_merges_exn
            ~global_slot:slot ledger [ zkapp_command ] )

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
              let failures =
                List.filter (List.concat failuress) ~f:(fun failure ->
                    not
                    @@ Transaction_status.Failure.equal failure
                         Transaction_status.Failure.Cancelled )
              in
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
              let balance = Currency.Balance.of_mina_int_exn 10_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 50
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.of_nanomina_int_exn 100
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Currency.Amount.of_nanomina_int_exn 1_500_000 in
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
          let (zkapp_command_spec
                : Transaction_snark.For_tests.Multiple_transfers_spec.t ) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
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
                Mina_numbers.Global_slot_since_genesis.(succ zero)
                [ txn ] ) )

    let%test_unit "zkApp command, before cliff time, min balance violation" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_mina_int_exn 100_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              (* high init min balance, payment amount enough to violate *)
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 99_000
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.of_nanomina_int_exn 100
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Currency.Amount.of_mina_int_exn 10_000 in
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
          let (zkapp_command_spec
                : Transaction_snark.For_tests.Multiple_transfers_spec.t ) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
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
              let result =
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants
                  ~global_slot:
                    Mina_numbers.Global_slot_since_genesis.(succ zero)
                  ~state_view:Transaction_snark_tests.Util.genesis_state_view
                  ledger zkapp_command
              in
              check_zkapp_failure
                Transaction_status.Failure.Source_minimum_balance_violation
                result ) )

    let%test_unit "zkApp command, before cliff time, fee payer fails" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_mina_int_exn 100_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              (* high init min balance, payment amount enough to violate *)
              let (timing : Account_timing.t) =
                (* init min balance same as balance, so can't even pay a
                   fee, before considering transfer
                *)
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 100_000
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10000
                  ; cliff_amount = Currency.Amount.of_nanomina_int_exn 100
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Currency.Amount.of_mina_int_exn 10_000 in
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
          let (zkapp_command_spec
                : Transaction_snark.For_tests.Multiple_transfers_spec.t ) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
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
              match
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants
                  ~global_slot:
                    Mina_numbers.Global_slot_since_genesis.(succ zero)
                  ~state_view:Transaction_snark_tests.Util.genesis_state_view
                  ledger zkapp_command
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
        let balance = Currency.Balance.of_mina_int_exn 200_000 in
        let nonce = Mina_numbers.Account_nonce.zero in
        let balance_as_amount = Currency.Balance.to_amount balance in
        (keypair, balance_as_amount, nonce, Account_timing.Untimed)
      in
      let ledger_init_state = Array.of_list [ untimed ] in
      let sender_keypair = List.nth_exn keypairs 0 in
      let zkapp_keypair = Signature_lib.Keypair.create () in
      let fee = 1_000_000 in
      let (create_timed_account_spec
            : Transaction_snark.For_tests.Deploy_snapp_spec.t ) =
        { sender = (sender_keypair, Account.Nonce.zero)
        ; fee = Currency.Fee.of_nanomina_int_exn fee
        ; fee_payer = None
        ; amount =
            Option.value_exn
              Currency.Amount.(
                add
                  (of_nanomina_int_exn balance)
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
                       Currency.Balance.of_nanomina_int_exn min_balance
                   ; cliff_time =
                       Mina_numbers.Global_slot_since_genesis.of_int 1000
                   ; cliff_amount =
                       Currency.Amount.of_nanomina_int_exn 100_000_000
                   ; vesting_period = Mina_numbers.Global_slot_span.of_int 10
                   ; vesting_increment =
                       Currency.Amount.of_nanomina_int_exn 100_000_000
                   }
                   : Account_update.Update.Timing_info.value )
             in
             { Account_update.Update.dummy with timing } )
        ; preconditions = None
        ; authorization_kind = Signature
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
              let result =
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants
                  ~global_slot:
                    Mina_numbers.Global_slot_since_genesis.(succ zero)
                  ~state_view:Transaction_snark_tests.Util.genesis_state_view
                  ledger zkapp_command
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
                Mina_numbers.Global_slot_since_genesis.(succ zero)
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
                Mina_numbers.Global_slot_since_genesis.(succ zero)
                [ zkapp_command ] ) )

    let%test_unit "zkApp command, just before cliff time, insufficient balance"
        =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_mina_int_exn 100_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 100_000
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10000
                  ; cliff_amount = Currency.Amount.of_mina_int_exn 100_000
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        (* min balance = balance, spending anything before cliff should trigger min balance violation *)
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Currency.Amount.of_mina_int_exn 10_000 in
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
          let (zkapp_command_spec
                : Transaction_snark.For_tests.Multiple_transfers_spec.t ) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
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
              match
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants
                  ~global_slot:
                    Mina_numbers.Global_slot_since_genesis.(of_int 9999)
                  ~state_view:Transaction_snark_tests.Util.genesis_state_view
                  ledger zkapp_command
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
              let balance = Currency.Balance.of_mina_int_exn 100_000 in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_mina_int_exn 100_000
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10000
                  ; cliff_amount = Currency.Amount.of_mina_int_exn 100_000
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_nanomina_int_exn 10
                  }
              in
              let balance_as_amount = Currency.Balance.to_amount balance in
              (keypair, balance_as_amount, nonce, timing) )
          |> Array.of_list
        in
        let zkapp_command =
          let open Mina_base in
          let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Currency.Amount.of_mina_int_exn 10_000 in
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
          let (zkapp_command_spec
                : Transaction_snark.For_tests.Multiple_transfers_spec.t ) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
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
                Mina_numbers.Global_slot_since_genesis.(of_int 10000)
                [ zkapp_command ] ) )

    let%test_unit "zkApp command, while vesting, sufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let balance_int = 100_000_000_000_000 in
        let init_min_balance_int = 100_000_000_000_000 in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_nanomina_int_exn balance_int in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_nanomina_int_exn init_min_balance_int
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.zero
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment =
                      Currency.Amount.of_nanomina_int_exn 100_000
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
          let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Currency.Amount.of_nanomina_int_exn amount_int in
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
          let (zkapp_command_spec
                : Transaction_snark.For_tests.Multiple_transfers_spec.t ) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
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
                Mina_numbers.Global_slot_since_genesis.(of_int 10_100)
                [ zkapp_command ] ) )

    let%test_unit "zkApp command, while vesting, insufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let balance_int = 100_000_000_000_000 in
        let init_min_balance_int = 100_000_000_000_000 in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_nanomina_int_exn balance_int in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_nanomina_int_exn init_min_balance_int
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.zero
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment =
                      Currency.Amount.of_nanomina_int_exn 100_000
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
          let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Currency.Amount.of_nanomina_int_exn amount_int in
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
          let (zkapp_command_spec
                : Transaction_snark.For_tests.Multiple_transfers_spec.t ) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
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
              let result =
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants
                  ~global_slot:
                    Mina_numbers.Global_slot_since_genesis.(of_int 10_100)
                  ~state_view:Transaction_snark_tests.Util.genesis_state_view
                  ledger zkapp_command
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
              let balance = Currency.Balance.of_nanomina_int_exn balance_int in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_nanomina_int_exn init_min_balance_int
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.zero
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_mina_int_exn 1
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
          let fee = Currency.Fee.of_nanomina_int_exn fee_int in
          let amount = Currency.Amount.of_nanomina_int_exn amount_int in
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
          let (zkapp_command_spec
                : Transaction_snark.For_tests.Multiple_transfers_spec.t ) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
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
                Mina_numbers.Global_slot_since_genesis.(
                  of_int (100_000 + 10_000))
                [ zkapp_command ] ) )

    (* same as previous test, amount is incremented by 1 *)
    let%test_unit "zkApp command, after vesting, insufficient balance" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let balance_int = 100_000_000_000_000 in
        let init_min_balance_int = 100_000_000_000_000 in
        let ledger_init_state =
          List.map keypairs ~f:(fun keypair ->
              let balance = Currency.Balance.of_nanomina_int_exn balance_int in
              let nonce = Mina_numbers.Account_nonce.zero in
              let (timing : Account_timing.t) =
                Timed
                  { initial_minimum_balance =
                      Currency.Balance.of_nanomina_int_exn init_min_balance_int
                  ; cliff_time =
                      Mina_numbers.Global_slot_since_genesis.of_int 10_000
                  ; cliff_amount = Currency.Amount.zero
                  ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                  ; vesting_increment = Currency.Amount.of_mina_int_exn 1
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
          let fee = Currency.Fee.of_nanomina_int_exn fee_int in
          let amount = Currency.Amount.of_nanomina_int_exn amount_int in
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
          let (zkapp_command_spec
                : Transaction_snark.For_tests.Multiple_transfers_spec.t ) =
            { sender = (sender_keypair, nonce)
            ; fee
            ; fee_payer = None
            ; receivers = [ (receiver_key, amount) ]
            ; amount
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
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
              let result =
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants
                  ~global_slot:
                    Mina_numbers.Global_slot_since_genesis.(of_int 110_000)
                  ~state_view:Transaction_snark_tests.Util.genesis_state_view
                  ledger zkapp_command
              in
              check_zkapp_failure Transaction_status.Failure.Overflow result ) )

    let%test_unit "zkApp command, create timed account with wrong authorization"
        =
      let ledger_init_state =
        List.map keypairs ~f:(fun keypair ->
            let balance = Currency.Amount.of_mina_int_exn 100_000 in
            let nonce = Mina_numbers.Account_nonce.zero in
            (keypair, balance, nonce, Account_timing.Untimed) )
        |> Array.of_list
      in
      let sender_keypair = List.hd_exn keypairs in
      let zkapp_keypair = Signature_lib.Keypair.create () in
      let (create_timed_account_spec
            : Transaction_snark.For_tests.Deploy_snapp_spec.t ) =
        { sender = (sender_keypair, Account.Nonce.zero)
        ; fee = Currency.Fee.of_nanomina_int_exn 1_000_000
        ; fee_payer = None
        ; amount = Currency.Amount.of_mina_int_exn 50_000
        ; zkapp_account_keypairs = [ zkapp_keypair ]
        ; memo =
            Signed_command_memo.create_from_string_exn
              "zkApp create timed account"
        ; new_zkapp_account = true
        ; snapp_update =
            (let timing =
               Zkapp_basic.Set_or_keep.Set
                 ( { initial_minimum_balance = Currency.Balance.of_mina_int_exn 1
                   ; cliff_time =
                       Mina_numbers.Global_slot_since_genesis.of_int 10
                   ; cliff_amount = Currency.Amount.of_mina_int_exn 1
                   ; vesting_period = Mina_numbers.Global_slot_span.of_int 10
                   ; vesting_increment = Currency.Amount.of_mina_int_exn 1
                   }
                   : Account_update.Update.Timing_info.value )
             in
             { Account_update.Update.dummy with timing } )
        ; preconditions = None
        ; authorization_kind = None_given
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
                  ( Transaction_status.Failure.Update_not_permitted_timing
                  , Pass_2 )
                ledger
                [ create_timed_account_zkapp_command ] ) )

    let%test_unit "zkApp command, change untimed account to timed" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Backtrace.elide := false ;
          let ledger_init_state =
            List.map keypairs ~f:(fun keypair ->
                let balance = Currency.Amount.of_mina_int_exn 100_000 in
                let nonce = Mina_numbers.Account_nonce.zero in
                (keypair, balance, nonce, Account_timing.Untimed) )
            |> Array.of_list
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let (update_timing_spec
                : Transaction_snark.For_tests.Update_states_spec.t ) =
            { sender = (sender_keypair, Account.Nonce.zero)
            ; fee = Currency.Fee.of_nanomina_int_exn 1_000_000
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
                           Currency.Balance.of_mina_int_exn 1
                       ; cliff_time =
                           Mina_numbers.Global_slot_since_genesis.of_int 10
                       ; cliff_amount = Currency.Amount.of_mina_int_exn 1
                       ; vesting_period =
                           Mina_numbers.Global_slot_span.of_int 10
                       ; vesting_increment = Currency.Amount.of_mina_int_exn 1
                       }
                       : Account_update.Update.Timing_info.value )
                 in
                 { Account_update.Update.dummy with timing } )
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
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
                let balance = Currency.Amount.of_mina_int_exn 100_000 in
                let nonce = Mina_numbers.Account_nonce.zero in
                ( keypair
                , balance
                , nonce
                , if i = 1 then
                    Account_timing.Timed
                      { initial_minimum_balance =
                          Currency.Balance.of_mina_int_exn 10
                      ; cliff_time =
                          Mina_numbers.Global_slot_since_genesis.of_int 10_000
                      ; cliff_amount = Currency.Amount.zero
                      ; vesting_period = Mina_numbers.Global_slot_span.of_int 1
                      ; vesting_increment =
                          Currency.Amount.of_nanomina_int_exn 100_000
                      }
                  else Account_timing.Untimed ) )
            |> Array.of_list
          in
          let sender_keypair = List.hd_exn keypairs in
          let zkapp_keypair = List.nth_exn keypairs 1 in
          let (update_timing_spec
                : Transaction_snark.For_tests.Update_states_spec.t ) =
            { sender = (sender_keypair, Account.Nonce.zero)
            ; fee = Currency.Fee.of_nanomina_int_exn 1_000_000
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
                           Currency.Balance.of_mina_int_exn 1
                       ; cliff_time =
                           Mina_numbers.Global_slot_since_genesis.of_int 10
                       ; cliff_amount = Currency.Amount.of_mina_int_exn 1
                       ; vesting_period =
                           Mina_numbers.Global_slot_span.of_int 10
                       ; vesting_increment = Currency.Amount.of_mina_int_exn 1
                       }
                       : Account_update.Update.Timing_info.value )
                 in
                 { Account_update.Update.dummy with timing } )
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
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
                      ( Transaction_status.Failure.Update_not_permitted_timing
                      , Pass_2 )
                    ledger
                    [ update_timing_zkapp_command ] ) ) )
  end )
