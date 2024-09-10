open Async
open Core
open Mina_base
open Mina_transaction
open Pipe_lib
open Signature_lib

let%test_module "Archive node unit tests" =
  ( module struct
    let logger = Logger.create ()

    let proof_level = Genesis_constants.Proof_level.None

    let precomputed_values =
      { (Lazy.force Precomputed_values.for_unit_tests) with proof_level }

    let constraint_constants = precomputed_values.constraint_constants

    let genesis_constants = precomputed_values.genesis_constants

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~logger ~proof_level ~constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ())
            ~commit_id:"not specified for unit tests" () )

    module Genesis_ledger = (val Genesis_ledger.for_unit_tests)

    let archive_uri =
      Uri.of_string
        (Option.value
           (Sys.getenv "MINA_TEST_POSTGRES")
           ~default:"postgres://admin:codarules@localhost:5432/archiver" )

    let conn_lazy =
      lazy
        ( Thread_safe.block_on_async_exn
        @@ fun () ->
        match%map Caqti_async.connect archive_uri with
        | Ok conn ->
            conn
        | Error e ->
            failwith @@ Caqti_error.show e )

    let conn_pool_lazy =
      lazy
        ( match Caqti_async.connect_pool archive_uri with
        | Ok pool ->
            pool
        | Error e ->
            failwith @@ Caqti_error.show e )

    let keys = Array.init 5 ~f:(fun _ -> Keypair.create ())

    let user_command_signed_gen =
      Mina_generators.User_command_generators.payment_with_random_participants
        ~keys ~max_amount:1000 ~fee_range:10 ()

    let genesis_state_view =
      let genesis_state_body =
        precomputed_values.protocol_state_with_hashes.data.body
      in
      Mina_state.Protocol_state.Body.view genesis_state_body

    let user_command_zkapp_gen :
        ('a, Zkapp_command.t) User_command.t_ Base_quickcheck.Generator.t =
      let open Base_quickcheck.Generator.Let_syntax in
      let%bind initial_balance =
        Base_quickcheck.Generator.int64_uniform_inclusive 200_000_000_000_000L
          400_000_000_000_000L
        >>| Unsigned.UInt64.of_int64 >>| Currency.Balance.of_uint64
      and fee_payer_key_index =
        Base_quickcheck.Generator.int_inclusive 0 @@ (Array.length keys - 1)
      in
      let test_keys = Array.init 10 ~f:(fun _ -> Keypair.create ()) in
      let extra_keys = Array.init 10 ~f:(fun _ -> Keypair.create ()) in
      let keys = Array.append test_keys extra_keys in
      let fee_payer_keypair = keys.(fee_payer_key_index) in
      let keymap =
        Array.map keys ~f:(fun { public_key; private_key } ->
            (Public_key.compress public_key, private_key) )
        |> Array.to_list |> Public_key.Compressed.Map.of_alist_exn
      in
      let ledger = Mina_ledger.Ledger.create ~depth:10 () in
      let public_keys =
        Array.map test_keys ~f:(fun key -> Public_key.compress key.public_key)
      in
      let account_ids =
        Array.map public_keys ~f:(fun pk ->
            Account_id.create pk Token_id.default )
      in
      let zkappify_account (account : Account.t) : Account.t =
        let verification_key =
          Some
            With_hash.
              { data = Side_loaded_verification_key.dummy
              ; hash = Zkapp_account.dummy_vk_hash ()
              }
        in
        let zkapp = Some { Zkapp_account.default with verification_key } in
        { account with zkapp }
      in
      let accounts =
        Array.mapi account_ids ~f:(fun ndx account_id ->
            let account = Account.create account_id initial_balance in
            if ndx mod 2 = 0 then (account_id, account)
            else (account_id, zkappify_account account) )
      in
      Array.map accounts ~f:(fun (account_id, account) ->
          Mina_ledger.Ledger.get_or_create_account ledger account_id account
          |> Or_error.ok_exn )
      |> fun _ ->
      let%map (zkapp_command : Zkapp_command.t) =
        Mina_generators.Zkapp_command_generators.gen_zkapp_command_from
          ~fee_payer_keypair ~keymap ~ledger
          ~protocol_state_view:genesis_state_view ~constraint_constants
          ~genesis_constants ()
      in
      User_command.Zkapp_command zkapp_command

    let fee_transfer_gen =
      Fee_transfer.Single.Gen.with_random_receivers ~min_fee:0 ~max_fee:10
        ~token:(Quickcheck.Generator.return Token_id.default)
        keys

    let coinbase_gen =
      Coinbase.Gen.with_random_receivers ~keys ~min_amount:20 ~max_amount:100
        ~fee_transfer:(fun ~coinbase_amount ->
          Coinbase.Fee_transfer.Gen.with_random_receivers ~keys
            ~min_fee:Currency.Fee.zero coinbase_amount )

    let%test_unit "User_command: read and write signed command" =
      let conn = Lazy.force conn_lazy in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      Async.Quickcheck.async_test ~sexp_of:[%sexp_of: User_command.t]
        user_command_signed_gen ~f:(fun user_command ->
          let transaction_hash = Transaction_hash.hash_command user_command in
          match%map
            let open Deferred.Result.Let_syntax in
            let%bind user_command_id =
              Processor.User_command.add_if_doesn't_exist conn
                ~v1_transaction_hash:false user_command
            in
            let%map result =
              Processor.User_command.find conn ~transaction_hash
                ~v1_transaction_hash:false
              >>| function
              | Some (`Signed_command_id signed_command_id) ->
                  Some signed_command_id
              | Some (`Zkapp_command_id _) | None ->
                  None
            in
            [%test_result: int] ~expect:user_command_id
              (Option.value_exn result)
          with
          | Ok () ->
              ()
          | Error e ->
              failwith @@ Caqti_error.show e )

    let%test_unit "User_command: read and write zkapp command" =
      let conn = Lazy.force conn_lazy in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      Async.Quickcheck.async_test ~trials:20 ~sexp_of:[%sexp_of: User_command.t]
        user_command_zkapp_gen ~f:(fun user_command ->
          let transaction_hash = Transaction_hash.hash_command user_command in
          match user_command with
          | Signed_command _ ->
              failwith "zkapp_gen failed"
          | Zkapp_command p -> (
              let rec add_token_owners
                  (forest :
                    ( Account_update.t
                    , Zkapp_command.Digest.Account_update.t
                    , Zkapp_command.Digest.Forest.t )
                    Zkapp_command.Call_forest.t ) =
                List.iter forest ~f:(fun { With_stack_hash.elt = tree; _ } ->
                    if List.is_empty tree.calls then ()
                    else
                      let acct_id =
                        Account_update.account_id tree.account_update
                      in
                      let token_id =
                        Account_id.derive_token_id ~owner:acct_id
                      in
                      Processor.Token_owners.add_if_doesn't_exist token_id
                        acct_id ;
                      add_token_owners tree.calls )
              in
              let%bind _ =
                Processor.Protocol_versions.add_if_doesn't_exist conn
                  ~transaction:Protocol_version.(transaction current)
                  ~network:Protocol_version.(network current)
                  ~patch:Protocol_version.(patch current)
              in
              add_token_owners p.account_updates ;
              match%map
                let open Deferred.Result.Let_syntax in
                let%bind user_command_id =
                  Processor.User_command.add_if_doesn't_exist conn
                    ~v1_transaction_hash:false user_command
                in
                let%map result =
                  Processor.User_command.find conn ~transaction_hash
                    ~v1_transaction_hash:false
                  >>| function
                  | Some (`Zkapp_command_id zkapp_command_id) ->
                      Some zkapp_command_id
                  | Some (`Signed_command_id _) | None ->
                      None
                in
                [%test_result: int] ~expect:user_command_id
                  (Option.value_exn result)
              with
              | Ok () ->
                  ()
              | Error e ->
                  failwith @@ Caqti_error.show e ) )

    let%test_unit "Fee_transfer: read and write" =
      let kind_gen =
        let open Quickcheck.Generator in
        let open Quickcheck.Generator.Let_syntax in
        let%map b = bool in
        if b then `Normal else `Via_coinbase
      in
      let conn = Lazy.force conn_lazy in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      Async.Quickcheck.async_test
        ~sexp_of:[%sexp_of: [ `Normal | `Via_coinbase ] * Fee_transfer.Single.t]
        (Quickcheck.Generator.tuple2 kind_gen fee_transfer_gen)
        ~f:(fun (kind, fee_transfer) ->
          let transaction_hash =
            Transaction_hash.hash_fee_transfer fee_transfer
          in
          match%map
            let open Deferred.Result.Let_syntax in
            let%bind fee_transfer_id =
              Processor.Fee_transfer.add_if_doesn't_exist conn fee_transfer kind
            in
            let%map result =
              Processor.Internal_command.find_opt conn ~transaction_hash
                ~v1_transaction_hash:false
                ~command_type:(Processor.Fee_transfer.Kind.to_string kind)
            in
            [%test_result: int] ~expect:fee_transfer_id
              (Option.value_exn result)
          with
          | Ok () ->
              ()
          | Error e ->
              failwith @@ Caqti_error.show e )

    let%test_unit "Coinbase: read and write" =
      let conn = Lazy.force conn_lazy in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      Async.Quickcheck.async_test ~sexp_of:[%sexp_of: Coinbase.t] coinbase_gen
        ~f:(fun coinbase ->
          let transaction_hash = Transaction_hash.hash_coinbase coinbase in
          match%map
            let open Deferred.Result.Let_syntax in
            let%bind coinbase_id =
              Processor.Coinbase.add_if_doesn't_exist conn coinbase
            in
            let%map result =
              Processor.Internal_command.find_opt conn ~transaction_hash
                ~v1_transaction_hash:false
                ~command_type:Processor.Coinbase.coinbase_command_type
            in
            [%test_result: int] ~expect:coinbase_id (Option.value_exn result)
          with
          | Ok () ->
              ()
          | Error e ->
              failwith @@ Caqti_error.show e )

    let%test_unit "Block: read and write" =
      let pool = Lazy.force conn_pool_lazy in
      Quickcheck.test ~trials:20
        ( Quickcheck.Generator.with_size ~size:10
        @@ Quickcheck_lib.gen_imperative_list
             (Transition_frontier.For_tests.gen_genesis_breadcrumb
                ~precomputed_values ~verifier () )
             (Transition_frontier.Breadcrumb.For_tests.gen_non_deferred
                ?logger:None ~precomputed_values ~verifier ?trust_system:None
                ~accounts_with_secret_keys:(Lazy.force Genesis_ledger.accounts)
                () ) )
        ~f:(fun breadcrumbs ->
          Thread_safe.block_on_async_exn
          @@ fun () ->
          let reader, writer =
            Strict_pipe.create ~name:"archive"
              (Buffered (`Capacity 100, `Overflow Crash))
          in
          let diffs =
            List.map
              ~f:(fun breadcrumb ->
                Diff.Transition_frontier
                  (Diff.Builder.breadcrumb_added ~precomputed_values ~logger
                     breadcrumb ) )
              breadcrumbs
          in
          List.iter diffs ~f:(Strict_pipe.Writer.write writer) ;
          Strict_pipe.Writer.close writer ;
          let%bind () =
            Processor.run
              ~genesis_constants:precomputed_values.genesis_constants
              ~constraint_constants:precomputed_values.constraint_constants pool
              reader ~logger ~delete_older_than:None
          in
          match%map
            Mina_caqti.deferred_result_list_fold breadcrumbs ~init:()
              ~f:(fun () breadcrumb ->
                Caqti_async.Pool.use
                  (fun conn ->
                    let open Deferred.Result.Let_syntax in
                    match%bind
                      Processor.Block.find_opt conn
                        ~state_hash:
                          (Transition_frontier.Breadcrumb.state_hash breadcrumb)
                    with
                    | Some id ->
                        let%bind Processor.Block.{ parent_id; _ } =
                          Processor.Block.load conn ~id
                        in
                        if
                          Unsigned.UInt32.compare
                            ( Consensus.Data.Consensus_state.blockchain_length
                            @@ Transition_frontier.Breadcrumb.consensus_state
                                 breadcrumb )
                            (Unsigned.UInt32.of_int 1)
                          > 0
                        then
                          Processor.For_test.assert_parent_exist ~parent_id
                            ~parent_hash:
                              (Transition_frontier.Breadcrumb.parent_hash
                                 breadcrumb )
                            conn
                        else Deferred.Result.return ()
                    | None ->
                        failwith "Failed to find saved block in database" )
                  pool )
          with
          | Ok () ->
              ()
          | Error e ->
              failwith @@ Caqti_error.show e )

    (*
    let%test_unit "Block: read and write with pruning" =
      let conn = Lazy.force conn_lazy in
      Quickcheck.test ~trials:20
        ( Quickcheck.Generator.with_size ~size:10
        @@ Quickcheck_lib.gen_imperative_list
             (Transition_frontier.For_tests.gen_genesis_breadcrumb
                ~precomputed_values ())
             (Transition_frontier.Breadcrumb.For_tests.gen_non_deferred
                ?logger:None ~precomputed_values ~verifier
                ?trust_system:None
                ~accounts_with_secret_keys:(Lazy.force Genesis_ledger.accounts))
        )
        ~f:(fun breadcrumbs ->
          Thread_safe.block_on_async_exn
          @@ fun () ->
          let reader, writer =
            Strict_pipe.create ~name:"archive"
              (Buffered (`Capacity 100, `Overflow Crash))
          in
          let delete_older_than = 7 in
          let processor_deferred_computation =
            Processor.run
              ~constraint_constants:precomputed_values.constraint_constants
              conn reader ~logger ~delete_older_than:(Some delete_older_than)
          in
          let diffs =
            List.map
              ~f:(fun breadcrumb ->
                Diff.Transition_frontier
                  (Diff.Builder.breadcrumb_added ~logger breadcrumb) )
              breadcrumbs
          in
          let max_height =
            List.fold ~init:Unsigned.UInt32.zero breadcrumbs
              ~f:(fun prev_max breadcrumb ->
                breadcrumb |> Transition_frontier.Breadcrumb.blockchain_length
                |> Unsigned.UInt32.max prev_max )
          in
          List.iter diffs ~f:(Strict_pipe.Writer.write writer) ;
          Strict_pipe.Writer.close writer ;
          let%bind () = processor_deferred_computation in
          match%map
            Processor.deferred_result_list_fold breadcrumbs ~init:()
              ~f:(fun () breadcrumb ->
                let open Deferred.Result.Let_syntax in
                let height =
                  breadcrumb
                  |> Transition_frontier.Breadcrumb.blockchain_length
                in
                match%bind
                  Processor.Block.find_opt conn
                    ~state_hash:
                      (Transition_frontier.Breadcrumb.state_hash breadcrumb)
                with
                | Some id ->
                    if
                      Unsigned.UInt32.(
                        height < sub max_height (of_int delete_older_than))
                    then
                      Error.raise
                        (Error.createf
                           !"The block with id %i was not pruned correctly: \
                             height %i < max_height %i - delete_older_than %i"
                           id
                           (Unsigned.UInt32.to_int height)
                           (Unsigned.UInt32.to_int max_height)
                           delete_older_than)
                    else
                      let%map.Async () =
                        Deferred.List.iter
                          (Transition_frontier.Breadcrumb.commands breadcrumb)
                          ~f:(fun cmd ->
                            match%map.Async
                              Processor.User_command.find conn
                                ~transaction_hash:
                                  (Transaction_hash.hash_command
                                     (User_command.forget_check cmd.data))
                            with
                            | Ok (Some _) ->
                                ()
                            | Ok None ->
                                Error.raise
                                  (Error.createf
                                     !"The user command %{sexp: \
                                       User_command.t} was pruned when it \
                                       should not have been"
                                     (User_command.forget_check cmd.data))
                            | Error e ->
                                failwith @@ Caqti_error.show e )
                      in
                      Ok ()
                | None ->
                    if
                      Unsigned.UInt32.(
                        height >= sub max_height (of_int delete_older_than))
                    then
                      Error.raise
                        (Error.createf
                           !"A block was pruned incorrectly: height %i >= \
                             max_height %i - delete_older_than %i "
                           (Unsigned.UInt32.to_int height)
                           (Unsigned.UInt32.to_int max_height)
                           delete_older_than)
                    else
                      let%map.Async () =
                        Deferred.List.iter
                          (Transition_frontier.Breadcrumb.commands breadcrumb)
                          ~f:(fun cmd ->
                            match%map.Async
                              Processor.User_command.find conn
                                ~transaction_hash:
                                  (Transaction_hash.hash_command
                                     (User_command.forget_check cmd.data))
                            with
                            | Ok None ->
                                ()
                            | Ok (Some _) ->
                                Error.raise
                                  (Error.createf
                                     !"The user command %{sexp: \
                                       User_command.t} was not pruned when it \
                                       should have been"
                                     (User_command.forget_check cmd.data))
                            | Error e ->
                                failwith @@ Caqti_error.show e )
                      in
                      Ok () )
          with
          | Ok () ->
              ()
          | Error e ->
              failwith @@ Caqti_error.show e )
    *)
  end )
