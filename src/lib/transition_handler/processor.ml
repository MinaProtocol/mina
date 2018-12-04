open Core_kernel
open Protocols.Coda_pow
open Pipe_lib.Strict_pipe
open Coda_base
open O1trace

module Make (Inputs : Inputs.S) :
  Transition_handler_processor_intf
  with type state_hash := State_hash.t
   and type time_controller := Inputs.Time.Controller.t
   and type external_transition := Inputs.External_transition.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t = struct
  open Inputs
  open Consensus.Mechanism
  module Catchup_monitor = Catchup_monitor.Make (Inputs)

  (* TODO: calculate a sensible value from postake consensus arguments *)
  let catchup_timeout_duration = Time.Span.of_ms 6000L

  let transition_parent_hash t =
    External_transition.protocol_state t |> Protocol_state.previous_state_hash

  let run ~logger ~time_controller ~frontier ~valid_transition_reader
      ~catchup_job_writer ~catchup_breadcrumbs_reader =
    let logger = Logger.child logger "Transition_handler.Catchup" in
    let catchup_monitor = Catchup_monitor.create ~catchup_job_writer in
    ignore
      (Reader.Merge.iter_sync
         [ Reader.map catchup_breadcrumbs_reader ~f:(fun cb ->
               `Catchup_breadcrumbs cb )
         ; Reader.map valid_transition_reader ~f:(fun vt ->
               `Valid_transition vt ) ]
         ~f:(fun msg ->
           trace_task "transition_handler_processor" (fun () ->
               match msg with
               | `Catchup_breadcrumbs [] ->
                   Logger.error logger "read empty catchup transitions"
               | `Catchup_breadcrumbs (_ :: _ as breadcrumbs) ->
                   List.iter breadcrumbs
                     ~f:(Transition_frontier.attach_breadcrumb_exn frontier)
               | `Valid_transition transition -> (
                   match
                     Transition_frontier.find frontier
                       (transition_parent_hash (With_hash.data transition))
                   with
                   | None ->
                       Catchup_monitor.watch catchup_monitor ~logger
                         ~time_controller
                         ~timeout_duration:catchup_timeout_duration ~transition
                   | Some _ ->
                       ignore
                         (Transition_frontier.add_transition_exn ~logger frontier
                            transition) ;
                       Catchup_monitor.notify catchup_monitor ~time_controller
                         ~transition ) ) ))
end

let%test_module "Transition_handler.Processor tests" = (module struct
  module Time = Coda_base.Block_time
  module Proof = Coda_base.Proof
  module Blockchain_state = Coda_base.Blockchain_state.Make (Genesis_ledger)
  module Protocol_state = Coda_base.Protocol_state.Make (Blockchain_state) (Consensus.Mechanism.Consensus_state)
  module Completed_work = Ledger_builder.Make_completed_work
      (Signature_lib.Public_key.Compressed)
      (Ledger_proof_statement)
  module Ledger_builder_diff = Ledger_builder.Make_diff (struct
    module Ledger_hash = Coda_base.Ledger_hash
    module Ledger_proof = Ledger_proof
    module Ledger_builder_aux_hash = Coda_base.Ledger_builder_hash.Aux_hash
    module Ledger_builder_hash = Coda_base.Ledger_builder_hash
    module Compressed_public_key = Signature_lib.Public_key.Compressed
    module User_command = Coda_base.User_command
    module Completed_work = Completed_work
  end)
  module External_transition = Coda_base.External_transition.Make (Ledger_builder_diff) (Protocol_state)
  module Ledger_builder = Ledger_builder.Make (struct
    module Compressed_public_key = Signature_lib.Public_key.Compressed
    module User_command = Coda_base.User_command
    module Fee_transfer = Coda_base.Fee_transfer
    module Coinbase = Coda_base.Coinbase
    module Transaction = Coda_base.Transaction
    module Ledger_hash = Coda_base.Ledger_hash
    module Frozen_ledger_hash = Coda_base.Frozen_ledger_hash
    module Ledger_proof_statement = Ledger_proof_statement
    module Proof = Proof
    module Sok_message = Coda_base.Sok_message
    module Ledger_proof = Ledger_proof
    module Ledger_proof_verifier = Ledger_proof_verifier
    module Account = Coda_base.Account
    module Ledger = Coda_base.Ledger
    module Sparse_ledger = Coda_base.Sparse_ledger
    module Ledger_builder_aux_hash = Coda_base.Ledger_builder_hash.Aux_hash
    module Ledger_builder_hash = Coda_base.Ledger_builder_hash
    module Completed_work = Completed_work
    module Ledger_builder_diff = Ledger_builder_diff
    module Config = struct
      let transaction_capacity_log_2 = 8
    end

    let check = failwith "stub"
  end)
  module Transition_frontier = Transition_frontier.Make
      (Ledger_builder_diff)
      (External_transition)
      (Ledger_builder)
  module Processor = Make (struct
    module Time = Time
    module Consensus_mechanism = Consensus.Mechanism
    module External_transition = External_transition
    module Proof = Proof
    module Transition_frontier = Transition_frontier
  end)

  let gen_transition ~seed ~choice =
    if choice then
      let parent_hash = 
        Transition_frontier.hashes frontier
        |> List.shuffle
        |> List.head_exn
      in
      (`Exists, Quickcheck.random_value ~seed (External_transition.gen_with_parent parent_hash))
    else
      (`Does_not_exist, Quickcheck.random_value ~seed External_transition.gen)

  let%test "valid transition behavior" =
    Thread_safe.block_on_async_exn (
      (* number of transitions to write during test *)
      let test_size = 200 in
      let seed = `Nondetermistic in
      let logger = Logger.create () in
      let time_controller = Time.Controller.create () in
      let frontier = Transition_frontier.create () in
      let (valid_transition_reader, valid_transition_writer) = Strict_pipe.create (Buffered (`Capacity test_size, `Overflow Crash)) in
      let (catchup_job_reader, catchup_job_writer) = Strict_pipe.create (Buffered (`Capacity test_size, `Overflow Crash)) in
      let (catchup_breadcrumbs_reader, _) = Strict_pipe.create (Buffered (`Capacity 0, `Overflow Crash)) in

      let expected_transitions = ref State_hash.Set.empty in
      let expected_catchup_jobs = ref State_hash.Set.empty in

      let expect_transition hash = expected_transitions := Set.add !expected_transitions hash in
      let expect_catchup_job hash = expected_catchup_jobs := Set.add !expected_catchup_jobs hash in

      Processor.run ~logger ~time_controller ~frontier ~valid_transition_reader ~catchup_job_writer ~catchup_breadcrumbs_reader;
      don't_wait_for (Reader.iter_sync catchup_job_reader ~f:check_catchup_job);

      for i = 1 to test_size do
        let (status, transition) = gen_transition ~seed ~choice:(Quickcheck.random_value ~seed Bool.gen) in
        let hash = Protocol_state.hash (External_transition.protocol_state transition) in
        let transition_with_hash = With_hash.{hash; data= transition} in
        (match status with
        | `Exists -> expect_transition hash
        | `Does_not_exist -> expect_catchup_job hash);
        Writer.write valid_transition_writer transition_with_hash
      done;

      (*
      Ivar.wait_for all_transitions_read;
      Ivar.wait_for all_catchups_read;
       *)

      let test_completed = Ivar.create () in
      Deferred.upon (Time.Timeout.create Time.Span.of_ms 500l) (fun () ->
          List.for_all (Transition_frontier.hashes frontier) ~f:(fun hash ->
              Set.exists expected_transitions ~f:(State_hash.equal hash))
          Ivar.fill test_completed ());
      test_completed)

  let%test "reader prioritization" = false
end)
