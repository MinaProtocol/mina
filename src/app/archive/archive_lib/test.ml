open Core
open Async
open Pipe_lib
open Coda_transition
open Coda_base
open Signature_lib

let%test_module "Processor" =
  ( module struct
    module Stubs = Transition_frontier_controller_tests.Stubs.Make (struct
      let max_length = 4
    end)

    module Processor = Processor.Make (struct
      let address = "v1/graphql"

      let headers = String.Map.of_alist_exn []

      let preprocess_variables_string =
        String.substr_replace_all ~pattern:{|"constraint_"|}
          ~with_:{|"constraint"|}
    end)

    let logger = Logger.null ()

    let port = 9000

    let try_with ~f =
      Deferred.Or_error.ok_exn
      @@ let%bind result =
           let open Deferred.Or_error.Let_syntax in
           let%bind t =
             Deferred.Result.map_error
               ~f:Graphql_client_lib.Connection_error.to_error
             @@ Processor.create port
           in
           Monitor.try_with_or_error ~name:"Write Processor" (fun () -> f t)
         in
         let%map clear_action =
           Processor.Client.query (Graphql_query.Clear_data.make ()) port
         in
         Or_error.all_unit
           [ result
           ; Result.map_error clear_action ~f:(fun error ->
                 Error.createf
                   !"Issue clearing data in database: %{sexp:Error.t}"
                 @@ Graphql_client_lib.Connection_error.to_error error )
             |> Result.ignore ]

    let assert_user_command
        ((user_command, block_time) :
          (User_command_payload.t, Public_key.t, _) User_command.Poly.t
          * Block_time.t option)
        ((decoded_user_command, decoded_block_time) :
          ( User_command_payload.t
          , Public_key.Compressed.t
          , _ )
          User_command.Poly.t
          * Block_time.t option) =
      [%test_result: User_command_payload.t] ~equal:User_command_payload.equal
        ~expect:user_command.payload decoded_user_command.payload ;
      [%test_result: Public_key.Compressed.t]
        ~equal:Public_key.Compressed.equal
        ~expect:(Public_key.compress user_command.sender)
        decoded_user_command.sender ;
      [%test_result: Block_time.t option]
        ~equal:[%equal: Block_time.t Option.t] ~expect:block_time
        decoded_block_time

    let assert_same_index_reference index1 index2 =
      [%test_result: int]
        ~message:
          "Expecting references to both public keys in Postgres to be the \
           same, but are not. Upsert may not be working correctly as expected"
        ~equal:Int.equal ~expect:index1 index2 ;
      index1

    let validated_merge (map1 : int Public_key.Compressed.Map.t)
        (map2 : int Public_key.Compressed.Map.t) =
      Map.merge map1 map2 ~f:(fun ~key:_ -> function
        | `Both (index1, index2) ->
            Some (assert_same_index_reference index1 index2)
        | `Left index | `Right index ->
            Some index )

    let query_participants (t : Processor.t) hashes =
      let%map response =
        Processor.Client.query_exn
          (Graphql_query.User_commands.Query_participants.make
             ~hashes:(Array.of_list hashes) ())
          t.port
        >>| fun obj -> obj#user_commands
      in
      Array.map response ~f:(fun obj ->
          let entry public_key = (public_key#value, public_key#id) in
          let participants =
            [entry obj#publicKeyByReceiver; entry obj#public_key]
          in
          Public_key.Compressed.Map.of_alist_reduce participants
            ~f:(fun index1 index2 -> assert_same_index_reference index1 index2
          ) )
      |> Array.reduce_exn ~f:validated_merge

    let write_transaction_pool_diff t user_commands =
      let reader, writer =
        Strict_pipe.create ~name:"archive"
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let processing_deferred_job = Processor.run t reader in
      Strict_pipe.Writer.write writer
        (Transaction_pool
           { Diff.Transaction_pool.added= user_commands
           ; removed= User_command.Set.empty }) ;
      Strict_pipe.Writer.close writer ;
      processing_deferred_job

    let serialized_hash =
      Transaction_hash.(Fn.compose to_base58_check hash_user_command)

    let n_keys = 2

    let keys = Array.init n_keys ~f:(fun _ -> Keypair.create ())

    let user_command_gen =
      User_command.Gen.payment_with_random_participants ~keys ~max_amount:10000
        ~max_fee:1000 ()

    let gen_user_command_with_time =
      Quickcheck.Generator.both user_command_gen Block_time.gen

    let%test_unit "Process multiple user commands from Transaction_pool diff \
                   (including a duplicate)" =
      Backtrace.elide := false ;
      Thread_safe.block_on_async_exn
      @@ fun () ->
      try_with ~f:(fun t ->
          Async.Quickcheck.async_test
            ~sexp_of:
              [%sexp_of:
                Block_time.t
                * (User_command.t * Block_time.t)
                * (User_command.t * Block_time.t)]
            (Quickcheck.Generator.tuple3 Block_time.gen
               gen_user_command_with_time gen_user_command_with_time) ~trials:1
            ~f:(fun ( block_time0
                    , (user_command1, block_time1)
                    , (user_command2, block_time2) )
               ->
              let min_block_time = Block_time.min block_time0 block_time1 in
              let max_block_time = Block_time.max block_time0 block_time1 in
              let hash1 = serialized_hash user_command1 in
              let hash2 = serialized_hash user_command2 in
              let%bind () =
                write_transaction_pool_diff t
                  (User_command.Map.of_alist_exn
                     [ (user_command1, min_block_time)
                     ; (user_command2, block_time2) ])
              in
              let%bind () =
                write_transaction_pool_diff t
                  (User_command.Map.of_alist_exn
                     [(user_command1, max_block_time)])
              in
              let%bind public_keys =
                Processor.Client.query_exn
                  (Graphql_query.Public_keys.Query.make ())
                  t.port
              in
              let queried_public_keys =
                Array.map public_keys#public_keys ~f:(fun obj -> obj#value)
              in
              [%test_result: Int.t] ~equal:Int.equal ~expect:n_keys
                (Array.length queried_public_keys) ;
              let queried_public_keys =
                Public_key.Compressed.Set.of_array queried_public_keys
              in
              let accessed_accounts =
                Public_key.Compressed.Set.of_list
                @@ List.concat
                     [ User_command.accounts_accessed user_command1
                     ; User_command.accounts_accessed user_command2 ]
              in
              [%test_result: Public_key.Compressed.Set.t]
                ~equal:Public_key.Compressed.Set.equal
                ~expect:accessed_accounts queried_public_keys ;
              let query_user_command hash =
                let%map query_result =
                  Processor.Client.query_exn
                    (Graphql_query.User_commands.Query.make ~hash ())
                    t.port
                in
                let queried_user_command = query_result#user_commands.(0) in
                Types.User_command.decode queried_user_command
              in
              let%bind decoded_user_command1 = query_user_command hash1 in
              assert_user_command
                (user_command1, Some min_block_time)
                decoded_user_command1 ;
              let%map decoded_user_command2 = query_user_command hash2 in
              assert_user_command
                (user_command2, Some block_time2)
                decoded_user_command2 ) )

    let%test_unit "Doing upserts with a nested object on Hasura does not \
                   update serial id references of objects within that object" =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      try_with ~f:(fun t ->
          Async.Quickcheck.async_test
            ~sexp_of:
              [%sexp_of:
                (User_command.t * Block_time.t)
                * (User_command.t * Block_time.t)]
            (Quickcheck.Generator.tuple2 gen_user_command_with_time
               gen_user_command_with_time) ~trials:1
            ~f:(fun ((user_command1, block_time1), (user_command2, block_time2))
               ->
              let hash1 = serialized_hash user_command1 in
              let hash2 = serialized_hash user_command2 in
              let%bind () =
                write_transaction_pool_diff t
                  (User_command.Map.of_alist_exn
                     [ (user_command1, block_time1)
                     ; (user_command2, block_time2) ])
              in
              let%bind participants_map1 =
                query_participants t [hash1; hash2]
              in
              let%bind () =
                write_transaction_pool_diff t
                  (User_command.Map.of_alist_exn [(user_command1, block_time2)])
              in
              let%bind participants_map2 = query_participants t [hash1] in
              let (_ : int Public_key.Compressed.Map.t) =
                validated_merge participants_map1 participants_map2
              in
              Deferred.unit ) )

    open Stubs

    let pids = Pid.Table.create ()

    let trust_system = Trust_system.null ()

    let create_added_breadcrumb_diff breadcrumb =
      let ((block, _) as validated_block) =
        Transition_frontier.Breadcrumb.validated_transition breadcrumb
      in
      let user_commands =
        External_transition.Validated.user_commands validated_block
      in
      let sender_receipt_chains_from_parent_ledger =
        let user_commands = User_command.Set.of_list user_commands in
        let senders =
          Public_key.Compressed.Set.map user_commands ~f:User_command.sender
        in
        let ledger =
          Staged_ledger.ledger
          @@ Transition_frontier.Breadcrumb.staged_ledger breadcrumb
        in
        Set.to_map senders ~f:(fun sender ->
            Option.value_exn
              (let open Option.Let_syntax in
              let%bind ledger_location =
                Ledger.location_of_key ledger sender
              in
              let%map {receipt_chain_hash; _} =
                Ledger.get ledger ledger_location
              in
              receipt_chain_hash) )
      in
      Diff.Transition_frontier.Breadcrumb_added
        {block; sender_receipt_chains_from_parent_ledger}

    (* TODO: make other tests that queries components of a block by testing other queries, such prove_receipt_chain and block pagination *)
    let%test_unit "Write a external transition diff successfully" =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier =
        Stubs.create_root_frontier ~logger ~pids Genesis_ledger.accounts
      in
      let root_breadcrumb = Transition_frontier.root frontier in
      let%bind () =
        Stubs.add_linear_breadcrumbs ~logger ~pids ~trust_system ~size:1
          ~accounts_with_secret_keys:Genesis_ledger.accounts ~frontier
          ~parent:root_breadcrumb
      in
      let successors =
        Transition_frontier.successors_rec frontier root_breadcrumb
      in
      try_with ~f:(fun t ->
          let reader, writer =
            Strict_pipe.create ~name:"archive"
              (Buffered (`Capacity 10, `Overflow Crash))
          in
          let processing_deferred_job = Processor.run t reader in
          let diffs =
            List.map
              ~f:(fun breadcrumb ->
                Diff.Transition_frontier
                  (create_added_breadcrumb_diff breadcrumb) )
              (root_breadcrumb :: successors)
          in
          List.iter diffs ~f:(Strict_pipe.Writer.write writer) ;
          Strict_pipe.Writer.close writer ;
          processing_deferred_job )

    let%test_unit "Can get the block height of all the blocks" =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier =
        Stubs.create_root_frontier ~logger ~pids Genesis_ledger.accounts
      in
      let root_breadcrumb = Transition_frontier.root frontier in
      let%bind () =
        Stubs.add_linear_breadcrumbs ~logger ~pids ~trust_system ~size:3
          ~accounts_with_secret_keys:Genesis_ledger.accounts ~frontier
          ~parent:root_breadcrumb
      in
      let expected_num_confirmations =
        Transition_frontier.(Breadcrumb.state_hash @@ root frontier)
        :: Transition_frontier.hash_path frontier
             (Transition_frontier.best_tip frontier)
        |> List.rev
        |> List.mapi ~f:(fun i state_hash -> (state_hash, i))
        |> State_hash.Map.of_alist_exn
      in
      let successors =
        Transition_frontier.successors_rec frontier root_breadcrumb
      in
      try_with ~f:(fun t ->
          let reader, writer =
            Strict_pipe.create ~name:"archive"
              (Buffered (`Capacity 10, `Overflow Crash))
          in
          let processing_deferred_job = Processor.run t reader in
          let diffs =
            List.map
              ~f:(fun breadcrumb ->
                Diff.Transition_frontier
                  (create_added_breadcrumb_diff breadcrumb) )
              (root_breadcrumb :: successors)
          in
          List.iter diffs ~f:(Strict_pipe.Writer.write writer) ;
          Strict_pipe.Writer.close writer ;
          let%bind () = processing_deferred_job in
          let graphql = Graphql_query.Blocks.Get_all_pending_blocks.make () in
          let%map response =
            Processor.Client.query_exn graphql t.port
            >>| (fun obj -> obj#blocks)
            >>| Array.map ~f:(fun block ->
                    ((block#state_hash)#value, block#status) )
            >>| Array.to_list >>| State_hash.Map.of_alist_exn
          in
          [%test_eq: int State_hash.Map.t]
            ~equal:(State_hash.Map.equal Int.equal)
            ~message:"Block confirmations are not equal"
            expected_num_confirmations response )
  end )
