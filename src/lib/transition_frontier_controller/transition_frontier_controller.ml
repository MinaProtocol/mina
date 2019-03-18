open Core_kernel
open Async_kernel
open Protocols.Coda_transition_frontier
open Coda_base
open Pipe_lib

module type Inputs_intf = sig
  include Sync_handler.Inputs_intf

  module Sync_handler :
    Sync_handler_intf
    with type ledger_hash := Ledger_hash.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type transition_frontier := Transition_frontier.t
     and type syncable_ledger_query := Sync_ledger.Query.t
     and type syncable_ledger_answer := Sync_ledger.Answer.t

  module Transition_handler :
    Transition_handler_intf
    with type time_controller := Time.Controller.t
     and type external_transition_verified := External_transition.Verified.t
     and type staged_ledger := Staged_ledger.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t
     and type time := Time.t
     and type transition_frontier_breadcrumb :=
                Transition_frontier.Breadcrumb.t

  module Network :
    Network_intf
    with type peer := Network_peer.Peer.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type consensus_state := Consensus.Consensus_state.Value.t
     and type state_body_hash := State_body_hash.t
     and type ledger_hash := Ledger_hash.t
     and type sync_ledger_query := Sync_ledger.Query.t
     and type sync_ledger_answer := Sync_ledger.Answer.t
     and type parallel_scan_state := Staged_ledger.Scan_state.t

  module Catchup :
    Catchup_intf
    with type external_transition_verified := External_transition.Verified.t
     and type state_hash := State_hash.t
     and type unprocessed_transition_cache :=
                Transition_handler.Unprocessed_transition_cache.t
     and type transition_frontier := Transition_frontier.t
     and type transition_frontier_breadcrumb :=
                Transition_frontier.Breadcrumb.t
     and type network := Network.t
end

module Make (Inputs : Inputs_intf) :
  Transition_frontier_controller_intf
  with type time_controller := Inputs.Time.Controller.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type network := Inputs.Network.t = struct
  open Inputs

  let kill reader writer =
    Strict_pipe.Reader.clear reader ;
    Strict_pipe.Writer.close writer

  let run ~logger ~network ~time_controller ~collected_transitions ~frontier
      ~network_transition_reader ~proposer_transition_reader ~clear_reader =
    let logger = Logger.child logger __MODULE__ in
    let valid_transition_pipe_capacity = 10 in
    let valid_transition_reader, valid_transition_writer =
      Strict_pipe.create
        (Buffered
           (`Capacity valid_transition_pipe_capacity, `Overflow Drop_head))
    in
    let primary_transition_pipe_capacity =
      valid_transition_pipe_capacity + List.length collected_transitions
    in
    let primary_transition_reader, primary_transition_writer =
      Strict_pipe.create
        (Buffered
           (`Capacity primary_transition_pipe_capacity, `Overflow Drop_head))
    in
    let processed_transition_reader, processed_transition_writer =
      Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))
    in
    let catchup_job_reader, catchup_job_writer =
      Strict_pipe.create Synchronous
    in
    let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
      Strict_pipe.create Synchronous
    in
    let proposer_transition_reader_copy, proposer_transition_writer_copy =
      Strict_pipe.create Synchronous
    in
    Strict_pipe.transfer proposer_transition_reader
      proposer_transition_writer_copy ~f:Fn.id
    |> don't_wait_for ;
    let unprocessed_transition_cache =
      Transition_handler.Unprocessed_transition_cache.create ~logger
    in
    Transition_handler.Validator.run ~logger ~frontier
      ~transition_reader:network_transition_reader ~valid_transition_writer
      ~unprocessed_transition_cache ;
    List.iter collected_transitions ~f:(fun t ->
        (* since the cache was just built, it's safe to assume
         * registering these will not fail, so long as there
         * are no duplicates in the list *)
        Transition_handler.Unprocessed_transition_cache.register
          unprocessed_transition_cache t
        |> Or_error.ok_exn
        |> Strict_pipe.Writer.write primary_transition_writer ) ;
    Strict_pipe.Reader.iter_without_pushback valid_transition_reader
      ~f:(Strict_pipe.Writer.write primary_transition_writer)
    |> don't_wait_for ;
    Transition_handler.Processor.run ~logger ~time_controller ~frontier
      ~primary_transition_reader
      ~proposer_transition_reader:proposer_transition_reader_copy
      ~catchup_job_writer ~catchup_breadcrumbs_reader
      ~catchup_breadcrumbs_writer ~processed_transition_writer
      ~unprocessed_transition_cache ;
    Catchup.run ~logger ~network ~frontier ~catchup_job_reader
      ~catchup_breadcrumbs_writer ~unprocessed_transition_cache ;
    Strict_pipe.Reader.iter_without_pushback clear_reader ~f:(fun _ ->
        kill valid_transition_reader valid_transition_writer ;
        kill primary_transition_reader primary_transition_writer ;
        kill processed_transition_reader processed_transition_writer ;
        kill catchup_job_reader catchup_job_writer ;
        kill catchup_breadcrumbs_reader catchup_breadcrumbs_writer ;
        kill proposer_transition_reader_copy proposer_transition_writer_copy )
    |> don't_wait_for ;
    processed_transition_reader
end
