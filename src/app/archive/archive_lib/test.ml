open Async
open Core
open Coda_base
open Pipe_lib
open Signature_lib

let%test_module "Archive node unit tests" =
  ( module struct
    let logger = Logger.create ()

    let proof_level = Genesis_constants.Proof_level.None

    let precomputed_values =
      {(Lazy.force Precomputed_values.for_unit_tests) with proof_level}

    module Genesis_ledger = (val Genesis_ledger.for_unit_tests)

    let conn_lazy =
      lazy
        ( Thread_safe.block_on_async_exn
        @@ fun () ->
        match%map
          Caqti_async.connect
            (Uri.of_string "postgres://admin:codarules@localhost:5432/archiver")
        with
        | Ok conn ->
            conn
        | Error e ->
            failwith @@ Caqti_error.show e )

    let keys = Array.init 5 ~f:(fun _ -> Keypair.create ())

    let user_command_gen =
      User_command.Gen.payment_with_random_participants ~keys ~max_amount:1000
        ~max_fee:10 ()

    let fee_transfer_gen =
      Fee_transfer.Single.Gen.with_random_receivers ~keys ~max_fee:10
        ~token:(Quickcheck.Generator.return Token_id.default)

    let coinbase_gen =
      Coinbase.Gen.with_random_receivers ~keys ~min_amount:20 ~max_amount:100
        ~fee_transfer:
          (Coinbase.Fee_transfer.Gen.with_random_receivers ~keys
             ~max_fee:(Currency.Fee.of_int 10))

    let%test_unit "User_command: read and write" =
      let conn = Lazy.force conn_lazy in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      Async.Quickcheck.async_test ~sexp_of:[%sexp_of: User_command.t]
        user_command_gen ~f:(fun user_command ->
          let transaction_hash =
            Transaction_hash.hash_user_command user_command
          in
          match%map
            let open Deferred.Result.Let_syntax in
            let%bind user_command_id =
              Processor.User_command.add_if_doesn't_exist conn user_command
            in
            let%map result =
              Processor.User_command.find conn ~transaction_hash
            in
            [%test_result: int] ~expect:user_command_id
              (Option.value_exn result)
          with
          | Ok () ->
              ()
          | Error e ->
              failwith @@ Caqti_error.show e )

    let%test_unit "Fee_transfer: read and write" =
      let conn = Lazy.force conn_lazy in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      Async.Quickcheck.async_test ~sexp_of:[%sexp_of: Fee_transfer.Single.t]
        fee_transfer_gen ~f:(fun fee_transfer ->
          let transaction_hash =
            Transaction_hash.hash_fee_transfer fee_transfer
          in
          match%map
            let open Deferred.Result.Let_syntax in
            let%bind fee_transfer_id =
              Processor.Fee_transfer.add_if_doesn't_exist conn fee_transfer
            in
            let%map result =
              Processor.Internal_command.find conn ~transaction_hash
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
              Processor.Internal_command.find conn ~transaction_hash
            in
            [%test_result: int] ~expect:coinbase_id (Option.value_exn result)
          with
          | Ok () ->
              ()
          | Error e ->
              failwith @@ Caqti_error.show e )

    let%test_unit "Block: read and write" =
      let conn = Lazy.force conn_lazy in
      Quickcheck.test ~trials:20
        ( Quickcheck.Generator.with_size ~size:10
        @@ Quickcheck_lib.gen_imperative_list
             (Transition_frontier.For_tests.gen_genesis_breadcrumb
                ~precomputed_values ())
             (Transition_frontier.Breadcrumb.For_tests.gen_non_deferred
                ?logger:None ~precomputed_values ?verifier:None
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
          let processor_deferred_computation =
            Processor.run
              ~constraint_constants:precomputed_values.constraint_constants
              conn reader ~logger ~delete_older_than:None
          in
          let diffs =
            List.map
              ~f:(fun breadcrumb ->
                Diff.Transition_frontier
                  (Diff.Builder.breadcrumb_added breadcrumb) )
              breadcrumbs
          in
          List.iter diffs ~f:(Strict_pipe.Writer.write writer) ;
          Strict_pipe.Writer.close writer ;
          let%bind () = processor_deferred_computation in
          match%map
            Processor.deferred_result_list_fold breadcrumbs ~init:()
              ~f:(fun () breadcrumb ->
                let open Deferred.Result.Let_syntax in
                match%bind
                  Processor.Block.find conn
                    ~state_hash:
                      (Transition_frontier.Breadcrumb.state_hash breadcrumb)
                with
                | Some id ->
                    let%bind Processor.Block.{parent_id; _} =
                      Processor.Block.load conn ~id
                    in
                    if
                      Transition_frontier.Breadcrumb.blockchain_length
                        breadcrumb
                      > Unsigned.UInt32.of_int 1
                    then
                      Processor.For_test.assert_parent_exist ~parent_id
                        ~parent_hash:
                          (Transition_frontier.Breadcrumb.parent_hash
                             breadcrumb)
                        conn
                    else Deferred.Result.return ()
                | None ->
                    failwith "Failed to find saved block in database" )
          with
          | Ok () ->
              ()
          | Error e ->
              failwith @@ Caqti_error.show e )

    let%test_unit "Block: read and write with pruning" =
      let conn = Lazy.force conn_lazy in
      Quickcheck.test ~trials:20
        ( Quickcheck.Generator.with_size ~size:10
        @@ Quickcheck_lib.gen_imperative_list
             (Transition_frontier.For_tests.gen_genesis_breadcrumb
                ~precomputed_values ())
             (Transition_frontier.Breadcrumb.For_tests.gen_non_deferred
                ?logger:None ~precomputed_values ?verifier:None
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
          let delete_older_than = 1L in
          let processor_deferred_computation =
            Processor.run
              ~constraint_constants:precomputed_values.constraint_constants
              conn reader ~logger
              ~delete_older_than:(Some (Int64.to_int_exn delete_older_than))
          in
          let diffs =
            List.map
              ~f:(fun breadcrumb ->
                Diff.Transition_frontier
                  (Diff.Builder.breadcrumb_added breadcrumb) )
              breadcrumbs
          in
          let max_timestamp =
            List.fold ~init:Int64.min_value breadcrumbs
              ~f:(fun prev_max breadcrumb ->
                breadcrumb |> Transition_frontier.Breadcrumb.protocol_state
                |> Coda_state.Protocol_state.blockchain_state
                |> Coda_state.Blockchain_state.timestamp |> Block_time.to_int64
                |> Int64.max prev_max )
          in
          List.iter diffs ~f:(Strict_pipe.Writer.write writer) ;
          Strict_pipe.Writer.close writer ;
          let%bind () = processor_deferred_computation in
          match%map
            Processor.deferred_result_list_fold breadcrumbs ~init:()
              ~f:(fun () breadcrumb ->
                let open Deferred.Result.Let_syntax in
                let timestamp =
                  breadcrumb |> Transition_frontier.Breadcrumb.protocol_state
                  |> Coda_state.Protocol_state.blockchain_state
                  |> Coda_state.Blockchain_state.timestamp
                  |> Block_time.to_int64
                in
                match%bind
                  Processor.Block.find conn
                    ~state_hash:
                      (Transition_frontier.Breadcrumb.state_hash breadcrumb)
                with
                | Some id ->
                    if Int64.(timestamp < max_timestamp - delete_older_than)
                    then
                      Error.raise
                        (Error.createf
                           !"The block with id %i was not pruned correctly: \
                             timestamp %{sexp: Int64.t} < max_timestamp \
                             %{sexp: Int64.t} - delete_older_than %{sexp: \
                             Int64.t}"
                           id timestamp max_timestamp delete_older_than) ;
                    let%bind Processor.Block.{parent_id; _} =
                      Processor.Block.load conn ~id
                    in
                    if
                      Transition_frontier.Breadcrumb.blockchain_length
                        breadcrumb
                      > Unsigned.UInt32.one
                    then
                      Processor.For_test.assert_parent_exist ~parent_id
                        ~parent_hash:
                          (Transition_frontier.Breadcrumb.parent_hash
                             breadcrumb)
                        conn
                    else Deferred.Result.return ()
                | None ->
                    if Int64.(timestamp >= max_timestamp - delete_older_than)
                    then
                      Error.raise
                        (Error.createf
                           !"A block was pruned incorrectly: \
                             timestamp %{sexp: Int64.t} >= max_timestamp \
                             %{sexp: Int64.t} - delete_older_than %{sexp: \
                             Int64.t}"
                           timestamp max_timestamp delete_older_than)
                    else Deferred.Result.return () )
          with
          | Ok () ->
              ()
          | Error e ->
              failwith @@ Caqti_error.show e )
  end )
