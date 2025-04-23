open Core_kernel
open Async
open Mina_base
open Pipe_lib
open Network_pool
open Transaction_inclusion_status
open Mina_numbers

let max_length = 10

let frontier_size = 1

let logger = Logger.null ()

let () =
  (* Disable log messages from best_tip_diff logger. *)
  Logger.Consumer_registry.register ~commit_id:""
    ~id:Logger.Logger_id.best_tip_diff ~processor:(Logger.Processor.raw ())
    ~transport:
      (Logger.Transport.create
         ( module struct
           type t = unit

           let transport () _ = ()
         end )
         () )
    ()

let time_controller = Block_time.Controller.basic ~logger

let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

let proof_level = precomputed_values.proof_level

let constraint_constants = precomputed_values.constraint_constants

module Genesis_ledger = (val precomputed_values.genesis_ledger)

let trust_system = Trust_system.null ()

let pool_max_size = precomputed_values.genesis_constants.txpool_max_size

let block_window_duration =
  Mina_compile_config.For_unit_tests.t.block_window_duration

let verifier () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      Verifier.For_tests.default ~constraint_constants ~logger ~proof_level () )

let key_gen =
  let open Quickcheck.Generator in
  let open Quickcheck.Generator.Let_syntax in
  let keypairs = List.map (Lazy.force Genesis_ledger.accounts) ~f:fst in
  let%map random_key_opt = of_list keypairs in
  ( Genesis_ledger.largest_account_keypair_exn ()
  , Signature_lib.Keypair.of_private_key_exn (Option.value_exn random_key_opt)
  )

let gen_frontier verifier =
  Transition_frontier.For_tests.gen ~logger ~precomputed_values ~verifier
    ~trust_system ~max_length ~size:frontier_size ()

(* TODO: Generate zkApps txns *)
let gen_user_command =
  Signed_command.Gen.payment ~sign_type:`Real ~max_amount:100 ~fee_range:10
    ~key_gen ~nonce:(Account_nonce.of_int 1) ()

let create_pool ~frontier_broadcast_pipe verifier =
  let config =
    Transaction_pool.Resource_pool.make_config ~trust_system ~pool_max_size
      ~verifier ~genesis_constants:precomputed_values.genesis_constants
      ~slot_tx_end:None
      ~vk_cache_db:(Zkapp_vk_cache_tag.For_tests.create_db ())
  in
  let transaction_pool, _, local_sink =
    Transaction_pool.create ~config
      ~constraint_constants:precomputed_values.constraint_constants
      ~consensus_constants:precomputed_values.consensus_constants
      ~time_controller ~logger ~frontier_broadcast_pipe ~log_gossip_heard:false
      ~on_remote_push:(Fn.const Deferred.unit) ~block_window_duration
  in
  don't_wait_for
  @@ Linear_pipe.iter (Transaction_pool.broadcasts transaction_pool)
       ~f:(fun Network_pool.With_nonce.{ message = transactions; _ } ->
         [%log trace]
           "Transactions have been applied successfully and is propagated \
            throughout the 'network'"
           ~metadata:
             [ ( "transactions"
               , Transaction_pool.Diff_versioned.to_yojson transactions )
             ] ;
         Deferred.unit ) ;
  (* Need to wait for transaction_pool to see the transition_frontier *)
  let%map () = Async.Scheduler.yield_until_no_jobs_remain () in
  (transaction_pool, local_sink)

let test_unknown_status_when_no_frontier () =
  let verifier = verifier () in
  Quickcheck.test ~trials:1 gen_user_command ~f:(fun user_command ->
      Backtrace.elide := false ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          let frontier_broadcast_pipe, _ = Broadcast_pipe.create None in
          let%bind transaction_pool, local_diffs_writer =
            create_pool ~frontier_broadcast_pipe verifier
          in
          let%bind () =
            Transaction_pool.Local_sink.push local_diffs_writer
              ([ Signed_command user_command ], Fn.const ())
          in
          let%map () = Async.Scheduler.yield_until_no_jobs_remain () in
          let state_testable =
            Alcotest.testable
              (fun fmt state -> Format.fprintf fmt "%s" (State.to_string state))
              State.equal
          in
          Alcotest.(check state_testable)
            "Transaction status should be Unknown when frontier doesn't exist"
            State.Unknown
            (get_status ~frontier_broadcast_pipe ~transaction_pool
               (Signed_command user_command) ) ) )

let test_pending_transaction () =
  let verifier = verifier () in
  Quickcheck.test ~trials:1
    (Quickcheck.Generator.tuple2 (gen_frontier verifier) gen_user_command)
    ~f:(fun (frontier, user_command) ->
      Async.Thread_safe.block_on_async_exn (fun () ->
          let frontier_broadcast_pipe, _ =
            Broadcast_pipe.create (Some frontier)
          in
          let%bind transaction_pool, local_diffs_writer =
            create_pool ~frontier_broadcast_pipe verifier
          in
          let%bind () =
            Transaction_pool.Local_sink.push local_diffs_writer
              ([ Signed_command user_command ], Fn.const ())
          in
          let%map () = Async.Scheduler.yield_until_no_jobs_remain () in
          let status =
            get_status ~frontier_broadcast_pipe ~transaction_pool
              (Signed_command user_command)
          in
          Alcotest.(check bool)
            "Transaction status should be Pending when in pool but not best \
             path"
            true
            (State.equal State.Pending status) ) )

let test_unknown_transaction () =
  let verifier = verifier () in
  let user_commands_generator =
    let open Quickcheck.Generator in
    let open Let_syntax in
    let%bind head_user_command = gen_user_command in
    let%map tail_user_commands =
      Quickcheck.Generator.list_with_length 10 gen_user_command
    in
    Mina_stdlib.Nonempty_list.init head_user_command tail_user_commands
  in
  Quickcheck.test ~trials:1
    (Quickcheck.Generator.tuple2 (gen_frontier verifier) user_commands_generator)
    ~f:(fun (frontier, user_commands) ->
      Async.Thread_safe.block_on_async_exn (fun () ->
          let frontier_broadcast_pipe, _ =
            Broadcast_pipe.create (Some frontier)
          in
          let%bind transaction_pool, local_diffs_writer =
            create_pool ~frontier_broadcast_pipe verifier
          in
          let unknown_user_command, pool_user_commands =
            Mina_stdlib.Nonempty_list.uncons user_commands
          in
          let%bind () =
            Transaction_pool.Local_sink.push local_diffs_writer
              ( List.map pool_user_commands ~f:(fun x ->
                    User_command.Signed_command x )
              , Fn.const () )
          in
          let%map () = Async.Scheduler.yield_until_no_jobs_remain () in
          Alcotest.(check bool)
            "Transaction status should be Unknown when not in pool or frontier"
            true
            (State.equal State.Unknown
               (get_status ~frontier_broadcast_pipe ~transaction_pool
                  (Signed_command unknown_user_command) ) ) ) )

let tests =
  [ ( "transaction_status"
    , [ Alcotest.test_case "unknown status when no frontier" `Quick
          test_unknown_status_when_no_frontier
      ; Alcotest.test_case "pending transaction" `Quick test_pending_transaction
      ; Alcotest.test_case "unknown transaction" `Quick test_unknown_transaction
      ] )
  ]

let () = Alcotest.run "Transaction_inclusion_status" tests
