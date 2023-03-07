open Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Signature_lib
open Helpers
open Protocol_config_examples
open Zkapp_cmd_builder

(* The function under test is quite slow, so keep the trials count low
   so that tests finish in a reasonable amount of time. *)
let trials = 100

let balance_to_fee = Fn.compose Amount.to_fee Balance.to_amount

(* This module tests the "pure" transaction logic implemented in this library.
   By "pure" we mean that ZK SNARKs aren't used for verification, instead all
   signatures and proofs are assumed to be valid. These verification details
   are provided by the functor parameters (Inputs module) and a full-featured
   implementation leveraging ZK SNARKs is given in transaction_snark library.

   As a consequence, we don't bother with constructing correct signatures or
   proofs here. We just give dummy signatures because this implementation
   accepts anything anyway. Note, however, that this implementation DOES check
   whether SOME signature or proof is given whenever required. It just doesn't
   validate them. *)
let%test_module "Test transaction logic." =
  ( module struct
    open Transaction_logic.Transaction_applied.Zkapp_command_applied

    let run_zkapp_cmd ~fee_payer ~fee ~accounts txns =
      let open Result.Let_syntax in
      let cmd =
        zkapp_cmd ~noncemap:(noncemap accounts) ~fee:(fee_payer, fee) txns
      in
      let%bind ledger = test_ledger accounts in
      let%map txn, _ =
        Transaction_logic.apply_zkapp_command_unchecked ~constraint_constants
          ~global_slot:Global_slot.(of_int 120)
          ~state_view:protocol_state ledger cmd
      in
      (txn, ledger)

    let%test_unit "Many transactions between distinct accounts." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Quickcheck.Generator.Let_syntax in
        let%bind accs_and_txns =
          Generator.list_non_empty Simple_txn.gen_account_pair_and_txn
          (* Generating too many transactions makes this test take too much time. *)
          |> Generator.filter ~f:(fun l -> List.length l < 4)
        in
        let account_pairs, txns = List.unzip accs_and_txns in
        let accounts =
          List.concat_map account_pairs ~f:(fun (a, b) -> [ a; b ])
        in
        (* Select a receiver to pay the fee. *)
        let%bind fee_payer =
          Generator.of_list @@ List.map ~f:snd account_pairs
        in
        let%map fee = Fee.(gen_incl zero @@ balance_to_fee fee_payer.balance) in
        (fee_payer.pk, fee, accounts, (txns :> transaction list)))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, ledger) ->
                 Transaction_status.equal txn.command.status Applied
                 && Predicates.verify_balance_changes ~txn ~ledger accounts ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "Fee payer must be able to pay the fee." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind (sender, receiver), txn =
          Simple_txn.gen_account_pair_and_txn
          |> Generator.filter
               ~f:Balance.(fun ((a, _), _) -> a.balance < max_int)
        in
        let accounts = [ sender; receiver ] in
        (* Make sure that fee is too high. *)
        let min_fee =
          Balance.(sender.balance - txn#amount)
          |> Option.value_map ~default:Fee.zero ~f:balance_to_fee
          |> Fee.(fun f -> f + of_nanomina_int_exn 1)
          |> Option.value ~default:Fee.max_int
        in
        let max_fee =
          Fee.(min_fee + of_mina_int_exn 10)
          |> Option.value ~default:Fee.max_int
        in
        let%map fee = Fee.(gen_incl min_fee max_fee) in
        (sender.pk, fee, accounts, [ (txn :> transaction) ]))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure
               ~with_error:(fun e ->
                 String.is_substring (Error.to_string_hum e)
                   ~substring:"Overflow" )
               ~f:(fun (txn, _) ->
                 Transaction_status.equal txn.command.status
                   (Failed [ []; [ Overflow ]; [ Cancelled ] ]) ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "Currency cannot be created out of thin air." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind account =
          Test_account.gen_constrained_balance ()
            ~max:Balance.(Option.value_exn @@ max_int - Amount.of_nanomina_int_exn 1)
        in
        let max_amount =
          Balance.(max_int - to_amount account.balance)
          |> Option.value_map ~default:Amount.zero ~f:Balance.to_amount
        in
        let%bind unsigned_amount =
          Amount.(gen_incl (of_nanomina_int_exn 1) max_amount)
        in
        let amount = Amount.Signed.of_unsigned unsigned_amount in
        let update = Single.make ~account:account.pk amount in
        let%map fee = Fee.(gen_incl zero (balance_to_fee account.balance)) in
        (account.pk, fee, [ account ], [ (update :> transaction) ]))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, _) ->
                 Transaction_status.equal txn.command.status
                   (Failed [ []; [ Invalid_fee_excess ] ]) ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "Currency cannot be destroyed." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind unsigned_amount =
          Amount.(gen_incl (of_nanomina_int_exn 1) max_int)
        in
        let%bind account =
          let min = Balance.of_uint64 @@ Amount.to_uint64 unsigned_amount in
          Test_account.gen_constrained_balance ~min ()
        in
        let amount = Amount.Signed.(negate @@ of_unsigned unsigned_amount) in
        let update = Single.make ~account:account.pk amount in
        let max_fee =
          Balance.(account.balance - unsigned_amount)
          |> Option.value_map ~default:Fee.zero ~f:balance_to_fee
        in
        let%map fee = Fee.(gen_incl zero max_fee) in
        (account.pk, fee, [ account ], [ (update :> transaction) ]))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, _) ->
                 Transaction_status.equal txn.command.status
                   (Failed [ []; [ Invalid_fee_excess ] ]) ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "Token_symbol of the account can be altered." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind account = Test_account.gen in
        (* The symbol is limited to 6 characters, but this limit is being
           enforced elsewhere and, unfortunately we cannot see this function
           fail if the symbol exceeds that limit.*)
        let%bind token = String.gen_with_length 6 Char.gen_uppercase in
        let txn =
          Alter_account.make ~account:account.pk
            { Account_update.Update.noop with token_symbol = Set token }
        in
        let%map fee = Fee.(gen_incl zero (balance_to_fee account.balance)) in
        (account.pk, fee, [ account ], [ (txn :> transaction) ]))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, ledger) ->
                 Transaction_status.equal txn.command.status Applied
                 && Predicates.verify_account_updates (List.hd_exn accounts)
                      ~txn ~ledger ~f:(fun balance_change -> function
                      | Some orig, Some updt ->
                          Predicates.verify_balance_change ~balance_change orig
                            updt
                          && not
                               Account.Poly.(
                                 Account.Token_symbol.equal orig.token_symbol
                                   updt.token_symbol)
                      | _ ->
                          false ) ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "Delegate of an account can be set." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind delegator = Test_account.gen in
        let%bind delegate = Test_account.gen in
        let txn =
          Alter_account.make ~account:delegator.pk
            { Account_update.Update.noop with delegate = Set delegate.pk }
        in
        let%map fee = Fee.(gen_incl zero (balance_to_fee delegate.balance)) in
        (delegate.pk, fee, [ delegator; delegate ], [ (txn :> transaction) ]))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, ledger) ->
                 let delegator = List.hd_exn accounts in
                 let delegate_pk =
                   (Option.value_exn @@ List.nth accounts 1).pk
                 in
                 Transaction_status.equal txn.command.status Applied
                 && Predicates.verify_account_updates delegator ~txn ~ledger
                      ~f:(fun _ -> function
                      | Some _, Some updt ->
                          Option.equal Public_key.Compressed.equal updt.delegate
                            (Some delegate_pk)
                      | _ ->
                          false ) ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    (* It is assumed here that the account is indeed a zkApp account. Presumably
       it's being checked elsewhere. If there's no zkApp associated with the
       account, this update succeeds, but does nothing. For the moment we're ignoring
       the fact that the account isn't being updated. We'll revisit and strengthen
       this test after some refactoring. *)
    let%test_unit "Zkapp URI can be set." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind account = Test_account.gen_with_zkapp in
        let%bind uri =
          Generator.filter Zkapp_account.gen_uri ~f:(fun uri ->
              Option.value_map account.zkapp ~default:true ~f:(fun zkapp ->
                  not @@ String.equal uri zkapp.zkapp_uri ) )
        in
        let txn =
          Alter_account.make ~account:account.pk
            { Account_update.Update.noop with zkapp_uri = Set uri }
        in
        let%map fee = Fee.(gen_incl zero (balance_to_fee account.balance)) in
        (account.pk, fee, [ account ], [ (txn :> transaction) ], uri))
        ~f:(fun (fee_payer, fee, accounts, txns, uri) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, ledger) ->
                 let account = List.hd_exn accounts in
                 Transaction_status.equal txn.command.status Applied
                 && Predicates.verify_account_updates ~txn ~ledger account
                      ~f:(fun _ -> function
                      | Some _, Some updt ->
                          Option.value_map updt.zkapp ~default:false
                            ~f:(fun zkapp -> String.equal uri zkapp.zkapp_uri)
                      | _ ->
                          false ) ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "Timing of an account can be changed." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind account =
          Test_account.gen_constrained_balance ~min:Balance.(of_nanomina_int_exn 1) ()
        in
        let global_slot = protocol_state.global_slot_since_genesis in
        let%bind timing =
          Account.gen_timing account.balance
          |> Generator.filter
               ~f:(fun
                    { cliff_time
                    ; cliff_amount
                    ; vesting_period
                    ; vesting_increment
                    ; initial_minimum_balance
                    ; _
                    }
                  ->
                 Account.min_balance_at_slot ~global_slot ~cliff_time
                   ~cliff_amount ~vesting_period ~vesting_increment
                   ~initial_minimum_balance
                 |> Balance.(( < ) zero) )
        in
        let timing_info =
          Account.Timing.of_record timing
          |> Account_update.Update.Timing_info.of_account_timing
          |> Option.value_exn
          (* Timing is guaranteed to return a proper timing. *)
        in
        let txn =
          Alter_account.make ~account:account.pk
            { Account_update.Update.noop with timing = Set timing_info }
        in
        (* Fee can't result in the balance falling below the set minimum. *)
        let max_fee =
          Fee.(
            balance_to_fee account.balance
            - balance_to_fee timing.initial_minimum_balance)
          |> Option.value ~default:Fee.zero
        in
        let%map fee = Fee.(gen_incl zero max_fee) in
        (account.pk, fee, [ account ], [ (txn :> transaction) ], timing))
        ~f:(fun (fee_payer, fee, accounts, txns, timing) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, ledger) ->
                 let account = List.hd_exn accounts in
                 Transaction_status.equal txn.command.status Applied
                 && Predicates.verify_account_updates account ~txn ~ledger
                      ~f:(fun _ -> function
                      | Some orig, Some updt ->
                          let open Account.Timing in
                          equal orig.timing Untimed
                          && equal updt.timing (Account.Timing.of_record timing)
                      | _ ->
                          false ) ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "Minimum balance cannot be set below the actual balance." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let gen_timing =
          let%map t = Account.gen_timing Balance.max_int in
          let minimum_balance =
            Account.min_balance_at_slot
              ~global_slot:protocol_state.global_slot_since_genesis
              ~initial_minimum_balance:t.initial_minimum_balance
              ~vesting_period:t.vesting_period
              ~vesting_increment:t.vesting_increment ~cliff_time:t.cliff_time
              ~cliff_amount:t.cliff_amount
          in
          (t, minimum_balance)
        in
        let%bind timing, minimum_balance =
          Generator.filter gen_timing
            ~f:Balance.(fun (_, min_bal) -> min_bal > of_nanomina_int_exn 1)
        in
        let%map account =
          Test_account.gen_constrained_balance ()
            ~min:Balance.(of_nanomina_int_exn 1)
            ~max:Balance.(Option.value ~default:max_int @@ minimum_balance - Amount.of_nanomina_int_exn 1)
        in
        let timing_info =
          Account.Timing.of_record timing
          |> Account_update.Update.Timing_info.of_account_timing
          |> Option.value_exn
          (* Timing is guaranteed to return a proper timing. *)
        in
        let txn =
          Alter_account.make ~account:account.pk
            { Account_update.Update.noop with timing = Set timing_info }
        in
        (account.pk, Fee.zero, [ account ], [ (txn :> transaction) ]))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, _ledger) ->
                 Transaction_status.equal txn.command.status
                   (Failed [ []; [ Source_minimum_balance_violation ] ]) ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "The account's voting choice can be changed." =
      Quickcheck.test ~trials
        (let open Quickcheck.Generator.Let_syntax in
        let%bind account = Test_account.gen in
        let%bind state_hash = State_hash.gen in
        let txn =
          Alter_account.make ~account:account.pk
            { Account_update.Update.noop with voting_for = Set state_hash }
        in
        let%map fee = Fee.(gen_incl zero (balance_to_fee account.balance)) in
        (account.pk, fee, [ account ], [ (txn :> transaction) ], state_hash))
        ~f:(fun (fee_payer, fee, accounts, txns, voting_choice) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, ledger) ->
                 let account = List.hd_exn accounts in
                 Transaction_status.equal txn.command.status Applied
                 && Predicates.verify_account_updates account ~ledger ~txn
                      ~f:(fun _ -> function
                      | Some orig, Some updt ->
                          let open State_hash in
                          equal orig.voting_for zero
                          && equal updt.voting_for voting_choice
                      | _ ->
                          false ) ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "The account's permissions can be changed." =
      Quickcheck.test ~trials
        (let open Quickcheck.Generator.Let_syntax in
        let%bind account = Test_account.gen in
        let%bind perms = Permissions.gen ~auth_tag:Proof in
        let txn =
          Alter_account.make ~account:account.pk
            { Account_update.Update.noop with permissions = Set perms }
        in
        let%map fee = Fee.(gen_incl zero (balance_to_fee account.balance)) in
        (account.pk, fee, [ account ], [ (txn :> transaction) ], perms))
        ~f:(fun (fee_payer, fee, accounts, txns, perms) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, ledger) ->
                 let account = List.hd_exn accounts in
                 Transaction_status.equal txn.command.status Applied
                 && Predicates.verify_account_updates account ~txn ~ledger
                      ~f:(fun _ -> function
                      | Some _, Some updt ->
                          Permissions.equal updt.permissions perms
                      | _ ->
                          false ) ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    (* Note that the change to the permissions takes effect immediately and can
       influence further updates. *)
    let%test_unit "After permissions were set to proof-only, signatures are \
                   insufficient authorization for making transactions." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind sender =
          Test_account.gen_constrained_balance ()
            ~min:Balance.one
        in
        let%bind receiver =
          Test_account.gen_constrained_balance ()
            ~max:Balance.(Option.value_exn (max_int - Amount.one))
        in
        let%bind perms = Permissions.gen ~auth_tag:Proof in
        let max_amount =
          let open Balance in
          max_int - to_amount receiver.balance
          |> Option.value ~default:(of_nanomina_int_exn 1)
          |> min sender.balance |> to_amount
        in
        let%bind amount =
          Amount.(gen_incl (of_nanomina_int_exn 1) max_amount)
        in
        let alter_perms =
          Alter_account.make ~account:sender.pk
            { Account_update.Update.noop with
              (* These settings actually matter for this scenario, so they must
                 be fixed. We try to increment nonces in the process, so that
                 must *not* require authorisation or we will see more errors
                 than expected. *)
              permissions =
                Set { perms with send = Proof; increment_nonce = None }
            }
        in
        let mina_transfer =
          Simple_txn.make ~sender:sender.pk ~receiver:receiver.pk amount
        in
        let txns =
          [ (alter_perms :> transaction); (mina_transfer :> transaction) ]
        in
        let%map fee = Fee.(gen_incl zero (balance_to_fee receiver.balance)) in
        (receiver.pk, fee, [ sender; receiver ], txns))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, _ledger) ->
                 Transaction_status.equal txn.command.status
                   (Failed
                      [ []
                      ; [ Cancelled ]
                      ; [ Update_not_permitted_balance ]
                      ; [ Cancelled ]
                      ] ) ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "All updates must succeed or none is applied." =
      (* But the fee is still paid. *)
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind sender =
          Test_account.gen_constrained_balance ~min:Balance.one ()
        in
        let%bind amounts = gen_balance_split ~limit:2 sender.balance in
        let amount1 = List.hd_exn amounts in
        let fee =
          List.nth amounts 1
          |> Option.value_map ~default:Fee.zero ~f:Amount.to_fee
        in
        let%bind amount2 = Amount.(gen_incl (of_nanomina_int_exn 1) max_int) in
        let%bind receiver1 = Test_account.gen_empty in
        let%map receiver2 = Test_account.gen_empty in
        let txn1 =
          Simple_txn.make ~sender:sender.pk ~receiver:receiver1.pk amount1
        in
        let txn2 =
          Simple_txn.make ~sender:sender.pk ~receiver:receiver2.pk amount2
        in
        ( sender.pk
        , fee
        , [ sender; receiver1; receiver2 ]
        , ([ txn1; txn2 ] :> transaction list) ))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, ledger) ->
                 Transaction_status.equal txn.command.status
                   (Failed
                      [ []
                      ; [ Cancelled ]
                      ; [ Cancelled ]
                      ; [ Overflow ]
                      ; [ Cancelled ]
                      ] )
                 && Predicates.verify_balances_unchanged ~txn ~ledger accounts )
            )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "If fee can't be paid, operation results in an error." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind delegator =
          Test_account.gen_constrained_balance ()
            ~max:Balance.(Option.value_exn (max_int - Amount.one))
        in
        let%bind delegate = Test_account.gen in
        let txn =
          Alter_account.make ~account:delegator.pk
            { Account_update.Update.noop with delegate = Set delegate.pk }
        in
        let min_fee =
          Balance.(delegator.balance + Amount.one)
          |> Option.value_map ~f:balance_to_fee ~default:Fee.max_int
        in
        let%map fee = Fee.(gen_incl min_fee max_int) in
        (delegator.pk, fee, [ delegator; delegate ], [ (txn :> transaction) ]))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (function
              | Ok _ ->
                  false
              | Error e ->
                  String.is_substring ~substring:"Overflow"
                    (Error.to_string_hum e) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )
  end )
