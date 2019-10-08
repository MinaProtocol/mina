(** [Catchup_scheduler] defines a process which schedules catchup jobs and
    monitors them for invalidation. This allows the transition frontier
    controller to handle out of order transitions without spinning up and
    tearing down catchup jobs constantly. The [Catchup_scheduler] must receive
    notifications whenever a new transition is added to the transition frontier
    so that it can determine if any pending catchup jobs can be invalidated.
    When catchup jobs are invalidated, the catchup scheduler extracts all of
    the invalidated catchup jobs and spins up a process to materialize
    breadcrumbs from those transitions, which will write the breadcrumbs back
    into the processor as if catchup had successfully completed. *)

open Core_kernel
open Async_kernel
open Pipe_lib.Strict_pipe
open Cache_lib
open Otp_lib
open Coda_base
open Coda_transition

module Make (Inputs : Inputs.S) = struct
  open Inputs
  module Breadcrumb_builder = Breadcrumb_builder.Make (Inputs)

  type t =
    { logger: Logger.t
    ; time_controller: Block_time.Controller.t
    ; catchup_job_writer:
        ( State_hash.t
          * ( External_transition.Initial_validated.t Envelope.Incoming.t
            , State_hash.t )
            Cached.t
            Rose_tree.t
            list
        , crash buffered
        , unit )
        Writer.t
          (** `collected_transitins` stores all seen transitions as its keys,
              and values are a list of direct children of those transitions.
              The invariant is that every collected transition would appear as
              a key in this table. Even if a transition doesn't has a child,
              its corresponding value in the hash table would just be an empty
              list. *)
    ; collected_transitions:
        ( External_transition.Initial_validated.t Envelope.Incoming.t
        , State_hash.t )
        Cached.t
        list
        State_hash.Table.t
          (** `parent_root_timeouts` stores the timeouts for catchup job. The
              keys are the missing transitions, and the values are the
              timeouts. *)
    ; parent_root_timeouts: unit Block_time.Timeout.t State_hash.Table.t
    ; breadcrumb_builder_supervisor:
        ( State_hash.t
        * ( External_transition.Initial_validated.t Envelope.Incoming.t
          , State_hash.t )
          Cached.t
          Rose_tree.t
          list )
        Capped_supervisor.t }

  let create ~logger ~verifier ~trust_system ~frontier ~time_controller
      ~(catchup_job_writer :
         ( State_hash.t
           * ( External_transition.Initial_validated.t Envelope.Incoming.t
             , State_hash.t )
             Cached.t
             Rose_tree.t
             list
         , crash buffered
         , unit )
         Writer.t)
      ~(catchup_breadcrumbs_writer :
         ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t Rose_tree.t
           list
           * [`Ledger_catchup of unit Ivar.t | `Catchup_scheduler]
         , crash buffered
         , unit )
         Writer.t) ~clean_up_signal =
    let collected_transitions = State_hash.Table.create () in
    let parent_root_timeouts = State_hash.Table.create () in
    upon (Ivar.read clean_up_signal) (fun () ->
        Hashtbl.iter collected_transitions ~f:(fun cached_transitions ->
            List.iter cached_transitions
              ~f:(Fn.compose ignore Cached.invalidate_with_failure) ) ;
        Hashtbl.iter parent_root_timeouts ~f:(fun timeout ->
            Block_time.Timeout.cancel time_controller timeout () ) ) ;
    let breadcrumb_builder_supervisor =
      Capped_supervisor.create ~job_capacity:30
        (fun (initial_hash, transition_branches) ->
          match%map
            Breadcrumb_builder.build_subtrees_of_breadcrumbs ~logger ~verifier
              ~trust_system ~frontier ~initial_hash transition_branches
          with
          | Ok trees_of_breadcrumbs ->
              Writer.write catchup_breadcrumbs_writer
                (trees_of_breadcrumbs, `Catchup_scheduler)
          | Error err ->
              Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                !"Error during buildup breadcrumbs inside catchup_scheduler: %s"
                (Error.to_string_hum err) ;
              List.iter transition_branches ~f:(fun subtree ->
                  Rose_tree.iter subtree ~f:(fun cached_transition ->
                      Cached.invalidate_with_failure cached_transition
                      |> ignore ) ) )
    in
    { logger
    ; collected_transitions
    ; time_controller
    ; catchup_job_writer
    ; parent_root_timeouts
    ; breadcrumb_builder_supervisor }

  let mem t transition =
    Hashtbl.mem t.collected_transitions
      (External_transition.parent_hash transition)

  let has_timeout t transition =
    Hashtbl.mem t.parent_root_timeouts
      (External_transition.parent_hash transition)

  let is_empty t =
    Hashtbl.is_empty t.collected_transitions
    && Hashtbl.is_empty t.parent_root_timeouts

  let cancel_timeout t hash =
    let remaining_time =
      Option.map
        (Hashtbl.find t.parent_root_timeouts hash)
        ~f:Block_time.Timeout.remaining_time
    in
    let cancel timeout =
      Block_time.Timeout.cancel t.time_controller timeout ()
    in
    Hashtbl.change t.parent_root_timeouts hash
      ~f:Fn.(compose (const None) (Option.iter ~f:cancel)) ;
    remaining_time

  let rec extract_subtree t cached_transition =
    let {With_hash.hash; _}, _ =
      Envelope.Incoming.data (Cached.peek cached_transition)
    in
    let successors =
      Option.value ~default:[] (Hashtbl.find t.collected_transitions hash)
    in
    Rose_tree.T (cached_transition, List.map successors ~f:(extract_subtree t))

  let extract_forest t hash =
    let successors =
      Option.value ~default:[] (Hashtbl.find t.collected_transitions hash)
    in
    (hash, List.map successors ~f:(extract_subtree t))

  let rec remove_tree t parent_hash =
    let children =
      Option.value ~default:[]
        (Hashtbl.find t.collected_transitions parent_hash)
    in
    Hashtbl.remove t.collected_transitions parent_hash ;
    Coda_metrics.(
      Gauge.dec_one
        Transition_frontier_controller.transitions_in_catchup_scheduler) ;
    List.iter children ~f:(fun child ->
        let {With_hash.hash; _}, _ =
          Envelope.Incoming.data (Cached.peek child)
        in
        remove_tree t hash )

  let watch t ~timeout_duration ~cached_transition =
    let transition_with_hash, _ =
      Envelope.Incoming.data (Cached.peek cached_transition)
    in
    let hash = With_hash.hash transition_with_hash in
    let parent_hash =
      With_hash.data transition_with_hash |> External_transition.parent_hash
    in
    let make_timeout duration =
      Block_time.Timeout.create t.time_controller duration ~f:(fun _ ->
          let forest = extract_forest t parent_hash in
          Hashtbl.remove t.parent_root_timeouts parent_hash ;
          Coda_metrics.(
            Gauge.dec_one
              Transition_frontier_controller.transitions_in_catchup_scheduler) ;
          remove_tree t parent_hash ;
          Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
            ~metadata:
              [ ("parent_hash", Coda_base.State_hash.to_yojson parent_hash)
              ; ( "duration"
                , `Int (Block_time.Span.to_ms duration |> Int64.to_int_trunc)
                )
              ; ( "cached_transition"
                , With_hash.data transition_with_hash
                  |> External_transition.to_yojson ) ]
            "Timed out waiting for the parent of $cached_transition after \
             $duration ms, signalling a catchup job" ;
          (* it's ok to create a new thread here because the thread essentially does no work *)
          if Writer.is_closed t.catchup_job_writer then
            Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
              "catchup job pipe was closed; attempt to write to closed pipe"
          else Writer.write t.catchup_job_writer forest )
    in
    match Hashtbl.find t.collected_transitions parent_hash with
    | None ->
        let remaining_time = cancel_timeout t hash in
        Hashtbl.add_exn t.collected_transitions ~key:parent_hash
          ~data:[cached_transition] ;
        Hashtbl.update t.collected_transitions hash
          ~f:(Option.value ~default:[]) ;
        Hashtbl.add t.parent_root_timeouts ~key:parent_hash
          ~data:
            (make_timeout
               (Option.fold remaining_time ~init:timeout_duration
                  ~f:(fun _ remaining_time ->
                    Block_time.Span.min remaining_time timeout_duration )))
        |> ignore ;
        Coda_metrics.(
          Gauge.inc_one
            Transition_frontier_controller.transitions_in_catchup_scheduler)
    | Some cached_sibling_transitions ->
        if
          List.exists cached_sibling_transitions
            ~f:(fun cached_sibling_transition ->
              let {With_hash.hash= sibling_hash; _}, _ =
                Envelope.Incoming.data (Cached.peek cached_sibling_transition)
              in
              State_hash.equal hash sibling_hash )
        then
          Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
            ~metadata:[("state_hash", State_hash.to_yojson hash)]
            "Received request to watch transition for catchup that already is \
             being watched: $state_hash"
        else
          let (_ : Block_time.Span.t option) = cancel_timeout t hash in
          Hashtbl.set t.collected_transitions ~key:parent_hash
            ~data:(cached_transition :: cached_sibling_transitions) ;
          Hashtbl.update t.collected_transitions hash
            ~f:(Option.value ~default:[]) ;
          Coda_metrics.(
            Gauge.inc_one
              Transition_frontier_controller.transitions_in_catchup_scheduler)

  let notify t ~hash =
    if
      (Option.is_none @@ Hashtbl.find t.parent_root_timeouts hash)
      && (Option.is_some @@ Hashtbl.find t.collected_transitions hash)
    then
      Or_error.errorf
        !"Received notification to kill catchup job on a \
          non-parent_root_transition: %{sexp: State_hash.t}"
        hash
    else
      let (_ : Block_time.Span.t option) = cancel_timeout t hash in
      Option.iter (Hashtbl.find t.collected_transitions hash)
        ~f:(fun collected_transitions ->
          let transition_subtrees =
            List.map collected_transitions ~f:(extract_subtree t)
          in
          Capped_supervisor.dispatch t.breadcrumb_builder_supervisor
            (hash, transition_subtrees) ) ;
      remove_tree t hash ;
      Or_error.return ()
end
