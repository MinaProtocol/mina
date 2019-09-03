(** This module contains the transition processor. The transition processor is
 *  the thread in which transitions are attached the to the transition frontier.
 *
 *  Two types of data are handled by the transition processor: validated external transitions
 *  with precomputed state hashes (via the proposer and validator pipes) and breadcrumb rose
 *  trees (via the catchup pipe).
 *)

open Core_kernel
open Async_kernel
open Pipe_lib.Strict_pipe
open Coda_base
open Coda_state
open Cache_lib
open O1trace

module Make (Inputs : Inputs.S) :
  Coda_intf.Transition_handler_processor_intf
  with type external_transition_with_initial_validation :=
              Inputs.External_transition.with_initial_validation
   and type external_transition_validated :=
              Inputs.External_transition.Validated.t
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
    Block_time.Span.of_ms
      (Consensus.Constants.block_window_duration_ms * 2 |> Int64.of_int)

  let cached_transform_deferred_result ~transform_cached ~transform_result
      cached =
    Cached.transform cached ~f:transform_cached
    |> Cached.sequence_deferred
    >>= Fn.compose transform_result Cached.sequence_result

  (* add a breadcrumb and perform post processing *)
  let add_and_finalize ~logger ~frontier ~catchup_scheduler
      ~processed_transition_writer ~only_if_present cached_breadcrumb =
    let breadcrumb =
      if Cached.is_pure cached_breadcrumb then Cached.peek cached_breadcrumb
      else Cached.invalidate_with_success cached_breadcrumb
    in
    let transition =
      Transition_frontier.Breadcrumb.transition_with_hash breadcrumb
    in
    let%map () =
      if only_if_present then
        let parent_hash = Transition_frontier.Breadcrumb.parent_hash breadcrumb in
        match Transition_frontier.find frontier parent_hash with
        | Some _ ->
            Transition_frontier.add_breadcrumb_exn frontier breadcrumb
        | None ->
            Logger.warn logger ~module_:__MODULE__
              ~location:__LOC__
              !"When trying to add breadcrumb, its parent had been removed from \
                transition frontier: %{sexp: State_hash.t}"
              parent_hash ;
            Deferred.unit
      else Transition_frontier.add_breadcrumb_exn frontier breadcrumb
    in
    Writer.write processed_transition_writer transition ;
    Catchup_scheduler.notify catchup_scheduler
      ~hash:(With_hash.hash transition)

  let process_transition ~logger ~trust_system ~verifier ~frontier
      ~catchup_scheduler ~processed_transition_writer
      ~transition:cached_initially_validated_transition =
    let enveloped_initially_validated_transition =
      Cached.peek cached_initially_validated_transition
    in
    let sender =
      Envelope.Incoming.sender enveloped_initially_validated_transition
    in
    let initially_validated_transition =
      Envelope.Incoming.data enveloped_initially_validated_transition
    in
    let {With_hash.hash= transition_hash; data= transition}, _ =
      initially_validated_transition
    in
    let metadata = [("state_hash", State_hash.to_yojson transition_hash)] in
    Deferred.map ~f:(Fn.const ())
      (let open Deferred.Result.Let_syntax in
      let%bind mostly_validated_transition =
        let open Deferred.Let_syntax in
        match
          Transition_frontier_validation.validate_frontier_dependencies ~logger
            ~frontier initially_validated_transition
        with
        | Ok t ->
            return (Ok t)
        | Error `Not_selected_over_frontier_root ->
            let%map () =
              Trust_system.record_envelope_sender trust_system logger sender
                ( Trust_system.Actions.Gossiped_invalid_transition
                , Some
                    ( "$state_hash was not selected over transition frontier \
                       root"
                    , metadata ) )
            in
            Error ()
        | Error `Already_in_frontier ->
            Logger.warn logger ~module_:__MODULE__ ~location:__LOC__ ~metadata
              "refusing to process $state_hash because is is already in the \
               transition frontier" ;
            return (Error ())
        | Error `Parent_missing_from_frontier ->
            Catchup_scheduler.watch catchup_scheduler
              ~timeout_duration:catchup_timeout_duration
              ~cached_transition:cached_initially_validated_transition ;
            return (Error ())
      in
      (* TODO: only access parent in transition frontier once (already done in call to validate dependencies) #2485 *)
      let parent_hash =
        Protocol_state.previous_state_hash
          (External_transition.protocol_state transition)
      in
      let parent_breadcrumb =
        Transition_frontier.find_exn frontier parent_hash
      in
      let%bind breadcrumb =
        cached_transform_deferred_result cached_initially_validated_transition
          ~transform_cached:(fun _ ->
            Transition_frontier.Breadcrumb.build ~logger ~verifier
              ~trust_system ~sender:(Some sender) ~parent:parent_breadcrumb
              ~transition:mostly_validated_transition )
          ~transform_result:(function
            | Error (`Invalid_staged_ledger_hash error)
            | Error (`Invalid_staged_ledger_diff error) ->
                Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                  ~metadata:
                    ( metadata
                    @ [("error", `String (Error.to_string_hum error))] )
                  "error while building breadcrumb in processor: $error" ;
                Deferred.return (Error ())
            | Error (`Fatal_error exn) ->
                raise exn
            | Ok breadcrumb ->
                Deferred.return (Ok breadcrumb) )
      in
      Deferred.map ~f:Result.return
        (add_and_finalize ~logger ~frontier ~catchup_scheduler
           ~processed_transition_writer ~only_if_present:false breadcrumb))

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
         , crash buffered
         , unit )
         Writer.t)
      ~(catchup_breadcrumbs_reader :
         (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t Rose_tree.t
         list
         Reader.t)
      ~(catchup_breadcrumbs_writer :
         ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t Rose_tree.t
           list
         , crash buffered
         , unit )
         Writer.t) ~processed_transition_writer =
    let catchup_scheduler =
      Catchup_scheduler.create ~logger ~verifier ~trust_system ~frontier
        ~time_controller ~catchup_job_writer ~catchup_breadcrumbs_writer
        ~clean_up_signal:clean_up_catchup_scheduler
    in
    let add_and_finalize =
      add_and_finalize ~frontier ~catchup_scheduler
        ~processed_transition_writer
    in
    let process_transition =
      process_transition ~logger ~trust_system ~verifier ~frontier
        ~catchup_scheduler ~processed_transition_writer
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
                           ~f:(add_and_finalize ~logger ~only_if_present:true) )
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
                     add_and_finalize ~logger ~only_if_present:false breadcrumb
                   with
                   | Ok () ->
                       ()
                   | Error err ->
                       Logger.error logger ~module_:__MODULE__
                         ~location:__LOC__
                         ~metadata:
                           [("error", `String (Error.to_string_hum err))]
                         "failed to attach breadcrumb proposed internally to \
                          transition frontier: $error" )
               | `Partially_valid_transition transition ->
                   process_transition ~transition ) ))
end
