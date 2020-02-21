open Core
open Async
open Pipe_lib
open Coda_base
open Signature_lib

let%test_module "Processor" =
  ( module struct
    let () =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    module Processor = Processor.Make (struct
      let headers = String.Map.of_alist_exn []

      let preprocess_variables_string =
        String.substr_replace_all ~pattern:{|"constraint_"|}
          ~with_:{|"constraint"|}
    end)

    let logger = Logger.null ()

    let uri =
      Uri.of_string ("http://localhost:" ^ string_of_int 9000 ^/ "v1/graphql")

    let try_with ~f =
      Deferred.Or_error.ok_exn
      @@ let%bind result =
           let t = Processor.create uri in
           Monitor.try_with_or_error ~name:"Write Processor" (fun () -> f t)
         in
         let%map clear_action =
           Processor.Client.query (Graphql_query.Clear_data.make ()) uri
         in
         Or_error.all_unit
           [ result
           ; Result.map_error clear_action ~f:(fun error ->
                 Error.createf
                   !"Issue clearing data in database: %{sexp:Error.t}"
                 @@ Graphql_lib.Client.Connection_error.to_error error )
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

    let validated_merge =
      Map.merge_skewed ~combine:(fun ~key:_ index1 index2 ->
          assert_same_index_reference index1 index2 )

    let query_participants (t : Processor.t) hashes =
      let%map response =
        Processor.Client.query_exn
          (Graphql_query.User_commands.Query_participants.make
             ~hashes:(Array.of_list hashes) ())
          t.hasura_endpoint
        >>| fun obj -> obj#user_commands
      in
      Array.map response ~f:(fun obj ->
          let entry public_key = (public_key#value, public_key#id) in
          let participants = [entry obj#receiver; entry obj#sender] in
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
        (Diff.Builder.user_commands user_commands) ;
      Strict_pipe.Writer.close writer ;
      processing_deferred_job

    let serialized_hash =
      Transaction_hash.(Fn.compose to_base58_check hash_user_command)

    let n_keys = 2

    let keys = Array.init n_keys ~f:(fun _ -> Keypair.create ())

    let user_command_gen =
      User_command.Gen.payment_with_random_participants ~keys ~max_amount:10000
        ~max_fee:1000 ()

    (* HACK: We are going to parse a json number. There are cases that the
       number can be greater than Int32.max, which would lead to an overflow
       error. Bounding the generated numbers between 0 and Int32.max would
       prevent this issue *)
    let gen_user_command_with_time =
      Quickcheck.Generator.both user_command_gen
        (Block_time.gen_incl
           (Block_time.of_int64 Int64.zero)
           (Block_time.of_int64 (Int64.of_int32 Int32.max_value)))

    let%test_unit "Process multiple user commands from Transaction_pool diff \
                   (including a duplicate)" =
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
                  [ (user_command1, min_block_time)
                  ; (user_command2, block_time2) ]
              in
              let%bind () =
                write_transaction_pool_diff t [(user_command1, max_block_time)]
              in
              let%bind public_keys =
                Processor.Client.query_exn
                  (Graphql_query.Public_keys.Query.make ())
                  t.hasura_endpoint
              in
              let queried_public_keys =
                Array.map public_keys#public_keys ~f:(fun obj -> obj#value)
              in
              [%test_result: Int.t] ~equal:Int.equal ~expect:n_keys
                (Array.length queried_public_keys) ;
              let queried_accounts =
                Account_id.Set.of_array
                @@ Array.map queried_public_keys ~f:(fun pk ->
                       Account_id.create pk Token_id.default )
              in
              let accessed_accounts =
                Account_id.Set.of_list
                @@ List.concat
                     [ User_command.accounts_accessed user_command1
                     ; User_command.accounts_accessed user_command2 ]
              in
              [%test_result: Account_id.Set.t] ~equal:Account_id.Set.equal
                ~expect:accessed_accounts queried_accounts ;
              let query_user_command hash =
                let%map query_result =
                  Processor.Client.query_exn
                    (Graphql_query.User_commands.Query.make ~hash ())
                    t.hasura_endpoint
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
                  [(user_command1, block_time1); (user_command2, block_time2)]
              in
              let%bind participants_map1 =
                query_participants t [hash1; hash2]
              in
              let%bind () =
                write_transaction_pool_diff t [(user_command1, block_time2)]
              in
              let%bind participants_map2 = query_participants t [hash1] in
              let (_ : int Public_key.Compressed.Map.t) =
                validated_merge participants_map1 participants_map2
              in
              Deferred.unit ) )

    (* TODO: make other tests that queries components of a block by testing
       other queries, such prove_receipt_chain and block pagination *)
    let%test_unit "Write a external transition diff successfully" =
      Quickcheck.test ~trials:2
        (Transition_frontier.For_tests.gen ~logger ~max_length:4 ~size:1 ())
        ~f:(fun frontier ->
          let root_breadcrumb = Transition_frontier.root frontier in
          let successors =
            Transition_frontier.successors_rec frontier root_breadcrumb
          in
          Thread_safe.block_on_async_exn (fun () ->
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
                          (Diff.Builder.breadcrumb_added breadcrumb) )
                      (root_breadcrumb :: successors)
                  in
                  List.iter diffs ~f:(Strict_pipe.Writer.write writer) ;
                  Strict_pipe.Writer.close writer ;
                  processing_deferred_job ) ) )

    let create_expected_num_confirmations_map frontier =
      let rec go breadcrumb : int * int State_hash.Map.t =
        let successors = Transition_frontier.successors frontier breadcrumb in
        let successors_block_confirmations, block_confirmation_maps =
          List.map successors ~f:go |> List.unzip
        in
        let max_successor_block_confirmation =
          List.max_elt successors_block_confirmations ~compare:Int.compare
          |> Option.value ~default:(-1)
        in
        let successors_block_confirmations =
          List.fold block_confirmation_maps ~init:State_hash.Map.empty
            ~f:
              (Map.merge_skewed ~combine:(fun ~key:_ ->
                   failwith
                     "Create_expected_num_confirmations_map: forks of \
                      breadcrumbs should have disjoint state_hashes" ))
        in
        let block_confirmation = max_successor_block_confirmation + 1 in
        ( block_confirmation
        , Map.set successors_block_confirmations
            ~key:(Transition_frontier.Breadcrumb.state_hash breadcrumb)
            ~data:block_confirmation )
      in
      snd @@ go (Transition_frontier.root frontier)

    let%test_unit "Can get the block confirmations for all the blocks" =
      Quickcheck.test ~trials:2
        (Transition_frontier.For_tests.gen ~logger ~max_length:4 ~size:3 ())
        ~f:(fun frontier ->
          let expected_num_confirmations =
            create_expected_num_confirmations_map frontier
          in
          let root_breadcrumb = Transition_frontier.root frontier in
          let successors =
            Transition_frontier.successors_rec frontier root_breadcrumb
          in
          Async.Thread_safe.block_on_async_exn
          @@ fun () ->
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
                      (Diff.Builder.breadcrumb_added breadcrumb) )
                  (root_breadcrumb :: successors)
              in
              List.iter diffs ~f:(Strict_pipe.Writer.write writer) ;
              Strict_pipe.Writer.close writer ;
              let%bind () = processing_deferred_job in
              let graphql =
                Graphql_query.Blocks.Get_all_pending_blocks.make ()
              in
              let%map response =
                Processor.Client.query_exn graphql t.hasura_endpoint
                >>| (fun obj -> obj#blocks)
                >>| Array.map ~f:(fun block ->
                        ((block#state_hash)#value, block#status) )
                >>| Array.to_list >>| State_hash.Map.of_alist_exn
              in
              [%test_eq: int State_hash.Map.t]
                ~equal:(State_hash.Map.equal Int.equal)
                ~message:"Block confirmations are not equal"
                expected_num_confirmations response ) )
  end )
