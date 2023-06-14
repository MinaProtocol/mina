open Core_kernel
open Currency
open Async

module Make (Inputs : Intf.Inputs_intf) = struct
  module Work_spec = Snark_work_lib.Work.Single.Spec

  module Job_status = struct
    type t = Assigned of Time.t

    let is_old (Assigned at_time) ~now ~reassignment_wait =
      let max_age = Time.Span.of_ms (Float.of_int reassignment_wait) in
      let delta = Time.diff now at_time in
      Time.Span.( > ) delta max_age
  end

  let stmt_of_work_spec = One_or_two.map ~f:Work_spec.statement

  module State = struct
    type t =
      { mutable available_jobs :
          (Inputs.Transaction_witness.t, Inputs.Ledger_proof.t) Work_spec.t
          One_or_two.t
          Inputs.Transaction_snark_work.With_hash.t
          list
      ; jobs_seen :
          ( Inputs.Transaction_snark_work.Statement_with_hash.t
          , Job_status.t )
          Hashtbl.t
      ; reassignment_wait : int
      }

    let init :
           reassignment_wait:int
        -> frontier_broadcast_pipe:
             Inputs.Transition_frontier.t option
             Pipe_lib.Broadcast_pipe.Reader.t
        -> logger:Logger.t
        -> t =
     fun ~reassignment_wait ~frontier_broadcast_pipe ~logger ->
      let t =
        { available_jobs = []
        ; jobs_seen =
            Hashtbl.create
              (module Inputs.Transaction_snark_work.Statement_with_hash)
        ; reassignment_wait
        }
      in
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
                      t.available_jobs <-
                        List.map
                          ~f:
                            (Inputs.Transaction_snark_work.With_hash.create
                               ~f:stmt_of_work_spec )
                          new_available_jobs ) ;
                  Deferred.unit )
              |> Deferred.don't_wait_for ) ;
          Deferred.unit )
      |> Deferred.don't_wait_for ;
      t

    let all_unseen_works t ~logger =
      let unseen_works =
        List.filter t.available_jobs ~f:(fun job ->
            let stmt =
              Inputs.Transaction_snark_work.With_hash.map ~f:stmt_of_work_spec
                job
            in
            not (Hashtbl.mem t.jobs_seen stmt) )
      in
      [%log debug]
        ~metadata:
          [ ("num_available", `Int (List.length t.available_jobs))
          ; ("num_unseen", `Int (List.length unseen_works))
          ]
        "Filtered $num_available available works into $num_unseen unseen works \
         while selecting work for snark workers" ;
      unseen_works

    let remove_old_assignments t ~logger =
      O1trace.sync_thread "work_lib_state_remove_old_assignments" (fun () ->
          let now = Time.now () in
          Hashtbl.filteri_inplace t.jobs_seen ~f:(fun ~key:work ~data:status ->
              if
                Job_status.is_old status ~now
                  ~reassignment_wait:t.reassignment_wait
              then (
                [%log info]
                  ~metadata:
                    [ ( "work"
                      , Inputs.Transaction_snark_work.Statement_with_hash
                        .to_yojson work )
                    ]
                  "Waited too long to get work for $work. Ready to be \
                   reassigned" ;
                Mina_metrics.(
                  Counter.inc_one Snark_work.snark_work_timed_out_rpc) ;
                false )
              else true ) )

    let remove t x =
      Hashtbl.remove t.jobs_seen
        (Inputs.Transaction_snark_work.With_hash.map ~f:stmt_of_work_spec x)

    let set t x =
      Hashtbl.set t.jobs_seen
        ~key:
          (Inputs.Transaction_snark_work.With_hash.map ~f:stmt_of_work_spec x)
        ~data:(Job_status.Assigned (Time.now ()))
  end

  let does_not_have_better_fee ~snark_pool ~fee statements : bool =
    Option.value_map ~default:true
      (Inputs.Snark_pool.get_completed_work snark_pool statements)
      ~f:(fun priced_proof ->
        let competing_fee = Inputs.Transaction_snark_work.fee priced_proof in
        Fee.compare fee competing_fee < 0 )

  module For_tests = struct
    let does_not_have_better_fee = does_not_have_better_fee
  end

  let get_expensive_work ~snark_pool ~fee
      (jobs :
        ('a, 'b) Work_spec.t One_or_two.t
        Inputs.Transaction_snark_work.With_hash.t
        list ) :
      ('a, 'b) Work_spec.t One_or_two.t
      Inputs.Transaction_snark_work.With_hash.t
      list =
    O1trace.sync_thread "work_lib_get_expensive_work" (fun () ->
        List.filter jobs
          ~f:
            (Fn.compose
               (does_not_have_better_fee ~snark_pool ~fee)
               (Inputs.Transaction_snark_work.With_hash.map ~f:stmt_of_work_spec) ) )

  let all_pending_work ~snark_pool =
    let f =
      Fn.compose Option.is_none
      @@ Inputs.Snark_pool.get_completed_work snark_pool
    in
    List.filter ~f

  (*Seen/Unseen jobs that are not in the snark pool yet*)
  let pending_work_statements ~snark_pool ~fee_opt (state : State.t) =
    let all_todo_statements =
      List.map state.available_jobs
        ~f:(Inputs.Transaction_snark_work.With_hash.map ~f:stmt_of_work_spec)
    in
    let expensive_work statements ~fee =
      List.filter statements ~f:(does_not_have_better_fee ~snark_pool ~fee)
    in
    match fee_opt with
    | None ->
        all_pending_work ~snark_pool all_todo_statements
    | Some fee ->
        expensive_work all_todo_statements ~fee
end
