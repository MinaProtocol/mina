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
                       (Transition_frontier.add_transition_exn frontier
                          transition) ;
                     Catchup_monitor.notify catchup_monitor ~time_controller
                       ~transition ) ) ))
end
