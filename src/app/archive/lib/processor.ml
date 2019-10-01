open Core
open Async
open Pipe_lib
open Coda_transition
open Coda_state
open Coda_base
open Signature_lib

module Make (Config : Graphql_client_lib.Config_intf) = struct
  type t = {port: int}

  module Client = Graphql_client_lib.Make (Config)

  let added_transactions {port} added =
    let open Deferred.Or_error.Let_syntax in
    let user_commands_with_times = Map.to_alist added in
    let user_commands_with_hashes_and_times =
      List.map user_commands_with_times ~f:(fun (user_command, times) ->
          ( With_hash.of_data user_command
              ~hash_data:Transaction_hash.hash_user_command
          , times ) )
    in
    let user_command_hashes =
      List.map user_commands_with_hashes_and_times
        ~f:(fun ({With_hash.hash; _}, _) -> hash)
    in
    let%bind queried_existing_user_commands =
      let open Deferred.Or_error.Let_syntax in
      let graphql =
        Graphql_query.User_commands.Query_first_seen.make
          ~hashes:
            ( List.map user_command_hashes ~f:Transaction_hash.to_base58_check
            |> Array.of_list )
          ()
      in
      let%map obj = Client.query_or_error graphql port in
      let list =
        Array.map obj#user_commands ~f:(fun obj -> (obj#hash, obj#first_seen))
        |> Array.to_list
      in
      Transaction_hash.Map.of_alist_exn list
    in
    let user_commands =
      List.map user_commands_with_hashes_and_times
        ~f:(fun ((With_hash.{data= _; hash} as user_command_with_hash), time)
           ->
          let current_first_time_opt =
            Option.join (Map.find queried_existing_user_commands hash)
          in
          Types.User_command.encode user_command_with_hash
          @@ Some
               (Option.value_map ~default:time current_first_time_opt
                  ~f:(fun current_time -> Block_time.min current_time time)) )
    in
    let graphql =
      Graphql_query.User_commands.Insert.make
        ~user_commands:(Array.of_list user_commands)
        ()
    in
    let%map _result = Client.query_or_error graphql port in
    ()

  let added_transition {port}
      ({With_hash.data= block; _} as block_with_hash :
        (External_transition.t, State_hash.t) With_hash.t)
      (_sender_receipt_chains_from_parent_ledger :
        Receipt.Chain_hash.t Public_key.Compressed.Map.t) =
    let open Deferred.Or_error.Let_syntax in
    let transactions =
      List.bind (External_transition.transactions block) ~f:(function
        | User_command checked_user_command ->
            [`User_command (User_command.forget_check checked_user_command)]
        | Fee_transfer fee_transfer -> (
          match fee_transfer with
          | One fee_transfer ->
              [`Fee_transfer fee_transfer]
          | Two (fee_transfer1, fee_transfer2) ->
              [`Fee_transfer fee_transfer1; `Fee_transfer fee_transfer2] )
        | Coinbase _ ->
            [] )
    in
    let user_commands, _fee_transfers =
      List.fold transactions ~init:([], [])
        ~f:(fun (acc_user_commands, acc_fee_transfers) -> function
        | `User_command user_command ->
            ( With_hash.of_data user_command
                ~hash_data:Transaction_hash.hash_user_command
              :: acc_user_commands
            , acc_fee_transfers )
        | `Fee_transfer fee_transfer ->
            ( acc_user_commands
            , With_hash.of_data fee_transfer
                ~hash_data:Transaction_hash.hash_fee_transfer
              :: acc_fee_transfers ) )
    in
    let%map first_seen_user_commands =
      let user_command_hashes =
        List.map user_commands
          ~f:(Fn.compose Transaction_hash.to_base58_check With_hash.hash)
      in
      let graphql =
        Graphql_query.User_commands.Query_first_seen.make
          ~hashes:(Array.of_list user_command_hashes)
          ()
      in
      let%map first_query_response =
        let%map result = Client.query_or_error graphql port in
        Array.to_list result#user_commands
        |> List.map ~f:(fun obj -> (obj#hash, obj#first_seen))
      in
      Transaction_hash.Map.of_alist_exn first_query_response
    in
    let block_time =
      Blockchain_state.timestamp @@ External_transition.blockchain_state block
    in
    let user_commands_with_time =
      List.map user_commands
        ~f:(fun ({With_hash.hash; _} as user_command_with_hash) ->
          let first_seen_in_db =
            Option.join @@ Map.find first_seen_user_commands hash
          in
          ( user_command_with_hash
          , Option.value_map first_seen_in_db ~default:(Some block_time)
              ~f:Option.some ) )
    in
    let encoded_block =
      Types.Blocks.serialize block_with_hash user_commands_with_time
    in
    (* Array.of_list [encoded_block] *)
    Graphql_query.Blocks.Insert.make ~blocks:(Array.of_list [encoded_block])

  let create port = {port}

  let run t reader =
    Strict_pipe.Reader.iter reader ~f:(function
      | Diff.Transition_frontier _ ->
          (* TODO: Implement *)
          Deferred.return ()
      | Transaction_pool {added; removed= _} ->
          Deferred.Or_error.ok_exn (added_transactions t added) )
end

let%test_module "Processor" =
  ( module struct
    module Processor = Make (struct
      let address = "v1/graphql"

      let headers = String.Map.of_alist_exn [("X-Hasura-Role", "user")]

      let preprocess_variables_string =
        String.substr_replace_all ~pattern:{|"constraint_"|}
          ~with_:{|"constraint"|}
    end)

    let t = {Processor.port= 9000}

    let try_with ~f =
      Deferred.Or_error.ok_exn
      @@ let%bind result =
           Monitor.try_with_or_error ~name:"Write Processor" f
         in
         let%map clear_action =
           Processor.Client.query_or_error
             (Graphql_query.Clear_data.make ())
             t.port
         in
         Or_error.all_unit
           [ result
           ; Result.map_error clear_action ~f:(fun error ->
                 Error.createf
                   !"Issue clearing data in database: %{sexp:Error.t}"
                   error )
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
                  (Graphql_query.Public_key.Query.make ())
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
  end )
