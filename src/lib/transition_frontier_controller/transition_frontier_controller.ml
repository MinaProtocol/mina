open Protocols.Coda_pow
open Protocols.Coda_transition_frontier
open Coda_base
open Pipe_lib

module type Inputs_intf = sig
  include Sync_handler.Inputs_intf

  module Time : Time_intf

  module Sync_handler :
    Sync_handler_intf
    with type hash := State_hash.t
     and type transition_frontier := Transition_frontier.t
     and type ancestor_proof := State_body_hash.t list

  module Transition_handler :
    Transition_handler_intf
    with type time_controller := Time.Controller.t
     and type external_transition := External_transition.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t
     and type time := Time.t
     and type transition_frontier_breadcrumb :=
                Transition_frontier.Breadcrumb.t

  module Catchup :
    Catchup_intf
    with type external_transition := External_transition.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t
     and type transition_frontier_breadcrumb :=
                Transition_frontier.Breadcrumb.t
end

module Make (Inputs : Inputs_intf) :
  Transition_frontier_controller_intf
  with type time_controller := Inputs.Time.Controller.t
   and type external_transition := Inputs.External_transition.t
   and type syncable_ledger_query := Inputs.Syncable_ledger.query
   and type syncable_ledger_answer := Inputs.Syncable_ledger.answer
   and type transition_frontier := Inputs.Transition_frontier.t
   and type time := Inputs.Time.t
   and type state_hash := State_hash.t = struct
  open Inputs

  let run ~logger ~time_controller ~frontier ~transition_reader =
    let logger = Logger.child logger "transition_frontier_controller" in
    let valid_transition_reader, valid_transition_writer =
      Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))
    in
    let processed_transition_reader, processed_transition_writer =
      Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))
    in
    let catchup_job_reader, catchup_job_writer =
      Strict_pipe.create (Buffered (`Capacity 5, `Overflow Drop_head))
    in
    let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
      Strict_pipe.create (Buffered (`Capacity 3, `Overflow Crash))
    in
    Transition_handler.Validator.run ~frontier ~transition_reader
      ~valid_transition_writer ~logger ;
    Transition_handler.Processor.run ~logger ~time_controller ~frontier
      ~valid_transition_reader ~processed_transition_writer ~catchup_job_writer
      ~catchup_breadcrumbs_reader ;
    Catchup.run ~frontier ~catchup_job_reader ~catchup_breadcrumbs_writer ;
    processed_transition_reader
end
