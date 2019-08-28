open Async
open Core
open Coda_base
open Signature_lib

let max_length = 6

module Stubs = Stubs.Make (struct
  let max_length = max_length
end)

open Stubs

let%test_module "Receipt Chain" =
  ( module struct
    module Receipt_chain = struct
      module Receipt_chain = Archive_process.Receipt_chain.Make (Stubs)

      let logger = Logger.create ()

      let trust_system = Trust_system.null ()

      let create_receipt_chain_database () =
        let directory = File_system.make_directory_name None in
        Receipt_chain_database.create ~directory

      let gen_payments_with_one_sender_txn amount sender_sk staged_ledger
          accounts_with_secret_keys =
        let public_keys =
          List.map accounts_with_secret_keys ~f:(fun (_, account) ->
              Account.public_key account )
        in
        let receiver_pk = List.random_element_exn public_keys in
        let nonce =
          get_nonce staged_ledger
            Public_key.(compress @@ of_private_key_exn sender_sk)
        in
        let payment =
          create_payment sender_sk receiver_pk
            (Currency.Amount.of_int amount)
            nonce
        in
        Sequence.singleton payment

      let get_receipt_chain breadcrumb public_key =
        let ledger =
          Staged_ledger.ledger
          @@ Transition_frontier.(Breadcrumb.staged_ledger breadcrumb)
        in
        let location =
          Option.value_exn (Ledger.location_of_key ledger public_key)
        in
        (Option.value_exn (Ledger.get ledger location)).receipt_chain_hash

      let largest_private_key_opt, largest_account =
        Genesis_ledger.largest_account_exn ()

      let largest_public_key = Account.public_key largest_account

      let largest_private_key = Option.value_exn largest_private_key_opt

      let store_breadcrumbs_in_receipt_chain_database ~writer ~root breadcrumbs
          =
        let transition_frontier_diffs =
          List.folding_map breadcrumbs ~init:root ~f:(fun previous added ->
              (added, Transition_frontier.Diff.New_breadcrumb {previous; added})
          )
        in
        let archive_diffs =
          List.map transition_frontier_diffs ~f:(fun diff ->
              Option.value_exn
                (Transition_frontier.Diff.Archive_diff
                 .of_transition_frontier_diff diff) )
        in
        List.iter archive_diffs ~f:(function
          | Transition_frontier.Diff.Archive_diff.Breadcrumb_added
              {block= transition_with_hash, _; senders_previous_receipt_chains}
            ->
              Receipt_chain.Writer.add writer transition_with_hash
                senders_previous_receipt_chains
          | Root_transitioned _ ->
              failwith "We should only be processing Root_transitioned diffs" )

      let assert_receipt_chain_in_breacrumbs ~max_length ~resulting_receipt
          breadcrumbs receipt_chain sender =
        List.fold_result breadcrumbs ~init:0 ~f:(fun index breadcrumb ->
            let proving_receipt = get_receipt_chain breadcrumb sender in
            let open Or_error.Let_syntax in
            let%bind ({payments; _} as proof) =
              Receipt_chain.Reader.prove receipt_chain ~proving_receipt
                ~resulting_receipt
            in
            let payments_length = List.length payments in
            let expected_payments_length = max_length - index in
            let%bind () =
              Result.ok_if_true
                (expected_payments_length = payments_length)
                ~error:
                  (Error.createf
                     !"Expected length of Merkle list %i\n\
                      \ Acount length of merkle list is %i"
                     expected_payments_length payments_length)
            in
            let%map () =
              Receipt_chain.Reader.verify ~resulting_receipt proof
            in
            index + 1 )

      let%test_unit "A node that has transactions in different blocks that \
                     are lined up and they can create a merkle proof for \
                     these transactions up to the best breadcrumb" =
        Async.Thread_safe.block_on_async_exn (fun () ->
            let (module Generators : Generator_intf) =
              ( module Make_generators (struct
                           let gen_payments =
                             gen_payments_with_one_sender_txn 1
                               largest_private_key

                           let accounts_with_secret_keys =
                             Genesis_ledger.accounts
                         end)
                         (struct
                           let logger = logger

                           let trust_system = trust_system
                         end) )
            in
            let%bind frontier = Generators.create_root_frontier () in
            let root = Transition_frontier.root frontier in
            let%map created_breadcrumbs =
              Generators.instantiate_linear_breadcrumbs max_length root
            in
            let receipt_chain_database = create_receipt_chain_database () in
            let reader, writer =
              Receipt_chain.create ~logger receipt_chain_database
            in
            store_breadcrumbs_in_receipt_chain_database ~writer ~root
              created_breadcrumbs ;
            let best_tip_receipt_hash =
              get_receipt_chain
                (List.last_exn created_breadcrumbs)
                largest_public_key
            in
            assert_receipt_chain_in_breacrumbs ~max_length
              ~resulting_receipt:best_tip_receipt_hash created_breadcrumbs
              reader largest_public_key
            |> Or_error.ok_exn |> ignore )

      let%test_unit "If a user has 2 different transactions with the same \
                     nonce on two different blocks that forked from a common \
                     block and there other transactions in descendant blocks \
                     of those blocks, then the user can create a valid proof \
                     for these forked transactions" =
        Async.Thread_safe.block_on_async_exn (fun () ->
            let (module Generators1 : Generator_intf) =
              ( module Make_generators (struct
                           let gen_payments =
                             gen_payments_with_one_sender_txn 1
                               largest_private_key

                           let accounts_with_secret_keys =
                             Genesis_ledger.accounts
                         end)
                         (struct
                           let logger = logger

                           let trust_system = trust_system
                         end) )
            in
            let (module Generators2 : Generator_intf) =
              ( module Make_generators (struct
                           let gen_payments =
                             gen_payments_with_one_sender_txn 2
                               largest_private_key

                           let accounts_with_secret_keys =
                             Genesis_ledger.accounts
                         end)
                         (struct
                           let logger = logger

                           let trust_system = trust_system
                         end) )
            in
            let%bind frontier = Generators1.create_root_frontier () in
            let root = Transition_frontier.root frontier in
            let total_path_length = max_length - 2 in
            let ancestor_path_length = total_path_length / 2 in
            let fork_length = total_path_length / 2 in
            let%bind ancestor_breadcrumbs =
              Generators1.instantiate_linear_breadcrumbs ancestor_path_length
                root
            in
            let least_common_ancestor = List.last_exn ancestor_breadcrumbs in
            let least_common_ancestor_receipt_chain =
              get_receipt_chain least_common_ancestor largest_public_key
            in
            Logger.debug logger
              !"Receipt chain of the least common ancestor"
              ~module_:__MODULE__ ~location:__LOC__
              ~metadata:
                [ ( "receipt_chain"
                  , Receipt.Chain_hash.to_yojson
                      least_common_ancestor_receipt_chain ) ] ;
            let%bind fork1 =
              Generators1.instantiate_linear_breadcrumbs fork_length
                least_common_ancestor
            and fork2 =
              Generators2.instantiate_linear_breadcrumbs fork_length
                least_common_ancestor
            in
            let receipt_chain_database = create_receipt_chain_database () in
            let reader, writer =
              Receipt_chain.create ~logger receipt_chain_database
            in
            let least_common_ancestor_parent =
              List.find_exn ancestor_breadcrumbs
                ~f:
                  (Fn.compose
                     (State_hash.equal
                        (Transition_frontier.Breadcrumb.parent_hash
                           least_common_ancestor))
                     Transition_frontier.Breadcrumb.state_hash)
            in
            store_breadcrumbs_in_receipt_chain_database ~writer
              ~root:least_common_ancestor_parent
              (least_common_ancestor :: fork1) ;
            store_breadcrumbs_in_receipt_chain_database ~writer
              ~root:least_common_ancestor_parent
              (least_common_ancestor :: fork2) ;
            ignore
            @@ Or_error.ok_exn
                 (assert_receipt_chain_in_breacrumbs
                    ~max_length:(1 + fork_length)
                    ~resulting_receipt:
                      (get_receipt_chain (List.last_exn fork1)
                         largest_public_key)
                    (least_common_ancestor :: fork1)
                    reader largest_public_key) ;
            ignore
            @@ Or_error.ok_exn
                 (assert_receipt_chain_in_breacrumbs
                    ~max_length:(1 + fork_length)
                    ~resulting_receipt:
                      (get_receipt_chain (List.last_exn fork2)
                         largest_public_key)
                    (least_common_ancestor :: fork2)
                    reader largest_public_key) ;
            Deferred.unit )

      let gen_payment_with_sender_having_multiple_txns
          ~num_transactions_per_block amount sender_sk staged_ledger
          accounts_with_secret_keys =
        let public_keys =
          List.map accounts_with_secret_keys ~f:(fun (_, account) ->
              Account.public_key account )
        in
        let receiver_pk = List.random_element_exn public_keys in
        let nonce_offset =
          get_nonce staged_ledger
            Public_key.(compress @@ of_private_key_exn sender_sk)
        in
        Sequence.of_list
          (List.folding_map (List.init num_transactions_per_block ~f:Fn.id)
             ~init:nonce_offset ~f:(fun nonce _ ->
               ( Account.Nonce.succ nonce
               , create_payment sender_sk receiver_pk
                   (Currency.Amount.of_int amount)
                   nonce ) ))

      let%test_unit "If a user has multiple transactions in a block (where \
                     the transactions' nonces are in contiguous order), then \
                     the user can create valid proofs for all of these \
                     transactions" =
        let num_transactions1 = 3 in
        let (module Generators1 : Generator_intf) =
          ( module Make_generators (struct
                       let gen_payments =
                         gen_payment_with_sender_having_multiple_txns
                           ~num_transactions_per_block:num_transactions1 1
                           largest_private_key

                       let accounts_with_secret_keys = Genesis_ledger.accounts
                     end)
                     (struct
                       let logger = logger

                       let trust_system = trust_system
                     end) )
        in
        let num_transactions2 = 4 in
        let (module Generators2 : Generator_intf) =
          ( module Make_generators (struct
                       let gen_payments =
                         gen_payment_with_sender_having_multiple_txns
                           ~num_transactions_per_block:num_transactions2 2
                           largest_private_key

                       let accounts_with_secret_keys = Genesis_ledger.accounts
                     end)
                     (struct
                       let logger = logger

                       let trust_system = trust_system
                     end) )
        in
        Async.Thread_safe.block_on_async_exn
        @@ fun () ->
        let%bind frontier = Generators1.create_root_frontier () in
        let root = Transition_frontier.root frontier in
        let%bind breadcrumb1 =
          Quickcheck.random_value Generators1.gen_breadcrumb
          @@ Deferred.return root
        in
        let%bind breadcrumb2 =
          Quickcheck.random_value Generators2.gen_breadcrumb
          @@ Deferred.return breadcrumb1
        in
        let all_user_commands =
          List.bind [breadcrumb1; breadcrumb2]
            ~f:Transition_frontier.Breadcrumb.user_commands
        in
        let total_num_transactions = num_transactions1 + num_transactions2 in
        [%test_pred: User_command.t list]
          ~message:
            "The number of user_commands added to the breadcrumbs should \
             equal to total_num_transactions generated by the test"
          (fun user_commands ->
            total_num_transactions
            = Set.length @@ User_command.Set.of_list user_commands )
          all_user_commands ;
        let receipt_chain_database = create_receipt_chain_database () in
        let reader, writer =
          Receipt_chain.create ~logger receipt_chain_database
        in
        store_breadcrumbs_in_receipt_chain_database ~writer ~root
          [breadcrumb1; breadcrumb2] ;
        let resulting_receipt =
          get_receipt_chain breadcrumb2 largest_public_key
        in
        let expected_receipt_chains =
          List.folding_map all_user_commands ~init:Receipt.Chain_hash.empty
            ~f:(fun prev_receipt user_command ->
              let receipt =
                Receipt.Chain_hash.cons
                  (User_command.payload user_command)
                  prev_receipt
              in
              (receipt, receipt) )
        in
        (* Prove that all the transactions in the blockchain have a corresponding receipt_chain_hash *)
        (let open Result.Let_syntax in
        List.fold_result expected_receipt_chains ~init:()
          ~f:(fun () proving_receipt ->
            let%bind proof =
              Receipt_chain.Reader.prove reader ~proving_receipt
                ~resulting_receipt
            in
            Receipt_chain.Reader.verify ~resulting_receipt proof ))
        |> Or_error.ok_exn |> ignore ;
        Deferred.unit
    end
  end )
