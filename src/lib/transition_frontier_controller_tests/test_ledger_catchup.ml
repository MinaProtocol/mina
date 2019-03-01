open Core
open Pipe_lib
open Async
open Coda_base

let max_length = 4

module Stubs = Stubs.Make (struct
  let max_length = max_length
end)

open Stubs

module Transition_handler = Transition_handler.Make (struct
  include Transition_frontier_inputs
  module Transition_frontier = Transition_frontier
  module State_proof = State_proof
  module Time = Time
end)

module Ledger_catchup = Ledger_catchup.Make (struct
  include Transition_frontier_inputs
  module Time = Time
  module Transition_frontier = Transition_frontier
  module Protocol_state_validator = Protocol_state_validator
  module Network = Network
  module Unprocessed_transition_cache =
    Transition_handler.Unprocessed_transition_cache
  module Transition_handler_validator = Transition_handler.Validator
end)

let%test_module "Ledger catchup" =
  ( module struct
    let test_catchup ~logger ~network (me : Transition_frontier.t) transition
        expected_breadcrumbs =
      let catchup_job_reader, catchup_job_writer =
        Pipe_lib.Strict_pipe.create
          (Buffered (`Capacity 10, `Overflow Drop_head))
      in
      let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create Synchronous
      in
      let unprocessed_transition_cache =
        Transition_handler.Unprocessed_transition_cache.create ~logger
      in
      let cached_transition =
        Transition_handler.Unprocessed_transition_cache.register
          unprocessed_transition_cache transition
        |> Or_error.ok_exn
      in
      Strict_pipe.Writer.write catchup_job_writer
        (Rose_tree.T (cached_transition, [])) ;
      Ledger_catchup.run ~logger ~network ~frontier:me
        ~catchup_breadcrumbs_writer ~catchup_job_reader
        ~unprocessed_transition_cache ;
      let result_ivar = Ivar.create () in
      (* TODO: expose Strict_pipe.read *)
      Strict_pipe.Reader.iter catchup_breadcrumbs_reader ~f:(fun rose_tree ->
          Deferred.return @@ Ivar.fill result_ivar rose_tree )
      |> don't_wait_for ;
      let%map cached_catchup_breadcrumbs =
        Ivar.read result_ivar >>| List.hd_exn
      in
      let catchup_breadcrumbs =
        Rose_tree.map cached_catchup_breadcrumbs
          ~f:(Fn.compose Or_error.ok_exn Cache_lib.Cached.invalidate)
      in
      Rose_tree.equal expected_breadcrumbs catchup_breadcrumbs
        ~f:(fun breadcrumb_tree1 breadcrumb_tree2 ->
          let to_transition =
            Transition_frontier.(
              Fn.compose With_hash.data Breadcrumb.transition_with_hash)
          in
          External_transition.Verified.equal
            (to_transition breadcrumb_tree1)
            (to_transition breadcrumb_tree2) )

    let%test "catchup to a peer" =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      let logger = Logger.create () in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind me, peer, network =
            Network_builder.setup_me_and_a_peer
              ~source_accounts:Genesis_ledger.accounts ~logger
              ~target_accounts:Genesis_ledger.accounts
              ~num_breadcrumbs:(max_length / 2)
          in
          let best_breadcrumb = Transition_frontier.best_tip peer.frontier in
          let best_transition =
            Transition_frontier.Breadcrumb.transition_with_hash best_breadcrumb
          in
          test_catchup ~logger ~network me best_transition
            ( Transition_frontier.path_map peer.frontier best_breadcrumb
                ~f:Fn.id
            |> Rose_tree.of_list_exn ) )

    let%test_unit "peers can provide transitions with length between \
                   max_length to 2 * max_length" =
      let logger = Logger.create () in
      Thread_safe.block_on_async_exn (fun () ->
          let num_breadcrumbs =
            Int.gen_incl max_length (2 * max_length) |> Quickcheck.random_value
          in
          let%bind me, peer, network =
            Network_builder.setup_me_and_a_peer ~logger
              ~source_accounts:Genesis_ledger.accounts
              ~target_accounts:Genesis_ledger.accounts ~num_breadcrumbs
          in
          let best_breadcrumb = Transition_frontier.best_tip peer.frontier in
          let best_transition =
            Transition_frontier.Breadcrumb.transition_with_hash best_breadcrumb
          in
          Logger.info logger !"Best transition of peer: %{sexp:State_hash.t}"
          @@ With_hash.hash best_transition ;
          let history =
            Transition_frontier.root_history_path_map peer.frontier
              (With_hash.hash best_transition)
              ~f:Fn.id
            |> Option.value_exn
          in
          let%map result =
            test_catchup ~logger ~network me best_transition
              (Rose_tree.of_list_exn @@ Non_empty_list.tail history)
          in
          assert result )
  end )
