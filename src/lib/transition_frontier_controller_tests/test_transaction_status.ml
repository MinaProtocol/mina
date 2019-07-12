open Core
open Coda_base
open Async
open Pipe_lib

module Stubs = Stubs.Make (struct
  let max_length = 5
end)

open Stubs

let%test_module "transaction_status" =
  ( module struct
    module Test = Transaction_status.Make (struct
      include Transition_frontier_inputs
      module Transition_frontier = Transition_frontier
      module Transaction_pool = Transaction_pool
    end)

    let logger = Logger.create ()

    let trust_system = Trust_system.null ()

    let key_gen =
      let open Quickcheck.Generator in
      let open Quickcheck.Generator.Let_syntax in
      let keypairs = List.map Genesis_ledger.accounts ~f:fst in
      let%map random_key_opt = of_list keypairs in
      ( Genesis_ledger.largest_account_keypair_exn ()
      , Signature_lib.Keypair.of_private_key_exn
          (Option.value_exn random_key_opt) )

    let create_pool ~frontier_broadcast_pipe =
      let incoming_diffs, _ = Linear_pipe.create () in
      let transaction_pool =
        Transaction_pool.create ~logger ~trust_system ~incoming_diffs
          ~frontier_broadcast_pipe
      in
      don't_wait_for
      @@ Linear_pipe.iter (Transaction_pool.broadcasts transaction_pool)
           ~f:(fun transactions ->
             Logger.trace logger
               "Transactions have been applied successfully and is propagated \
                throughout the 'network'"
               ~module_:__MODULE__ ~location:__LOC__
               ~metadata:
                 [ ( "transactions"
                   , Transaction_pool.Resource_pool.Diff.to_yojson transactions
                   ) ] ;
             Deferred.unit ) ;
      (* Need to wait for transaction_pool to see the transition_frontier *)
      let%map () = after (Time.Span.of_sec 1.0) in
      transaction_pool

    let%test_unit "A pending transaction is either in the transition frontier \
                   or transaction pool, but not in the best path of the \
                   transition frontier" =
      Async.Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier =
        create_root_frontier ~logger Genesis_ledger.accounts
      in
      let frontier_broadcast_pipe, _ = Broadcast_pipe.create (Some frontier) in
      let%bind transaction_pool = create_pool ~frontier_broadcast_pipe in
      let user_command =
        Quickcheck.random_value
          (User_command.Gen.payment ~sign_type:`Real ~max_amount:100
             ~max_fee:10 ~key_gen ())
      in
      let%map () = Transaction_pool.add transaction_pool user_command in
      Logger.info logger "Computing status" ~module_:__MODULE__
        ~location:__LOC__ ;
      [%test_eq: Transaction_status.State.t]
        ~equal:Transaction_status.State.equal Transaction_status.State.Pending
        (Test.get_status ~frontier_broadcast_pipe ~transaction_pool
           user_command)

    let%test_unit "An unknown transaction does not appear in the transition \
                   frontier or transaction pool " =
      Async.Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier =
        create_root_frontier ~logger Genesis_ledger.accounts
      in
      let frontier_broadcast_pipe, _ = Broadcast_pipe.create (Some frontier) in
      let%bind transaction_pool = create_pool ~frontier_broadcast_pipe in
      let user_commands =
        Option.value_exn
          (Quickcheck.random_value
             (let open Quickcheck.Generator in
             let open Let_syntax in
             let%map user_commands =
               Quickcheck.Generator.list_with_length 10
                 (User_command.Gen.payment ~sign_type:`Real ~max_amount:100
                    ~max_fee:10 ~key_gen ())
             in
             User_command.Set.of_list user_commands
             |> Set.to_list |> Non_empty_list.of_list_opt))
      in
      let unknown_user_command, pool_user_commands =
        Non_empty_list.uncons user_commands
      in
      let%map () =
        Deferred.List.iter pool_user_commands ~f:(fun user_command ->
            Transaction_pool.add transaction_pool user_command )
      in
      Logger.info logger "Computing status" ~module_:__MODULE__
        ~location:__LOC__ ;
      [%test_eq: Transaction_status.State.t]
        ~equal:Transaction_status.State.equal Transaction_status.State.Unknown
        (Test.get_status ~frontier_broadcast_pipe ~transaction_pool
           unknown_user_command)
  end )
