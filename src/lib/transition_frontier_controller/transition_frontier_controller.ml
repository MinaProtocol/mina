open Core_kernel
open Async_kernel
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
     and type external_transition_verified := External_transition.Verified.t
     and type staged_ledger := Staged_ledger.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t
     and type time := Time.t
     and type transition_frontier_breadcrumb :=
                Transition_frontier.Breadcrumb.t

  module Network :
    Network_intf
    with type peer := Kademlia.Peer.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type ancestor_proof_input := State_hash.t * int
     and type ancestor_proof := Ancestor.Proof.t

  module Catchup :
    Catchup_intf
    with type external_transition := External_transition.t
     and type external_transition_verified := External_transition.Verified.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t
     and type transition_frontier_breadcrumb :=
                Transition_frontier.Breadcrumb.t
     and type network := Network.t
end

module Make (Inputs : Inputs_intf) :
  Transition_frontier_controller_intf
  with type time_controller := Inputs.Time.Controller.t
   and type external_transition := Inputs.External_transition.t
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

  let run ~logger ~network ~time_controller ~frontier ~transition_reader
      ~clear_reader =
    let logger = Logger.child logger __MODULE__ in
    let valid_transition_reader, valid_transition_writer =
      Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))
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
    Transition_handler.Validator.run ~frontier ~transition_reader
      ~valid_transition_writer ~logger ;
    Transition_handler.Processor.run ~logger ~time_controller ~frontier
      ~valid_transition_reader ~catchup_job_writer ~catchup_breadcrumbs_reader
      ~catchup_breadcrumbs_writer ~processed_transition_writer ;
    Catchup.run ~logger ~network ~frontier ~catchup_job_reader
      ~catchup_breadcrumbs_writer ;
    Strict_pipe.Reader.iter_without_pushback clear_reader ~f:(fun _ ->
        kill valid_transition_reader valid_transition_writer ;
        kill processed_transition_reader processed_transition_writer ;
        kill catchup_job_reader catchup_job_writer ;
        kill catchup_breadcrumbs_reader catchup_breadcrumbs_writer )
    |> don't_wait_for ;
    processed_transition_reader
end
