(**
 * [Catchup_monitor] defines a process which schedules catchup jobs and
 * monitors them for invalidation. This allows the transition frontier
 * controller to handle out of order transitions without spinning up
 * and tearing down catchup jobs constantly. The [Catchup_monitor] must
 * receive notifications whenever a new transition is added to the
 * transition frontier so that it can determine if any pending catchup
 * jobs can be invalidated. When catchup jobs are invalidated, the
 * catchup monitor extracts all of the invalidated catchup jobs and
 * spins up a process to materialize breadcrumbs from those transitions,
 * which will write the breadcrumbs back into the processor as if
 * catchup had successfully completed.
 *)

open Core_kernel
open Async_kernel
open Pipe_lib.Strict_pipe
open Otp_lib
open Coda_base

module Make (Inputs : Inputs.S) = struct
  open Inputs
  open Consensus.Mechanism

  type t =
    { logger: Logger.t
    ; time_controller: Time.Controller.t
    ; catchup_job_writer:
        ( (External_transition.Verified.t, State_hash.t) With_hash.t
        , synchronous
        , unit Deferred.t )
        Writer.t
    ; timeouts:
        ( (External_transition.Verified.t, State_hash.t) With_hash.t
        , unit Time.Timeout.t )
        List.Assoc.t
        State_hash.Table.t
    ; breadcrumb_builder_supervisor:
        (External_transition.Verified.t, State_hash.t) With_hash.t Rose_tree.t
        list
        Capped_supervisor.t }

  let create ~logger ~frontier ~time_controller ~catchup_job_writer
      ~catchup_breadcrumbs_writer =
    let logger = Logger.child logger "catchup_monitor" in
    let timeouts = State_hash.Table.create () in
    let breadcrumb_builder_supervisor =
      Capped_supervisor.create ~job_capacity:5 (fun transition_branches ->
          let%bind breadcrumbs =
            Deferred.List.map transition_branches ~f:(fun branch ->
                let (Rose_tree.T (branch_base, _)) = branch in
                let branch_parent_hash =
                  With_hash.data branch_base
                  |> External_transition.Verified.protocol_state
                  |> Protocol_state.previous_state_hash
                in
                let branch_parent =
                  Transition_frontier.find_exn frontier branch_parent_hash
                in
                Rose_tree.Deferred.fold_map branch ~init:branch_parent
                  ~f:(fun parent transition_with_hash ->
                    Deferred.create (fun ivar ->
                        Transition_frontier.Breadcrumb.build ~logger ~parent
                          ~transition_with_hash
                        |> Or_error.ok_exn |> Ivar.fill ivar ) ) )
          in
          Writer.write catchup_breadcrumbs_writer breadcrumbs )
    in
    { logger
    ; time_controller
    ; catchup_job_writer
    ; timeouts
    ; breadcrumb_builder_supervisor }

  let watch t ~timeout_duration ~transition =
    let hash = With_hash.hash transition in
    let parent_hash =
      With_hash.data transition |> External_transition.Verified.protocol_state
      |> Protocol_state.previous_state_hash
    in
    let make_timeout () =
      Time.Timeout.create t.time_controller timeout_duration ~f:(fun _ ->
          (* it's ok to create a new thread here because the thread essentially does no work *)
          don't_wait_for (Writer.write t.catchup_job_writer transition) )
    in
    Hashtbl.update t.timeouts parent_hash ~f:(function
      | None -> [(transition, make_timeout ())]
      | Some entries ->
          if
            List.exists entries ~f:(fun (trans, _) ->
                State_hash.equal hash (With_hash.hash trans) )
          then (
            Logger.info t.logger
              !"Received request to watch transition for catchup that already \
                was being watched: %{sexp: State_hash.t}"
              hash ;
            entries )
          else (transition, make_timeout ()) :: entries )

  let rec extract t (transition, timeout) =
    Time.Timeout.cancel t.time_controller timeout () ;
    let successors =
      Option.value ~default:[]
        (Hashtbl.find t.timeouts (With_hash.hash transition))
    in
    Rose_tree.T (transition, List.map successors ~f:(extract t))

  let notify t ~transition =
    Option.iter
      (Hashtbl.find t.timeouts (With_hash.hash transition))
      ~f:(fun entries ->
        let transition_branches = List.map entries ~f:(extract t) in
        Capped_supervisor.dispatch t.breadcrumb_builder_supervisor
          transition_branches )
end
