open Core_kernel
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

  module Network :
    Network_intf
    with type peer := Kademlia.Peer.t
     and type state_hash := State_hash.t
     and type transition := External_transition.t
     and type ancestor_proof_input := State_hash.t * int
     and type ancestor_proof := Ancestor.Proof.t
     and type protocol_state := External_transition.Protocol_state.value

  module Catchup :
    Catchup_intf
    with type external_transition := External_transition.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t
     and type transition_frontier_breadcrumb :=
                Transition_frontier.Breadcrumb.t
     and type network := Network.t

  module Bootstrap_controller :
    Bootstrap_controller_intf
    with type network := Network.t
     and type transition_frontier := Transition_frontier.t
     and type external_transition := External_transition.t
     and type ancestor_prover := Ancestor.Prover.t
end

module Make (Inputs : Inputs_intf) :
  Transition_frontier_controller_intf
  with type time_controller := Inputs.Time.Controller.t
   and type external_transition := Inputs.External_transition.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type network := Inputs.Network.t = struct
  open Inputs

  let to_unix_timestamp recieved_time =
    recieved_time |> Time.to_span_since_epoch |> Time.Span.to_ms
    |> Unix_timestamp.of_int64

  let run ~logger ~network ~time_controller ~frontier ~transition_reader =
    let logger = Logger.child logger __MODULE__ in
    let valid_transition_reader, valid_transition_writer =
      Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))
    in
    let valid_transition_writer =
      Strict_pipe.Closed_writer.wrap valid_transition_writer
    in
    let processed_transition_reader, processed_transition_writer =
      Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))
    in
    let processed_transition_writer =
      Strict_pipe.Closed_writer.wrap processed_transition_writer
    in
    let catchup_job_reader, catchup_job_writer =
      Strict_pipe.create (Buffered (`Capacity 5, `Overflow Drop_head))
    in
    let catchup_job_writer =
      Strict_pipe.Closed_writer.wrap catchup_job_writer
    in
    let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
      Strict_pipe.create (Buffered (`Capacity 3, `Overflow Crash))
    in
    let catchup_breadcrumbs_writer =
      Strict_pipe.Closed_writer.wrap catchup_breadcrumbs_writer
    in
    let ancestor_prover =
      Ancestor.Prover.create ~max_size:(2 * Transition_frontier.max_length)
    in
    Transition_handler.Validator.run ~frontier ~transition_reader
      ~valid_transition_writer ~logger ;
    Transition_handler.Processor.run ~logger ~time_controller ~frontier
      ~valid_transition_reader ~processed_transition_writer ~catchup_job_writer
      ~catchup_breadcrumbs_reader ;
    Catchup.run ~logger ~network ~frontier ~catchup_job_reader
      ~catchup_breadcrumbs_writer ;
    (* HACK: Bootstrap accepts unix_timestamp rather than Time.t *)
    Bootstrap_controller.run ~valid_transition_writer
      ~processed_transition_writer ~catchup_job_writer
      ~catchup_breadcrumbs_writer ~parent_log:logger ~network ~ancestor_prover
      ~frontier
      ~transition_reader:
        (Strict_pipe.Reader.map transition_reader
           ~f:(fun (transition, `Time_received tm) ->
             (transition, `Time_received (to_unix_timestamp tm)) )) ;
    processed_transition_reader
end
