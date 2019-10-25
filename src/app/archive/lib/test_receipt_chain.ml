open Core
open Async
open Coda_base
open Pipe_lib
open Signature_lib

let%test_module "Processor" =
  ( module struct
    let max_length = 6

    module Stubs = Transition_frontier_controller_tests.Stubs.Make (struct
      let max_length = max_length
    end)

    open Stubs

    let logger = Logger.create ()

    let pids = Pid.Table.create ()

    let trust_system = Trust_system.null ()

    let accounts_with_secret_keys = Genesis_ledger.accounts

    let largest_public_key = Genesis_ledger.largest_public_key_exn ()

    let largest_private_key = Genesis_ledger.largest_private_key_exn ()

    let deferred_fold_result ~init ~f =
      Deferred.List.fold ~init:(Ok init) ~f:(fun acc elem ->
          match acc with
          | Ok acc ->
              f acc elem
          | Error e ->
              Deferred.return @@ Error e )

    let get_receipt_chain breadcrumb public_key =
      let ledger =
        Staged_ledger.ledger
        @@ Transition_frontier.(Breadcrumb.staged_ledger breadcrumb)
      in
      let location =
        Option.value_exn (Ledger.location_of_key ledger public_key)
      in
      (Option.value_exn (Ledger.get ledger location)).receipt_chain_hash

    let get_nonce staged_ledger sender_pk =
      let ledger = Staged_ledger.ledger staged_ledger in
      let account_location =
        Option.value_exn (Ledger.location_of_key ledger sender_pk)
      in
      (Option.value_exn (Ledger.get ledger account_location)).nonce

    let create_payment sender_sk receiver_pk send_amount nonce =
      let sender_keypair = Keypair.of_private_key_exn sender_sk in
      let payload : User_command.Payload.t =
        User_command.Payload.create ~fee:Currency.Fee.zero ~nonce
          ~memo:User_command_memo.dummy
          ~body:(Payment {receiver= receiver_pk; amount= send_amount})
      in
      User_command.sign sender_keypair payload

    let assert_receipt_chain_in_breacrumbs ~resulting_receipt
        breadcrumbs_from_oldest_to_youngest receipt_chain_processor sender =
      deferred_fold_result (List.rev breadcrumbs_from_oldest_to_youngest)
        ~init:0 ~f:(fun expected_payments_length breadcrumb ->
          let proving_receipt = get_receipt_chain breadcrumb sender in
          let open Deferred.Or_error.Let_syntax in
          let%bind init, payments =
            Receipt_chain.prove receipt_chain_processor ~proving_receipt
              ~resulting_receipt
          in
          let user_command_payloads_from_sender =
            List.filter_map ~f:(fun user_command ->
                Option.some_if
                  ( Public_key.Compressed.equal sender
                  @@ User_command.sender user_command )
                @@ User_command.payload user_command )
            @@ Transition_frontier.Breadcrumb.user_commands breadcrumb
          in
          Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
            !"Payloads in breacdcrumb"
            ~metadata:
              [ ( "Breadcrumbs"
                , `List
                    (List.map ~f:User_command_payload.to_yojson
                       user_command_payloads_from_sender) ) ] ;
          Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
            !"Successfully wrote proof"
            ~metadata:
              [ ( "Proving Receipt"
                , Receipt.Chain_hash.to_yojson proving_receipt )
              ; ( "Target Receipt"
                , Receipt.Chain_hash.to_yojson resulting_receipt )
              ; ("Num payments", `Int (List.length payments))
              ; ( "Merkle list"
                , `List (List.map ~f:User_command_payload.to_yojson payments)
                ) ] ;
          let payments_length = List.length payments in
          let%bind () =
            Deferred.return
            @@ Result.ok_if_true
                 (expected_payments_length = payments_length)
                 ~error:
                   (Error.createf
                      !"Expected length of Merkle list %i\n\
                        Actual length of merkle list is %i"
                      expected_payments_length payments_length)
          in
          let%map () =
            Deferred.return
            @@ Result.ok_if_true
                 ~error:
                   (Error.createf
                      !"Proof for proving receipt (%{sexp: \
                        Receipt.Chain_hash.t}) is not valid "
                      proving_receipt)
            @@ Receipt_chain.verify ~init payments resulting_receipt
          in
          expected_payments_length + 1 )
      |> Deferred.Result.ignore

    module Gen_payments = struct
      let one_sender_txn amount sender_sk staged_ledger
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

      let sender_having_multiple_txns ~num_transactions_per_block amount
          sender_sk staged_ledger accounts_with_secret_keys =
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
    end

    (* Converts breadcrumbs into ADDED_BREADCRUMB diffs and then the archive node stores it *)
    let store ~writer ~root created_breadcrumbs =
      let diffs =
        Test_setup.create_added_breadcrumb_diff
          (module Stubs.Transition_frontier)
          ~root created_breadcrumbs
      in
      List.iter diffs ~f:(Strict_pipe.Writer.write writer)

    let%test_unit "A node that has transactions in different blocks that are \
                   lined up can create a merkle proof for these transactions \
                   up to the best breadcrumb" =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier =
            Stubs.create_root_frontier ~logger ~pids Genesis_ledger.accounts
          in
          let root = Transition_frontier.root frontier in
          let%bind created_breadcrumbs =
            Stubs.instantiate_linear_breadcrumbs ~logger ~pids ~trust_system
              ~accounts_with_secret_keys
              ~gen_payments:(Gen_payments.one_sender_txn 1 largest_private_key)
              max_length root
          in
          Test_setup.try_with Test_setup.port ~f:(fun () ->
              let reader, writer =
                Strict_pipe.create ~name:"receipt_chain"
                  (Buffered (`Capacity 10, `Overflow Crash))
              in
              let processor = Processor.create ~logger Test_setup.port in
              let receipt_chain_processor =
                Receipt_chain.create (logger, Test_setup.port)
              in
              let processing_deferred_job = Processor.run processor reader in
              let best_tip_receipt_hash =
                get_receipt_chain
                  (List.last_exn created_breadcrumbs)
                  largest_public_key
              in
              store ~writer ~root created_breadcrumbs ;
              Strict_pipe.Writer.close writer ;
              let%bind () = processing_deferred_job in
              assert_receipt_chain_in_breacrumbs
                ~resulting_receipt:best_tip_receipt_hash created_breadcrumbs
                receipt_chain_processor largest_public_key
              |> Deferred.Or_error.ok_exn |> Deferred.ignore ) )

    let%test_unit "If a user has 2 different transactions with the same nonce \
                   on two different blocks that forked from a common block \
                   and there are other transactions in descendant blocks of \
                   those blocks, then the user can create a valid proof for \
                   these forked transactions" =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier =
            Stubs.create_root_frontier ~logger ~pids Genesis_ledger.accounts
          in
          let root = Transition_frontier.root frontier in
          let total_path_length = max_length - 2 in
          let ancestor_path_length = total_path_length / 2 in
          let fork_length = total_path_length / 2 in
          let%bind ancestor_breadcrumbs =
            Stubs.instantiate_linear_breadcrumbs ~logger ~pids ~trust_system
              ~accounts_with_secret_keys ancestor_path_length root
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
            let gen_payments =
              Gen_payments.one_sender_txn 1 largest_private_key
            in
            Stubs.instantiate_linear_breadcrumbs ~gen_payments ~logger ~pids
              ~trust_system ~accounts_with_secret_keys fork_length
              least_common_ancestor
          and fork2 =
            let gen_payments =
              Gen_payments.one_sender_txn 1 largest_private_key
            in
            Stubs.instantiate_linear_breadcrumbs ~gen_payments ~logger ~pids
              ~trust_system ~accounts_with_secret_keys fork_length
              least_common_ancestor
          in
          let least_command_ancestor_parent_hash =
            Transition_frontier.Breadcrumb.parent_hash least_common_ancestor
          in
          let least_common_ancestor_parent =
            List.find_exn ancestor_breadcrumbs
              ~f:
                (Fn.compose
                   (State_hash.equal least_command_ancestor_parent_hash)
                   Transition_frontier.Breadcrumb.state_hash)
          in
          Test_setup.try_with Test_setup.port ~f:(fun () ->
              let processor = Processor.create ~logger Test_setup.port in
              let receipt_chain_processor =
                Receipt_chain.create (logger, Test_setup.port)
              in
              let reader, writer =
                Strict_pipe.create ~name:"receipt_chain"
                  (Buffered (`Capacity 10, `Overflow Crash))
              in
              let processing_deferred_job = Processor.run processor reader in
              store ~writer ~root:least_common_ancestor_parent
                (least_common_ancestor :: fork1) ;
              store ~writer ~root:least_common_ancestor_parent
                (least_common_ancestor :: fork2) ;
              Strict_pipe.Writer.close writer ;
              let%bind () = processing_deferred_job in
              let%bind () =
                Deferred.Or_error.ok_exn
                  (assert_receipt_chain_in_breacrumbs
                     ~resulting_receipt:
                       (get_receipt_chain (List.last_exn fork1)
                          largest_public_key)
                     (least_common_ancestor :: fork1)
                     receipt_chain_processor largest_public_key)
              in
              let%bind () =
                Deferred.Or_error.ok_exn
                  (assert_receipt_chain_in_breacrumbs
                     ~resulting_receipt:
                       (get_receipt_chain (List.last_exn fork2)
                          largest_public_key)
                     (least_common_ancestor :: fork2)
                     receipt_chain_processor largest_public_key)
              in
              Deferred.unit ) )

    let%test_unit "If a user has multiple transactions in a block (where the \
                   transactions' nonces are in contiguous order), then the \
                   user can create valid proofs for all of these transactions"
        =
      let num_transactions1 = 3 in
      let num_transactions2 = 4 in
      Async.Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier =
        Stubs.create_root_frontier ~logger ~pids Genesis_ledger.accounts
      in
      let root = Transition_frontier.root frontier in
      let%bind breadcrumb1 =
        let gen_payments =
          Gen_payments.sender_having_multiple_txns
            ~num_transactions_per_block:num_transactions1 1 largest_private_key
        in
        Quickcheck.random_value
          (Stubs.gen_breadcrumb ~gen_payments ~logger ~pids ~trust_system
             Genesis_ledger.accounts)
        @@ Deferred.return root
      in
      let%bind breadcrumb2 =
        let gen_payments =
          Gen_payments.sender_having_multiple_txns
            ~num_transactions_per_block:num_transactions2 2 largest_private_key
        in
        Quickcheck.random_value
          (Stubs.gen_breadcrumb ~gen_payments ~logger ~pids ~trust_system
             Genesis_ledger.accounts)
        @@ Deferred.return breadcrumb1
      in
      let all_user_commands =
        List.bind [breadcrumb1; breadcrumb2]
          ~f:Transition_frontier.Breadcrumb.user_commands
      in
      let total_num_transactions = num_transactions1 + num_transactions2 in
      [%test_pred: User_command.t list]
        ~message:
          "The number of user_commands added to the breadcrumbs should equal \
           to total number of transactions generated by the test"
        (fun user_commands ->
          total_num_transactions
          = Set.length @@ User_command.Set.of_list user_commands )
        all_user_commands ;
      Test_setup.try_with Test_setup.port ~f:(fun () ->
          let reader, writer =
            Strict_pipe.create ~name:"receipt_chain"
              (Buffered (`Capacity 10, `Overflow Crash))
          in
          let processor = Processor.create ~logger Test_setup.port in
          let processing_deferred_job = Processor.run processor reader in
          let receipt_chain_processor =
            Receipt_chain.create (logger, Test_setup.port)
          in
          store ~writer ~root [breadcrumb1; breadcrumb2] ;
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
          Strict_pipe.Writer.close writer ;
          let%bind () = processing_deferred_job in
          deferred_fold_result expected_receipt_chains ~init:()
            ~f:(fun () proving_receipt ->
              (let open Deferred.Result.Let_syntax in
              let%bind init, user_commands =
                Receipt_chain.prove receipt_chain_processor ~proving_receipt
                  ~resulting_receipt
              in
              Deferred.return
              @@ Result.ok_if_true
                   ~error:(Error.of_string "Expected correct test")
              @@ Receipt_chain.verify ~init user_commands resulting_receipt)
              |> Deferred.Or_error.ignore )
          |> Deferred.Or_error.ok_exn |> ignore ;
          Deferred.unit )
  end )
