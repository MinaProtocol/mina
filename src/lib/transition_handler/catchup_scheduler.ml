(**
 * [Catchup_scheduler] defines a process which schedules catchup jobs and
 * monitors them for invalidation. This allows the transition frontier
 * controller to handle out of order transitions without spinning up
 * and tearing down catchup jobs constantly. The [Catchup_scheduler] must
 * receive notifications whenever a new transition is added to the
 * transition frontier so that it can determine if any pending catchup
 * jobs can be invalidated. When catchup jobs are invalidated, the
 * catchup scheduler extracts all of the invalidated catchup jobs and
 * spins up a process to materialize breadcrumbs from those transitions,
 * which will write the breadcrumbs back into the processor as if
 * catchup had successfully completed.
 *)

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
    ; timeouts:
        ( ( (External_transition.Verified.t, State_hash.t) With_hash.t
          , State_hash.t )
          Cached.t
        , unit Time.Timeout.t )
        List.Assoc.t
        State_hash.Table.t
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
              |> Cached.lift_deferred
            in
            match Cached.lift_result cached_breadcrumb_result with
            | Error (`Validation_error e) ->
                (* TODO: Punish *)
                Logger.error logger
                  "invalid transition in catchup scheduler breadcrumb \
                   builder: %s"
                  (Error.to_string_hum e) ;
                raise (Error.to_exn e)
            | Error (`Fatal_error e) -> raise e
            | Ok breadcrumb -> breadcrumb ) )

  let create ~logger ~frontier ~time_controller ~catchup_job_writer
      ~catchup_breadcrumbs_writer =
    let logger = Logger.child logger "catchup_scheduler" in
    let timeouts = State_hash.Table.create () in
    let breadcrumb_builder_supervisor =
      Capped_supervisor.create ~job_capacity:5 (fun transition_branches ->
          build_breadcrumbs ~logger ~frontier transition_branches
          >>= Writer.write catchup_breadcrumbs_writer )
    in
    { logger
    ; time_controller
    ; catchup_job_writer
    ; timeouts
    ; breadcrumb_builder_supervisor }

  let watch t ~timeout_duration ~cached_transition =
    let hash = With_hash.hash (Cached.peek cached_transition) in
    let parent_hash =
      With_hash.data (Cached.peek cached_transition)
      |> External_transition.Verified.protocol_state
      |> Protocol_state.previous_state_hash
    in
    let make_timeout () =
      Time.Timeout.create t.time_controller timeout_duration ~f:(fun _ ->
          (* it's ok to create a new thread here because the thread essentially does no work *)
          don't_wait_for (Writer.write t.catchup_job_writer cached_transition)
      )
    in
    Hashtbl.update t.timeouts parent_hash ~f:(function
      | None -> [(cached_transition, make_timeout ())]
      | Some entries ->
          if
            List.exists entries ~f:(fun (trans, _) ->
                State_hash.equal hash (With_hash.hash (Cached.peek trans)) )
          then (
            Logger.info t.logger
              !"Received request to watch transition for catchup that already \
                was being watched: %{sexp: State_hash.t}"
              hash ;
            entries )
          else (cached_transition, make_timeout ()) :: entries )

  let rec extract_subtree t (cached_transition, timeout) =
    Time.Timeout.cancel t.time_controller timeout () ;
    let successors =
      Option.value ~default:[]
        (Hashtbl.find t.timeouts
           (With_hash.hash (Cached.peek cached_transition)))
    in
    Rose_tree.T (cached_transition, List.map successors ~f:(extract_subtree t))

  let notify t ~transition =
    Option.iter
      (Hashtbl.find t.timeouts (With_hash.hash transition))
      ~f:(fun entries ->
        Hashtbl.remove t.timeouts (With_hash.hash transition) ;
        let transition_subtrees = List.map entries ~f:(extract_subtree t) in
        Capped_supervisor.dispatch t.breadcrumb_builder_supervisor
          transition_subtrees )
end
