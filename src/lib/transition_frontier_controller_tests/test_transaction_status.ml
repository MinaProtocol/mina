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

    let pids = Child_processes.Termination.create_pid_set ()

    let trust_system = Trust_system.null ()

    let key_gen =
      let open Quickcheck.Generator in
      let open Quickcheck.Generator.Let_syntax in
      let keypairs = List.map Genesis_ledger.accounts ~f:fst in
      let%map random_key_opt = of_list keypairs in
      ( Genesis_ledger.largest_account_keypair_exn ()
      , Signature_lib.Keypair.of_private_key_exn
          (Option.value_exn random_key_opt) )

    let user_command_gen =
      User_command.Gen.payment ~sign_type:`Real ~max_amount:100 ~max_fee:10
        ~key_gen ()

    let create_pool ~frontier_broadcast_pipe =
      let incoming_diffs, _ = Linear_pipe.create () in
      let transaction_pool =
        Transaction_pool.create ~logger ~pids ~trust_system ~incoming_diffs
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
      let%map () = Async.Scheduler.yield_until_no_jobs_remain () in
      transaction_pool

    let single_async_test ~f gen =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Quickcheck.async_test ~trials:1 gen ~f )

    let get_status_exn ~frontier_broadcast_pipe ~transaction_pool user_command
        =
      Or_error.ok_exn
      @@ Test.get_status ~frontier_broadcast_pipe ~transaction_pool
           user_command

    let%test_unit "If the transition frontier currently doesn't exist, the \
                   status of a sent transaction will be unknown" =
      single_async_test user_command_gen ~f:(fun user_command ->
          let frontier_broadcast_pipe, _ = Broadcast_pipe.create None in
          let%bind transaction_pool = create_pool ~frontier_broadcast_pipe in
          let%map () = Transaction_pool.add transaction_pool user_command in
          Logger.info logger "Hello" ~module_:__MODULE__ ~location:__LOC__ ;
          [%test_eq: Transaction_status.State.t]
            ~equal:Transaction_status.State.equal
            Transaction_status.State.Unknown
            (get_status_exn ~frontier_broadcast_pipe ~transaction_pool
               user_command) )

    let%test_unit "A pending transaction is either in the transition frontier \
                   or transaction pool, but not in the best path of the \
                   transition frontier" =
      single_async_test user_command_gen ~f:(fun user_command ->
          let%bind frontier =
            create_root_frontier ~logger ~pids Genesis_ledger.accounts
          in
          let frontier_broadcast_pipe, _ =
            Broadcast_pipe.create (Some frontier)
          in
          let%bind transaction_pool = create_pool ~frontier_broadcast_pipe in
          let%map () = Transaction_pool.add transaction_pool user_command in
          Logger.info logger "Computing status" ~module_:__MODULE__
            ~location:__LOC__ ;
          [%test_eq: Transaction_status.State.t]
            ~equal:Transaction_status.State.equal
            Transaction_status.State.Pending
            (get_status_exn ~frontier_broadcast_pipe ~transaction_pool
               user_command) )

    let%test_unit "An unknown transaction does not appear in the transition \
                   frontier or transaction pool " =
      let user_commands_generator =
        let open Quickcheck.Generator in
        let open Let_syntax in
        let%bind head_user_command = user_command_gen in
        let%map tail_user_commands =
          Quickcheck.Generator.list_with_length 10 user_command_gen
        in
        Non_empty_list.init head_user_command tail_user_commands
      in
      single_async_test user_commands_generator ~f:(fun user_commands ->
          let%bind frontier =
            create_root_frontier ~logger ~pids Genesis_ledger.accounts
          in
          let frontier_broadcast_pipe, _ =
            Broadcast_pipe.create (Some frontier)
          in
          let%bind transaction_pool = create_pool ~frontier_broadcast_pipe in
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
            ~equal:Transaction_status.State.equal
            Transaction_status.State.Unknown
            (get_status_exn ~frontier_broadcast_pipe ~transaction_pool
               unknown_user_command) )
  end )
