open Core
open Async
open Pipe_lib
open Coda_base
open Signature_lib

module Make (Config : Graphql_client_lib.Config_intf) = struct
  type t = {port: int}

  module Client = Graphql_client_lib.Make (Config)

  let added_transactions {port} added =
    let open Deferred.Or_error.Let_syntax in
    let user_commands_with_times = Map.to_alist added in
    let user_commands =
      List.map user_commands_with_times ~f:(fun (user_command, time) ->
          Types.User_command.encode
            (With_hash.of_data user_command
               ~hash_data:Transaction_hash.hash_user_command)
            (Some time) )
    in
    let graphql =
      Graphql_query.User_commands.Insert.make
        ~user_commands:(Array.of_list user_commands)
        ()
    in
    let%map _result = Client.query_or_error graphql port in
    ()

  let create port = {port}

  let run t reader =
    Strict_pipe.Reader.iter reader ~f:(function
      | Diff.Transition_frontier _ ->
          (* TODO: Implement *)
          Deferred.return ()
      | Transaction_pool {added; removed= _} ->
          Deferred.Or_error.ok_exn (added_transactions t added)
          |> Deferred.ignore )
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
        (user_command :
          (User_command_payload.t, Public_key.t, _) User_command.Poly.t)
        (decoded_user_command :
          ( User_command_payload.t
          , Public_key.Compressed.t
          , _ )
          User_command.Poly.t) =
      [%test_result: User_command_payload.t] ~equal:User_command_payload.equal
        ~expect:user_command.payload decoded_user_command.payload ;
      [%test_result: Public_key.Compressed.t]
        ~equal:Public_key.Compressed.equal
        ~expect:(Public_key.compress user_command.sender)
        decoded_user_command.sender

    let%test_unit "Process a single user command i the Transaction_pool diff" =
      Backtrace.elide := false ;
      let keys = Array.init 2 ~f:(fun _ -> Keypair.create ()) in
      let user_command_gen =
        User_command.Gen.payment_with_random_participants ~keys
          ~max_amount:10000 ~max_fee:1000 ()
      in
      let quickcheck =
        Quickcheck.Generator.both user_command_gen Block_time.gen
      in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      try_with ~f:(fun () ->
          Async.Quickcheck.async_test quickcheck ~trials:1
            ~f:(fun (user_command, block_time) ->
              let reader, writer =
                Strict_pipe.create ~name:"archive"
                  (Buffered (`Capacity 10, `Overflow Crash))
              in
              let deferred = Processor.run t reader in
              Strict_pipe.Writer.write writer
                (Transaction_pool
                   { Diff.Transaction_pool.added=
                       User_command.Map.of_alist_exn
                         [(user_command, block_time)]
                   ; removed= User_command.Set.empty }) ;
              Strict_pipe.Writer.close writer ;
              let%bind () = deferred in
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
              let decoded_user_command =
                Types.User_command.decode queried_user_command
              in
              assert_user_command user_command decoded_user_command ) )
  end )
