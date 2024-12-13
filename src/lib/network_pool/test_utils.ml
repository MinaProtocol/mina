
open Signature_lib
open Core
open Async
open Mina_base
open Mina_transaction
open Pipe_lib
open Network_peer
open Transaction_pool

let%test_module "transaction pool utils" =
( module struct

    module Mock_base_ledger = Mocks.Base_ledger
    module Mock_staged_ledger = Mocks.Staged_ledger

    let num_test_keys = 10

    (* keys for accounts in the ledger *)
    let test_keys =
      Array.init num_test_keys ~f:(fun _ -> Signature_lib.Keypair.create ())

    let num_extra_keys = 30

    let block_window_duration =
      Mina_compile_config.For_unit_tests.t.block_window_duration

    (* keys that can be used when generating new accounts *)
    let extra_keys =
      Array.init num_extra_keys ~f:(fun _ -> Signature_lib.Keypair.create ())

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let constraint_constants = precomputed_values.constraint_constants

    let consensus_constants = precomputed_values.consensus_constants

    let proof_level = precomputed_values.proof_level

    let genesis_constants = precomputed_values.genesis_constants

    let minimum_fee =
      Currency.Fee.to_nanomina_int genesis_constants.minimum_user_command_fee

    let logger = Logger.create ()

    let time_controller = Block_time.Controller.basic ~logger

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~logger ~proof_level ~constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ())
            ~commit_id:"not specified for unit tests" () )

    let `VK vk, `Prover prover =
      Transaction_snark.For_tests.create_trivial_snapp ~constraint_constants ()

    let vk = Async.Thread_safe.block_on_async_exn (fun () -> vk)

    let dummy_state_view =
      let state_body =
        let consensus_constants =
          Consensus.Constants.create ~constraint_constants
            ~protocol_constants:genesis_constants.protocol
        in
        let compile_time_genesis =
          (*not using Precomputed_values.for_unit_test because of dependency cycle*)
          Mina_state.Genesis_protocol_state.t
            ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
            ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
            ~constraint_constants ~consensus_constants
            ~genesis_body_reference:Staged_ledger_diff.genesis_body_reference
        in
        compile_time_genesis.data |> Mina_state.Protocol_state.body
      in
      { (Mina_state.Protocol_state.Body.view state_body) with
        global_slot_since_genesis = Mina_numbers.Global_slot_since_genesis.zero
      }

    module Mock_transition_frontier = struct
      module Breadcrumb = struct
        type t = Mock_staged_ledger.t

        let staged_ledger = Fn.id
      end

      type best_tip_diff =
        { new_commands : User_command.Valid.t With_status.t list
        ; removed_commands : User_command.Valid.t With_status.t list
        ; reorg_best_tip : bool
        }

      type t = best_tip_diff Broadcast_pipe.Reader.t * Breadcrumb.t ref

      let create ?permissions :
          unit -> t * best_tip_diff Broadcast_pipe.Writer.t =
       fun () ->
        let zkappify_account (account : Account.t) : Account.t =
          let zkapp =
            Some { Zkapp_account.default with verification_key = Some vk }
          in
          { account with
            zkapp
          ; permissions =
              ( match permissions with
              | Some p ->
                  p
              | None ->
                  Permissions.user_default )
          }
        in
        let pipe_r, pipe_w =
          Broadcast_pipe.create
            { new_commands = []; removed_commands = []; reorg_best_tip = false }
        in
        let initial_balance =
          Currency.Balance.of_mina_string_exn "900000000.0"
        in
        let ledger = Mina_ledger.Ledger.create_ephemeral ~depth:10 () in
        Array.iteri test_keys ~f:(fun i kp ->
            let account_id =
              Account_id.create
                (Public_key.compress kp.public_key)
                Token_id.default
            in
            let _tag, account, loc =
              Or_error.ok_exn
              @@ Mina_ledger.Ledger.Ledger_inner.get_or_create ledger account_id
            in
            (* set the account balance *)
            let account = { account with balance = initial_balance } in
            (* zkappify every other account *)
            let account =
              if i mod 2 = 0 then account else zkappify_account account
            in
            Mina_ledger.Ledger.Ledger_inner.set ledger loc account ) ;
        ((pipe_r, ref ledger), pipe_w)

      let best_tip (_, best_tip) = !best_tip

      let best_tip_diff_pipe (pipe, _) = pipe
    end

    module Test =
      Make0 (Mock_base_ledger) (Mock_staged_ledger) (Mock_transition_frontier)

    type test =
      { txn_pool : Test.Resource_pool.t
      ; best_tip_diff_w :
          Mock_transition_frontier.best_tip_diff Broadcast_pipe.Writer.t
      ; best_tip_ref : Mina_ledger.Ledger.t ref
      ; frontier_pipe_w :
          Mock_transition_frontier.t option Broadcast_pipe.Writer.t
      }

    let pool_max_size = 25

    let apply_initial_ledger_state t init_ledger_state =
      let new_ledger =
        Mina_ledger.Ledger.create_ephemeral
          ~depth:(Mina_ledger.Ledger.depth !(t.best_tip_ref))
          ()
      in
      Mina_ledger.Ledger.apply_initial_ledger_state new_ledger init_ledger_state ;
      t.best_tip_ref := new_ledger

  let ledger_snapshot t =
      Array.map test_keys ~f:(fun kp ->
          let ledger = Option.value_exn t.txn_pool.best_tip_ledger in
          let account_id =
            Account_id.create
              (Public_key.compress kp.public_key)
              Token_id.default
          in
          let loc =
            Option.value_exn
            @@ Mina_ledger.Ledger.Ledger_inner.location_of_account ledger
                 account_id
          in
          let account =
            Option.value_exn @@ Mina_ledger.Ledger.Ledger_inner.get ledger loc
          in
          ( kp
          , Account.balance account |> Currency.Balance.to_amount
          , Account.nonce account
          , Account.timing account ) )


    let assert_user_command_sets_equal cs1 cs2 =
      let index cs =
        let decompose c =
          ( Transaction_hash.User_command.hash c
          , Transaction_hash.User_command.command c )
        in
        List.map cs ~f:decompose |> Transaction_hash.Map.of_alist_exn
      in
      let index1 = index cs1 in
      let index2 = index cs2 in
      let set1 = Transaction_hash.Set.of_list @@ Map.keys index1 in
      let set2 = Transaction_hash.Set.of_list @@ Map.keys index2 in
      if not (Set.equal set1 set2) then (
        let additional1, additional2 =
          Set.symmetric_diff set1 set2
          |> Sequence.map
               ~f:
                 (Either.map ~first:(Map.find_exn index1)
                    ~second:(Map.find_exn index2) )
          |> Sequence.to_list
          |> List.partition_map ~f:Fn.id
        in
        assert (List.length additional1 + List.length additional2 > 0) ;
        let report_additional commands a b =
          Core.Printf.printf "%s user commands not in %s:\n" a b ;
          List.iter commands ~f:(fun c ->
              Core.Printf.printf !"  %{Sexp}\n" (User_command.sexp_of_t c) )
        in
        if List.length additional1 > 0 then
          report_additional additional1 "actual" "expected" ;
        if List.length additional2 > 0 then
          report_additional additional2 "expected" "actual" ) ;
      [%test_eq: Transaction_hash.Set.t] set1 set2

    let replace_valid_zkapp_command_authorizations ~keymap ~ledger valid_cmds :
        User_command.Valid.t list Deferred.t =
      let open Deferred.Let_syntax in
      let%map zkapp_commands_fixed =
        Deferred.List.map
          (valid_cmds : User_command.Valid.t list)
          ~f:(function
            | Zkapp_command zkapp_command_dummy_auths ->
                let%map cmd =
                  Zkapp_command_builder.replace_authorizations ~keymap ~prover
                    (Zkapp_command.Valid.forget zkapp_command_dummy_auths)
                in
                User_command.Zkapp_command cmd
            | Signed_command _ ->
                failwith "Expected Zkapp_command valid user command" )
      in
      match
        User_command.Unapplied_sequence.to_all_verifiable zkapp_commands_fixed
          ~load_vk_cache:(fun account_ids ->
            Set.to_list account_ids
            |> Zkapp_command.Verifiable.load_vks_from_ledger
                 ~get_batch:(Mina_ledger.Ledger.get_batch ledger)
                 ~location_of_account_batch:
                   (Mina_ledger.Ledger.location_of_account_batch ledger)
            |> Map.map ~f:(fun vk ->
                   Zkapp_basic.F_map.Map.singleton vk.hash vk ) )
        |> Or_error.bind ~f:(fun xs ->
               List.map xs ~f:User_command.check_verifiable
               |> Or_error.combine_errors )
      with
      | Ok cmds ->
          cmds
      | Error err ->
          Error.raise
          @@ Error.tag ~tag:"Could not create Zkapp_command.Valid.t" err

    (** Assert the invariants of the locally generated command tracking system. *)
    let assert_locally_generated (pool : Test.Resource_pool.t) =
      ignore
        ( Hashtbl.merge pool.locally_generated_committed
            pool.locally_generated_uncommitted ~f:(fun ~key -> function
            | `Both ((committed, _), (uncommitted, _)) ->
                failwithf
                  !"Command \
                    %{sexp:Transaction_hash.User_command_with_valid_signature.t} \
                    in both locally generated committed and uncommitted with \
                    times %s and %s"
                  key (Time.to_string committed)
                  (Time.to_string uncommitted)
                  ()
            | `Left cmd ->
                Some cmd
            | `Right cmd ->
                (* Locally generated uncommitted transactions should be in the
                   pool, so long as we're not in the middle of updating it. *)
                assert (
                  Indexed_pool.member pool.pool
                    (Transaction_hash.User_command.of_checked key) ) ;
                Some cmd )
          : ( Transaction_hash.User_command_with_valid_signature.t
            , Time.t * [ `Batch of int ] )
            Hashtbl.t )

    let assert_fee_wu_ordering (pool : Test.Resource_pool.t) =
      let txns = Test.Resource_pool.transactions pool |> Sequence.to_list in
      let compare txn1 txn2 =
        let open Transaction_hash.User_command_with_valid_signature in
        let cmd1 = command txn1 in
        let cmd2 = command txn2 in
        (* ascending order of nonces, if same fee payer *)
        if
          Account_id.equal
            (User_command.fee_payer cmd1)
            (User_command.fee_payer cmd2)
        then
          Account.Nonce.compare
            (User_command.applicable_at_nonce cmd1)
            (User_command.applicable_at_nonce cmd2)
        else
          let get_fee_wu cmd = User_command.fee_per_wu cmd in
          (* descending order of fee/weight *)
          Currency.Fee_rate.compare (get_fee_wu cmd2) (get_fee_wu cmd1)
      in
      assert (List.is_sorted txns ~compare)

    let assert_pool_txs test txs =
      Indexed_pool.For_tests.assert_pool_consistency test.txn_pool.pool ;
      assert_locally_generated test.txn_pool ;
      assert_fee_wu_ordering test.txn_pool ;
      assert_user_command_sets_equal
        ( Sequence.to_list
        @@ Sequence.map ~f:Transaction_hash.User_command.of_checked
        @@ Test.Resource_pool.transactions test.txn_pool )
        (List.map
           ~f:
             (Fn.compose Transaction_hash.User_command.create
                User_command.forget_check )
           txs )

    let setup_test ?(verifier = verifier) ?permissions ?slot_tx_end () =
      let frontier, best_tip_diff_w =
        Mock_transition_frontier.create ?permissions ()
      in
      let _, best_tip_ref = frontier in
      let frontier_pipe_r, frontier_pipe_w =
        Broadcast_pipe.create @@ Some frontier
      in
      let trust_system = Trust_system.null () in
      let config =
        Test.Resource_pool.make_config ~trust_system ~pool_max_size ~verifier
          ~genesis_constants ~slot_tx_end
      in
      let pool_, _, _ =
        Test.create ~config ~logger:(Logger.create ()) ~constraint_constants
          ~consensus_constants ~time_controller
          ~frontier_broadcast_pipe:frontier_pipe_r ~log_gossip_heard:false
          ~on_remote_push:(Fn.const Deferred.unit) ~block_window_duration
      in
      let txn_pool = Test.resource_pool pool_ in
      let%map () = Async.Scheduler.yield_until_no_jobs_remain () in
      { txn_pool; best_tip_diff_w; best_tip_ref; frontier_pipe_w }

    let independent_cmds : User_command.Valid.t list =
      let rec go n cmds =
        let open Quickcheck.Generator.Let_syntax in
        if n < Array.length test_keys then
          let%bind cmd =
            let sender = test_keys.(n) in
            User_command.Valid.Gen.payment ~sign_type:`Real
              ~key_gen:
                (Quickcheck.Generator.tuple2 (return sender)
                   (Quickcheck_lib.of_array test_keys) )
              ~max_amount:1_000_000_000 ~fee_range:1_000_000_000 ()
          in
          go (n + 1) (cmd :: cmds)
        else Quickcheck.Generator.return @@ List.rev cmds
      in
      Quickcheck.random_value ~seed:(`Deterministic "constant") (go 0 [])

      let mk_zkapp_user_cmd (pool : Test.Resource_pool.t) zkapp_command =
        let best_tip_ledger = Option.value_exn pool.best_tip_ledger in
        let keymap =
          Array.fold (Array.append test_keys extra_keys)
            ~init:Public_key.Compressed.Map.empty
            ~f:(fun map { public_key; private_key } ->
              let key = Public_key.compress public_key in
              Public_key.Compressed.Map.add_exn map ~key ~data:private_key )
        in
        let zkapp_command =
          Or_error.ok_exn
            (Zkapp_command.Valid.to_valid ~failed:false
               ~find_vk:
                 (Zkapp_command.Verifiable.load_vk_from_ledger
                    ~get:(Mina_ledger.Ledger.get best_tip_ledger)
                    ~location_of_account:
                      (Mina_ledger.Ledger.location_of_account best_tip_ledger) )
               zkapp_command )
        in
        let zkapp_command = User_command.Zkapp_command zkapp_command in
        let%bind zkapp_command =
          replace_valid_zkapp_command_authorizations ~keymap
            ~ledger:best_tip_ledger [ zkapp_command ]
        in
        let zkapp_command = List.hd_exn zkapp_command in
        Deferred.return zkapp_command
  
      let mk_basic_zkapp ?(fee = 10_000_000_000) ?(empty_update = false)
          ?preconditions ?permissions nonce fee_payer_kp =
        let open Zkapp_command_builder in
        let preconditions =
          Option.value preconditions
            ~default:
              Account_update.Preconditions.
                { network = Zkapp_precondition.Protocol_state.accept
                ; account = Zkapp_precondition.Account.accept
                ; valid_while = Ignore
                }
        in
        let update : Account_update.Update.t =
          let permissions =
            match permissions with
            | None ->
                Zkapp_basic.Set_or_keep.Keep
            | Some perms ->
                Zkapp_basic.Set_or_keep.Set perms
          in
          { Account_update.Update.noop with permissions }
        in
        let account_updates =
          if empty_update then []
          else
            mk_forest
              [ mk_node
                  (mk_account_update_body Signature No fee_payer_kp
                     Token_id.default 0 ~preconditions ~update )
                  []
              ]
        in
        account_updates
        |> mk_zkapp_command ~memo:"" ~fee
             ~fee_payer_pk:(Public_key.compress fee_payer_kp.public_key)
             ~fee_payer_nonce:(Account.Nonce.of_int nonce)

    let mk_payment' ?valid_until ~sender_idx ~receiver_idx ~fee ~nonce ~amount
        () =
      let get_pk idx = Public_key.compress test_keys.(idx).public_key in
      Signed_command.sign test_keys.(sender_idx)
        (Signed_command_payload.create
           ~fee:(Currency.Fee.of_nanomina_int_exn fee)
           ~fee_payer_pk:(get_pk sender_idx) ~valid_until
           ~nonce:(Account.Nonce.of_int nonce)
           ~memo:(Signed_command_memo.create_by_digesting_string_exn "foo")
           ~body:
             (Signed_command_payload.Body.Payment
                { receiver_pk = get_pk receiver_idx
                ; amount = Currency.Amount.of_nanomina_int_exn amount
                } ) )

    let mk_single_account_update ~chain ~fee_payer_idx ~zkapp_account_idx ~fee
        ~nonce ~ledger =
      let fee = Currency.Fee.of_nanomina_int_exn fee in
      let fee_payer_kp = test_keys.(fee_payer_idx) in
      let nonce = Account.Nonce.of_int nonce in
      let spec : Transaction_snark.For_tests.Single_account_update_spec.t =
        Transaction_snark.For_tests.Single_account_update_spec.
          { fee_payer = (fee_payer_kp, nonce)
          ; fee
          ; memo = Signed_command_memo.create_from_string_exn "invalid proof"
          ; zkapp_account_keypair = test_keys.(zkapp_account_idx)
          ; update = { Account_update.Update.noop with zkapp_uri = Set "abcd" }
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; actions = []
          }
      in
      let%map zkapp_command =
        Transaction_snark.For_tests.single_account_update ~chain
          ~constraint_constants spec
      in
      Or_error.ok_exn
        (Zkapp_command.Verifiable.create ~failed:false
           ~find_vk:
             (Zkapp_command.Verifiable.load_vk_from_ledger
                ~get:(Mina_ledger.Ledger.get ledger)
                ~location_of_account:
                  (Mina_ledger.Ledger.location_of_account ledger) )
           zkapp_command )

    let mk_transfer_zkapp_command ?valid_period ?fee_payer_idx ~sender_idx
        ~receiver_idx ~fee ~nonce ~amount () =
      let sender_kp = test_keys.(sender_idx) in
      let sender_nonce = Account.Nonce.of_int nonce in
      let sender = (sender_kp, sender_nonce) in
      let amount = Currency.Amount.of_nanomina_int_exn amount in
      let receiver_kp = test_keys.(receiver_idx) in
      let receiver =
        receiver_kp.public_key |> Signature_lib.Public_key.compress
      in
      let fee_payer =
        match fee_payer_idx with
        | None ->
            None
        | Some (idx, nonce) ->
            let fee_payer_kp = test_keys.(idx) in
            let fee_payer_nonce = Account.Nonce.of_int nonce in
            Some (fee_payer_kp, fee_payer_nonce)
      in
      let fee = Currency.Fee.of_nanomina_int_exn fee in
      let protocol_state_precondition =
        match valid_period with
        | None ->
            Zkapp_precondition.Protocol_state.accept
        | Some time ->
            Zkapp_precondition.Protocol_state.valid_until time
      in
      let test_spec : Transaction_snark.For_tests.Multiple_transfers_spec.t =
        { sender
        ; fee_payer
        ; fee
        ; receivers = [ (receiver, amount) ]
        ; amount
        ; zkapp_account_keypairs = []
        ; memo = Signed_command_memo.create_from_string_exn "expiry tests"
        ; new_zkapp_account = false
        ; snapp_update = Account_update.Update.dummy
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; actions = []
        ; preconditions =
            Some
              { Account_update.Preconditions.network =
                  protocol_state_precondition
              ; account =
                  (let nonce =
                     if Option.is_none fee_payer then
                       Account.Nonce.succ sender_nonce
                     else sender_nonce
                   in
                   Zkapp_precondition.Account.nonce nonce )
              ; valid_while = Ignore
              }
        }
      in
      let zkapp_command =
        Transaction_snark.For_tests.multiple_transfers ~constraint_constants
          test_spec
      in
      let zkapp_command =
        Or_error.ok_exn
          (Zkapp_command.Valid.to_valid ~failed:false
             ~find_vk:
               (Zkapp_command.Verifiable.load_vk_from_ledger
                  ~get:(fun _ -> failwith "Not expecting proof zkapp_command")
                  ~location_of_account:(fun _ ->
                    failwith "Not expecting proof zkapp_command" ) )
             zkapp_command )
      in
      User_command.Zkapp_command zkapp_command

    let mk_payment ?valid_until ~sender_idx ~receiver_idx ~fee ~nonce ~amount ()
        =
      User_command.Signed_command
        (mk_payment' ?valid_until ~sender_idx ~fee ~nonce ~receiver_idx ~amount
           () )

    let mk_zkapp_commands_single_block num_cmds (pool : Test.Resource_pool.t) :
        User_command.Valid.t list Deferred.t =
      assert (num_cmds < Array.length test_keys - 1) ;
      let best_tip_ledger = Option.value_exn pool.best_tip_ledger in
      let keymap =
        Array.fold (Array.append test_keys extra_keys)
          ~init:Public_key.Compressed.Map.empty
          ~f:(fun map { public_key; private_key } ->
            let key = Public_key.compress public_key in
            Public_key.Compressed.Map.add_exn map ~key ~data:private_key )
      in
      let account_state_tbl =
        List.take (Array.to_list test_keys) num_cmds
        |> List.map ~f:(fun kp ->
               let id =
                 Account_id.create
                   (Public_key.compress kp.public_key)
                   Token_id.default
               in
               let state =
                 Option.value_exn
                   (let%bind.Option loc =
                      Mina_ledger.Ledger.location_of_account best_tip_ledger id
                    in
                    Mina_ledger.Ledger.get best_tip_ledger loc )
               in
               (id, (state, `Fee_payer)) )
        |> Account_id.Table.of_alist_exn
      in
      let rec go n cmds =
        let open Quickcheck.Generator.Let_syntax in
        if n >= num_cmds then Quickcheck.Generator.return @@ List.rev cmds
        else
          let%bind cmd =
            let fee_payer_keypair = test_keys.(n) in
            let%map (zkapp_command : Zkapp_command.t) =
              Mina_generators.Zkapp_command_generators.gen_zkapp_command_from
                ~max_token_updates:1 ~keymap ~account_state_tbl
                ~fee_payer_keypair ~ledger:best_tip_ledger ~constraint_constants
                ~genesis_constants ()
            in
            let zkapp_command =
              { zkapp_command with
                account_updates =
                  Zkapp_command.Call_forest.map zkapp_command.account_updates
                    ~f:(fun (p : Account_update.t) ->
                      { p with
                        body =
                          { p.body with
                            preconditions =
                              { p.body.preconditions with
                                account =
                                  ( match p.body.preconditions.account.nonce with
                                  | Zkapp_basic.Or_ignore.Check n as c
                                    when Zkapp_precondition.Numeric.(
                                           is_constant Tc.nonce c) ->
                                      Zkapp_precondition.Account.nonce n.lower
                                  | _ ->
                                      Zkapp_precondition.Account.accept )
                              }
                          }
                      } )
              }
            in
            let zkapp_command_valid_vk_hashes =
              Zkapp_command.For_tests.replace_vks zkapp_command vk
            in
            let valid_zkapp_command =
              Or_error.ok_exn
                (Zkapp_command.Valid.to_valid ~failed:false
                   ~find_vk:
                     (Zkapp_command.Verifiable.load_vk_from_ledger
                        ~get:(Mina_ledger.Ledger.get best_tip_ledger)
                        ~location_of_account:
                          (Mina_ledger.Ledger.location_of_account
                             best_tip_ledger ) )
                   zkapp_command_valid_vk_hashes )
            in
            User_command.Zkapp_command valid_zkapp_command
          in
          go (n + 1) (cmd :: cmds)
      in
      let valid_zkapp_commands =
        Quickcheck.random_value ~seed:(`Deterministic "zkapp_command") (go 0 [])
      in
      replace_valid_zkapp_command_authorizations ~keymap ~ledger:best_tip_ledger
        valid_zkapp_commands

    type pool_apply = (User_command.t list, [ `Other of Error.t ]) Result.t
    [@@deriving sexp, compare]

    let canonicalize t =
      Result.map t ~f:(List.sort ~compare:User_command.compare)

    let compare_pool_apply (t1 : pool_apply) (t2 : pool_apply) =
      compare_pool_apply (canonicalize t1) (canonicalize t2)

    let assert_pool_apply expected_commands result =
      let accepted_commands =
        Result.map result ~f:(fun (_, accepted, _) -> accepted)
      in
      [%test_eq: pool_apply] accepted_commands
        (Ok (List.map ~f:User_command.forget_check expected_commands))

    let mk_with_status (cmd : User_command.Valid.t) =
      { With_status.data = cmd; status = Applied }

    let add_commands ?(local = true) test cs =
      let sender =
        if local then Envelope.Sender.Local
        else
          Envelope.Sender.Remote
            (Peer.create
               (Unix.Inet_addr.of_string "1.2.3.4")
               ~peer_id:
                 (Peer.Id.unsafe_of_string "contents should be irrelevant")
               ~libp2p_port:8302 )
      in
      let tm0 = Time.now () in
      let%map verified =
        Test.Resource_pool.Diff.verify test.txn_pool
          (Envelope.Incoming.wrap
             ~data:(List.map ~f:User_command.forget_check cs)
             ~sender )
        >>| Fn.compose Or_error.ok_exn
              (Result.map_error ~f:Intf.Verification_error.to_error)
      in
      let result =
        Test.Resource_pool.Diff.unsafe_apply test.txn_pool verified
      in
      let tm1 = Time.now () in
      [%log' info test.txn_pool.logger] "Time for add_commands: %0.04f sec"
        (Time.diff tm1 tm0 |> Time.Span.to_sec) ;
      ( match result with
      | Ok (`Accept, _, rejects) ->
          List.iter rejects ~f:(fun (cmd, err) ->
              Core.Printf.printf
                !"command was rejected because %s: %{Yojson.Safe}\n%!"
                (Diff_versioned.Diff_error.to_string_name err)
                (User_command.to_yojson cmd) )
      | Ok (`Reject, _, _) ->
          failwith "diff was rejected during application"
      | Error (`Other err) ->
          Core.Printf.printf
            !"failed to apply diff to pool: %s\n%!"
            (Error.to_string_hum err) ) ;
      result

    let add_commands' ?local test cs =
      add_commands ?local test cs >>| assert_pool_apply cs

    let reorg ?(reorg_best_tip = false) test new_commands removed_commands =
      let%bind () =
        Broadcast_pipe.Writer.write test.best_tip_diff_w
          { Mock_transition_frontier.new_commands =
              List.map ~f:mk_with_status new_commands
          ; removed_commands = List.map ~f:mk_with_status removed_commands
          ; reorg_best_tip
          }
      in
      Async.Scheduler.yield_until_no_jobs_remain ()

    let _user_command_to_base64 c = 
      match User_command.forget_check c with
      | User_command.Signed_command c -> 
          Signed_command.to_base64 c
      | User_command.Zkapp_command p ->
           Zkapp_command.to_base64 p

    let commit_commands test cs =
      let ledger = Option.value_exn test.txn_pool.best_tip_ledger in
      List.iter cs ~f:(fun c ->
          match User_command.forget_check c with
          | User_command.Signed_command c -> (
              let (`If_this_is_used_it_should_have_a_comment_justifying_it valid)
                  =
                Signed_command.to_valid_unsafe c
              in
              let applied =
                Or_error.ok_exn
                @@ Mina_ledger.Ledger.apply_user_command ~constraint_constants
                     ~txn_global_slot:
                       Mina_numbers.Global_slot_since_genesis.zero ledger valid
              in
              match applied.body with
              | Failed ->
                  failwith "failed to apply user command to ledger"
              | _ ->
                  () )
          | User_command.Zkapp_command p -> (
              let applied, _ =
                Or_error.ok_exn
                @@ Mina_ledger.Ledger.apply_zkapp_command_unchecked
                     ~constraint_constants
                     ~global_slot:dummy_state_view.global_slot_since_genesis
                     ~state_view:dummy_state_view ledger p
              in
              match With_status.status applied.command with
              | Failed failures ->
                  failwithf
                    "failed to apply zkapp_command transaction to ledger: [%s]"
                    ( String.concat ~sep:", "
                    @@ List.bind
                         ~f:(List.map ~f:Transaction_status.Failure.to_string)
                         failures )
                    ()
              | Applied ->
                  () ) )

    let commit_commands' test cs =
      let open Mina_ledger in
      let ledger = Option.value_exn test.txn_pool.best_tip_ledger in
      test.best_tip_ref :=
        Ledger.Maskable.register_mask
          (Ledger.Any_ledger.cast (module Mina_ledger.Ledger) ledger)
          (Ledger.Mask.create ~depth:(Ledger.depth ledger) ()) ;
      let%map () = reorg test [] [] in
      assert (
        not (phys_equal (Option.value_exn test.txn_pool.best_tip_ledger) ledger) ) ;
      assert (
        phys_equal
          (Option.value_exn test.txn_pool.best_tip_ledger)
          !(test.best_tip_ref) ) ;
      commit_commands test cs ;
      assert (
        not (phys_equal (Option.value_exn test.txn_pool.best_tip_ledger) ledger) ) ;
      assert (
        phys_equal
          (Option.value_exn test.txn_pool.best_tip_ledger)
          !(test.best_tip_ref) ) ;
      ledger

    let advance_chain test cs = commit_commands test cs ; reorg test cs []

    (* TODO: remove this (all of these test should be expressed by committing txns to the ledger, not mutating accounts *)
    let modify_ledger ledger ~idx ~balance ~nonce =
      let id =
        Account_id.create
          (Signature_lib.Public_key.compress test_keys.(idx).public_key)
          Token_id.default
      in
      let loc =
        Option.value_exn @@ Mina_ledger.Ledger.location_of_account ledger id
      in
      let account = Option.value_exn @@ Mina_ledger.Ledger.get ledger loc in
      Mina_ledger.Ledger.set ledger loc
        { account with
          balance = Currency.Balance.of_nanomina_int_exn balance
        ; nonce = Account.Nonce.of_int nonce
        }

    let mk_linear_case_test t cmds =
      assert_pool_txs t [] ;
      let%bind () = add_commands' t cmds in
      let%bind () = advance_chain t (List.take independent_cmds 1) in
      assert_pool_txs t (List.drop cmds 1) ;
      let%bind () =
        advance_chain t (List.take (List.drop independent_cmds 1) 2)
      in
      assert_pool_txs t (List.drop cmds 3) ;
      Deferred.unit

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
      
end)