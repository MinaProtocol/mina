(*
open Core
open Async
open Pipe_lib
open Stubs

module Processor = Transition_handler.Processor.Make (struct
  module Time = Time
  module External_transition = External_transition
  module Proof = Coda_base.Proof
  module Transition_frontier = Transition_frontier
  module State_proof = State_proof
  module Staged_ledger = Staged_ledger
  module Staged_ledger_diff = Staged_ledger_diff
  module Transaction_snark_work = Transaction_snark_work
  module Ledger_proof = Ledger_proof
  module Ledger_proof_statement = Ledger_proof_statement
  module Staged_ledger_aux_hash = Staged_ledger_aux_hash
end)

let%test_module "Transition_handler.Processor tests" =
  ( module struct
    let%test "adding transitions whose parents are in the frontier" =
      Backtrace.elide := false ;
      Printexc.record_backtrace true ;
      let test_size = 10 in
      let logger = Logger.create () in
      let gen_next_breadcrumb frontier =
        let open Core.Quickcheck.Let_syntax in
        let%map create_breadcrumb = gen_breadcrumb ~logger in
        let open Deferred.Let_syntax in
        let parent_breadcrumb = Transition_frontier.best_tip frontier in
        let%map next_breadcrumb =
          create_breadcrumb (Deferred.return parent_breadcrumb)
        in
        next_breadcrumb
      in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = Quickcheck.random_value (gen_frontier ~logger) in
          let time_controller = Coda_base.Block_time.Controller.create () in
          let valid_transition_reader, valid_transition_writer =
            Strict_pipe.create
              (Buffered (`Capacity test_size, `Overflow Drop_head))
          in
          let proposer_transition_reader, _ =
            Strict_pipe.create
              (Buffered (`Capacity test_size, `Overflow Drop_head))
          in
          let _, catchup_job_writer = Strict_pipe.create Synchronous in
          let processed_transition_reader, processed_transition_writer =
            Strict_pipe.create
              (Buffered (`Capacity test_size, `Overflow Drop_head))
          in
          let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
            Strict_pipe.create Synchronous
          in
          let size frontier =
            Transition_frontier.all_breadcrumbs frontier |> List.length
          in
          let old_frontier_size = size frontier in
          Processor.run ~logger ~time_controller ~frontier
            ~primary_transition_reader:valid_transition_reader
            ~proposer_transition_reader ~catchup_job_writer
            ~catchup_breadcrumbs_reader ~catchup_breadcrumbs_writer
            ~processed_transition_writer ;
          let expected_state_hashes =
            Coda_base.State_hash.Hash_set.create ()
          in
          let finish_processing_transitions_signal = Ivar.create () in
          Strict_pipe.Reader.fold processed_transition_reader ~init:1
            ~f:(fun acc_counter _ ->
              if acc_counter >= test_size then
                Ivar.fill finish_processing_transitions_signal () ;
              return (acc_counter + 1) )
          |> Deferred.ignore |> don't_wait_for ;
          let%bind () =
            Deferred.List.init test_size ~f:(fun _ ->
                let%map breadcrumb =
                  Quickcheck.random_value (gen_next_breadcrumb frontier)
                in
                let transition_with_hash =
                  Transition_frontier.Breadcrumb.transition_with_hash
                    breadcrumb
                in
                let state_hash = With_hash.hash transition_with_hash in
                Hash_set.add expected_state_hashes state_hash ;
                Strict_pipe.Writer.write valid_transition_writer
                  transition_with_hash )
            |> Deferred.ignore
          in
          let%map () = Ivar.read finish_processing_transitions_signal in
          let new_frontier_size = size frontier in
          let all_states =
            Transition_frontier.(
              all_breadcrumbs frontier
              |> List.map
                   ~f:
                     (Fn.compose With_hash.hash Breadcrumb.transition_with_hash)
              |> Coda_base.State_hash.Hash_set.of_list)
          in
          new_frontier_size - old_frontier_size = test_size
          && Hash_set.for_all expected_state_hashes
               ~f:(Hash_set.mem all_states) )
  end )
*)
