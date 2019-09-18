open Core
open Async
open Pipe_lib

let run reader graphql_port =
  Strict_pipe.Reader.iter reader ~f:(function
    | Diff.Transition_frontier _ ->
        (* TODO: Implement *)
        Deferred.unit
    | Transaction_pool {added; removed= _} ->
        let new_user_commands =
          (* TODO: do not include user_commands that are already in the database  *)
          Map.to_alist added
          |> List.map ~f:(fun (user_command, block_time) ->
                 Types.User_command.encode user_command block_time )
          |> Array.of_list
        in
        let graphql =
          Graphql_commands.Transaction_pool_insert.make
            ~user_commands:new_user_commands ()
        in
        let%bind _ = Graphql_client_lib.query graphql graphql_port in
        Deferred.unit )
