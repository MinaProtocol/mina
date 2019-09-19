open Core
open Async
open Pipe_lib
open Coda_base
open Signature_lib

let receiver user_command =
  Public_key.Compressed.to_base58_check
  @@
  match (User_command.payload user_command).body with
  | Payment payment ->
      payment.receiver
  | Stake_delegation (Set_delegate delegation) ->
      delegation.new_delegate

let run reader graphql_port =
  let query graphql = Graphql_client_lib.query graphql graphql_port in
  Strict_pipe.Reader.iter reader ~f:(function
    | Diff.Transition_frontier _ ->
        (* TODO: Implement *)
        Deferred.unit
    | Transaction_pool {added; removed= _} ->
        let participants =
          Map.fold added ~init:Public_key.Compressed.Set.empty
            ~f:(fun ~key:user_command ~data:_ acc_participants ->
              let extra_participants =
                User_command.accounts_accessed user_command
              in
              Set.union acc_participants
                (Public_key.Compressed.Set.of_list extra_participants) )
          |> Set.to_array
        in
        let existing_public_keys =
          query
            (Graphql_commands.Public_keys_get_existing.make
               ~public_keys:participants ())
        in
        let new_user_commands =
          (* TODO: do not include user_commands that are already in the database  *)
          Map.to_alist added
          |> List.map ~f:(fun (user_command, block_time) ->
                 Types.User_command.encode user_command block_time )
          |> Array.of_list
        in
        (* Graphql_commands.Public_keys_get_existing.make  *)
        let graphql =
          Graphql_commands.Transaction_pool_insert.make
            ~user_commands:new_user_commands ()
        in
        let%bind _ = Graphql_client_lib.query graphql graphql_port in
        Deferred.unit )
