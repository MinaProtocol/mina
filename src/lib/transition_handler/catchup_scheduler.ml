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

module Make (Inputs : Inputs.S) = struct
  open Inputs
  open Consensus

  type t =
    { logger: Logger.t
    ; time_controller: Time.Controller.t
    ; catchup_job_writer:
        ( ( (External_transition.Verified.t, State_hash.t) With_hash.t
          , State_hash.t )
          Cached.t
        , synchronous
        , unit Deferred.t )
        Writer.t
          (** `collected_transitins` stores all seen transitions as its keys,
              and values are a list of direct children of those transitions.
              The invariant is that every collected transition would appear as
              a key in this table. Even if a transition doesn't has a child,
              its corresponding value in the hash table would just be an empty
              list. *)
    ; collected_transitions:
        ( (External_transition.Verified.t, State_hash.t) With_hash.t
        , State_hash.t )
        Cached.t
        list
        State_hash.Table.t
          (** `parent_root_timeouts` stores the timeouts for catchup job. The
              keys are the missing transitions, and the values are the
              timeouts. *)
    ; parent_root_timeouts: unit Time.Timeout.t State_hash.Table.t
    ; breadcrumb_builder_supervisor:
        ( (External_transition.Verified.t, State_hash.t) With_hash.t
        , State_hash.t )
        Cached.t
        Rose_tree.t
        list
        Capped_supervisor.t }

  let build_breadcrumbs ~logger ~frontier transition_subtrees =
    Deferred.List.map transition_subtrees
      ~f:(fun (Rose_tree.T (subtree_root, _) as subtree) ->
        let subtree_root_parent_hash =
          With_hash.data (Cached.peek subtree_root)
          |> External_transition.Verified.protocol_state
          |> Protocol_state.previous_state_hash
        in
        let branch_parent =
          Transition_frontier.find_exn frontier subtree_root_parent_hash
        in
        Rose_tree.Deferred.fold_map subtree
          ~init:(Cached.phantom branch_parent)
          ~f:(fun parent cached_transition_with_hash ->
            let%map cached_breadcrumb_result =
              Cached.transform cached_transition_with_hash
                ~f:(fun transition_with_hash ->
                  Transition_frontier.Breadcrumb.build ~logger
                    ~parent:(Cached.peek parent) ~transition_with_hash )
              |> Cached.sequence_deferred
            in
            match Cached.sequence_result cached_breadcrumb_result with
            | Error (`Validation_error e) ->
                (* TODO: Punish *)
                Logger.faulty_peer logger
                  "invalid transition in catchup scheduler breadcrumb \
                   builder: %s"
                  (Error.to_string_hum e) ;
                raise (Error.to_exn e)
            | Error (`Fatal_error e) -> raise e
            | Ok breadcrumb -> breadcrumb ) )

  let create ~logger ~frontier ~time_controller ~catchup_job_writer
      ~catchup_breadcrumbs_writer =
    let logger = Logger.child logger "catchup_scheduler" in
    let collected_transitions = State_hash.Table.create () in
    let parent_root_timeouts = State_hash.Table.create () in
    let breadcrumb_builder_supervisor =
      Capped_supervisor.create ~job_capacity:5 (fun transition_branches ->
          build_breadcrumbs ~logger ~frontier transition_branches
          >>= Writer.write catchup_breadcrumbs_writer )
    in
    { logger
    ; collected_transitions
    ; time_controller
    ; catchup_job_writer
    ; parent_root_timeouts
    ; breadcrumb_builder_supervisor }

  let cancel_timeout t hash =
    let remaining_time =
      Option.map
        (Hashtbl.find t.parent_root_timeouts hash)
        ~f:Time.Timeout.remaining_time
    in
    let cancel timeout = Time.Timeout.cancel t.time_controller timeout () in
    Hashtbl.change t.parent_root_timeouts hash
      ~f:Fn.(compose (const None) (Option.iter ~f:cancel)) ;
    remaining_time

  let cancel_child_timeout t parent_hash =
    let open Option.Let_syntax in
    let%bind children = Hashtbl.find t.collected_transitions parent_hash in
    let remaining_times =
      List.(
        filter_opt
        @@ map children ~f:(fun child ->
               cancel_timeout t (With_hash.hash (Cached.peek child)) ))
    in
    List.min_elt remaining_times ~compare:Time.Span.compare

  let watch t ~timeout_duration ~cached_transition =
    let hash = With_hash.hash (Cached.peek cached_transition) in
    let parent_hash =
      With_hash.data (Cached.peek cached_transition)
      |> External_transition.Verified.protocol_state
      |> Protocol_state.previous_state_hash
    in
    let make_timeout duration =
      Time.Timeout.create t.time_controller duration ~f:(fun _ ->
          (* it's ok to create a new thread here because the thread essentially does no work *)
          don't_wait_for (Writer.write t.catchup_job_writer cached_transition)
      )
    in
    Hashtbl.update t.collected_transitions parent_hash ~f:(function
      | None ->
          let remaining_time = cancel_child_timeout t hash in
          Hashtbl.add_exn t.collected_transitions ~key:hash ~data:[] ;
          Hashtbl.add_exn t.parent_root_timeouts ~key:parent_hash
            ~data:
              (make_timeout
                 (Option.value remaining_time ~default:timeout_duration)) ;
          [cached_transition]
      | Some sibling_transitions ->
          if
            List.exists sibling_transitions ~f:(fun collected_transition ->
                State_hash.equal hash
                @@ With_hash.hash (Cached.peek collected_transition) )
          then (
            Logger.info t.logger
              !"Received request to watch transition for catchup that already \
                was being watched: %{sexp: State_hash.t}"
              hash ;
            sibling_transitions )
          else
            let _ : Time.Span.t option = cancel_child_timeout t hash in
            Hashtbl.add_exn t.collected_transitions ~key:hash ~data:[] ;
            cached_transition :: sibling_transitions )

  let rec extract_subtree t cached_transition =
    let successors =
      Option.value ~default:[]
        (Hashtbl.find t.collected_transitions
           (With_hash.hash (Cached.peek cached_transition)))
    in
    Rose_tree.T (cached_transition, List.map successors ~f:(extract_subtree t))

  let rec remove_tree t parent_hash =
    let children =
      Option.value ~default:[]
        (Hashtbl.find t.collected_transitions parent_hash)
    in
    Hashtbl.remove t.collected_transitions parent_hash ;
    List.iter children ~f:(fun child ->
        remove_tree t (With_hash.hash (Cached.peek child)) )

  let notify t ~transition =
    let hash = With_hash.hash transition in
    if
      (Option.is_none @@ Hashtbl.find t.parent_root_timeouts hash)
      && (Option.is_some @@ Hashtbl.find t.collected_transitions hash)
    then
      Or_error.errorf
        !"Received notification to kill catchup job on a \
          non-parent_root_transition: %{sexp: State_hash.t}"
        hash
    else
      let _ : Time.Span.t option = cancel_timeout t hash in
      Option.iter (Hashtbl.find t.collected_transitions hash)
        ~f:(fun collected_transitions ->
          let transition_subtrees =
            List.map collected_transitions ~f:(extract_subtree t)
          in
          Capped_supervisor.dispatch t.breadcrumb_builder_supervisor
            transition_subtrees ) ;
      remove_tree t hash ;
      Or_error.return ()
end
