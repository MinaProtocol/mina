open Core_kernel
open Async
open Mina_base
open Mina_ledger
open Mina_numbers
open Mina_transaction
open Mina_state
open Currency
open Signature_lib
open Staged_ledger

module Sl = Staged_ledger
open Staged_ledger.Test_helpers

let () =
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true

    let self_pk =
      Quickcheck.random_value ~seed:(`Deterministic "self_pk")
        Public_key.Compressed.gen

    let coinbase_receiver_keypair =
      Quickcheck.random_value ~seed:(`Deterministic "receiver_pk") Keypair.gen

    let coinbase_receiver =
      Public_key.compress coinbase_receiver_keypair.public_key

    let proof_level = Genesis_constants.For_unit_tests.Proof_level.t

    let genesis_constants = Genesis_constants.For_unit_tests.t

    let constraint_constants =
      Genesis_constants.For_unit_tests.Constraint_constants.t

    let zkapp_cmd_limit_hardcap = 200

    let logger = Logger.null ()

    let `VK vk, `Prover zkapp_prover =
      Transaction_snark.For_tests.create_trivial_snapp ()

    let vk = Async.Thread_safe.block_on_async_exn (fun () -> vk)

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default ~constraint_constants ~logger ~proof_level
            () )

    let find_vk ledger =
      Zkapp_command.Verifiable.load_vk_from_ledger ~get:(Ledger.get ledger)
        ~location_of_account:(Ledger.location_of_account ledger)

    let supercharge_coinbase ~ledger ~winner ~global_slot =
      (*using staged ledger to confirm coinbase amount is correctly generated*)
      let epoch_ledger =
        Sparse_ledger.of_ledger_subset_exn ledger
          (List.map [ winner ] ~f:(fun k ->
               Account_id.create k Token_id.default ) )
      in
      Sl.can_apply_supercharged_coinbase_exn ~winner ~global_slot ~epoch_ledger

    (* Functor for testing with different instantiated staged ledger modules. *)
    let create_and_apply_with_state_body_hash
        ~(current_state_view : Zkapp_precondition.Protocol_state.View.t)
        ~global_slot ~state_and_body_hash ~signature_kind ?zkapp_cmd_limit
        ?(coinbase_receiver = coinbase_receiver) ?(winner = self_pk) sl txns
        stmt_to_work =
      let open Deferred.Let_syntax in
      let supercharge_coinbase =
        supercharge_coinbase ~ledger:(Sl.ledger !sl) ~winner ~global_slot
      in
      let diff =
        Sl.create_diff ~constraint_constants ~global_slot !sl ~logger
          ~current_state_view ~transactions_by_fee:txns
          ~get_completed_work:stmt_to_work ~supercharge_coinbase
          ~coinbase_receiver ~zkapp_cmd_limit
      in
      let diff, _invalid_txns =
        match diff with
        | Ok x ->
            x
        | Error e ->
            Error.raise (Pre_diff_info.Error.to_error e)
      in
      let diff' = Staged_ledger_diff.forget diff in
      let%map ( `Hash_after_applying hash
              , `Ledger_proof ledger_proof
              , `Staged_ledger sl'
              , `Pending_coinbase_update (is_new_stack, pc_update) ) =
        match%map
          Sl.apply ~constraint_constants ~global_slot !sl diff' ~logger
            ~verifier ~get_completed_work:(Fn.const None) ~current_state_view
            ~state_and_body_hash ~coinbase_receiver ~supercharge_coinbase
            ~zkapp_cmd_limit_hardcap ~signature_kind
        with
        | Ok x ->
            x
        | Error e ->
            Error.raise (Sl.Staged_ledger_error.to_error e)
      in
      assert (Staged_ledger_hash.equal hash (Sl.hash sl')) ;
      sl := sl' ;
      (ledger_proof, diff', is_new_stack, pc_update, supercharge_coinbase)

    let create_and_apply ?(coinbase_receiver = coinbase_receiver)
        ?(winner = self_pk) ~global_slot ~protocol_state_view
        ~state_and_body_hash ~signature_kind sl txns stmt_to_work =
      let open Deferred.Let_syntax in
      let%map ledger_proof, diff, _, _, _ =
        create_and_apply_with_state_body_hash ~coinbase_receiver ~winner
          ~current_state_view:protocol_state_view ~global_slot
          ~state_and_body_hash sl txns stmt_to_work ~signature_kind
      in
      (ledger_proof, diff)

    module Transfer = Mina_ledger.Ledger_transfer.Make (Ledger) (Ledger)

    (* Run the given function inside of the Deferred monad, with a staged
         ledger and a separate test ledger, after applying the given
         init_state to both. In the below tests we apply the same commands to
         the staged and test ledgers, and verify they are in the same state.
    *)
    let async_with_given_ledger ledger
        (f :
             snarked_ledger:Ledger.t
          -> Sl.t ref
          -> Ledger.Mask.Attached.t
          -> unit Deferred.t ) =
      let casted = Ledger.Any_ledger.cast (module Ledger) ledger in
      let test_mask =
        Ledger.Maskable.register_mask casted
          (Ledger.Mask.create ~depth:(Ledger.depth ledger) ())
      in
      let snarked_ledger_mask =
        Ledger.Maskable.register_mask casted
          (Ledger.Mask.create ~depth:(Ledger.depth ledger) ())
      in
      let sl = ref @@ Sl.create_exn ~constraint_constants ~ledger in
      Async.Thread_safe.block_on_async_exn (fun () ->
          f ~snarked_ledger:snarked_ledger_mask sl test_mask ) ;
      ignore @@ Ledger.Maskable.unregister_mask_exn ~loc:__LOC__ test_mask

    (* populate the ledger from an initial state before running the function *)
    let async_with_ledgers ledger_init_state
        (f :
             snarked_ledger:Ledger.t
          -> Sl.t ref
          -> Ledger.Mask.Attached.t
          -> unit Deferred.t ) =
      Ledger.with_ephemeral_ledger ~depth:constraint_constants.ledger_depth
        ~f:(fun ledger ->
          Ledger.apply_initial_ledger_state ledger ledger_init_state ;
          async_with_given_ledger ledger f )

    (* Assert the given staged ledger is in the correct state after applying
         the first n user commands passed to the given base ledger. Checks the
         states of the block producer account and user accounts but ignores
         snark workers for simplicity. *)
    let assert_ledger :
           Ledger.t
        -> coinbase_cost:Currency.Fee.t
        -> global_slot:Mina_numbers.Global_slot_since_genesis.t
        -> protocol_state_view:Zkapp_precondition.Protocol_state.View.t
        -> signature_kind:Mina_signature_kind.t
        -> Sl.t
        -> User_command.Valid.t list
        -> int
        -> Account_id.t list
        -> unit =
     fun test_ledger ~coinbase_cost ~global_slot ~protocol_state_view
         ~signature_kind staged_ledger cmds_all cmds_used pks_to_check ->
      let producer_account_id =
        Account_id.create coinbase_receiver Token_id.default
      in
      let producer_account =
        Option.bind
          (Ledger.location_of_account test_ledger producer_account_id)
          ~f:(Ledger.get test_ledger)
      in
      let is_producer_acc_new = Option.is_none producer_account in
      let old_producer_balance =
        Option.value_map producer_account ~default:Currency.Balance.zero
          ~f:(fun a -> a.balance)
      in
      let apply_cmds cmds =
        cmds
        |> List.map ~f:(fun cmd ->
               Transaction.Command (User_command.forget_check cmd) )
        |> Ledger.apply_transactions ~signature_kind ~constraint_constants
             ~global_slot ~txn_state_view:protocol_state_view test_ledger
        |> Or_error.ignore_m
      in
      Or_error.ok_exn @@ apply_cmds @@ List.take cmds_all cmds_used ;
      let get_account_exn ledger pk =
        Option.value_exn
          (Option.bind
             (Ledger.location_of_account ledger pk)
             ~f:(Ledger.get ledger) )
      in
      (* Check the user accounts in the updated staged ledger are as
         expected.
      *)
      List.iter pks_to_check ~f:(fun pk ->
          let expect = get_account_exn test_ledger pk in
          let actual = get_account_exn (Sl.ledger staged_ledger) pk in
          [%test_result: Account.t] ~expect actual ) ;
      (* We only test that the block producer got the coinbase reward here, since calculating the exact correct amount depends on the snark fees and tx fees. *)
      let producer_balance_with_coinbase =
        (let open Option.Let_syntax in
        let%bind total_cost =
          if is_producer_acc_new then
            Currency.Fee.add coinbase_cost
              constraint_constants.account_creation_fee
          else Some coinbase_cost
        in
        let%bind reward =
          Currency.Amount.(
            sub constraint_constants.coinbase_amount (of_fee total_cost))
        in
        Currency.Balance.add_amount old_producer_balance reward)
        |> Option.value_exn
      in
      let new_producer_balance =
        (get_account_exn (Sl.ledger staged_ledger) producer_account_id).balance
      in
      assert (
        Currency.Balance.(
          new_producer_balance >= producer_balance_with_coinbase) )

    let work_fee = constraint_constants.account_creation_fee

    (* Deterministically compute a prover public key from a snark work statement. *)
    let stmt_to_prover :
        Transaction_snark_work.Statement.t -> Public_key.Compressed.t =
     fun stmts ->
      let prover_seed =
        One_or_two.fold stmts ~init:"P" ~f:(fun p stmt ->
            p
            ^ Frozen_ledger_hash.to_bytes stmt.target.first_pass_ledger
            ^ Frozen_ledger_hash.to_bytes stmt.target.second_pass_ledger )
      in
      Quickcheck.random_value ~seed:(`Deterministic prover_seed)
        Public_key.Compressed.gen

    let proofs stmts : Ledger_proof.Cached.t One_or_two.t =
      let sok_digest = Sok_message.Digest.default in
      One_or_two.map stmts ~f:(fun statement ->
          Ledger_proof.Cached.create ~statement ~sok_digest
            ~proof:(Lazy.force Proof.For_tests.transaction_dummy_tag) )

    let stmt_to_work_random_prover (stmts : Transaction_snark_work.Statement.t)
        : Transaction_snark_work.Checked.t option =
      let prover = stmt_to_prover stmts in
      Some
        (Transaction_snark_work.Checked.create_unsafe
           { fee = work_fee; proofs = proofs stmts; prover } )

    let stmt_to_work_zero_fee ~prover
        (stmts : Transaction_snark_work.Statement.t) :
        Transaction_snark_work.Checked.t option =
      Some
        (Transaction_snark_work.Checked.create_unsafe
           { fee = Currency.Fee.zero; proofs = proofs stmts; prover } )

    (* Fixed public key for when there is only one snark worker. *)
    let snark_worker_pk =
      Quickcheck.random_value ~seed:(`Deterministic "snark worker")
        Public_key.Compressed.gen

    let stmt_to_work_one_prover (stmts : Transaction_snark_work.Statement.t) :
        Transaction_snark_work.Checked.t option =
      Some
        (Transaction_snark_work.Checked.create_unsafe
           { fee = work_fee; proofs = proofs stmts; prover = snark_worker_pk } )

    let coinbase_first_prediff = function
      | Staged_ledger_diff.At_most_two.Zero ->
          (0, [])
      | One None ->
          (1, [])
      | One (Some ft) ->
          (1, [ ft ])
      | Two None ->
          (2, [])
      | Two (Some (ft, None)) ->
          (2, [ ft ])
      | Two (Some (ft1, Some ft2)) ->
          (2, [ ft1; ft2 ])

    let coinbase_second_prediff = function
      | Staged_ledger_diff.At_most_one.Zero ->
          (0, [])
      | One None ->
          (1, [])
      | One (Some ft) ->
          (1, [ ft ])

    let coinbase_count (sl_diff : Staged_ledger_diff.t) =
      (coinbase_first_prediff (fst sl_diff.diff).coinbase |> fst)
      + Option.value_map ~default:0 (snd sl_diff.diff) ~f:(fun d ->
            coinbase_second_prediff d.coinbase |> fst )

    let coinbase_cost (sl_diff : Staged_ledger_diff.t) =
      let coinbase_fts =
        (coinbase_first_prediff (fst sl_diff.diff).coinbase |> snd)
        @ Option.value_map ~default:[] (snd sl_diff.diff) ~f:(fun d ->
              coinbase_second_prediff d.coinbase |> snd )
      in
      List.fold coinbase_fts ~init:Currency.Fee.zero ~f:(fun total ft ->
          Currency.Fee.add total ft.fee |> Option.value_exn )

    let () =
      Async.Scheduler.set_record_backtraces true ;
      Backtrace.elide := false

    (* The tests are still very slow, so we set ~trials very low for all the
       QuickCheck tests. We may be able to turn them up after #2759 and/or #2760
       happen.
    *)

    (* Get the public keys from a ledger init state. *)
    let init_pks (init : Ledger.init_state) =
      Array.to_sequence init
      |> Sequence.map ~f:(fun ((kp : Signature_lib.Keypair.t), _, _, _) ->
             Account_id.create
               (Public_key.compress kp.public_key)
               Token_id.default )
      |> Sequence.to_list

    (* Fee excess at top level ledger proofs should always be zero *)
    let assert_fee_excess :
           ( Ledger_proof.Cached.t
           * (Transaction.t With_status.t * _ * _)
             Sl.Scan_state.Transactions_ordered.Poly.t
             list )
           option
        -> unit =
     fun proof_opt ->
      let fee_excess =
        Option.value_map ~default:Fee_excess.zero proof_opt
          ~f:(fun (proof, _txns) ->
            (Ledger_proof.Cached.statement proof).fee_excess )
      in
      assert (Fee_excess.is_zero fee_excess)

    let transaction_capacity =
      Int.pow 2 constraint_constants.transaction_capacity_log_2

    (* Abstraction for the pattern of taking a list of commands and applying it
       in chunks up to a given max size. *)
    let rec iter_cmds_acc :
           User_command.Valid.t list (** All the commands to apply. *)
        -> int option list
           (** A list of chunk sizes. If a chunk's size is None, apply as many
            commands as possible. *)
        -> 'acc
        -> (   User_command.Valid.t list (** All commands remaining. *)
            -> int option (* Current chunk size. *)
            -> User_command.Valid.t Sequence.t
               (* Sequence of commands to apply. *)
            -> 'acc
            -> (Staged_ledger_diff.t * 'acc) Deferred.t )
        -> 'acc Deferred.t =
     fun cmds cmd_iters acc f ->
      match cmd_iters with
      | [] ->
          Deferred.return acc
      | count_opt :: counts_rest ->
          let cmds_this_iter_max =
            match count_opt with
            | None ->
                cmds
            | Some count ->
                assert (count <= List.length cmds) ;
                List.take cmds count
          in
          let%bind diff, acc' =
            f cmds count_opt (Sequence.of_list cmds_this_iter_max) acc
          in
          let cmds_applied_count =
            List.length @@ Staged_ledger_diff.commands diff
          in
          iter_cmds_acc (List.drop cmds cmds_applied_count) counts_rest acc' f

    (** Generic test framework. *)
    let test_simple :
           global_slot:int
        -> signature_kind:Mina_signature_kind.t
        -> Account_id.t list
        -> User_command.Valid.t list
        -> int option list
        -> Sl.t ref
        -> ?expected_proof_count:int option (*Number of ledger proofs expected*)
        -> ?allow_failures:bool
        -> ?check_snarked_ledger_transition:bool
        -> snarked_ledger:Ledger.t
        -> Ledger.Mask.Attached.t
        -> [ `One_prover | `Many_provers ]
        -> (   Transaction_snark_work.Statement.t
            -> Transaction_snark_work.Checked.t option )
        -> unit Deferred.t =
     fun ~global_slot ~signature_kind account_ids_to_check cmds cmd_iters sl
         ?(expected_proof_count = None) ?(allow_failures = false)
         ?(check_snarked_ledger_transition = false) ~snarked_ledger test_mask
         provers stmt_to_work ->
      let global_slot =
        Mina_numbers.Global_slot_since_genesis.of_int global_slot
      in
      let state_tbl = State_hash.Table.create () in
      (*Add genesis state to the table*)
      let genesis, _ = dummy_state_and_view () in
      let state_hash = (Mina_state.Protocol_state.hashes genesis).state_hash in
      State_hash.Table.add state_tbl ~key:state_hash ~data:genesis |> ignore ;
      let%map `Proof_count total_ledger_proofs, _ =
        iter_cmds_acc cmds cmd_iters
          (`Proof_count 0, `Slot global_slot)
          (fun cmds_left count_opt cmds_this_iter
               (`Proof_count proof_count, `Slot global_slot) ->
            let current_state, current_view =
              dummy_state_and_view ~global_slot ()
            in
            let state_hash =
              (Mina_state.Protocol_state.hashes current_state).state_hash
            in
            State_hash.Table.add state_tbl ~key:state_hash ~data:current_state
            |> ignore ;
            let%bind ledger_proof, diff =
              create_and_apply ~global_slot ~protocol_state_view:current_view
                ~state_and_body_hash:
                  ( state_hash
                  , (Mina_state.Protocol_state.hashes current_state)
                      .state_body_hash |> Option.value_exn )
                ~signature_kind sl cmds_this_iter stmt_to_work
            in
            List.iter (Staged_ledger_diff.commands diff) ~f:(fun c ->
                match With_status.status c with
                | Applied ->
                    ()
                | Failed ftl ->
                    if not allow_failures then
                      failwith
                        (sprintf
                           "Transaction application failed for command %s. \
                            Failures %s"
                           ( User_command.to_yojson (With_status.data c)
                           |> Yojson.Safe.to_string )
                           ( Transaction_status.Failure.Collection.to_yojson ftl
                           |> Yojson.Safe.to_string ) ) ) ;
            let do_snarked_ledger_transition proof_opt =
              let apply_first_pass =
                Ledger.apply_transaction_first_pass ~signature_kind
                  ~constraint_constants
              in
              let apply_second_pass = Ledger.apply_transaction_second_pass in
              let apply_first_pass_sparse_ledger ~global_slot ~txn_state_view
                  sparse_ledger txn =
                let%map.Or_error _ledger, partial_txn =
                  Mina_ledger.Sparse_ledger.apply_transaction_first_pass
                    ~constraint_constants ~global_slot ~txn_state_view
                    sparse_ledger txn
                in
                partial_txn
              in
              let get_state state_hash =
                Ok (State_hash.Table.find_exn state_tbl state_hash)
              in
              let%bind () =
                match proof_opt with
                | Some (proof, _transactions) ->
                    (*update snarked ledger with the transactions in the most recently emitted proof*)
                    let%map res =
                      Sl.Scan_state.get_snarked_ledger_async
                        ~ledger:snarked_ledger ~get_protocol_state:get_state
                        ~apply_first_pass ~apply_second_pass
                        ~apply_first_pass_sparse_ledger ~signature_kind
                        (Sl.scan_state !sl)
                    in
                    let target_snarked_ledger =
                      let stmt = Ledger_proof.Cached.statement proof in
                      stmt.target.first_pass_ledger
                    in
                    [%test_eq: Ledger_hash.t] target_snarked_ledger
                      (Ledger.merkle_root snarked_ledger) ;
                    Or_error.ok_exn res
                | None ->
                    Deferred.return ()
              in
              (*Check snarked_ledger to staged_ledger transition*)
              let casted =
                Ledger.Any_ledger.cast (module Ledger) snarked_ledger
              in
              let sl_of_snarked_ledger =
                Ledger.Maskable.register_mask casted
                  (Ledger.Mask.create ~depth:(Ledger.depth snarked_ledger) ())
              in
              let expected_staged_ledger_merkle_root =
                Ledger.merkle_root (Sl.ledger !sl)
              in
              let%map construction_result =
                Sl.of_scan_state_pending_coinbases_and_snarked_ledger ~logger
                  ~snarked_local_state:
                    Mina_state.(
                      Protocol_state.blockchain_state current_state
                      |> Blockchain_state.snarked_local_state)
                  ~verifier ~constraint_constants ~scan_state:(Sl.scan_state !sl)
                  ~snarked_ledger:sl_of_snarked_ledger
                  ~expected_merkle_root:expected_staged_ledger_merkle_root
                  ~pending_coinbases:(Sl.pending_coinbase_collection !sl) ~get_state
                  ~signature_kind
              in
              let _result = Or_error.ok_exn construction_result in
              [%test_eq: Ledger_hash.t]
                (Ledger.merkle_root sl_of_snarked_ledger)
                (Ledger.merkle_root (Sl.ledger !sl)) ;
              ignore (Ledger.unregister_mask_exn sl_of_snarked_ledger ~loc:__LOC__ : Ledger.Mask.t)
            in
            let%bind () =
              if check_snarked_ledger_transition then
                do_snarked_ledger_transition ledger_proof
              else Deferred.return ()
            in
            let proof_count' =
              Option.value_map ~default:proof_count
                ~f:(fun _ -> proof_count + 1)
                ledger_proof
            in
            assert_fee_excess ledger_proof ;
            let cmds_applied_this_iter =
              List.length @@ Staged_ledger_diff.commands diff
            in
            let cb = coinbase_count diff in
            ( match provers with
            | `One_prover ->
                assert (cb = 1)
            | `Many_provers ->
                assert (cb > 0 && cb < 3) ) ;
            ( match count_opt with
            | Some _ ->
                (* There is an edge case where cmds_applied_this_iter = 0, when
                   there is only enough space for coinbase transactions. *)
                assert (cmds_applied_this_iter <= Sequence.length cmds_this_iter) ;
                let commands_in_ledger =
                  List.map (Staged_ledger_diff.commands diff)
                    ~f:(fun { With_status.data; _ } -> data)
                in
                let commands_applied =
                  Sequence.take cmds_this_iter cmds_applied_this_iter
                  |> Sequence.map ~f:User_command.forget_check
                  |> Sequence.to_list
                in
                assert (
                  List.equal
                    User_command.equal_ignoring_proofs_and_hashes_and_aux
                    commands_in_ledger commands_applied )
            | None ->
                () ) ;
            let coinbase_cost = coinbase_cost diff in
            assert_ledger test_mask ~coinbase_cost ~global_slot
              ~protocol_state_view:current_view ~signature_kind !sl cmds_left
              cmds_applied_this_iter account_ids_to_check ;
            (*increment global slots to simulate multiple blocks*)
            return
              ( diff
              , ( `Proof_count proof_count'
                , `Slot
                    (Mina_numbers.Global_slot_since_genesis.succ global_slot) )
              ) )
      in
      (*Should have enough blocks to generate at least expected_proof_count
        proofs*)
      if Option.is_some expected_proof_count then
        assert (total_ledger_proofs = Option.value_exn expected_proof_count)

    (* How many blocks do we need to fully exercise the ledger
       behavior and produce one ledger proof *)
    let min_blocks_for_first_snarked_ledger_generic =
      (constraint_constants.transaction_capacity_log_2 + 1)
      * (constraint_constants.work_delay + 1)
      + 1

    (* n-1 extra blocks for n ledger proofs since we are already producing one
       proof *)
    let max_blocks_for_coverage n =
      min_blocks_for_first_snarked_ledger_generic + n - 1

    (** Generator for when we always have enough commands to fill all slots. *)

    let gen_at_capacity ~signature_kind :
        (Ledger.init_state * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger_init_state = Ledger.gen_initial_ledger_state in
      let%bind iters = Int.gen_incl 1 (max_blocks_for_coverage 0) in
      let num_cmds = transaction_capacity * iters in
      let%bind cmds =
        User_command.Valid.Gen.sequence ~length:num_cmds
          ~sign_type:(`Real signature_kind) ledger_init_state
      in
      assert (List.length cmds = num_cmds) ;
      return (ledger_init_state, cmds, List.init iters ~f:(Fn.const None))

    let gen_zkapps ?ledger_init_state ?failure ~num_zkapps zkapps_per_iter :
        (Ledger.t * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind zkapp_command_and_fee_payer_keypairs, ledger =
        Mina_generators.User_command_generators
        .sequence_zkapp_command_with_ledger ?ledger_init_state
          ~max_token_updates:1 ~length:num_zkapps ~vk ?failure
          ~constraint_constants ~genesis_constants ()
      in
      let zkapps =
        List.map zkapp_command_and_fee_payer_keypairs ~f:(function
          | Zkapp_command zkapp_command_valid, _fee_payer_keypair, keymap ->
              let zkapp_command_with_auths =
                Async.Thread_safe.block_on_async_exn (fun () ->
                    Zkapp_command_builder.replace_authorizations ~keymap
                      (Zkapp_command.Valid.forget zkapp_command_valid) )
              in
              let valid_zkapp_command_with_auths : Zkapp_command.Valid.t =
                match
                  Zkapp_command.Valid.For_tests.to_valid ~failed:false
                    ~find_vk:(find_vk ledger) zkapp_command_with_auths
                with
                | Ok ps ->
                    ps
                | Error err ->
                    Error.raise
                    @@ Error.tag ~tag:"Could not create Zkapp_command.Valid.t"
                         err
              in
              User_command.Zkapp_command valid_zkapp_command_with_auths
          | Signed_command _, _, _ ->
              failwith "Expected a Zkapp_command, got a Signed command" )
      in
      assert (List.length zkapps = num_zkapps) ;
      return (ledger, zkapps, zkapps_per_iter)

    let gen_failing_zkapps_at_capacity :
        (Ledger.t * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind iters = Int.gen_incl 1 (max_blocks_for_coverage 0) in
      let num_zkapps = transaction_capacity * iters in
      gen_zkapps
        ~failure:
          Mina_generators.Zkapp_command_generators.Invalid_account_precondition
        ~num_zkapps
        (List.init iters ~f:(Fn.const None))

    let gen_zkapps_at_capacity :
        (Ledger.t * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind iters = Int.gen_incl 1 (max_blocks_for_coverage 0) in
      let num_zkapps = transaction_capacity * iters in
      gen_zkapps ~num_zkapps (List.init iters ~f:(Fn.const None))

    (*Same as gen_at_capacity except that the number of iterations[iters] is
      the function of [extra_block_count] and is same for all generated values*)
    let gen_zkapps_at_capacity_fixed_blocks extra_block_count :
        (Ledger.t * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let iters = max_blocks_for_coverage extra_block_count in
      let num_zkapps = transaction_capacity * iters in
      gen_zkapps ~num_zkapps (List.init iters ~f:(Fn.const None))

    let gen_zkapps_below_capacity ?ledger_init_state ?(extra_blocks = false) ()
        :
        (Ledger.t * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let iters_max =
        max_blocks_for_coverage 0 * if extra_blocks then 4 else 2
      in
      let iters_min = max_blocks_for_coverage 0 in
      let%bind iters = Int.gen_incl iters_min iters_max in
      (* see comment in gen_below_capacity for rationale *)
      let%bind zkapps_per_iter =
        Quickcheck.Generator.list_with_length iters
          (Int.gen_incl 1 ((transaction_capacity / 2) - 1))
      in
      let num_zkapps = List.fold zkapps_per_iter ~init:0 ~f:( + ) in
      gen_zkapps ?ledger_init_state ~num_zkapps
        (List.map ~f:Option.some zkapps_per_iter)

    (*Same as gen_at_capacity except that the number of iterations[iters] is
      the function of [extra_block_count] and is same for all generated values*)
    let gen_at_capacity_fixed_blocks ~signature_kind extra_block_count :
        (Ledger.init_state * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger_init_state = Ledger.gen_initial_ledger_state in
      let iters = max_blocks_for_coverage extra_block_count in
      let total_cmds = transaction_capacity * iters in
      let%bind cmds =
        User_command.Valid.Gen.sequence ~length:total_cmds
          ~sign_type:(`Real signature_kind) ledger_init_state
      in
      assert (List.length cmds = total_cmds) ;
      return (ledger_init_state, cmds, List.init iters ~f:(Fn.const None))

    (* Generator for when we have less commands than needed to fill all slots. *)
    let gen_below_capacity ~signature_kind ?(extra_blocks = false) () =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger_init_state = Ledger.gen_initial_ledger_state in
      let iters_max =
        max_blocks_for_coverage 0 * if extra_blocks then 4 else 2
      in
      let iters_min = max_blocks_for_coverage 0 in
      let%bind iters = Int.gen_incl iters_min iters_max in
      (* N.B. user commands per block is much less than transactions per block
         due to fee transfers and coinbases, especially with worse case number
         of provers, so in order to exercise not filling the scan state
         completely we always apply <= 1/2 transaction_capacity commands.
      *)
      let%bind cmds_per_iter =
        Quickcheck.Generator.list_with_length iters
          (Int.gen_incl 1 ((transaction_capacity / 2) - 1))
      in
      let total_cmds = List.fold cmds_per_iter ~init:0 ~f:( + ) in
      let%bind cmds =
        User_command.Valid.Gen.sequence ~length:total_cmds
          ~sign_type:(`Real signature_kind) ledger_init_state
      in
      assert (List.length cmds = total_cmds) ;
      return (ledger_init_state, cmds, List.map ~f:Option.some cmds_per_iter)

    let gen_all_user_commands_below_capacity ~signature_kind () =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger_init_state, cmds, iters_signed_commands =
        gen_below_capacity ~signature_kind ()
      in
      let%bind ledger, zkapps, iters_zkapps =
        gen_zkapps_below_capacity ~ledger_init_state ()
      in
      Ledger.apply_initial_ledger_state ledger ledger_init_state ;
      let iters = iters_zkapps @ iters_signed_commands in
      let%map cmds =
        let rec go zkapps payments acc =
          match (zkapps, payments) with
          | [], [] ->
              return acc
          | [], payments ->
              return (payments @ acc)
          | zkapps, [] ->
              return (zkapps @ acc)
          | zkapps, payments ->
              let%bind n = Int.gen_incl 1 transaction_capacity in
              let%bind take_zkapps = Quickcheck.Generator.bool in
              if take_zkapps then
                let take_list, leave_list = List.split_n zkapps n in
                go leave_list payments (List.rev take_list @ acc)
              else
                let take_list, leave_list = List.split_n payments n in
                go zkapps leave_list (List.rev take_list @ acc)
        in
        go zkapps cmds []
      in
      (ledger, List.rev cmds, iters)

    let ledger_account_ids ledger =
      Ledger.to_list_sequential ledger |> List.map ~f:Account.identifier

    let max_throughput_ledger_proof_count_fixed_blocks () =
      let signature_kind = Mina_signature_kind.Testnet in
      let expected_proof_count = 3 in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2
            (gen_at_capacity_fixed_blocks ~signature_kind expected_proof_count)
            small_positive_int)
        ~sexp_of:
          [%sexp_of:
            ( Ledger.init_state
            * Mina_base.User_command.Valid.t list
            * int option list )
            * int]
        ~trials:1
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger sl test_mask ->
              test_simple ~global_slot ~signature_kind
                (init_pks ledger_init_state)
                cmds iters sl ~expected_proof_count:(Some expected_proof_count)
                test_mask ~snarked_ledger `Many_provers
                stmt_to_work_random_prover ) )

    let max_throughput () =
      let signature_kind = Mina_signature_kind.Testnet in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2 (gen_at_capacity ~signature_kind) small_positive_int)
        ~sexp_of:
          [%sexp_of:
            ( Ledger.init_state
            * Mina_base.User_command.Valid.t list
            * int option list )
            * int]
        ~trials:15
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger sl test_mask ->
              test_simple ~global_slot ~signature_kind
                (init_pks ledger_init_state)
                cmds iters sl test_mask ~snarked_ledger `Many_provers
                stmt_to_work_random_prover ) )

    let max_throughput_zkapps () =
      (* limit trials to prevent too-many-open-files failure *)
      Quickcheck.test ~trials:3
        Quickcheck.Generator.(tuple2 gen_zkapps_at_capacity small_positive_int)
        ~f:(fun ((ledger, zkapps, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot
                ~signature_kind:Mina_signature_kind.Testnet account_ids zkapps
                iters sl test_mask ~snarked_ledger `Many_provers
                stmt_to_work_random_prover ) )

    let max_throughput_with_zkapp_transactions_that_may_fail () =
      (* limit trials to prevent too-many-open-files failure *)
      Quickcheck.test ~trials:2
        Quickcheck.Generator.(
          tuple2 gen_failing_zkapps_at_capacity small_positive_int)
        ~f:(fun ((ledger, zkapps, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot
                ~signature_kind:Mina_signature_kind.Testnet account_ids zkapps
                iters ~allow_failures:true sl test_mask ~snarked_ledger
                `Many_provers stmt_to_work_random_prover ) )

    let max_throughput_ledger_proof_count_fixed_blocks_zkapps () =
      let expected_proof_count = 3 in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2
            (gen_zkapps_at_capacity_fixed_blocks expected_proof_count)
            small_positive_int)
        ~trials:1
        ~f:(fun ((ledger, zkapps, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot
                ~signature_kind:Mina_signature_kind.Testnet account_ids zkapps
                iters sl ~expected_proof_count:(Some expected_proof_count)
                ~check_snarked_ledger_transition:true test_mask ~snarked_ledger
                `Many_provers stmt_to_work_random_prover ) )

    let random_number_of_commands_zkapp_signed_command () =
      let signature_kind = Mina_signature_kind.Testnet in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2
            (gen_all_user_commands_below_capacity ~signature_kind ())
            small_positive_int)
        ~trials:3
        ~f:(fun ((ledger, cmds, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot ~signature_kind account_ids cmds iters sl
                test_mask ~snarked_ledger ~check_snarked_ledger_transition:true
                `Many_provers stmt_to_work_random_prover ) )

    let be_able_to_include_random_number_of_commands () =
      let signature_kind = Mina_signature_kind.Testnet in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2 (gen_below_capacity ~signature_kind ()) small_positive_int)
        ~trials:20
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger sl test_mask ->
              test_simple ~global_slot ~signature_kind
                (init_pks ledger_init_state)
                cmds iters sl test_mask ~snarked_ledger `Many_provers
                stmt_to_work_random_prover ) )

    let be_able_to_include_random_number_of_commands_zkapps () =
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2 (gen_zkapps_below_capacity ()) small_positive_int)
        ~trials:2
        ~f:(fun ((ledger, zkapps, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot
                ~signature_kind:Mina_signature_kind.Testnet account_ids zkapps
                iters sl test_mask ~snarked_ledger `Many_provers
                stmt_to_work_random_prover ) )

    let be_able_to_include_random_number_of_commands_one_prover () =
      let signature_kind = Mina_signature_kind.Testnet in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2 (gen_below_capacity ~signature_kind ()) small_positive_int)
        ~trials:20
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger sl test_mask ->
              test_simple ~global_slot ~signature_kind
                (init_pks ledger_init_state)
                cmds iters sl test_mask ~snarked_ledger `One_prover
                stmt_to_work_one_prover ) )

    let be_able_to_include_random_number_of_commands_one_prover_zkapps () =
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2
            (gen_zkapps_below_capacity ~extra_blocks:true ())
            small_positive_int)
        ~trials:2
        ~f:(fun ((ledger, zkapps, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot
                ~signature_kind:Mina_signature_kind.Testnet account_ids zkapps
                iters sl test_mask ~snarked_ledger
                ~check_snarked_ledger_transition:true `One_prover
                stmt_to_work_one_prover ) )

    let zero_proof_fee_should_not_create_a_fee_transfer () =
      let signature_kind = Mina_signature_kind.Testnet in
      let stmt_to_work_zero_fee stmts =
        Some
          (Transaction_snark_work.Checked.create_unsafe
             { fee = Currency.Fee.zero
             ; proofs = proofs stmts
             ; prover = snark_worker_pk
             } )
      in
      let expected_proof_count = 3 in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2
            (gen_at_capacity_fixed_blocks ~signature_kind expected_proof_count)
            small_positive_int)
        ~trials:20
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger sl test_mask ->
              let%map () =
                test_simple ~global_slot ~signature_kind
                  ~expected_proof_count:(Some expected_proof_count)
                  (init_pks ledger_init_state)
                  cmds iters sl test_mask ~snarked_ledger `One_prover
                  stmt_to_work_zero_fee
              in
              assert (
                Option.is_none
                  (Ledger.location_of_account test_mask
                     (Account_id.create snark_worker_pk Token_id.default) ) ) )
          )

    let compute_statuses ~ledger ~coinbase_amount ~global_slot diff =
      with_ledger_mask ledger ~f:(fun status_ledger ->
          let diff =
            Pre_diff_info.compute_statuses ~constraint_constants ~diff
              ~coinbase_amount ~coinbase_receiver ~ledger:status_ledger
              ~global_slot
              ~txn_state_view:(dummy_state_view ~global_slot ())
            |> Result.map_error ~f:Pre_diff_info.Error.to_error
            |> Or_error.ok_exn
          in
          Staged_ledger_diff.forget { diff } )

    let invalid_diff_test_check_zero_fee_excess_for_partitions () =
      let signature_kind = Mina_signature_kind.Testnet in
      let create_diff_with_non_zero_fee_excess ~ledger ~coinbase_amount
          ~global_slot txns completed_works
          (partition : Sl.Scan_state.Space_partition.t) : Staged_ledger_diff.t =
        (*With exact number of user commands in partition.first, the fee transfers that settle the fee_excess would be added to the next tree causing a non-zero fee excess*)
        let slots, job_count1 = partition.first in
        match partition.second with
        | None ->
            compute_statuses ~ledger ~coinbase_amount ~global_slot
            @@ ( { completed_works = List.take completed_works job_count1
                 ; commands = List.take txns slots
                 ; coinbase = Zero
                 ; internal_command_statuses = []
                 }
               , None )
        | Some (_, _) ->
            let txns_in_second_diff = List.drop txns slots in
            compute_statuses ~ledger ~coinbase_amount ~global_slot
              ( { completed_works = List.take completed_works job_count1
                ; commands = List.take txns slots
                ; coinbase = Zero
                ; internal_command_statuses = []
                }
              , Some
                  { completed_works =
                      ( if List.is_empty txns_in_second_diff then []
                      else List.drop completed_works job_count1 )
                  ; commands = txns_in_second_diff
                  ; coinbase = Zero
                  ; internal_command_statuses = []
                  } )
      in
      let empty_diff = Staged_ledger_diff.empty_diff in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2 (gen_at_capacity ~signature_kind) small_positive_int)
        ~sexp_of:
          [%sexp_of:
            (Ledger.init_state * User_command.Valid.t list * int option list)
            * int]
        ~trials:10
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              let%map checked =
                iter_cmds_acc cmds iters true
                  (fun _cmds_left _count_opt cmds_this_iter checked ->
                    let scan_state = Sl.scan_state !sl in
                    let work =
                      Sl.Scan_state.work_statements_for_new_diff scan_state
                    in
                    let partitions =
                      Sl.Scan_state.partition_if_overflowing scan_state
                    in
                    let work_done =
                      List.map
                        ~f:(fun stmts ->
                          Transaction_snark_work.Checked.create_unsafe
                            { fee = Fee.zero
                            ; proofs = proofs stmts
                            ; prover = snark_worker_pk
                            } )
                        work
                    in
                    let cmds_this_iter = cmds_this_iter |> Sequence.to_list in
                    let global_slot =
                      Mina_numbers.Global_slot_since_genesis.of_int global_slot
                    in
                    let diff =
                      create_diff_with_non_zero_fee_excess
                        ~ledger:(Sl.ledger !sl)
                        ~coinbase_amount:constraint_constants.coinbase_amount
                        ~global_slot cmds_this_iter work_done partitions
                    in
                    let current_state, current_view =
                      dummy_state_and_view ~global_slot ()
                    in
                    let state_hashes =
                      Mina_state.Protocol_state.hashes current_state
                    in
                    let%bind apply_res =
                      Sl.apply ~constraint_constants ~global_slot !sl diff
                        ~logger ~verifier ~get_completed_work:(Fn.const None)
                        ~current_state_view:current_view
                        ~state_and_body_hash:
                          ( state_hashes.state_hash
                          , state_hashes.state_body_hash |> Option.value_exn )
                        ~coinbase_receiver ~supercharge_coinbase:true
                        ~zkapp_cmd_limit_hardcap ~signature_kind
                    in
                    let checked', diff' =
                      match apply_res with
                      | Error (Sl.Staged_ledger_error.Non_zero_fee_excess _) ->
                          (true, empty_diff)
                      | Error err ->
                          failwith
                          @@ sprintf
                               !"Expecting Non-zero-fee-excess error, got \
                                 %{sexp: Sl.Staged_ledger_error.t}"
                               err
                      | Ok
                          ( `Hash_after_applying _hash
                          , `Ledger_proof _ledger_proof
                          , `Staged_ledger sl'
                          , `Pending_coinbase_update _ ) ->
                          sl := sl' ;
                          (false, diff)
                    in
                    return (diff', checked || checked') )
              in
              (*Note: if this fails, try increasing the number of trials to get a diff that does fail*)
              assert checked ) )

    let provers_can_t_pay_the_account_creation_fee () =
      let signature_kind = Mina_signature_kind.Testnet in
      let no_work_included (diff : Staged_ledger_diff.t) =
        List.is_empty (Staged_ledger_diff.completed_works diff)
      in
      let stmt_to_work stmts =
        let prover = stmt_to_prover stmts in
        Some
          (Transaction_snark_work.Checked.create_unsafe
             { fee =
                 Currency.Fee.(sub work_fee (of_nanomina_int_exn 1))
                 |> Option.value_exn
             ; proofs = proofs stmts
             ; prover
             } )
      in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2 (gen_below_capacity ~signature_kind ()) small_positive_int)
        ~sexp_of:
          [%sexp_of:
            (Ledger.init_state * User_command.Valid.t list * int option list)
            * int]
        ~shrinker:
          (Quickcheck.Shrinker.create
             (fun ((init_state, cmds, iters), global_slot) ->
               if List.length iters > 1 then
                 Sequence.singleton
                   ( ( init_state
                     , List.take cmds (List.length cmds - transaction_capacity)
                     , [ None ] )
                   , global_slot )
               else Sequence.empty ) )
        ~trials:1
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              iter_cmds_acc cmds iters ()
                (fun _cmds_left _count_opt cmds_this_iter () ->
                  let diff =
                    let global_slot =
                      Mina_numbers.Global_slot_since_genesis.of_int global_slot
                    in
                    let current_state_view = dummy_state_view ~global_slot () in
                    let diff_result =
                      Sl.create_diff ~constraint_constants ~global_slot !sl
                        ~logger ~current_state_view
                        ~transactions_by_fee:cmds_this_iter
                        ~get_completed_work:stmt_to_work ~coinbase_receiver
                        ~supercharge_coinbase:true ~zkapp_cmd_limit:None
                    in
                    match diff_result with
                    | Ok (diff, _invalid_txns) ->
                        Staged_ledger_diff.forget diff
                    | Error e ->
                        Error.raise (Pre_diff_info.Error.to_error e)
                  in
                  (*No proofs were purchased since the fee for the proofs are not sufficient to pay for account creation*)
                  assert (no_work_included diff) ;
                  Deferred.return (diff, ()) ) ) )

    let stmt_to_work_restricted work_list provers
        (stmts : Transaction_snark_work.Statement.t) :
        Transaction_snark_work.Checked.t option =
      let prover =
        match provers with
        | `Many_provers ->
            stmt_to_prover stmts
        | `One_prover ->
            snark_worker_pk
      in
      if
        Option.is_some
          (List.find work_list ~f:(fun s ->
               Transaction_snark_work.Statement.compare s stmts = 0 ) )
      then
        Some
          (Transaction_snark_work.Checked.create_unsafe
             { fee = work_fee; proofs = proofs stmts; prover } )
      else None

    (** Like test_simple but with a random number of completed jobs available.
                   *)

    let test_random_number_of_proofs :
           global_slot:int
        -> signature_kind:Mina_signature_kind.t
        -> Ledger.init_state
        -> User_command.Valid.t list
        -> int option list
        -> int list
        -> Sl.t ref
        -> Ledger.Mask.Attached.t
        -> [ `One_prover | `Many_provers ]
        -> unit Deferred.t =
     fun ~global_slot ~signature_kind init_state cmds cmd_iters proofs_available
         sl test_mask provers ->
      let%map proofs_available_left =
        iter_cmds_acc cmds cmd_iters proofs_available
          (fun cmds_left _count_opt cmds_this_iter proofs_available_left ->
            let work_list : Transaction_snark_work.Statement.t list =
              Transaction_snark_scan_state.all_work_statements_exn
                (Sl.scan_state !sl)
            in
            let proofs_available_this_iter =
              List.hd_exn proofs_available_left
            in
            let global_slot =
              Mina_numbers.Global_slot_since_genesis.of_int global_slot
            in
            let current_state, current_state_view =
              dummy_state_and_view ~global_slot ()
            in
            let state_and_body_hash =
              let state_hashes =
                Mina_state.Protocol_state.hashes current_state
              in
              ( state_hashes.state_hash
              , state_hashes.state_body_hash |> Option.value_exn )
            in
            let%map proof, diff =
              create_and_apply ~global_slot ~state_and_body_hash
                ~protocol_state_view:current_state_view ~signature_kind sl
                cmds_this_iter
                (stmt_to_work_restricted
                   (List.take work_list proofs_available_this_iter)
                   provers )
            in
            assert_fee_excess proof ;
            let cmds_applied_this_iter =
              List.length @@ Staged_ledger_diff.commands diff
            in
            let cb = coinbase_count diff in
            assert (proofs_available_this_iter = 0 || cb > 0) ;
            ( match provers with
            | `One_prover ->
                assert (cb <= 1)
            | `Many_provers ->
                assert (cb <= 2) ) ;
            let coinbase_cost = coinbase_cost diff in
            assert_ledger test_mask ~coinbase_cost ~global_slot
              ~protocol_state_view:current_state_view ~signature_kind !sl
              cmds_left cmds_applied_this_iter (init_pks init_state) ;
            (diff, List.tl_exn proofs_available_left) )
      in
      assert (List.is_empty proofs_available_left)

    let max_throughput_random_number_of_proofs_worst_case_provers () =
      let signature_kind = Mina_signature_kind.Testnet in
      (* Always at worst case number of provers *)
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters =
          gen_at_capacity ~signature_kind
        in
        (* How many proofs will be available at each iteration. *)
        let%bind proofs_available =
          (* I think in the worst case every user command begets 1.5
             transactions - one for the command and half of one for a fee
             transfer - and the merge overhead means you need (amortized) twice
             as many SNARKs as transactions, but since a SNARK work usually
             covers two SNARKS it cancels. So we need to admit up to (1.5 * the
             number of commands) works. I make it twice as many for simplicity
             and to cover coinbases. *)
          Quickcheck_lib.map_gens iters ~f:(fun _ ->
              Int.gen_incl 0 (transaction_capacity * 2) )
        in
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      Quickcheck.test g ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_random_number_of_proofs ~global_slot ~signature_kind
                ledger_init_state cmds iters proofs_available sl test_mask
                `Many_provers ) )

    let random_no_of_transactions_random_number_of_proofs_worst_case_provers () =
      let signature_kind = Mina_signature_kind.Testnet in
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters =
          gen_below_capacity ~signature_kind ~extra_blocks:true ()
        in
        let%bind proofs_available =
          Quickcheck_lib.map_gens iters ~f:(fun cmds_opt ->
              Int.gen_incl 0 (3 * Option.value_exn cmds_opt) )
        in
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      let shrinker =
        Quickcheck.Shrinker.create
          (fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
          ->
            let all_but_last xs = List.take xs (List.length xs - 1) in
            let iter_count = List.length iters in
            let mod_iters iters' =
              ( ledger_init_state
              , List.take cmds
                @@ List.sum (module Int) iters' ~f:(Option.value ~default:0)
              , iters'
              , List.take proofs_available (List.length iters')
              , global_slot )
            in
            let half_iters =
              if iter_count > 1 then
                Some (mod_iters (List.take iters (iter_count / 2)))
              else None
            in
            let one_less_iters =
              if iter_count > 2 then Some (mod_iters (all_but_last iters))
              else None
            in
            List.filter_map [ half_iters; one_less_iters ] ~f:Fn.id
            |> Sequence.of_list )
      in
      Quickcheck.test g ~shrinker ~shrink_attempts:`Exhaustive
        ~sexp_of:
          [%sexp_of:
            Ledger.init_state
            * User_command.Valid.t list
            * int option list
            * int list
            * int] ~trials:50
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_random_number_of_proofs ~global_slot ~signature_kind
                ledger_init_state cmds iters proofs_available sl test_mask
                `Many_provers ) )

    let random_number_of_commands_random_number_of_proofs_one_prover () =
      let signature_kind = Mina_signature_kind.Testnet in
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters =
          gen_below_capacity ~signature_kind ~extra_blocks:true ()
        in
        let%bind proofs_available =
          Quickcheck_lib.map_gens iters ~f:(fun cmds_opt ->
              Int.gen_incl 0 (3 * Option.value_exn cmds_opt) )
        in
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      Quickcheck.test g ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_random_number_of_proofs ~global_slot ~signature_kind
                ledger_init_state cmds iters proofs_available sl test_mask
                `One_prover ) )

    let stmt_to_work_random_fee work_list provers
        (stmts : Transaction_snark_work.Statement.t) :
        Transaction_snark_work.Checked.t option =
      let prover =
        match provers with
        | `Many_provers ->
            stmt_to_prover stmts
        | `One_prover ->
            snark_worker_pk
      in
      Option.map
        (List.find work_list ~f:(fun (s, _) ->
             Transaction_snark_work.Statement.compare s stmts = 0 ) )
        ~f:(fun (_, fee) ->
          Transaction_snark_work.Checked.create_unsafe
            { fee; proofs = proofs stmts; prover } )

    (** Like test_random_number_of_proofs but with random proof fees.
                   *)
    let test_random_proof_fee :
           global_slot:int
        -> signature_kind:Mina_signature_kind.t
        -> Ledger.init_state
        -> User_command.Valid.t list
        -> int option list
        -> (int * Fee.t list) list
        -> Sl.t ref
        -> Ledger.Mask.Attached.t
        -> [ `One_prover | `Many_provers ]
        -> unit Deferred.t =
     fun ~global_slot ~signature_kind _init_state cmds cmd_iters
         proofs_available sl _test_mask provers ->
      let%map proofs_available_left =
        iter_cmds_acc cmds cmd_iters proofs_available
          (fun _cmds_left _count_opt cmds_this_iter proofs_available_left ->
            let work_list : Transaction_snark_work.Statement.t list =
              Sl.Scan_state.work_statements_for_new_diff (Sl.scan_state !sl)
            in
            let proofs_available_this_iter, fees_for_each =
              List.hd_exn proofs_available_left
            in
            let work_to_be_done =
              let work_list = List.take work_list proofs_available_this_iter in
              List.(zip_exn work_list (take fees_for_each (length work_list)))
            in
            let global_slot =
              Mina_numbers.Global_slot_since_genesis.of_int global_slot
            in
            let current_state, current_state_view =
              dummy_state_and_view ~global_slot ()
            in
            let state_and_body_hash =
              let state_hashes =
                Mina_state.Protocol_state.hashes current_state
              in
              ( state_hashes.state_hash
              , state_hashes.state_body_hash |> Option.value_exn )
            in
            let%map _proof, diff =
              create_and_apply ~global_slot
                ~protocol_state_view:current_state_view ~state_and_body_hash
                ~signature_kind sl cmds_this_iter
                (stmt_to_work_random_fee work_to_be_done provers)
            in
            let sorted_work_from_diff1
                (pre_diff :
                  Staged_ledger_diff.Pre_diff_with_at_most_two_coinbase.t ) =
              List.sort pre_diff.completed_works ~compare:(fun w w' ->
                  Fee.compare w.fee w'.fee )
            in
            let sorted_work_from_diff2
                (pre_diff :
                  Staged_ledger_diff.Pre_diff_with_at_most_one_coinbase.t option
                  ) =
              Option.value_map pre_diff ~default:[] ~f:(fun p ->
                  List.sort p.completed_works ~compare:(fun w w' ->
                      Fee.compare w.fee w'.fee ) )
            in
            let () =
              let assert_same_fee { Coinbase.Fee_transfer.fee; _ } fee' =
                assert (Fee.equal fee fee')
              in
              let first_pre_diff, second_pre_diff_opt = diff.diff in
              match
                ( first_pre_diff.coinbase
                , Option.value_map second_pre_diff_opt
                    ~default:Staged_ledger_diff.At_most_one.Zero ~f:(fun d ->
                      d.coinbase ) )
              with
              | ( Staged_ledger_diff.At_most_two.Zero
                , Staged_ledger_diff.At_most_one.Zero )
              | Two None, Zero ->
                  ()
              | One ft_opt, Zero ->
                  Option.value_map ft_opt ~default:() ~f:(fun single ->
                      let work =
                        List.hd_exn (sorted_work_from_diff1 first_pre_diff)
                      in
                      assert_same_fee single work.fee )
              | Zero, One ft_opt ->
                  Option.value_map ft_opt ~default:() ~f:(fun single ->
                      let work =
                        List.hd_exn (sorted_work_from_diff2 second_pre_diff_opt)
                      in
                      assert_same_fee single work.fee )
              | Two (Some (ft, ft_opt)), Zero ->
                  let work_done = sorted_work_from_diff1 first_pre_diff in
                  let work = List.hd_exn work_done in
                  assert_same_fee ft work.fee ;
                  Option.value_map ft_opt ~default:() ~f:(fun single ->
                      let work = List.hd_exn (List.drop work_done 1) in
                      assert_same_fee single work.fee )
              | _ ->
                  failwith @@ "Incorrect coinbase in the diff "
                  ^ ( Staged_ledger_diff.read_all_proofs_from_disk diff
                    |> Staged_ledger_diff.Stable.Latest.to_yojson
                    |> Yojson.Safe.to_string )
            in
            (diff, List.tl_exn proofs_available_left) )
      in
      assert (List.is_empty proofs_available_left)

    let max_throughput_random_random_fee_number_of_proofs_worst_case_provers () =
      (* Always at worst case number of provers *)
      let signature_kind = Mina_signature_kind.Testnet in
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters =
          gen_at_capacity ~signature_kind
        in
        (* How many proofs will be available at each iteration. *)
        let%bind proofs_available =
          Quickcheck_lib.map_gens iters ~f:(fun _ ->
              let%bind number_of_proofs =
                Int.gen_incl 0 (transaction_capacity * 2)
              in
              let%map fees =
                Quickcheck.Generator.list_with_length number_of_proofs
                  Fee.(
                    gen_incl (of_nanomina_int_exn 1) (of_nanomina_int_exn 20))
              in
              (number_of_proofs, fees) )
        in
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      Quickcheck.test g ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_random_proof_fee ~global_slot ~signature_kind
                ledger_init_state cmds iters proofs_available sl test_mask
                `Many_provers ) )

    let max_throughput_random_fee () =
      let signature_kind = Mina_signature_kind.Testnet in
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters =
          gen_at_capacity ~signature_kind
        in
        let%bind proofs_available =
          Quickcheck_lib.map_gens iters ~f:(fun _ ->
              let number_of_proofs =
                transaction_capacity
                (*All proofs are available*)
              in
              let%map fees =
                Quickcheck.Generator.list_with_length number_of_proofs
                  Fee.(
                    gen_incl (of_nanomina_int_exn 1) (of_nanomina_int_exn 20))
              in
              (number_of_proofs, fees) )
        in
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      Quickcheck.test g
        ~sexp_of:
          [%sexp_of:
            Ledger.init_state
            * Mina_base.User_command.Valid.t list
            * int option list
            * (int * Fee.t list) list
            * int] ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_random_proof_fee ~global_slot ~signature_kind
                ledger_init_state cmds iters proofs_available sl test_mask
                `Many_provers ) )

    let check_pending_coinbase ~supercharge_coinbase proof ~sl_before ~sl_after
        (_state_hash, state_body_hash) global_slot pc_update ~is_new_stack =
      let pending_coinbase_before = Sl.pending_coinbase_collection sl_before in
      let root_before = Pending_coinbase.merkle_root pending_coinbase_before in
      let unchecked_root_after =
        Pending_coinbase.merkle_root (Sl.pending_coinbase_collection sl_after)
      in
      let f_pop_and_add () =
        let open Snark_params.Tick in
        let open Pending_coinbase in
        let proof_emitted =
          if Option.is_some proof then Boolean.true_ else Boolean.false_
        in
        let%bind root_after_popping, _deleted_stack =
          Pending_coinbase.Checked.pop_coinbases ~constraint_constants
            ~proof_emitted
            (Hash.var_of_t root_before)
        in
        let pc_update_var = Update.var_of_t pc_update in
        let coinbase_receiver =
          Public_key.Compressed.(var_of_t coinbase_receiver)
        in
        let supercharge_coinbase = Boolean.var_of_value supercharge_coinbase in
        let state_body_hash_var = State_body_hash.var_of_t state_body_hash in
        let global_slot_var =
          Mina_numbers.Global_slot_since_genesis.Checked.constant global_slot
        in
        Pending_coinbase.Checked.add_coinbase ~constraint_constants
          root_after_popping pc_update_var ~coinbase_receiver
          ~supercharge_coinbase state_body_hash_var global_slot_var
      in
      let checked_root_after_update =
        let open Snark_params.Tick in
        let open Pending_coinbase in
        let comp =
          let%map result =
            handle f_pop_and_add
              (unstage
                 (handler ~depth:constraint_constants.pending_coinbase_depth
                    pending_coinbase_before ~is_new_stack ) )
          in
          As_prover.read Hash.typ result
        in
        let x = Or_error.ok_exn (run_and_check comp) in
        x
      in
      [%test_eq: Pending_coinbase.Hash.t] unchecked_root_after
        checked_root_after_update

    let test_pending_coinbase :
           global_slot:int
        -> signature_kind:Mina_signature_kind.t
        -> Ledger.init_state
        -> User_command.Valid.t list
        -> int option list
        -> int list
        -> Sl.t ref
        -> Ledger.Mask.Attached.t
        -> [ `One_prover | `Many_provers ]
        -> unit Deferred.t =
     fun ~global_slot ~signature_kind init_state cmds cmd_iters proofs_available
         sl test_mask provers ->
      let global_slot =
        Mina_numbers.Global_slot_since_genesis.of_int global_slot
      in
      let%map proofs_available_left, _ =
        iter_cmds_acc cmds cmd_iters (proofs_available, global_slot)
          (fun
            cmds_left
            _count_opt
            cmds_this_iter
            (proofs_available_left, global_slot)
          ->
            let work_list : Transaction_snark_work.Statement.t list =
              Sl.Scan_state.all_work_statements_exn (Sl.scan_state !sl)
            in
            let proofs_available_this_iter =
              List.hd_exn proofs_available_left
            in
            let sl_before = !sl in
            let current_state, current_state_view =
              dummy_state_and_view ~global_slot ()
            in
            let state_and_body_hash =
              let state_hashes =
                Mina_state.Protocol_state.hashes current_state
              in
              ( state_hashes.state_hash
              , state_hashes.state_body_hash |> Option.value_exn )
            in
            let%map proof, diff, is_new_stack, pc_update, supercharge_coinbase =
              create_and_apply_with_state_body_hash ~current_state_view
                ~global_slot ~state_and_body_hash ~signature_kind sl
                cmds_this_iter
                (stmt_to_work_restricted
                   (List.take work_list proofs_available_this_iter)
                   provers )
            in
            check_pending_coinbase proof ~supercharge_coinbase ~sl_before
              ~sl_after:!sl state_and_body_hash global_slot pc_update
              ~is_new_stack ;
            assert_fee_excess proof ;
            let cmds_applied_this_iter =
              List.length @@ Staged_ledger_diff.commands diff
            in
            let cb = coinbase_count diff in
            assert (proofs_available_this_iter = 0 || cb > 0) ;
            ( match provers with
            | `One_prover ->
                assert (cb <= 1)
            | `Many_provers ->
                assert (cb <= 2) ) ;
            let coinbase_cost = coinbase_cost diff in
            assert_ledger test_mask ~coinbase_cost ~global_slot
              ~protocol_state_view:current_state_view ~signature_kind !sl
              cmds_left cmds_applied_this_iter (init_pks init_state) ;
            ( diff
            , ( List.tl_exn proofs_available_left
              , Mina_numbers.Global_slot_since_genesis.succ global_slot ) ) )
      in
      assert (List.is_empty proofs_available_left)

    let pending_coinbase_test ~signature_kind prover =
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters =
          gen_below_capacity ~signature_kind ~extra_blocks:true ()
        in
        let%bind proofs_available =
          Quickcheck_lib.map_gens iters ~f:(fun cmds_opt ->
              Int.gen_incl 0 (3 * Option.value_exn cmds_opt) )
        in
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      Quickcheck.test g ~trials:5
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_pending_coinbase ~global_slot ~signature_kind
                ledger_init_state cmds iters proofs_available sl test_mask
                prover ) )

    let validate_pending_coinbase_for_random_number_of_commands_random_number_of_proofs_one_prover () =
      pending_coinbase_test ~signature_kind:Mina_signature_kind.Testnet
        `One_prover

    let validate_pending_coinbase_for_random_number_of_commands_random_number_of_proofs_many_provers () =
      pending_coinbase_test ~signature_kind:Mina_signature_kind.Testnet
        `Many_provers

    let timed_account n =
      let keypair =
        Quickcheck.random_value
          ~seed:(`Deterministic (sprintf "timed_account_%d" n))
          Keypair.gen
      in
      let account_id =
        Account_id.create
          (Public_key.compress keypair.public_key)
          Token_id.default
      in
      let balance = Balance.of_mina_int_exn 100 in
      (*Should fully vest by slot = 7*)
      let acc =
        Account.create_timed account_id balance ~initial_minimum_balance:balance
          ~cliff_time:(Mina_numbers.Global_slot_since_genesis.of_int 4)
          ~cliff_amount:Amount.zero
          ~vesting_period:(Mina_numbers.Global_slot_span.of_int 2)
          ~vesting_increment:(Amount.of_mina_int_exn 50)
        |> Or_error.ok_exn
      in
      (keypair, acc)

    let untimed_account n =
      let keypair =
        Quickcheck.random_value
          ~seed:(`Deterministic (sprintf "untimed_account_%d" n))
          Keypair.gen
      in
      let account_id =
        Account_id.create
          (Public_key.compress keypair.public_key)
          Token_id.default
      in
      let balance = Balance.of_mina_int_exn 100 in
      let acc = Account.create account_id balance in
      (keypair, acc)

    let supercharge_coinbase_test ~(self : Account.t) ~(delegator : Account.t)
        ~block_count ~signature_kind f_expected_balance sl =
      let coinbase_receiver = self in
      let init_balance = coinbase_receiver.balance in
      let check_receiver_account sl count =
        let location =
          Ledger.location_of_account (Sl.ledger sl)
            (Account.identifier coinbase_receiver)
          |> Option.value_exn
        in
        let account = Ledger.get (Sl.ledger sl) location |> Option.value_exn in
        [%test_eq: Balance.t]
          (f_expected_balance count init_balance)
          account.balance
      in
      Deferred.List.iter
        (List.init block_count ~f:(( + ) 1))
        ~f:(fun block_count ->
          let global_slot =
            Mina_numbers.Global_slot_since_genesis.of_int block_count
          in
          let current_state, current_state_view =
            dummy_state_and_view ~global_slot ()
          in
          let state_and_body_hash =
            let state_hashes = Mina_state.Protocol_state.hashes current_state in
            ( state_hashes.state_hash
            , state_hashes.state_body_hash |> Option.value_exn )
          in
          let%bind _ =
            create_and_apply_with_state_body_hash ~winner:delegator.public_key
              ~coinbase_receiver:coinbase_receiver.public_key sl
              ~current_state_view
              ~global_slot:
                (Mina_numbers.Global_slot_since_genesis.of_int block_count)
              ~state_and_body_hash ~signature_kind Sequence.empty
              (stmt_to_work_zero_fee ~prover:self.public_key)
          in
          check_receiver_account !sl block_count ;
          return () )

    let normal_coinbase = constraint_constants.coinbase_amount

    let scale_exn amt i = Amount.scale amt i |> Option.value_exn

    let supercharged_coinbase =
      scale_exn constraint_constants.coinbase_amount
        constraint_constants.supercharged_coinbase_factor

    let g = Ledger.gen_initial_ledger_state

    let supercharged_coinbase_staking () =
      let signature_kind = Mina_signature_kind.Testnet in
      let keypair_self, self = timed_account 1 in
      let slots_with_locked_tokens =
        7
        (*calculated from the timing values for timed_accounts*)
      in
      let block_count = slots_with_locked_tokens + 5 in
      let f_expected_balance block_no init_balance =
        if block_no <= slots_with_locked_tokens then
          Balance.add_amount init_balance (scale_exn normal_coinbase block_no)
          |> Option.value_exn
        else
          (* init balance +
                (normal_coinbase * slots_with_locked_tokens) +
                (supercharged_coinbase * remaining slots))*)
          Balance.add_amount
            ( Balance.add_amount init_balance
                (scale_exn normal_coinbase slots_with_locked_tokens)
            |> Option.value_exn )
            (scale_exn supercharged_coinbase
               (block_no - slots_with_locked_tokens) )
          |> Option.value_exn
      in
      Quickcheck.test g ~trials:1 ~f:(fun ledger_init_state ->
          let ledger_init_state =
            Array.append
              [| ( keypair_self
                 , Balance.to_amount self.balance
                 , self.nonce
                 , self.timing )
              |]
              ledger_init_state
          in
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              supercharge_coinbase_test ~self ~signature_kind ~delegator:self
                ~block_count f_expected_balance sl ) )

    let supercharged_coinbase_unlocked_account_delegating_to_locked_account () =
      let signature_kind = Mina_signature_kind.Testnet in
      let keypair_self, locked_self = timed_account 1 in
      let keypair_delegator, unlocked_delegator = untimed_account 1 in
      let slots_with_locked_tokens =
        7
        (*calculated from the timing values for timed_accounts*)
      in
      let block_count = slots_with_locked_tokens + 2 in
      let f_expected_balance block_no init_balance =
        Balance.add_amount init_balance
          (scale_exn supercharged_coinbase block_no)
        |> Option.value_exn
      in
      Quickcheck.test g ~trials:1 ~f:(fun ledger_init_state ->
          let ledger_init_state =
            Array.append
              [| ( keypair_self
                 , Balance.to_amount locked_self.balance
                 , locked_self.nonce
                 , locked_self.timing )
               ; ( keypair_delegator
                 , Balance.to_amount unlocked_delegator.balance
                 , unlocked_delegator.nonce
                 , unlocked_delegator.timing )
              |]
              ledger_init_state
          in
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              supercharge_coinbase_test ~signature_kind ~self:locked_self
                ~delegator:unlocked_delegator ~block_count f_expected_balance sl ) )

    let supercharged_coinbase_locked_account_delegating_to_unlocked_account () =
      let signature_kind = Mina_signature_kind.Testnet in
      let keypair_self, unlocked_self = untimed_account 1 in
      let keypair_delegator, locked_delegator = timed_account 1 in
      let slots_with_locked_tokens =
        7
        (*calculated from the timing values for the timed_account*)
      in
      let block_count = slots_with_locked_tokens + 2 in
      let f_expected_balance block_no init_balance =
        if block_no <= slots_with_locked_tokens then
          Balance.add_amount init_balance (scale_exn normal_coinbase block_no)
          |> Option.value_exn
        else
          (* init balance +
                (normal_coinbase * slots_with_locked_tokens) +
                (supercharged_coinbase * remaining slots))*)
          Balance.add_amount
            ( Balance.add_amount init_balance
                (scale_exn normal_coinbase slots_with_locked_tokens)
            |> Option.value_exn )
            (scale_exn supercharged_coinbase
               (block_no - slots_with_locked_tokens) )
          |> Option.value_exn
      in
      Quickcheck.test g ~trials:1 ~f:(fun ledger_init_state ->
          let ledger_init_state =
            Array.append
              [| ( keypair_self
                 , Balance.to_amount unlocked_self.balance
                 , unlocked_self.nonce
                 , unlocked_self.timing )
               ; ( keypair_delegator
                 , Balance.to_amount locked_delegator.balance
                 , locked_delegator.nonce
                 , locked_delegator.timing )
              |]
              ledger_init_state
          in
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              supercharge_coinbase_test ~signature_kind ~self:unlocked_self
                ~delegator:locked_delegator ~block_count f_expected_balance sl ) )

    let supercharged_coinbase_locked_account_delegating_to_locked_account () =
      let signature_kind = Mina_signature_kind.Testnet in
      let keypair_self, locked_self = timed_account 1 in
      let keypair_delegator, locked_delegator = timed_account 2 in
      let slots_with_locked_tokens =
        7
        (*calculated from the timing values for timed_accounts*)
      in
      let block_count = slots_with_locked_tokens in
      let f_expected_balance block_no init_balance =
        (*running the test as long as both the accounts remain locked and hence normal coinbase in all the blocks*)
        Balance.add_amount init_balance (scale_exn normal_coinbase block_no)
        |> Option.value_exn
      in
      Quickcheck.test g ~trials:1 ~f:(fun ledger_init_state ->
          let ledger_init_state =
            Array.append
              [| ( keypair_self
                 , Balance.to_amount locked_self.balance
                 , locked_self.nonce
                 , locked_self.timing )
               ; ( keypair_delegator
                 , Balance.to_amount locked_delegator.balance
                 , locked_delegator.nonce
                 , locked_delegator.timing )
              |]
              ledger_init_state
          in
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              supercharge_coinbase_test ~signature_kind ~self:locked_self
                ~delegator:locked_delegator ~block_count f_expected_balance sl ) )

    let command_insufficient_funds ~signature_kind =
      let open Quickcheck.Generator.Let_syntax in
      let%map ledger_init_state = Ledger.gen_initial_ledger_state
      and global_slot = Quickcheck.Generator.small_positive_int in
      let kp, balance, nonce, _ = ledger_init_state.(0) in
      let receiver_pk =
        Quickcheck.random_value ~seed:(`Deterministic "receiver_pk")
          Public_key.Compressed.gen
      in
      let insufficient_account_creation_fee =
        Currency.Fee.to_nanomina_int constraint_constants.account_creation_fee
        / 2
        |> Currency.Amount.of_nanomina_int_exn
      in
      let source_pk = Public_key.compress kp.public_key in
      let body =
        Signed_command_payload.Body.Payment
          Payment_payload.Poly.
            { receiver_pk; amount = insufficient_account_creation_fee }
      in
      let fee = Currency.Amount.to_fee balance in
      let payload =
        Signed_command.Payload.create ~fee ~fee_payer_pk:source_pk ~nonce
          ~memo:Signed_command_memo.dummy ~valid_until:None ~body
      in
      let signed_command =
        User_command.Signed_command
          (Signed_command.sign ~signature_kind kp payload)
      in
      (ledger_init_state, signed_command, global_slot)

    let commands_with_insufficient_funds_are_not_included () =
      let logger = Logger.null () in
      Quickcheck.test
        (command_insufficient_funds ~signature_kind:Mina_signature_kind.Testnet)
        ~trials:1 ~f:(fun (ledger_init_state, invalid_command, global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              let global_slot =
                Mina_numbers.Global_slot_since_genesis.of_int global_slot
              in
              let current_state_view = dummy_state_view ~global_slot () in
              let diff_result =
                Sl.create_diff ~constraint_constants ~global_slot !sl ~logger
                  ~current_state_view
                  ~transactions_by_fee:(Sequence.of_list [ invalid_command ])
                  ~get_completed_work:(stmt_to_work_zero_fee ~prover:self_pk)
                  ~coinbase_receiver ~supercharge_coinbase:false
                  ~zkapp_cmd_limit:None
              in
              ( match diff_result with
              | Ok (diff, _invalid_txns) ->
                  assert (
                    List.is_empty
                      (Staged_ledger_diff.With_valid_signatures_and_proofs
                       .commands diff ) )
              | Error e ->
                  Error.raise (Pre_diff_info.Error.to_error e) ) ;
              Deferred.unit ) )

    let blocks_having_commands_with_insufficient_funds_are_rejected () =
      let logger = Logger.null () in
      let signature_kind = Mina_signature_kind.Testnet in
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%map ledger_init_state = Ledger.gen_initial_ledger_state
        and global_slot = Quickcheck.Generator.small_positive_int in
        let command (kp : Keypair.t) (balance : Currency.Amount.t)
            (nonce : Account.Nonce.t) (validity : [ `Valid | `Invalid ]) =
          let receiver_pk =
            Quickcheck.random_value ~seed:(`Deterministic "receiver_pk")
              Public_key.Compressed.gen
          in
          let account_creation_fee, fee =
            match validity with
            | `Valid ->
                let account_creation_fee =
                  constraint_constants.account_creation_fee
                  |> Currency.Amount.of_fee
                in
                ( account_creation_fee
                , Currency.Amount.to_fee
                    ( Currency.Amount.sub balance account_creation_fee
                    |> Option.value_exn ) )
            | `Invalid ->
                (* Not enough account creation fee and using full balance for fee*)
                ( Currency.Fee.to_nanomina_int
                    constraint_constants.account_creation_fee
                  / 2
                  |> Currency.Amount.of_nanomina_int_exn
                , Currency.Amount.to_fee balance )
          in
          let fee_payer_pk = Public_key.compress kp.public_key in
          let body =
            Signed_command_payload.Body.Payment
              Payment_payload.Poly.
                { receiver_pk; amount = account_creation_fee }
          in
          let payload =
            Signed_command.Payload.create ~fee ~fee_payer_pk ~nonce
              ~memo:Signed_command_memo.dummy ~valid_until:None ~body
          in
          User_command.Signed_command
            (Signed_command.sign ~signature_kind kp payload)
        in
        let signed_command =
          let kp, balance, nonce, _ = ledger_init_state.(0) in
          command kp balance nonce `Valid
        in
        let invalid_command =
          let kp, balance, nonce, _ = ledger_init_state.(1) in
          command kp balance nonce `Invalid
        in
        (ledger_init_state, signed_command, invalid_command, global_slot)
      in
      Quickcheck.test g ~trials:1
        ~f:(fun (ledger_init_state, valid_command, invalid_command, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              let global_slot =
                Mina_numbers.Global_slot_since_genesis.of_int global_slot
              in
              let current_state, current_state_view =
                dummy_state_and_view ~global_slot ()
              in
              let state_and_body_hash =
                let state_hashes =
                  Mina_state.Protocol_state.hashes current_state
                in
                ( state_hashes.state_hash
                , state_hashes.state_body_hash |> Option.value_exn )
              in
              let diff_result =
                Sl.create_diff ~constraint_constants ~global_slot !sl ~logger
                  ~current_state_view
                  ~transactions_by_fee:(Sequence.of_list [ valid_command ])
                  ~get_completed_work:(stmt_to_work_zero_fee ~prover:self_pk)
                  ~coinbase_receiver ~supercharge_coinbase:false
                  ~zkapp_cmd_limit:None
              in
              match diff_result with
              | Error e ->
                  Error.raise (Pre_diff_info.Error.to_error e)
              | Ok (diff, _invalid_txns) -> (
                  assert (
                    List.length
                      (Staged_ledger_diff.With_valid_signatures_and_proofs
                       .commands diff )
                    = 1 ) ;
                  let f, s = diff.diff in
                  let failed_command =
                    With_status.
                      { data = invalid_command
                      ; status =
                          Transaction_status.Failed
                            Transaction_status.Failure.(
                              Collection.of_single_failure
                                Amount_insufficient_to_create_account)
                      }
                  in
                  (*Replace the valid command with an invalid command)*)
                  let diff =
                    { Staged_ledger_diff.With_valid_signatures_and_proofs.diff =
                        ({ f with commands = [ failed_command ] }, s)
                    }
                  in
                  match%map
                    Sl.apply ~constraint_constants ~global_slot !sl
                      (Staged_ledger_diff.forget diff)
                      ~logger ~verifier ~get_completed_work:(Fn.const None)
                      ~current_state_view ~state_and_body_hash
                      ~coinbase_receiver ~supercharge_coinbase:false
                      ~zkapp_cmd_limit_hardcap ~signature_kind
                  with
                  | Ok _x ->
                      assert false
                  (*TODO: check transaction logic errors here. Verified that the error is here is [The source account has an insufficient balance]*)
                  | Error (Staged_ledger_error.Unexpected _ as e) ->
                      [%log info] "Error %s" (Staged_ledger_error.to_string e) ;
                      assert true
                  | Error _ ->
                      assert false ) ) )

    let gen_spec_keypair_and_global_slot =
      let open Quickcheck.Generator.Let_syntax in
      let%bind test_spec = Mina_transaction_logic.For_tests.Test_spec.gen in
      let pks =
        Public_key.Compressed.Set.of_list
          (List.map (Array.to_list test_spec.init_ledger) ~f:(fun s ->
               Public_key.compress (fst s).public_key ) )
      in
      let%map kp =
        Quickcheck.Generator.filter Keypair.gen ~f:(fun kp ->
            not
              (Public_key.Compressed.Set.mem pks
                 (Public_key.compress kp.public_key) ) )
      and global_slot = Quickcheck.Generator.small_positive_int in
      (test_spec, kp, global_slot)

    let when_creating_diff_invalid_commands_would_be_skipped () =
      let signature_kind = Mina_signature_kind.Testnet in
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%bind spec_keypair_and_slot = gen_spec_keypair_and_global_slot in
        let%map signed_commands_or_zkapps =
          List.gen_with_length 7 Bool.quickcheck_generator
        in
        (spec_keypair_and_slot, signed_commands_or_zkapps |> List.to_array)
      in
      Async.Thread_safe.block_on_async_exn
      @@ fun () ->
      Async.Quickcheck.async_test ~trials:20 gen
        ~f:(fun
             ( ({ init_ledger; _ }, new_kp, global_slot)
             , signed_commands_or_zkapps )
           ->
          let open Transaction_snark.For_tests in
          let zkapp_pk = Public_key.compress new_kp.public_key in
          let ledger =
            Ledger.create ~depth:constraint_constants.ledger_depth ()
          in
          Mina_transaction_logic.For_tests.Init_ledger.init
            (module Ledger.Ledger_inner)
            init_ledger ledger ;
          Transaction_snark.For_tests.create_trivial_zkapp_account
            ~permissions:Permissions.user_default ~vk ~ledger zkapp_pk ;
          let sl = Sl.create_exn ~constraint_constants ~ledger in
          [%log info] "signed commands or zkapps"
            ~metadata:
              [ ( "signed_commands_or_zkapps"
                , `List
                    (List.map (Array.to_list signed_commands_or_zkapps)
                       ~f:(fun b -> `Bool b) ) )
              ] ;
          let default_fee = Fee.of_nanomina_int_exn 2_000_000 in
          let default_amount = Amount.of_mina_int_exn 1 in
          let mk_signed_command ~(fee_payer : Keypair.t) ~(receiver : Keypair.t)
              ?(amount = default_amount) ~(nonce : Account.Nonce.t) () =
            let body =
              Signed_command_payload.Body.Payment
                Payment_payload.Poly.
                  { receiver_pk = Public_key.compress receiver.public_key
                  ; amount
                  }
            in
            let payload =
              Signed_command.Payload.create ~fee:default_fee
                ~fee_payer_pk:Public_key.(compress fee_payer.public_key)
                ~nonce ~memo:Signed_command_memo.dummy ~valid_until:None ~body
            in
            User_command.Signed_command
              (Signed_command.sign ~signature_kind fee_payer payload)
          in
          let mk_zkapp_command ~(fee_payer : Keypair.t) ?(fee = default_fee)
              ~(nonce : Account.Nonce.t) () =
            let spec : Update_states_spec.t =
              { sender = (new_kp, Account.Nonce.zero)
              ; fee
              ; fee_payer = Some (fee_payer, nonce)
              ; receivers = []
              ; amount = default_amount
              ; zkapp_account_keypairs = [ new_kp ]
              ; memo = Signed_command_memo.dummy
              ; new_zkapp_account = false
              ; snapp_update =
                  { Account_update.Update.dummy with
                    delegate = Zkapp_basic.Set_or_keep.Set zkapp_pk
                  }
              ; current_auth = Permissions.Auth_required.Signature
              ; call_data = Snark_params.Tick.Field.zero
              ; events = []
              ; actions = []
              ; preconditions = None
              }
            in
            let%map zkapp_command =
              Transaction_snark.For_tests.update_states
                ~zkapp_prover_and_vk:(zkapp_prover, Async.Deferred.return vk)
                ~constraint_constants spec
            in
            let valid_zkapp_command =
              Zkapp_command.Valid.For_tests.to_valid ~failed:false
                ~find_vk:(find_vk ledger) zkapp_command
              |> Or_error.ok_exn
            in
            User_command.Zkapp_command valid_zkapp_command
          in
          let mk_user_command ~signed_command_or_zkapp ~fee_payer ~receiver
              ?amount ~nonce () =
            match signed_command_or_zkapp with
            | true ->
                return
                @@ mk_signed_command ~fee_payer ~receiver ?amount ~nonce ()
            | false ->
                mk_zkapp_command ~fee_payer
                  ?fee:
                    (Option.map amount ~f:(fun amount -> Amount.to_fee amount))
                  ~nonce ()
          in
          let fee_payer, _ = init_ledger.(0) in
          let fee_payer1, _ = init_ledger.(2) in
          let receiver, _ = init_ledger.(1) in
          let%bind valid_command_1 =
            mk_user_command
              ~signed_command_or_zkapp:signed_commands_or_zkapps.(0)
              ~fee_payer ~receiver ~nonce:(Account.Nonce.of_int 0) ()
          and valid_command_2 =
            mk_user_command
              ~signed_command_or_zkapp:signed_commands_or_zkapps.(1)
              ~fee_payer ~receiver ~nonce:(Account.Nonce.of_int 1) ()
          and invalid_command_3 =
            mk_user_command
              ~signed_command_or_zkapp:signed_commands_or_zkapps.(2)
              ~fee_payer ~receiver ~amount:Amount.max_int
              ~nonce:(Account.Nonce.of_int 2) ()
          and invalid_command_4 =
            mk_user_command
              ~signed_command_or_zkapp:signed_commands_or_zkapps.(3)
              ~fee_payer ~receiver ~nonce:(Account.Nonce.of_int 3) ()
          and valid_command_5 =
            mk_user_command
              ~signed_command_or_zkapp:signed_commands_or_zkapps.(4)
              ~fee_payer ~receiver ~nonce:(Account.Nonce.of_int 2) ()
          and invalid_command_6 =
            mk_user_command
              ~signed_command_or_zkapp:signed_commands_or_zkapps.(5)
              ~fee_payer ~receiver ~nonce:(Account.Nonce.of_int 4) ()
          and valid_command_7 =
            mk_user_command
              ~signed_command_or_zkapp:signed_commands_or_zkapps.(6)
              ~fee_payer:fee_payer1 ~receiver ~nonce:(Account.Nonce.of_int 0) ()
          in
          let global_slot =
            Mina_numbers.Global_slot_since_genesis.of_int global_slot
          in
          let current_state, current_state_view =
            dummy_state_and_view ~global_slot ()
          in
          let state_and_body_hash =
            let state_hashes = Mina_state.Protocol_state.hashes current_state in
            ( state_hashes.state_hash
            , state_hashes.state_body_hash |> Option.value_exn )
          in
          match
            Sl.create_diff ~constraint_constants ~global_slot sl ~logger
              ~current_state_view
              ~transactions_by_fee:
                (Sequence.of_list
                   [ valid_command_1
                   ; valid_command_2
                   ; invalid_command_3
                   ; invalid_command_4
                   ; valid_command_5
                   ; invalid_command_6
                   ; valid_command_7
                   ] )
              ~get_completed_work:(stmt_to_work_zero_fee ~prover:self_pk)
              ~coinbase_receiver ~supercharge_coinbase:false
              ~zkapp_cmd_limit:None
          with
          | Error e ->
              Error.raise (Pre_diff_info.Error.to_error e)
          | Ok (diff, invalid_txns) -> (
              let valid_commands =
                Staged_ledger_diff.With_valid_signatures_and_proofs.commands
                  diff
                |> List.map ~f:(fun { data; _ } ->
                       User_command.forget_check data )
              in
              assert (
                List.equal User_command.equal_ignoring_proofs_and_hashes_and_aux
                  valid_commands
                  ( [ valid_command_1
                    ; valid_command_2
                    ; valid_command_5
                    ; valid_command_7
                    ]
                  |> List.map ~f:(fun cmd -> User_command.forget_check cmd) ) ) ;
              assert (List.length invalid_txns = 3) ;
              match%bind
                Sl.apply ~constraint_constants ~global_slot sl
                  (Staged_ledger_diff.forget diff)
                  ~logger ~verifier ~get_completed_work:(Fn.const None)
                  ~current_state_view ~state_and_body_hash ~coinbase_receiver
                  ~supercharge_coinbase:false ~zkapp_cmd_limit_hardcap
                  ~signature_kind
              with
              | Ok _x -> (
                  let valid_command_1_with_status =
                    With_status.
                      { data = valid_command_1
                      ; status = Transaction_status.Applied
                      }
                  in
                  let invalid_command_3_with_status =
                    With_status.
                      { data = invalid_command_3
                      ; status = Transaction_status.Applied
                      }
                  in
                  let invalid_command_4_with_status =
                    With_status.
                      { data = invalid_command_4
                      ; status = Transaction_status.Applied
                      }
                  in
                  let valid_command_7_with_status =
                    With_status.
                      { data = valid_command_7
                      ; status = Transaction_status.Applied
                      }
                  in
                  let f, s = diff.diff in
                  let diff =
                    { Staged_ledger_diff.With_valid_signatures_and_proofs.diff =
                        ( { f with
                            commands =
                              [ valid_command_1_with_status
                              ; invalid_command_3_with_status
                              ; invalid_command_4_with_status
                              ; valid_command_7_with_status
                              ]
                          }
                        , s )
                    }
                  in
                  match%map
                    Sl.apply ~constraint_constants ~global_slot sl
                      (Staged_ledger_diff.forget diff)
                      ~logger ~verifier ~get_completed_work:(Fn.const None)
                      ~current_state_view ~state_and_body_hash
                      ~coinbase_receiver ~supercharge_coinbase:false
                      ~zkapp_cmd_limit_hardcap ~signature_kind
                  with
                  | Ok _x ->
                      assert false
                  | Error _e ->
                      assert true )
              | Error e ->
                  [%log info] "Error %s" (Staged_ledger_error.to_string e) ;
                  assert false ) )

    let rec lift_deferred_zkapp_commands cmds =
      match cmds with
      | { With_status.status; data } :: cmds' ->
          let%bind data' = data in
          let%map cmds'' = lift_deferred_zkapp_commands cmds' in
          { With_status.status; data = User_command.Zkapp_command data' }
          :: cmds''
      | [] ->
          return []

    let test_staged_ledger_diff_validity ~signature_kind ~expectation
        ~setup_test =
      let make_account () =
        let keypair = Keypair.create () in
        let pubkey = Public_key.compress keypair.public_key in
        let account =
          Account.create
            (Account_id.create pubkey Token_id.default)
            (Balance.of_mina_int_exn 10_000)
        in
        (account, keypair)
      in
      let get_location ledger account =
        account |> Account.identifier
        |> Ledger.location_of_account ledger
        |> Option.value_exn
      in
      let account_a, keypair_a = make_account () in
      let account_b, keypair_b = make_account () in
      let init_ledger : Mina_transaction_logic.For_tests.Init_ledger.t =
        let balance = Fn.compose Unsigned.UInt64.to_int64 Balance.to_uint64 in
        [| (keypair_a, balance account_a.balance)
         ; (keypair_b, balance account_b.balance)
         ; (coinbase_receiver_keypair, 0L)
        |]
      in
      Ledger.with_ledger ~depth:constraint_constants.ledger_depth
        ~f:(fun ledger ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              Mina_transaction_logic.For_tests.Init_ledger.init
                (module Ledger.Ledger_inner)
                init_ledger ledger ;
              (* we could predict these based on the init ledger, but best to use the proper API *)
              let location_a = get_location ledger account_a in
              let location_b = get_location ledger account_b in
              let%bind cmds =
                setup_test ledger
                  (account_a, keypair_a.private_key, location_a)
                  (account_b, keypair_b.private_key, location_b)
              in
              (*
            let cmds = List.map cmds ~f:(fun cmd ->
              (* this is a test, so it's fine *)
              let (`If_this_is_used_it_should_have_a_comment_justifying_it cmd) = User_command.to_valid_unsafe cmd in
              cmd)
            in
            *)
              let diff : Staged_ledger_diff.t =
                let pre_diff :
                    Staged_ledger_diff.Pre_diff_with_at_most_two_coinbase.t =
                  { completed_works = []
                  ; commands = cmds
                  ; coinbase = Zero
                  ; internal_command_statuses = [ Applied ]
                  }
                in
                { diff = (pre_diff, None) }
              in
              let sl = Sl.create_exn ~constraint_constants ~ledger in
              let global_slot =
                Mina_numbers.Global_slot_since_genesis.of_int 1
              in
              let current_state, current_state_view =
                dummy_state_and_view ~global_slot ()
              in
              let state_and_body_hash =
                let state_hashes =
                  Mina_state.Protocol_state.hashes current_state
                in
                ( state_hashes.state_hash
                , state_hashes.state_body_hash |> Option.value_exn )
              in
              let%map result =
                apply ~logger ~constraint_constants ~global_slot
                  ~get_completed_work:(Fn.const None) ~verifier
                  ~current_state_view ~state_and_body_hash ~coinbase_receiver
                  ~supercharge_coinbase:false sl diff ~zkapp_cmd_limit_hardcap
                  ~signature_kind
              in
              match (expectation, result) with
              | `Accept, Ok _ | `Reject, Error _ ->
                  ()
              | `Accept, Error _ ->
                  failwith
                    "expected staged ledger diff to be accepted, but it was \
                     rejected"
              | `Reject, Ok _ ->
                  failwith
                    "expected staged ledger diff to be rejected, but it was \
                     accepted" ) )

    let mk_basic_node ?(preconditions = Account_update.Preconditions.accept)
        ?(update = Account_update.Update.noop) ~(account : Account.t)
        ~(authorization : Account_update.Authorization_kind.t) () =
      Zkapp_command_builder.mk_node
        { public_key = account.public_key
        ; token_id = account.token_id
        ; update
        ; balance_change = Amount.Signed.zero
        ; increment_nonce = false
        ; events = []
        ; actions = []
        ; call_data = Pickles.Impls.Step.Field.Constant.zero
        ; call_depth = 0
        ; preconditions
        ; use_full_commitment = true
        ; implicit_account_creation_fee = false
        ; may_use_token = Account_update.May_use_token.No
        ; authorization_kind = authorization
        }
        []

    let mk_basic_zkapp_command ?prover ~keymap ~fee ~fee_payer_pk
        ~fee_payer_nonce nodes =
      let open Zkapp_command_builder in
      mk_forest nodes
      |> mk_zkapp_command ~fee ~fee_payer_pk ~fee_payer_nonce
      |> replace_authorizations ?prover ~keymap

    let setting_verification_keys_across_differing_accounts () =
      test_staged_ledger_diff_validity
        ~signature_kind:Mina_signature_kind.Testnet ~expectation:`Accept
        ~setup_test:(fun _ledger (a, privkey_a, _loc_a) (b, privkey_b, _loc_b)
                    ->
          let `VK vk_a, `Prover prover_a =
            Transaction_snark.For_tests.create_trivial_snapp ~unique_id:0 ()
          in
          let%bind.Async.Deferred vk_a = vk_a in
          let `VK vk_b, `Prover _prover_b =
            Transaction_snark.For_tests.create_trivial_snapp ~unique_id:1 ()
          in
          let%bind.Async.Deferred vk_b = vk_b in
          let keymap =
            Public_key.Compressed.Map.of_alist_exn
              [ (a.public_key, privkey_a); (b.public_key, privkey_b) ]
          in
          lift_deferred_zkapp_commands
            [ (* command from A that sets a new verification key *)
              { status = Applied
              ; data =
                  mk_basic_zkapp_command ~keymap
                    ~fee:
                      (Fee.to_nanomina_int
                         Genesis_constants.For_unit_tests.t
                           .minimum_user_command_fee )
                    ~fee_payer_pk:a.public_key
                    ~fee_payer_nonce:(Unsigned.UInt32.of_int 0)
                    [ mk_basic_node ~account:a ~authorization:Signature
                        ~update:
                          { Account_update.Update.noop with
                            verification_key = Zkapp_basic.Set_or_keep.Set vk_a
                          }
                        ()
                    ]
              }
            ; (* command from B that sets a different verification key *)
              { status = Applied
              ; data =
                  mk_basic_zkapp_command ~keymap
                    ~fee:
                      (Fee.to_nanomina_int
                         Genesis_constants.For_unit_tests.t
                           .minimum_user_command_fee )
                    ~fee_payer_pk:a.public_key
                    ~fee_payer_nonce:(Unsigned.UInt32.of_int 1)
                    [ mk_basic_node ~account:b ~authorization:Signature
                        ~update:
                          { Account_update.Update.noop with
                            verification_key = Zkapp_basic.Set_or_keep.Set vk_b
                          }
                        ()
                    ]
              }
            ; (* proven command from A that is valid against the previously set verification key *)
              { status = Applied
              ; data =
                  mk_basic_zkapp_command ~prover:prover_a ~keymap
                    ~fee:
                      (Fee.to_nanomina_int
                         Genesis_constants.For_unit_tests.t
                           .minimum_user_command_fee )
                    ~fee_payer_pk:a.public_key
                    ~fee_payer_nonce:(Unsigned.UInt32.of_int 2)
                    [ mk_basic_node ~account:a ~authorization:(Proof vk_a.hash)
                        ()
                    ]
              }
            ] )

    let verification_keys_set_in_failed_commands_should_not_be_usable_later () =
      test_staged_ledger_diff_validity
        ~signature_kind:Mina_signature_kind.Testnet ~expectation:`Accept
        ~setup_test:(fun _ledger (a, privkey_a, _loc_a) (_b, _privkey_b, _loc_b)
                    ->
          let `VK vk_a, `Prover prover_a =
            Transaction_snark.For_tests.create_trivial_snapp ~unique_id:0 ()
          in
          let%bind.Async.Deferred vk_a = vk_a in
          let `VK vk_b, `Prover _prover_b =
            Transaction_snark.For_tests.create_trivial_snapp ~unique_id:1 ()
          in
          let%bind.Async.Deferred vk_b = vk_b in
          let keymap =
            Public_key.Compressed.Map.of_alist_exn [ (a.public_key, privkey_a) ]
          in
          lift_deferred_zkapp_commands
            [ (* successful command from A that sets verification key *)
              { status = Applied
              ; data =
                  mk_basic_zkapp_command ~keymap
                    ~fee:
                      (Fee.to_nanomina_int
                         Genesis_constants.For_unit_tests.t
                           .minimum_user_command_fee )
                    ~fee_payer_pk:a.public_key
                    ~fee_payer_nonce:(Unsigned.UInt32.of_int 0)
                    [ mk_basic_node ~account:a ~authorization:Signature
                        ~update:
                          { Account_update.Update.noop with
                            verification_key = Zkapp_basic.Set_or_keep.Set vk_a
                          }
                        ()
                    ]
              }
              (* failing command from A that sets another verification key *)
            ; { status =
                  Failed [ []; [ Account_nonce_precondition_unsatisfied ] ]
              ; data =
                  mk_basic_zkapp_command ~keymap
                    ~fee:
                      (Fee.to_nanomina_int
                         Genesis_constants.For_unit_tests.t
                           .minimum_user_command_fee )
                    ~fee_payer_pk:a.public_key
                    ~fee_payer_nonce:(Unsigned.UInt32.of_int 1)
                    [ mk_basic_node ~account:a ~authorization:Signature
                        ~preconditions:
                          { Account_update.Preconditions.accept with
                            account =
                              Zkapp_precondition.Account.nonce
                                (Account.Nonce.of_int 0)
                          }
                        ~update:
                          { Account_update.Update.noop with
                            verification_key = Zkapp_basic.Set_or_keep.Set vk_b
                          }
                        ()
                    ]
              }
            ; (* proven command from A that is valid against the first verification key only *)
              { status = Applied
              ; data =
                  mk_basic_zkapp_command ~prover:prover_a ~keymap
                    ~fee:
                      (Fee.to_nanomina_int
                         Genesis_constants.For_unit_tests.t
                           .minimum_user_command_fee )
                    ~fee_payer_pk:a.public_key
                    ~fee_payer_nonce:(Unsigned.UInt32.of_int 2)
                    [ mk_basic_node ~account:a ~authorization:(Proof vk_a.hash)
                        ()
                    ]
              }
            ] )

    let mismatched_verification_keys_in_zkapp_accounts_and_transactions () =
      let signature_kind = Mina_signature_kind.Testnet in
      let open Transaction_snark.For_tests in
      Quickcheck.test ~trials:1 gen_spec_keypair_and_global_slot
        ~f:(fun ({ init_ledger; specs = _ }, new_kp, global_slot) ->
          let fee = Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Amount.of_mina_int_exn 10 in
          let snapp_pk = Signature_lib.Public_key.compress new_kp.public_key in
          let snapp_update =
            { Account_update.Update.dummy with
              delegate = Zkapp_basic.Set_or_keep.Set snapp_pk
            }
          in
          let memo = Signed_command_memo.dummy in
          let test_spec : Update_states_spec.t =
            { sender = (new_kp, Mina_base.Account.Nonce.zero)
            ; fee
            ; fee_payer = None
            ; receivers = []
            ; amount
            ; zkapp_account_keypairs = [ new_kp ]
            ; memo
            ; new_zkapp_account = false
            ; snapp_update
            ; current_auth = Permissions.Auth_required.Proof
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
            ; preconditions = None
            }
          in
          Ledger.with_ledger ~depth:constraint_constants.ledger_depth
            ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Mina_transaction_logic.For_tests.Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  (* create a zkApp account *)
                  let snapp_permissions =
                    let default = Permissions.user_default in
                    { default with
                      set_delegate = Permissions.Auth_required.Proof
                    }
                  in
                  let snapp_account_id =
                    Account_id.create snapp_pk Token_id.default
                  in
                  let dummy_vk =
                    let data = Pickles.Side_loaded.Verification_key.dummy in
                    let hash = Zkapp_account.digest_vk data in
                    ({ data; hash } : _ With_hash.t)
                  in
                  let valid_against_ledger =
                    let new_mask =
                      Ledger.Mask.create ~depth:(Ledger.depth ledger) ()
                    in
                    let l = Ledger.register_mask ledger new_mask in
                    Transaction_snark.For_tests.create_trivial_zkapp_account
                      ~permissions:snapp_permissions ~vk ~ledger:l snapp_pk ;
                    l
                  in
                  let%bind zkapp_command =
                    let zkapp_prover_and_vk =
                      (zkapp_prover, Async.Deferred.return vk)
                    in
                    Transaction_snark.For_tests.update_states
                      ~zkapp_prover_and_vk ~constraint_constants test_spec
                  in
                  let valid_zkapp_command =
                    Or_error.ok_exn
                      (Zkapp_command.Valid.For_tests.to_valid ~failed:false
                         ~find_vk:(find_vk valid_against_ledger)
                         zkapp_command )
                  in
                  ignore (Ledger.unregister_mask_exn valid_against_ledger
                       ~loc:__LOC__ : Ledger.Mask.t) ;
                  (*Different key in the staged ledger*)
                  Transaction_snark.For_tests.create_trivial_zkapp_account
                    ~permissions:snapp_permissions ~vk:dummy_vk ~ledger snapp_pk ;
                  let open Async.Deferred.Let_syntax in
                  let sl = ref @@ Sl.create_exn ~constraint_constants ~ledger in
                  let global_slot =
                    Mina_numbers.Global_slot_since_genesis.of_int global_slot
                  in
                  let failed_zkapp_command =
                    Or_error.ok_exn
                      (Zkapp_command.Valid.For_tests.to_valid ~failed:true
                         ~find_vk:(find_vk ledger) zkapp_command )
                  in
                  let current_state, current_state_view =
                    dummy_state_and_view ~global_slot ()
                  in
                  let state_and_body_hash =
                    let state_hashes =
                      Mina_state.Protocol_state.hashes current_state
                    in
                    ( state_hashes.state_hash
                    , state_hashes.state_body_hash |> Option.value_exn )
                  in
                  let%bind _proof, diff =
                    create_and_apply ~global_slot ~state_and_body_hash
                      ~protocol_state_view:current_state_view ~signature_kind sl
                      (Sequence.singleton
                         (User_command.Zkapp_command failed_zkapp_command) )
                      stmt_to_work_one_prover
                  in
                  let command =
                    Staged_ledger_diff.commands diff |> List.hd_exn
                  in
                  (*Zkapp_command with incompatible vk is added with failed status*)
                  ( match command.status with
                  | Failed failure_tbl ->
                      let failures = List.concat failure_tbl in
                      assert (not (List.is_empty failures)) ;
                      let failed_as_expected =
                        List.fold failures ~init:false ~f:(fun acc f ->
                            acc
                            || Mina_base.Transaction_status.Failure.(
                                 equal Unexpected_verification_key_hash f) )
                      in
                      assert failed_as_expected
                  | Applied ->
                      failwith
                        "expected zkapp command to fail due to vk mismatch" ) ;
                  (*Update the account to have correct vk*)
                  let loc =
                    Option.value_exn
                      (Ledger.location_of_account ledger snapp_account_id)
                  in
                  let account = Option.value_exn (Ledger.get ledger loc) in
                  Ledger.set ledger loc
                    { account with
                      zkapp =
                        Some
                          { (Option.value_exn account.zkapp) with
                            verification_key = Some vk
                          }
                    } ;
                  let sl = ref @@ Sl.create_exn ~constraint_constants ~ledger in
                  let%bind _proof, diff =
                    create_and_apply sl ~global_slot ~state_and_body_hash
                      ~protocol_state_view:current_state_view ~signature_kind
                      (Sequence.singleton
                         (User_command.Zkapp_command valid_zkapp_command) )
                      stmt_to_work_one_prover
                  in
                  let commands = Staged_ledger_diff.commands diff in
                  assert (List.length commands = 1) ;
                  match List.hd_exn commands with
                  | { With_status.data = Zkapp_command _ps; status = Applied }
                    ->
                      return ()
                  | { With_status.data = Zkapp_command _ps
                    ; status = Failed tbl
                    } ->
                      failwith
                        (sprintf "Zkapp_command application failed %s"
                           ( Transaction_status.Failure.Collection.to_yojson tbl
                           |> Yojson.Safe.to_string ) )
                  | _ ->
                      failwith "expecting zkapp_command transaction" ) ) )

    let invalid_account_update_hash_would_be_rejected () =
      let signature_kind = Mina_signature_kind.Testnet in
      let open Transaction_snark.For_tests in
      Quickcheck.test ~trials:1 gen_spec_keypair_and_global_slot
        ~f:(fun ({ init_ledger; specs }, zkapp_account_keypair, global_slot) ->
          let fee = Fee.of_nanomina_int_exn 1_000_000 in
          let fee_payer = (List.hd_exn specs).sender in
          let memo = Signed_command_memo.dummy in
          let spec : Single_account_update_spec.t =
            { fee_payer
            ; fee
            ; zkapp_account_keypair
            ; memo
            ; update =
                { Account_update.Update.dummy with zkapp_uri = Set "abc" }
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
            }
          in
          Ledger.with_ledger ~depth:constraint_constants.ledger_depth
            ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let zkapp_account_pk =
                    Signature_lib.Public_key.compress
                      zkapp_account_keypair.public_key
                  in
                  let zkapp_prover_and_vk =
                    (zkapp_prover, Async.Deferred.return vk)
                  in
                  let%bind zkapp_command =
                    single_account_update ~zkapp_prover_and_vk
                      ~constraint_constants ~signature_kind spec
                  in
                  Mina_transaction_logic.For_tests.Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  Transaction_snark.For_tests.create_trivial_zkapp_account
                    ~permissions:
                      { Permissions.user_default with set_zkapp_uri = Proof }
                    ~vk ~ledger zkapp_account_pk ;
                  let invalid_zkapp_command =
                    Or_error.ok_exn
                      (Zkapp_command.Valid.For_tests.to_valid ~failed:false
                         ~find_vk:(find_vk ledger) zkapp_command )
                  in
                  let sl = ref @@ Sl.create_exn ~constraint_constants ~ledger in
                  let global_slot =
                    Mina_numbers.Global_slot_since_genesis.of_int global_slot
                  in
                  let current_state, current_state_view =
                    dummy_state_and_view ~global_slot ()
                  in
                  let state_and_body_hash =
                    let state_hashes =
                      Mina_state.Protocol_state.hashes current_state
                    in
                    ( state_hashes.state_hash
                    , state_hashes.state_body_hash |> Option.value_exn )
                  in
                  match
                    Sl.create_diff ~constraint_constants ~global_slot !sl
                      ~logger ~current_state_view
                      ~transactions_by_fee:
                        (Sequence.singleton
                           (User_command.Zkapp_command invalid_zkapp_command) )
                      ~get_completed_work:
                        (stmt_to_work_zero_fee ~prover:self_pk)
                      ~coinbase_receiver ~supercharge_coinbase:false
                      ~zkapp_cmd_limit:None
                  with
                  | Error e ->
                      Error.raise (Pre_diff_info.Error.to_error e)
                  | Ok (diff, _invalid_txns) -> (
                      assert (
                        List.length
                          (Staged_ledger_diff.With_valid_signatures_and_proofs
                           .commands diff )
                        = 1 ) ;

                      let%bind verifier_full =
                        Verifier.For_tests.default ~constraint_constants ~logger
                          ~proof_level:Full ()
                      in
                      match%map
                        Sl.apply ~constraint_constants ~global_slot !sl
                          (Staged_ledger_diff.forget diff)
                          ~get_completed_work:(Fn.const None) ~logger
                          ~verifier:verifier_full ~current_state_view
                          ~state_and_body_hash ~coinbase_receiver
                          ~supercharge_coinbase:false ~zkapp_cmd_limit_hardcap
                          ~signature_kind
                      with
                      | Ok _ ->
                          failwith "invalid block should be rejected"
                      | Error e ->
                          if
                            String.is_substring
                              (Staged_ledger_error.to_string e)
                              ~substring:"batch verification failed"
                          then ()
                          else
                            failwith
                              "block should be rejected because batch \
                               verification failed" ) ) ) )

