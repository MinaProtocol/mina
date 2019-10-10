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

    let t = {Processor.port= 9000}

    let try_with ~f =
      Deferred.Or_error.ok_exn
      @@ let%bind result =
           Monitor.try_with_or_error ~name:"Write Processor" f
         in
         let%map clear_action =
           Processor.Client.query_or_error
             (Graphql_query.Clear_data.T.make ())
             t.port
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

    let%test_unit "Process multiple user commands from Transaction_pool diff \
                   (including a duplicate)" =
      Backtrace.elide := false ;
      let n_keys = 2 in
      let keys = Array.init n_keys ~f:(fun _ -> Keypair.create ()) in
      let user_command_gen =
        User_command.Gen.payment_with_random_participants ~keys
          ~max_amount:10000 ~max_fee:1000 ()
      in
      let gen_user_command_with_time =
        Quickcheck.Generator.both user_command_gen Block_time.gen
      in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      try_with ~f:(fun () ->
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
              let reader, writer =
                Strict_pipe.create ~name:"archive"
                  (Buffered (`Capacity 10, `Overflow Crash))
              in
              let min_block_time = Block_time.min block_time0 block_time1 in
              let max_block_time = Block_time.max block_time0 block_time1 in
              let processing_deferred_job = Processor.run t reader in
              Strict_pipe.Writer.write writer
                (Transaction_pool
                   { Diff.Transaction_pool.added=
                       User_command.Map.of_alist_exn
                         [ (user_command1, min_block_time)
                         ; (user_command2, block_time2) ]
                   ; removed= User_command.Set.empty }) ;
              Strict_pipe.Writer.write writer
                (Transaction_pool
                   { Diff.Transaction_pool.added=
                       User_command.Map.of_alist_exn
                         [(user_command1, max_block_time)]
                   ; removed= User_command.Set.empty }) ;
              Strict_pipe.Writer.close writer ;
              let%bind () = processing_deferred_job in
              let%bind public_keys =
                Processor.Client.query
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
              let query_user_command user_command =
                let%map query_result =
                  Processor.Client.query
                    (Graphql_query.User_commands.Query.make
                       ~hash:
                         Transaction_hash.(
                           to_base58_check @@ hash_user_command user_command)
                       ())
                    t.port
                in
                let queried_user_command = query_result#user_commands.(0) in
                Types.User_command.decode queried_user_command
              in
              let%bind decoded_user_command1 =
                query_user_command user_command1
              in
              assert_user_command
                (user_command1, Some min_block_time)
                decoded_user_command1 ;
              let%map decoded_user_command2 =
                query_user_command user_command2
              in
              assert_user_command
                (user_command2, Some block_time2)
                decoded_user_command2 ) )

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
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
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
      try_with ~f:(fun () ->
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
  end )
