open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Pipe_lib.Strict_pipe
open Coda_base
open O1trace

module Make (Inputs : Inputs.S) :
  Transition_handler_processor_intf
  with type state_hash := State_hash.t
   and type time_controller := Inputs.Time.Controller.t
   and type external_transition := Inputs.External_transition.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t = struct
  open Inputs
  open Consensus.Mechanism
  module Catchup_monitor = Catchup_monitor.Make (Inputs)

  (* TODO: calculate a sensible value from postake consensus arguments *)
  let catchup_timeout_duration = Time.Span.of_ms 6000L

  let transition_parent_hash t =
    External_transition.Verified.protocol_state t
    |> Protocol_state.previous_state_hash

  let run ~logger ~time_controller ~frontier ~valid_transition_reader
      ~catchup_job_writer ~catchup_breadcrumbs_reader
      ~catchup_breadcrumbs_writer ~processed_transition_writer =
    let logger = Logger.child logger "Transition_handler.Catchup" in
    let catchup_monitor =
      Catchup_monitor.create ~logger ~frontier ~time_controller
        ~catchup_job_writer ~catchup_breadcrumbs_writer
    in
    ignore
      (Reader.Merge.iter
         [ Reader.map catchup_breadcrumbs_reader ~f:(fun cb ->
               `Catchup_breadcrumbs cb )
         ; Reader.map valid_transition_reader ~f:(fun vt ->
               `Valid_transition vt ) ]
         ~f:(fun msg ->
           let open Deferred.Let_syntax in
           trace_task "transition_handler_processor" (fun () ->
               match msg with
               | `Catchup_breadcrumbs breadcrumbs ->
                   return
                     (List.iter breadcrumbs
                        ~f:
                          (Rose_tree.iter
                             ~f:
                               (Transition_frontier.attach_breadcrumb_exn
                                  frontier)))
               | `Valid_transition transition -> (
                 match
                   Transition_frontier.find frontier
                     (transition_parent_hash (With_hash.data transition))
                 with
                 | None ->
                     return
                       (Catchup_monitor.watch catchup_monitor
                          ~timeout_duration:catchup_timeout_duration
                          ~transition)
                 | Some _ -> (
                     match%map
                       let open Deferred.Or_error.Let_syntax in
                       let parent_hash =
                         With_hash.data transition
                         |> External_transition.Verified.protocol_state
                         |> Protocol_state.previous_state_hash
                       in
                       let%bind parent =
                         match
                           Transition_frontier.find frontier parent_hash
                         with
                         | Some parent -> return parent
                         | None ->
                             Deferred.Or_error.error_string "parent not found"
                       in
                       let%map breadcrumb =
                         match
                           Transition_frontier.Breadcrumb.build ~logger ~parent
                             ~transition_with_hash:transition
                         with
                         | Error (`Validation_error e) ->
                             (*TODO: Punish*) Error e
                         | Error (`Fatal_error e) -> raise e
                         | Ok b -> Ok b
                       in
                       Transition_frontier.add_breadcrumb_exn frontier
                         breadcrumb ;
                       Writer.write processed_transition_writer transition ;
                       Catchup_monitor.notify catchup_monitor ~transition
                     with
                     | Ok () -> ()
                     | Error err ->
                         Logger.error logger
                           "error while adding transition: %s"
                           (Error.to_string_hum err) ) ) ) ))
end
