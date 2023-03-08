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
let trials = 10

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
          Generator.filter
            ~f:Balance.(fun a -> a.balance < max_int)
            Test_account.gen
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
          Generator.filter
            ~f:Amount.(fun a -> Balance.to_amount a.balance >= unsigned_amount)
            Test_account.gen
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

    (* It is assumed here that the account is indeed an zkApp account. Presumably
       it's being checked elsewhere. If there's no zkApp associated with the
       account, this update succeeds, but does nothing. For the moment we're ignoring
       the fact that the account isn't being updated. We'll revisit and strengthen
        this test after some refactoring. *)
    let%test_unit "Zkapp URI can be set." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind account = Test_account.gen in
        let%bind uri = String.gen_with_length 64 Char.gen_alphanum in
        let txn =
          Alter_account.make ~account:account.pk
            { Account_update.Update.noop with zkapp_uri = Set uri }
        in
        let%map fee = Fee.(gen_incl zero (balance_to_fee account.balance)) in
        (account.pk, fee, [ account ], [ (txn :> transaction) ]))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: Zk_cmd_result.t Or_error.t]
            (Predicates.pure ~f:(fun (txn, _) ->
                 Transaction_status.equal txn.command.status Applied ) )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )
  end )
