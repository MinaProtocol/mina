(** This module contains the transition processor. The transition processor is
 *  the thread in which transitions are attached the to the transition frontier.
 *
 *  Two types of data are handled by the transition processor: validated external transitions
 *  with precomputed state hashes (via the proposer and validator pipes) and breadcrumb rose
 *  trees (via the catchup pipe).
 *)

open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Pipe_lib.Strict_pipe
open Coda_base
open Cache_lib
open O1trace

module Make (Inputs : Inputs.With_unprocessed_transition_cache.S) :
  Transition_handler_processor_intf
  with type state_hash := State_hash.t
   and type time_controller := Inputs.Time.Controller.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type unprocessed_transition_cache :=
              Inputs.Unprocessed_transition_cache.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t = struct
  open Inputs
  open Consensus
  module Catchup_scheduler = Catchup_scheduler.Make (Inputs)

  (* TODO: calculate a sensible value from postake consensus arguments *)
  let catchup_timeout_duration = Time.Span.of_ms 6000L

  let transition_parent_hash t =
    External_transition.Verified.protocol_state t
    |> Protocol_state.previous_state_hash

  let run ~logger ~time_controller ~frontier
      ~(primary_transition_reader :
         ( (External_transition.Verified.t, State_hash.t) With_hash.t
         , State_hash.t )
         Cached.t
         Reader.t)
      ~(proposer_transition_reader :
         (External_transition.Verified.t, State_hash.t) With_hash.t Reader.t)
      ~(catchup_job_writer :
         ( ( (External_transition.Verified.t, State_hash.t) With_hash.t
           , State_hash.t )
           Cached.t
         , synchronous
         , unit Deferred.t )
         Writer.t)
      ~(catchup_breadcrumbs_reader :
         (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t Rose_tree.t
         list
         Reader.t)
      ~(catchup_breadcrumbs_writer :
         ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t Rose_tree.t
           list
         , synchronous
         , unit Deferred.t )
         Writer.t) ~processed_transition_writer ~unprocessed_transition_cache =
    let logger = Logger.child logger "Transition_handler.Catchup" in
    let catchup_scheduler =
      Catchup_scheduler.create ~logger ~frontier ~time_controller
        ~catchup_job_writer ~catchup_breadcrumbs_writer
    in
    (* add a breadcrumb and perform post processing *)
    let add_and_finalize cached_breadcrumb =
      let open Deferred.Or_error.Let_syntax in
      let%bind breadcrumb =
        Deferred.return (Cached.invalidate cached_breadcrumb)
      in
      let transition =
        Transition_frontier.Breadcrumb.transition_with_hash breadcrumb
      in
      let%bind () =
        Deferred.map ~f:Result.return
          (Transition_frontier.add_breadcrumb_exn frontier breadcrumb)
      in
      Writer.write processed_transition_writer transition ;
      Deferred.return
        (Catchup_scheduler.notify catchup_scheduler
           ~hash:(With_hash.hash transition))
    in
    ignore
      (Reader.Merge.iter
         [ Reader.map proposer_transition_reader ~f:(fun vt ->
               (* The proposer transitions are registered into the cache in order to prevent
                * duplicate internal proposals. Otherwise, this could just be wrapped with a
                * phantom Cached.t *)
               `Valid_transition
                 ( Unprocessed_transition_cache.register
                     unprocessed_transition_cache vt
                 |> Or_error.ok_exn ) )
         ; Reader.map catchup_breadcrumbs_reader ~f:(fun cb ->
               `Catchup_breadcrumbs cb )
         ; Reader.map primary_transition_reader ~f:(fun vt ->
               `Valid_transition vt ) ]
         ~f:(fun msg ->
           let open Deferred.Let_syntax in
           trace_recurring_task "transition_handler_processor" (fun () ->
               match msg with
               | `Catchup_breadcrumbs breadcrumb_subtrees -> (
                   match%map
                     Deferred.Or_error.List.iter breadcrumb_subtrees
                       ~f:(fun subtree ->
                         Rose_tree.Deferred.Or_error.iter subtree
                           ~f:add_and_finalize )
                   with
                   | Ok () -> ()
                   | Error err ->
                       Logger.error logger
                         "failed to attach all catchup breadcrumbs to \
                          transition frontier: %s"
                         (Error.to_string_hum err) )
               | `Valid_transition cached_transition -> (
                 match
                   Transition_frontier.find frontier
                     (transition_parent_hash
                        (With_hash.data (Cached.peek cached_transition)))
                 with
                 | None ->
                     return
                       (Catchup_scheduler.watch catchup_scheduler
                          ~timeout_duration:catchup_timeout_duration
                          ~cached_transition)
                 | Some _ -> (
                     match%map
                       let open Deferred.Result.Let_syntax in
                       let parent_hash =
                         Cached.peek cached_transition
                         |> With_hash.data
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
                       let%bind breadcrumb =
                         let open Deferred.Let_syntax in
                         let%map cached_breadcrumb =
                           Cached.transform cached_transition
                             ~f:(fun transition_with_hash ->
                               Transition_frontier.Breadcrumb.build ~logger
                                 ~parent ~transition_with_hash )
                           |> Cached.sequence_deferred
                         in
                         match Cached.sequence_result cached_breadcrumb with
                         | Error (`Validation_error e) ->
                             (* TODO: Punish *) Error e
                         | Error (`Fatal_error e) -> raise e
                         | Ok b -> Ok b
                       in
                       add_and_finalize breadcrumb
                     with
                     | Ok () -> ()
                     | Error err ->
                         Logger.error logger
                           "error while adding transition: %s"
                           (Error.to_string_hum err) ) ) ) ))
end
