(* Only show stdout for failed inline tests.*)
open Inline_test_quiet_logs
open Core
open Async
open Mina_base
open Mina_transaction
open Pipe_lib
open Network_peer
open Test_utils
open Signature_lib

let%test_module "transaction pool" =
  ( module struct

let%test_unit "transactions are removed in linear case (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_linear_case_test test independent_cmds )

    let%test_unit "transactions are removed in linear case (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_commands_single_block 7 test.txn_pool
          >>= mk_linear_case_test test )

    let mk_remove_and_add_test t cmds =
      assert_pool_txs t [] ;
      (* omit the 1st (0-based) command *)
      let%bind () = add_commands' t (List.hd_exn cmds :: List.drop cmds 2) in
      commit_commands t (List.take cmds 1) ;
      let%bind () = reorg t (List.take cmds 1) (List.slice cmds 1 2) in
      assert_pool_txs t (List.tl_exn cmds) ;
      Deferred.unit

    let%test_unit "Transactions are removed and added back in fork changes \
                   (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_remove_and_add_test test independent_cmds )

    let%test_unit "Transactions are removed and added back in fork changes \
                   (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_commands_single_block 7 test.txn_pool
          >>= mk_remove_and_add_test test )

    let mk_invalid_test t cmds =
      assert_pool_txs t [] ;
      let%bind () = advance_chain t (List.take cmds 2) in
      let%bind () =
        add_commands t cmds >>| assert_pool_apply (List.drop cmds 2)
      in
      assert_pool_txs t (List.drop cmds 2) ;
      Deferred.unit

    let%test_unit "invalid transactions are not accepted (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_invalid_test test independent_cmds )

    let%test_unit "invalid transactions are not accepted (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_commands_single_block 7 test.txn_pool
          >>= mk_invalid_test test )

    let current_global_slot () =
      let current_time = Block_time.now time_controller in
      (* for testing, consider this slot to be a since-genesis slot *)
      Consensus.Data.Consensus_time.(
        of_time_exn ~constants:consensus_constants current_time
        |> to_global_slot)
      |> Mina_numbers.Global_slot_since_hard_fork.to_uint32
      |> Mina_numbers.Global_slot_since_genesis.of_uint32

    let mk_now_invalid_test t _cmds ~mk_command =
      let cmd1 =
        mk_command ~sender_idx:0 ~receiver_idx:5 ~fee:minimum_fee ~nonce:0
          ~amount:99_999_999_999 ()
      in
      let cmd2 =
        mk_command ~sender_idx:0 ~receiver_idx:5 ~fee:minimum_fee ~nonce:0
          ~amount:999_000_000_000 ()
      in
      assert_pool_txs t [] ;
      let%bind () = add_commands' t [ cmd1 ] in
      assert_pool_txs t [ cmd1 ] ;
      let%bind () = advance_chain t [ cmd2 ] in
      assert_pool_txs t [] ; Deferred.unit

    let%test_unit "Now-invalid transactions are removed from the pool on fork \
                   changes (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_now_invalid_test test independent_cmds
            ~mk_command:(mk_payment ?valid_until:None) )

    let%test_unit "Now-invalid transactions are removed from the pool on fork \
                   changes (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_commands_single_block 7 test.txn_pool
          >>= mk_now_invalid_test test
                ~mk_command:
                  (mk_transfer_zkapp_command ?valid_period:None
                     ?fee_payer_idx:None ) )

    let mk_expired_not_accepted_test t ~padding cmds =
      assert_pool_txs t [] ;
      let%bind () =
        let current_time = Block_time.now time_controller in
        let slot_end =
          Consensus.Data.Consensus_time.(
            of_time_exn ~constants:consensus_constants current_time
            |> end_time ~constants:consensus_constants)
        in
        at (Block_time.to_time_exn slot_end)
      in
      let curr_slot = current_global_slot () in
      let slot_padding = Mina_numbers.Global_slot_span.of_int padding in
      let curr_slot_plus_padding =
        Mina_numbers.Global_slot_since_genesis.add curr_slot slot_padding
      in
      let valid_command =
        mk_payment ~valid_until:curr_slot_plus_padding ~sender_idx:1
          ~fee:minimum_fee ~nonce:1 ~receiver_idx:7 ~amount:1_000_000_000 ()
      in
      let expired_commands =
        [ mk_payment ~valid_until:curr_slot ~sender_idx:0 ~fee:minimum_fee
            ~nonce:1 ~receiver_idx:9 ~amount:1_000_000_000 ()
        ; mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:2 ~receiver_idx:9
            ~amount:1_000_000_000 ()
        ]
      in
      (* Wait till global slot increases by 1 which invalidates
         the commands with valid_until = curr_slot
      *)
      let%bind () =
        after
          (Block_time.Span.to_time_span
             consensus_constants.block_window_duration_ms )
      in
      let all_valid_commands = cmds @ [ valid_command ] in
      let%bind () =
        add_commands t (all_valid_commands @ expired_commands)
        >>| assert_pool_apply all_valid_commands
      in
      assert_pool_txs t all_valid_commands ;
      Deferred.unit

    let%test_unit "expired transactions are not accepted (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_expired_not_accepted_test test ~padding:10 independent_cmds )

    let%test_unit "expired transactions are not accepted (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_commands_single_block 7 test.txn_pool
          >>= mk_expired_not_accepted_test test ~padding:55 )

    let%test_unit "Expired transactions that are already in the pool are \
                   removed from the pool when best tip changes (user commands)"
        =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind t = setup_test () in
          assert_pool_txs t [] ;
          let curr_slot = current_global_slot () in
          let curr_slot_plus_three =
            Mina_numbers.Global_slot_since_genesis.add curr_slot
              (Mina_numbers.Global_slot_span.of_int 3)
          in
          let curr_slot_plus_seven =
            Mina_numbers.Global_slot_since_genesis.add curr_slot
              (Mina_numbers.Global_slot_span.of_int 7)
          in
          let few_now =
            List.take independent_cmds (List.length independent_cmds / 2)
          in
          let expires_later1 =
            mk_payment ~valid_until:curr_slot_plus_three ~sender_idx:0
              ~fee:minimum_fee ~nonce:1 ~receiver_idx:9 ~amount:10_000_000_000
              ()
          in
          let expires_later2 =
            mk_payment ~valid_until:curr_slot_plus_seven ~sender_idx:0
              ~fee:minimum_fee ~nonce:2 ~receiver_idx:9 ~amount:10_000_000_000
              ()
          in
          let valid_commands = few_now @ [ expires_later1; expires_later2 ] in
          let%bind () = add_commands' t valid_commands in
          assert_pool_txs t valid_commands ;
          (* new commands from best tip diff should be removed from the pool *)
          (* update the nonce to be consistent with the commands in the block *)
          modify_ledger !(t.best_tip_ref) ~idx:0 ~balance:1_000_000_000_000_000
            ~nonce:2 ;
          let%bind () = reorg t [ List.nth_exn few_now 0; expires_later1 ] [] in
          let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
          assert_pool_txs t (expires_later2 :: List.drop few_now 1) ;
          (* Add new commands, remove old commands some of which are now expired *)
          let expired_command =
            mk_payment ~valid_until:curr_slot ~sender_idx:9 ~fee:minimum_fee
              ~nonce:0 ~receiver_idx:5 ~amount:1_000_000_000 ()
          in
          let unexpired_command =
            mk_payment ~valid_until:curr_slot_plus_seven ~sender_idx:8
              ~fee:minimum_fee ~nonce:0 ~receiver_idx:9 ~amount:1_000_000_000 ()
          in
          let valid_forever = List.nth_exn few_now 0 in
          let removed_commands =
            [ valid_forever
            ; expires_later1
            ; expired_command
            ; unexpired_command
            ]
          in
          let n_block_times n =
            Int64.(
              Block_time.Span.to_ms consensus_constants.block_window_duration_ms
              * n)
            |> Block_time.Span.of_ms
          in
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 3L))
          in
          modify_ledger !(t.best_tip_ref) ~idx:0 ~balance:1_000_000_000_000_000
            ~nonce:1 ;
          let%bind _ = reorg t [ valid_forever ] removed_commands in
          (* expired_command should not be in the pool because they are expired
             and (List.nth few_now 0) because it was committed in a block
          *)
          assert_pool_txs t
            ( expires_later1 :: expires_later2 :: unexpired_command
            :: List.drop few_now 1 ) ;
          (* after 5 block times there should be no expired transactions *)
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 5L))
          in
          let%bind _ = reorg t [] [] in
          assert_pool_txs t (List.drop few_now 1) ;
          Deferred.unit )

    let%test_unit "Expired transactions that are already in the pool are \
                   removed from the pool when best tip changes (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind t = setup_test () in
          assert_pool_txs t [] ;
          let curr_slot = current_global_slot () in
          let curr_slot_plus_three =
            Mina_numbers.Global_slot_since_genesis.add curr_slot
              (Mina_numbers.Global_slot_span.of_int 3)
          in
          let curr_slot_plus_seven =
            Mina_numbers.Global_slot_since_genesis.add curr_slot
              (Mina_numbers.Global_slot_span.of_int 7)
          in
          let few_now =
            List.take independent_cmds (List.length independent_cmds / 2)
          in
          let expires_later1 =
            mk_transfer_zkapp_command
              ~valid_period:{ lower = curr_slot; upper = curr_slot_plus_three }
              ~fee_payer_idx:(0, 1) ~sender_idx:1 ~receiver_idx:9
              ~fee:minimum_fee ~amount:10_000_000_000 ~nonce:1 ()
          in
          let expires_later2 =
            mk_transfer_zkapp_command
              ~valid_period:{ lower = curr_slot; upper = curr_slot_plus_seven }
              ~fee_payer_idx:(2, 1) ~sender_idx:3 ~receiver_idx:9
              ~fee:minimum_fee ~amount:10_000_000_000 ~nonce:1 ()
          in
          let valid_commands = few_now @ [ expires_later1; expires_later2 ] in
          let%bind () = add_commands' t valid_commands in
          assert_pool_txs t valid_commands ;
          let n_block_times n =
            Int64.(
              Block_time.Span.to_ms consensus_constants.block_window_duration_ms
              * n)
            |> Block_time.Span.of_ms
          in
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 4L))
          in
          let%bind () = reorg t [] [] in
          assert_pool_txs t (expires_later2 :: few_now) ;
          (* after 5 block times there should be no expired transactions *)
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 5L))
          in
          let%bind () = reorg t [] [] in
          assert_pool_txs t few_now ; Deferred.unit )

    let%test_unit "Now-invalid transactions are removed from the pool when the \
                   transition frontier is recreated (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          (* Set up initial frontier *)
          let%bind t = setup_test () in
          assert_pool_txs t [] ;
          let%bind _ = add_commands t independent_cmds in
          assert_pool_txs t independent_cmds ;
          (* Destroy initial frontier *)
          Broadcast_pipe.Writer.close t.best_tip_diff_w ;
          let%bind _ = Broadcast_pipe.Writer.write t.frontier_pipe_w None in
          (* Set up second frontier *)
          let ((_, ledger_ref2) as frontier2), _best_tip_diff_w2 =
            Mock_transition_frontier.create ()
          in
          modify_ledger !ledger_ref2 ~idx:0 ~balance:20_000_000_000_000 ~nonce:5 ;
          modify_ledger !ledger_ref2 ~idx:1 ~balance:0 ~nonce:0 ;
          modify_ledger !ledger_ref2 ~idx:2 ~balance:0 ~nonce:1 ;
          let%bind _ =
            Broadcast_pipe.Writer.write t.frontier_pipe_w (Some frontier2)
          in
          assert_pool_txs t (List.drop independent_cmds 3) ;
          Deferred.unit )

    let%test_unit "transaction replacement works" =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind t = setup_test () in
      let set_sender idx (tx : Signed_command.t) =
        let sender_kp = test_keys.(idx) in
        let sender_pk = Public_key.compress sender_kp.public_key in
        let payload : Signed_command.Payload.t =
          match tx.payload with
          | { common; body = Payment payload } ->
              { common = { common with fee_payer_pk = sender_pk }
              ; body = Payment payload
              }
          | { common; body = Stake_delegation (Set_delegate payload) } ->
              { common = { common with fee_payer_pk = sender_pk }
              ; body = Stake_delegation (Set_delegate payload)
              }
        in
        User_command.Signed_command (Signed_command.sign sender_kp payload)
      in
      let txs0 =
        [ mk_payment' ~sender_idx:0 ~fee:minimum_fee ~nonce:0 ~receiver_idx:9
            ~amount:20_000_000_000 ()
        ; mk_payment' ~sender_idx:0 ~fee:minimum_fee ~nonce:1 ~receiver_idx:9
            ~amount:12_000_000_000 ()
        ; mk_payment' ~sender_idx:0 ~fee:minimum_fee ~nonce:2 ~receiver_idx:9
            ~amount:500_000_000_000 ()
        ]
      in
      let txs0' = List.map txs0 ~f:Signed_command.forget_check in
      let txs1 = List.map ~f:(set_sender 1) txs0' in
      let txs2 = List.map ~f:(set_sender 2) txs0' in
      let txs3 = List.map ~f:(set_sender 3) txs0' in
      let txs_all =
        List.map ~f:(fun x -> User_command.Signed_command x) txs0
        @ txs1 @ txs2 @ txs3
      in
      let%bind () = add_commands' t txs_all in
      assert_pool_txs t txs_all ;
      let replace_txs =
        [ (* sufficient fee *)
          mk_payment ~sender_idx:0
            ~fee:
              ( minimum_fee
              + Currency.Fee.to_nanomina_int Indexed_pool.replace_fee )
            ~nonce:0 ~receiver_idx:1 ~amount:440_000_000_000 ()
        ; (* insufficient fee *)
          mk_payment ~sender_idx:1 ~fee:minimum_fee ~nonce:0 ~receiver_idx:1
            ~amount:788_000_000_000 ()
        ; (* sufficient *)
          mk_payment ~sender_idx:2
            ~fee:
              ( minimum_fee
              + Currency.Fee.to_nanomina_int Indexed_pool.replace_fee )
            ~nonce:1 ~receiver_idx:4 ~amount:721_000_000_000 ()
        ; (* insufficient *)
          (let amount = 927_000_000_000 in
           let fee =
             let ledger = !(t.best_tip_ref) in
             let sender_kp = test_keys.(3) in
             let sender_pk = Public_key.compress sender_kp.public_key in
             let sender_aid = Account_id.create sender_pk Token_id.default in
             let location =
               Mock_base_ledger.location_of_account ledger sender_aid
               |> Option.value_exn
             in
             (* Spend all of the tokens in the account. Should fail because the
                command with nonce=0 will already have spent some.
             *)
             let account =
               Mock_base_ledger.get ledger location |> Option.value_exn
             in
             Currency.Balance.to_nanomina_int account.balance - amount
           in
           mk_payment ~sender_idx:3 ~fee ~nonce:1 ~receiver_idx:4 ~amount () )
        ]
      in
      add_commands t replace_txs
      >>| assert_pool_apply
            [ List.nth_exn replace_txs 0; List.nth_exn replace_txs 2 ]

    let%test_unit "it drops queued transactions if a committed one makes there \
                   be insufficient funds" =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind t = setup_test () in
      let txs =
        [ mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:0 ~receiver_idx:9
            ~amount:20_000_000_000 ()
        ; mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:1 ~receiver_idx:5
            ~amount:77_000_000_000 ()
        ; mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:2 ~receiver_idx:3
            ~amount:891_000_000_000 ()
        ]
      in
      let committed_tx =
        mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:0 ~receiver_idx:2
          ~amount:25_000_000_000 ()
      in
      let%bind () = add_commands' t txs in
      assert_pool_txs t txs ;
      modify_ledger !(t.best_tip_ref) ~idx:0 ~balance:970_000_000_000 ~nonce:1 ;
      let%bind () = reorg t [ committed_tx ] [] in
      assert_pool_txs t [ List.nth_exn txs 1 ] ;
      Deferred.unit

    let%test_unit "max size is maintained" =
      Quickcheck.test ~trials:500
        (let open Quickcheck.Generator.Let_syntax in
        let%bind init_ledger_state =
          Mina_ledger.Ledger.gen_initial_ledger_state
        in
        let%bind cmds_count = Int.gen_incl pool_max_size (pool_max_size * 2) in
        let%bind cmds =
          User_command.Valid.Gen.sequence ~sign_type:`Real ~length:cmds_count
            init_ledger_state
        in
        return (init_ledger_state, cmds))
        ~f:(fun (init_ledger_state, cmds) ->
          Thread_safe.block_on_async_exn (fun () ->
              let%bind t = setup_test () in
              apply_initial_ledger_state t init_ledger_state ;
              let%bind () = reorg ~reorg_best_tip:true t [] [] in
              let cmds1, cmds2 = List.split_n cmds pool_max_size in
              let%bind apply_res1 = add_commands t cmds1 in
              assert (Result.is_ok apply_res1) ;
              [%test_eq: int] pool_max_size (Indexed_pool.size t.txn_pool.pool) ;
              let%map _apply_res2 = add_commands t cmds2 in
              (* N.B. Adding a transaction when the pool is full may drop > 1
                 command, so the size now is not necessarily the maximum.
                 Applying the diff may also return an error if none of the new
                 commands have higher fee than the lowest one already in the
                 pool.
              *)
              assert (Indexed_pool.size t.txn_pool.pool <= pool_max_size) ) )

    let assert_rebroadcastable test cmds =
      let expected =
        if List.is_empty cmds then []
        else
          [ List.map cmds
              ~f:
                (Fn.compose Transaction_hash.User_command.create
                   User_command.forget_check )
          ]
      in
      let actual =
        Test.Resource_pool.get_rebroadcastable test.txn_pool
          ~has_timed_out:(Fn.const `Ok)
        |> List.map ~f:(List.map ~f:Transaction_hash.User_command.create)
      in
      if List.length actual > 1 then
        failwith "unexpected number of rebroadcastable diffs" ;

      List.iter (List.zip_exn actual expected) ~f:(fun (a, b) ->
          assert_user_command_sets_equal a b )

    let mk_rebroadcastable_test t cmds =
      assert_pool_txs t [] ;
      assert_rebroadcastable t [] ;
      (* Locally generated transactions are rebroadcastable *)
      let%bind () = add_commands' ~local:true t (List.take cmds 2) in
      assert_pool_txs t (List.take cmds 2) ;
      assert_rebroadcastable t (List.take cmds 2) ;
      (* Adding non-locally-generated transactions doesn't affect
         rebroadcastable pool *)
      let%bind () = add_commands' ~local:false t (List.slice cmds 2 5) in
      assert_pool_txs t (List.take cmds 5) ;
      assert_rebroadcastable t (List.take cmds 2) ;
      (* When locally generated transactions are committed they are no
         longer rebroadcastable *)
      let%bind () = add_commands' ~local:true t (List.slice cmds 5 7) in
      let%bind checkpoint_1 = commit_commands' t (List.take cmds 1) in
      let%bind checkpoint_2 = commit_commands' t (List.slice cmds 1 5) in
      let%bind () = reorg t (List.take cmds 5) [] in
      assert_pool_txs t (List.slice cmds 5 7) ;
      assert_rebroadcastable t (List.slice cmds 5 7) ;
      (* Reorgs put locally generated transactions back into the
         rebroadcastable pool, if they were removed and not re-added *)
      (* restore up to after the application of the first command *)
      t.best_tip_ref := checkpoint_2 ;
      (* reorg both removes and re-adds the first command (which is local) *)
      let%bind () = reorg t (List.take cmds 1) (List.take cmds 5) in
      assert_pool_txs t (List.slice cmds 1 7) ;
      assert_rebroadcastable t (List.nth_exn cmds 1 :: List.slice cmds 5 7) ;
      (* Committing them again removes them from the pool again. *)
      commit_commands t (List.slice cmds 1 5) ;
      let%bind () = reorg t (List.slice cmds 1 5) [] in
      assert_pool_txs t (List.slice cmds 5 7) ;
      assert_rebroadcastable t (List.slice cmds 5 7) ;
      (* When transactions expire from rebroadcast pool they are gone. This
         doesn't affect the main pool.
      *)
      t.best_tip_ref := checkpoint_1 ;
      let%bind () = reorg t [] (List.take cmds 5) in
      assert_pool_txs t (List.take cmds 7) ;
      assert_rebroadcastable t (List.take cmds 2 @ List.slice cmds 5 7) ;
      ignore
        ( Test.Resource_pool.get_rebroadcastable t.txn_pool
            ~has_timed_out:(Fn.const `Timed_out)
          : User_command.t list list ) ;
      assert_rebroadcastable t [] ;
      Deferred.unit

    let%test_unit "rebroadcastable transaction behavior (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_rebroadcastable_test test independent_cmds )

    let%test_unit "rebroadcastable transaction behavior (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_commands_single_block 7 test.txn_pool
          >>= mk_rebroadcastable_test test )

    let%test_unit "apply user cmds and zkapps" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind t = setup_test () in
          let num_cmds = Array.length test_keys in
          (* the user cmds and snapp cmds are taken from the same list of keys,
             so splitting by the order from that list makes sure that they
             don't share fee payer keys
             therefore, the original nonces in the accounts are valid
          *)
          let take_len = num_cmds / 2 in
          let%bind snapp_cmds =
            let%map cmds = mk_zkapp_commands_single_block 7 t.txn_pool in
            List.take cmds take_len
          in
          let user_cmds = List.drop independent_cmds take_len in
          let all_cmds = snapp_cmds @ user_cmds in
          assert_pool_txs t [] ;
          let%bind () = add_commands' t all_cmds in
          assert_pool_txs t all_cmds ; Deferred.unit )

    let%test_unit "zkapp cmd with same nonce should replace previous submitted \
                   zkapp with same nonce" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind () = after (Time.Span.of_sec 2.) in
          let%bind t = setup_test () in
          assert_pool_txs t [] ;
          let fee_payer_kp = test_keys.(0) in
          let%bind valid_command1 =
            mk_basic_zkapp ~fee:10_000_000_000 0 fee_payer_kp
            |> mk_zkapp_user_cmd t.txn_pool
          in
          let%bind valid_command2 =
            mk_basic_zkapp ~fee:20_000_000_000 ~empty_update:true 0 fee_payer_kp
            |> mk_zkapp_user_cmd t.txn_pool
          in
          let%bind () =
            add_commands t ([ valid_command1 ] @ [ valid_command2 ])
            >>| assert_pool_apply [ valid_command2 ]
          in
          Deferred.unit )

    let%test_unit "commands are rejected if fee payer permissions are not \
                   handled" =
      let test_permissions ~is_able_to_send send_command permissions =
        let%bind t = setup_test () in
        assert_pool_txs t [] ;
        let%bind set_permissions_command =
          mk_basic_zkapp 0 test_keys.(0) ~permissions
          |> mk_zkapp_user_cmd t.txn_pool
        in
        let%bind () = add_commands' t [ set_permissions_command ] in
        let%bind () = advance_chain t [ set_permissions_command ] in
        assert_pool_txs t [] ;
        let%map result = add_commands t [ send_command ] in
        let expectation = if is_able_to_send then [ send_command ] else [] in
        assert_pool_apply expectation result
      in
      let run_test_cases send_cmd =
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              send = Permissions.Auth_required.Signature
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              send = Permissions.Auth_required.Either
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              send = Permissions.Auth_required.None
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              send = Permissions.Auth_required.Impossible
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              send = Permissions.Auth_required.Proof
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              increment_nonce = Permissions.Auth_required.Signature
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              increment_nonce = Permissions.Auth_required.Either
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              increment_nonce = Permissions.Auth_required.None
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              increment_nonce = Permissions.Auth_required.Impossible
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              increment_nonce = Permissions.Auth_required.Proof
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              access = Permissions.Auth_required.Signature
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              access = Permissions.Auth_required.Either
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              access = Permissions.Auth_required.None
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              access = Permissions.Auth_required.Impossible
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              access = Permissions.Auth_required.Proof
            }
        in
        return ()
      in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind () =
            let send_command =
              mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:1 ~receiver_idx:1
                ~amount:1_000_000 ()
            in
            run_test_cases send_command
          in
          let%bind () =
            let send_command =
              mk_transfer_zkapp_command ~fee_payer_idx:(0, 1) ~sender_idx:0
                ~fee:minimum_fee ~nonce:2 ~receiver_idx:1 ~amount:1_000_000 ()
            in
            run_test_cases send_command
          in
          return () )

    let%test "account update with a different network id that uses proof \
              authorization would be rejected" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind verifier_full =
            Verifier.create ~logger ~proof_level:Full ~constraint_constants
              ~conf_dir:None
              ~pids:(Child_processes.Termination.create_pid_table ())
              ~commit_id:"not specified for unit tests" ()
          in
          let%bind test =
            setup_test ~verifier:verifier_full
              ~permissions:
                { Permissions.user_default with set_zkapp_uri = Proof }
              ()
          in
          let%bind zkapp_command =
            mk_single_account_update
              ~chain:Mina_signature_kind.(Other_network "invalid")
              ~fee_payer_idx:0 ~fee:minimum_fee ~nonce:0 ~zkapp_account_idx:1
              ~ledger:(Option.value_exn test.txn_pool.best_tip_ledger)
          in
          match%map
            Test.Resource_pool.Diff.verify test.txn_pool
              (Envelope.Incoming.wrap
                 ~data:
                   [ User_command.forget_check
                     @@ Zkapp_command
                          (Zkapp_command.Valid.of_verifiable zkapp_command)
                   ]
                 ~sender:Envelope.Sender.Local )
          with
          | Error (Intf.Verification_error.Invalid e) ->
              String.is_substring (Error.to_string_hum e) ~substring:"proof"
          | _ ->
              false )

    let%test_unit "transactions added before slot_tx_end are accepted" =
      Thread_safe.block_on_async_exn (fun () ->
          let curr_slot =
            Mina_numbers.(
              Global_slot_since_hard_fork.of_uint32
              @@ Global_slot_since_genesis.to_uint32 @@ current_global_slot ())
          in
          let slot_tx_end =
            Mina_numbers.Global_slot_since_hard_fork.(succ @@ succ curr_slot)
          in
          let%bind t = setup_test ~slot_tx_end () in
          assert_pool_txs t [] ;
          add_commands t independent_cmds >>| assert_pool_apply independent_cmds )

    let%test_unit "transactions added at slot_tx_end are rejected" =
      Thread_safe.block_on_async_exn (fun () ->
          let curr_slot =
            Mina_numbers.(
              Global_slot_since_hard_fork.of_uint32
              @@ Global_slot_since_genesis.to_uint32 @@ current_global_slot ())
          in
          let%bind t = setup_test ~slot_tx_end:curr_slot () in
          assert_pool_txs t [] ;
          add_commands t independent_cmds >>| assert_pool_apply [] )

    let%test_unit "transactions added after slot_tx_end are rejected" =
      Thread_safe.block_on_async_exn (fun () ->
          let curr_slot =
            Mina_numbers.(
              Global_slot_since_hard_fork.of_uint32
              @@ Global_slot_since_genesis.to_uint32 @@ current_global_slot ())
          in
          let slot_tx_end =
            Option.value_exn
            @@ Mina_numbers.(
                 Global_slot_since_hard_fork.(
                   sub curr_slot @@ Global_slot_span.of_int 1))
          in
          let%bind t = setup_test ~slot_tx_end () in
          assert_pool_txs t [] ;
          add_commands t independent_cmds >>| assert_pool_apply [] )
        end)