(* Test suite registration *)
let tests =
  [ ( "staged ledger tests"
    , [
    Alcotest.test_case "Max throughput-ledger proof count-fixed blocks" `Quick max_throughput_ledger_proof_count_fixed_blocks ;
    Alcotest.test_case "Max throughput" `Quick max_throughput ;
    Alcotest.test_case "Max_throughput (zkapps)" `Quick max_throughput_zkapps ;
    Alcotest.test_case "Max_throughput with zkApp transactions that may fail" `Quick max_throughput_with_zkapp_transactions_that_may_fail ;
    Alcotest.test_case "Max throughput-ledger proof count-fixed blocks (zkApps)" `Quick max_throughput_ledger_proof_count_fixed_blocks_zkapps ;
    Alcotest.test_case "Random number of commands (zkapp + signed command)" `Quick random_number_of_commands_zkapp_signed_command ;
    Alcotest.test_case "Be able to include random number of commands" `Quick be_able_to_include_random_number_of_commands ;
    Alcotest.test_case "Be able to include random number of commands (zkapps)" `Quick be_able_to_include_random_number_of_commands_zkapps ;
    Alcotest.test_case "Be able to include random number of commands (One prover)" `Quick be_able_to_include_random_number_of_commands_one_prover ;
    Alcotest.test_case "Be able to include random number of commands (One prover," `Quick be_able_to_include_random_number_of_commands_one_prover_zkapps ;
    Alcotest.test_case "Zero proof-fee should not create a fee transfer" `Quick zero_proof_fee_should_not_create_a_fee_transfer ;
    Alcotest.test_case "Invalid diff test: check zero fee excess for partitions" `Quick invalid_diff_test_check_zero_fee_excess_for_partitions ;
    Alcotest.test_case "Provers can't pay the account creation fee" `Quick provers_can_t_pay_the_account_creation_fee ;
    Alcotest.test_case "max throughput-random number of proofs-worst case provers" `Quick max_throughput_random_number_of_proofs_worst_case_provers ;
    Alcotest.test_case "random no of transactions-random number of proofs-worst" `Quick random_no_of_transactions_random_number_of_proofs_worst_case_provers ;
    Alcotest.test_case "Random number of commands-random number of proofs-one" `Quick random_number_of_commands_random_number_of_proofs_one_prover ;
    Alcotest.test_case "max throughput-random-random fee-number of proofs-worst" `Quick max_throughput_random_random_fee_number_of_proofs_worst_case_provers ;
    Alcotest.test_case "Max throughput-random fee" `Quick max_throughput_random_fee ;
    Alcotest.test_case "Validate pending coinbase for random number of" `Quick validate_pending_coinbase_for_random_number_of_commands_random_number_of_proofs_one_prover ;
    Alcotest.test_case "Validate pending coinbase for random number of" `Quick validate_pending_coinbase_for_random_number_of_commands_random_number_of_proofs_many_provers ;
    Alcotest.test_case "Supercharged coinbase - staking" `Quick supercharged_coinbase_staking ;
    Alcotest.test_case "Supercharged coinbase - unlocked account delegating to" `Quick supercharged_coinbase_unlocked_account_delegating_to_locked_account ;
    Alcotest.test_case "Supercharged coinbase - locked account delegating to" `Quick supercharged_coinbase_locked_account_delegating_to_unlocked_account ;
    Alcotest.test_case "Supercharged coinbase - locked account delegating to locked" `Quick supercharged_coinbase_locked_account_delegating_to_locked_account ;
    Alcotest.test_case "Commands with Insufficient funds are not included" `Quick commands_with_insufficient_funds_are_not_included ;
    Alcotest.test_case "Blocks having commands with insufficient funds are rejected" `Quick blocks_having_commands_with_insufficient_funds_are_rejected ;
    Alcotest.test_case "When creating diff, invalid commands would be skipped" `Quick when_creating_diff_invalid_commands_would_be_skipped ;
    Alcotest.test_case "Setting verification keys across differing accounts" `Quick setting_verification_keys_across_differing_accounts ;
    Alcotest.test_case "Verification keys set in failed commands should not be" `Quick verification_keys_set_in_failed_commands_should_not_be_usable_later ;
    Alcotest.test_case "Mismatched verification keys in zkApp accounts and" `Quick mismatched_verification_keys_in_zkapp_accounts_and_transactions ;
    Alcotest.test_case "Invalid account_update_hash would be rejected" `Quick invalid_account_update_hash_would_be_rejected
      ] )
  ]

let () = Alcotest.run "Staged Ledger" tests
