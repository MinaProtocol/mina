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
   and type trust_system := Trust_system.t
   and type time_controller := Inputs.Time.Controller.t
   and type external_transition_with_initial_validation :=
              Inputs.External_transition.with_initial_validation
   and type external_transition_validated :=
              Inputs.External_transition.Validated.t
   and type unprocessed_transition_cache :=
              Inputs.Unprocessed_transition_cache.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t
   and type verifier := Inputs.Verifier.t = struct
  open Inputs
  module Catchup_scheduler = Catchup_scheduler.Make (Inputs)
  module Transition_frontier_validation =
    External_transition.Transition_frontier_validation (Transition_frontier)

  type external_transition_with_initial_validation =
    ( [`Time_received] * Truth.true_t
    , [`Proof] * Truth.true_t
    , [`Frontier_dependencies] * Truth.false_t
    , [`Staged_ledger_diff] * Truth.false_t )
    External_transition.Validation.with_transition

  (* TODO: calculate a sensible value from postake consensus arguments *)
  let catchup_timeout_duration =
    Time.Span.of_ms
      (Consensus.Constants.block_window_duration_ms * 2 |> Int64.of_int)

  let run ~logger ~verifier ~trust_system ~time_controller ~frontier
      ~(primary_transition_reader :
         ( external_transition_with_initial_validation Envelope.Incoming.t
         , State_hash.t )
         Cached.t
         Reader.t)
      ~(proposer_transition_reader : Transition_frontier.Breadcrumb.t Reader.t)
      ~(clean_up_catchup_scheduler : unit Ivar.t)
      ~(catchup_job_writer :
         ( State_hash.t
           * ( external_transition_with_initial_validation Envelope.Incoming.t
             , State_hash.t )
             Cached.t
             Rose_tree.t
             list
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
    let catchup_scheduler =
      Catchup_scheduler.create ~logger ~verifier ~trust_system ~frontier
        ~time_controller ~catchup_job_writer ~catchup_breadcrumbs_writer
        ~clean_up_signal:clean_up_catchup_scheduler
    in
    (* add a breadcrumb and perform post processing *)
    let add_and_finalize ~only_if_present cached_breadcrumb =
      let open Deferred.Or_error.Let_syntax in
      let%bind breadcrumb =
        Deferred.Or_error.return
          (Cached.invalidate_with_success cached_breadcrumb)
      in
      let transition =
        Transition_frontier.Breadcrumb.transition_with_hash breadcrumb
      in
      let add_breadcrumb =
        if only_if_present then
          Transition_frontier.add_breadcrumb_if_present_exn
        else Transition_frontier.add_breadcrumb_exn
      in
      let%bind () =
        Deferred.map ~f:Result.return (add_breadcrumb frontier breadcrumb)
      in
      Writer.write processed_transition_writer transition ;
      Deferred.return
        (Catchup_scheduler.notify catchup_scheduler
           ~hash:(With_hash.hash transition))
    in
    ignore
      (Reader.Merge.iter
         (* It is fine to skip the cache layer on propose transitions because it
            * is extradornarily unlikely we would write an internal bug triggering this
            * case, and the external case (where we received an identical external
            * transition from the network) can happen iff there is another node
            * with the exact same private key and view of the transaction pool. *)
         [ Reader.map proposer_transition_reader ~f:(fun breadcrumb ->
               `Proposed_breadcrumb (Cached.pure breadcrumb) )
         ; Reader.map catchup_breadcrumbs_reader ~f:(fun cb ->
               `Catchup_breadcrumbs cb )
         ; Reader.map primary_transition_reader ~f:(fun vt ->
               `Partially_valid_transition vt ) ]
         ~f:(fun msg ->
           let open Deferred.Let_syntax in
           trace_recurring_task "transition_handler_processor" (fun () ->
               match msg with
               | `Catchup_breadcrumbs breadcrumb_subtrees -> (
                   match%map
                     Deferred.Or_error.List.iter breadcrumb_subtrees
                       ~f:(fun subtree ->
                         Rose_tree.Deferred.Or_error.iter
                           subtree
                           (* It could be the case that by the time we try and
                             * add the breadcrumb, it's no longer relevant when
                             * we're catching up *)
                           ~f:(add_and_finalize ~only_if_present:true) )
                   with
                   | Ok () ->
                       ()
                   | Error err ->
                       Logger.error logger ~module_:__MODULE__
                         ~location:__LOC__
                         "failed to attach all catchup breadcrumbs to \
                          transition frontier: %s"
                         (Error.to_string_hum err) )
               | `Proposed_breadcrumb breadcrumb -> (
                   match%map
                     add_and_finalize ~only_if_present:false breadcrumb
                   with
                   | Ok () ->
                       ()
                   | Error err ->
                       Logger.error logger ~module_:__MODULE__
                         ~location:__LOC__
                         "failed to attach breadcrumb proposed internally to \
                          transition frontier: %s"
                         (Error.to_string_hum err) )
               | `Partially_valid_transition
                   cached_transition_with_initial_validation -> (
                   Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                     ~metadata:
                       [("state_hash", State_hash.to_yojson transition_hash)]
                     "begining to process external transition: $state_hash" ;
                   match
                     Transition_frontier_validation
                     .validate_frontier_dependencies ~logger ~frontier
                       (Envelope.Incoming.data (Cached.peek cached_transition))
                   with
                   | Error `Not_selected_over_frontier_root ->
                       () (* TODO: punish *)
                   | Error `Already_in_frontier ->
                       failwith "impossible? (probably not)"
                   | Error `Parent_missing_from_frontier ->
                       Catchup_scheduler.watch catchup_scheduler
                         ~timeout_duration:catchup_timeout_duration
                         ~cached_transition:
                           cached_transition_with_initial_validation ;
                       return ()
                   | Ok transition_with_validation -> (
                       (* TODO: look up parent only once (parent is already looked up in call to validate dependencies *)
                       (*
                       let cached_transition_with_validation =
                         Cached.transform cached_transition_with_initial_validation
                          ~f:(Fn.const transition_with_validation)
                       in
                       *)
                       let ( {With_hash.hash= transition_hash; data= transition}
                           , _ ) =
                         transition_with_validation
                       in
                       let parent_hash =
                         External_transition.parent_hash transition
                       in
                       let parent =
                         Option.value_exn
                           (Transition_frontier.find frontier parent_hash)
                       in
                       match%map
                         let%bind breadcrumb =
                           let open Deferred.Let_syntax in
                           let%bind cached_breadcrumb =
                             Cached.transform cached_transition ~f:(fun _ ->
                                 let transition_with_hash =
                                   Envelope.Incoming.data
                                     transition_with_hash_enveloped
                                 in
                                 let sender =
                                   Envelope.Incoming.sender
                                     transition_with_hash_enveloped
                                 in
                                 let%map breadcrumb_result =
                                   Transition_frontier.Breadcrumb.build ~logger
                                     ~verifier ~trust_system ~parent
                                     ~transition_with_hash
                                     ~sender:(Some sender)
                                 in
                                 Result.map_error breadcrumb_result
                                   ~f:(fun error -> (sender, error)) )
                             |> Cached.sequence_deferred
                           in
                           match Cached.sequence_result cached_breadcrumb with
                           | Error (_sender, `Invalid_staged_ledger_hash error)
                           | Error (_sender, `Invalid_staged_ledger_diff error)
                             ->
                               return (Error error)
                           | Error (_sender, `Fatal_error error) ->
                               raise error
                           | Ok breadcrumb ->
                               return (Ok breadcrumb)
                         in
                         add_and_finalize ~only_if_present:false breadcrumb
                       with
                       | Ok () ->
                           ()
                       | Error err ->
                           Logger.error logger ~module_:__MODULE__
                             ~location:__LOC__
                             "error while adding transition: %s"
                             (Error.to_string_hum err) ) ) ) ))
end
