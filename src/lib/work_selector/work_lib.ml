open Core_kernel
open Currency
open Async

module Make (Inputs : Intf.Inputs_intf) = struct
  module Inputs = Inputs
  module Work_spec = Snark_work_lib.Work.Single.Spec

  module State = struct
    module Job_key = struct
      type t = Transaction_snark.Statement.t One_or_two.t
      [@@deriving compare, equal, sexp, to_yojson]

      let of_job x = One_or_two.map ~f:Work_spec.statement x
    end

    module Job_key_set = Set.Make (Job_key)

    type t =
      { mutable available_jobs :
          ( Inputs.Transaction_witness.t
          , Inputs.Ledger_proof.Cached.t )
          Work_spec.t
          One_or_two.t
          list
            (** Jobs received from [frontier_broadcast_pipe], would be updated
                whenever the pipe has broadcasted new frontier. The works
                between consecutive frontier broadcasts should be largely
                identical. *)
      ; mutable jobs_scheduled : Job_key_set.t
            (** Jobs that are already scheduled by the work selector. This is
                only cleaned up when a new batch of jobs arrived. *)
            (* WARN: Don't replace this with a hashset! Hashing statements are
               very slow! *)
      }

    let init :
           frontier_broadcast_pipe:
             Inputs.Transition_frontier.t option
             Pipe_lib.Broadcast_pipe.Reader.t
        -> logger:Logger.t
        -> t =
     fun ~frontier_broadcast_pipe ~logger ->
      let t = { available_jobs = []; jobs_scheduled = Job_key_set.empty } in
      Pipe_lib.Broadcast_pipe.Reader.iter frontier_broadcast_pipe
        ~f:(fun frontier_opt ->
          ( match frontier_opt with
          | None ->
              [%log debug] "No frontier, setting available work to be empty" ;
              t.available_jobs <- []
          | Some frontier ->
              Pipe_lib.Broadcast_pipe.Reader.iter
                (Inputs.Transition_frontier.best_tip_pipe frontier) ~f:(fun _ ->
                  let best_tip_staged_ledger =
                    Inputs.Transition_frontier.best_tip_staged_ledger frontier
                  in
                  let start_time = Time.now () in
                  ( match
                      Inputs.Staged_ledger.all_work_pairs best_tip_staged_ledger
                        ~get_state:
                          (Inputs.Transition_frontier.get_protocol_state
                             frontier )
                    with
                  | Error e ->
                      [%log fatal]
                        "Error occured when updating available work: $error"
                        ~metadata:[ ("error", Error_json.error_to_yojson e) ]
                  | Ok new_available_jobs ->
                      let end_time = Time.now () in
                      [%log info] "Updating new available work took $time ms"
                        ~metadata:
                          [ ( "time"
                            , `Float
                                ( Time.diff end_time start_time
                                |> Time.Span.to_ms ) )
                          ] ;
                      t.available_jobs <- new_available_jobs ;
                      let new_job_keys =
                        List.map ~f:Job_key.of_job t.available_jobs
                        |> Job_key_set.of_list
                      in
                      t.jobs_scheduled <-
                        Job_key_set.inter t.jobs_scheduled new_job_keys ) ;
                  Deferred.unit )
              |> Deferred.don't_wait_for ) ;
          Deferred.unit )
      |> Deferred.don't_wait_for ;
      t

    let mark_scheduled t x =
      t.jobs_scheduled <-
        Job_key_set.add t.jobs_scheduled
          (One_or_two.map ~f:Work_spec.statement x)

    let does_not_have_better_fee ~snark_pool ~fee
        (statements : Inputs.Transaction_snark_work.Statement.t) : bool =
      Option.value_map ~default:true
        (Inputs.Snark_pool.get_completed_work snark_pool statements)
        ~f:(fun priced_proof ->
          let competing_fee =
            Inputs.Transaction_snark_work.Checked.fee priced_proof
          in
          Fee.compare fee competing_fee < 0 )

    let all_unscheduled_expensive_works ~snark_pool ~fee (t : t) =
      O1trace.sync_thread "work_lib_all_unscheduled_expensive_works" (fun () ->
          List.filter t.available_jobs ~f:(fun job ->
              let job_key = Job_key.of_job job in
              (not (Job_key_set.mem t.jobs_scheduled job_key))
              && does_not_have_better_fee ~snark_pool ~fee job_key ) )
  end

  let all_pending_work ~snark_pool statements =
    List.filter statements ~f:(fun st ->
        Option.is_none (Inputs.Snark_pool.get_completed_work snark_pool st) )

  let all_work ~snark_pool (state : State.t) =
    O1trace.sync_thread "work_lib_all_unseen_works" (fun () ->
        List.map state.available_jobs ~f:(fun job ->
            let statement = One_or_two.map ~f:Work_spec.statement job in
            let fee_prover_opt =
              Option.map
                (Inputs.Snark_pool.get_completed_work snark_pool statement)
                ~f:(fun (p : Inputs.Transaction_snark_work.Checked.t) ->
                  ( Inputs.Transaction_snark_work.Checked.fee p
                  , Inputs.Transaction_snark_work.Checked.prover p ) )
            in
            (job, fee_prover_opt) ) )

  let all_completed_work ~snark_pool statements =
    List.filter_map statements ~f:(fun st ->
        Inputs.Snark_pool.get_completed_work snark_pool st )

  (*Seen/Unseen jobs that are not in the snark pool yet*)
  let pending_work_statements ~snark_pool ~fee_opt (state : State.t) =
    let all_todo_statements =
      List.map state.available_jobs ~f:(One_or_two.map ~f:Work_spec.statement)
    in
    let expensive_work statements ~fee =
      List.filter statements
        ~f:(State.does_not_have_better_fee ~snark_pool ~fee)
    in
    match fee_opt with
    | None ->
        all_pending_work ~snark_pool all_todo_statements
    | Some fee ->
        expensive_work all_todo_statements ~fee

  let completed_work_statements ~snark_pool (state : State.t) =
    let all_todo_statements =
      List.map state.available_jobs ~f:(One_or_two.map ~f:Work_spec.statement)
    in
    all_completed_work ~snark_pool all_todo_statements

  module For_tests = struct
    let does_not_have_better_fee = State.does_not_have_better_fee
  end
end
