open Core_kernel
open Currency
open Async

module Make (Inputs : Intf.Inputs_intf) = struct
  module Inputs = Inputs
  module Work_spec = Snark_work_lib.Work.Single.Spec
  module SL = Inputs.Staged_ledger

  (* The statement bundle of a job bundle; [None] if any sub-job's statement
     cannot be formed (a merge job whose sub-statements do not merge). *)
  let statement_bundle (job : SL.Available_job.t One_or_two.t) :
      Transaction_snark.Statement.t One_or_two.t option =
    match One_or_two.map job ~f:SL.statement_of_job with
    | `One (Some a) ->
        Some (`One a)
    | `Two (Some a, Some b) ->
        Some (`Two (a, b))
    | _ ->
        None

  let yojson_summary (job : SL.Available_job.t One_or_two.t) =
    let f j =
      match SL.job_transaction j with
      | Some txn ->
          Inputs.Transaction.yojson_summary txn
      | None ->
          `List [ `String "merge" ]
    in
    `List (One_or_two.map ~f job |> One_or_two.to_list)

  module State = struct
    module Job_key = struct
      module T = struct
        type t = Transaction_snark.Statement.t One_or_two.t
        [@@deriving compare, sexp, to_yojson, hash]
      end

      include T
      include Comparable.Make (T)
    end

    (* A statement bundle (all the selector and the snark pool need) paired with
       the job(s) to build a proving spec from if it is dispatched. *)
    type candidate = Job_key.t * SL.Available_job.t One_or_two.t

    let no_get_state _ = Or_error.error_string "work_selector: no frontier yet"

    type t =
      { mutable available_jobs : candidate list
            (** The pending work as (statement, job) pairs — the statement is all
                that selection and the snark pool need. Updated whenever the
                best-tip pipe broadcasts. *)
      ; mutable jobs_scheduled : Job_key.Set.t
            (* WARN: Don't replace this with a hashset! Hashing statements are
               very slow! *)
            (** Statements already scheduled by the selector; pruned when a new
                batch arrives. *)
      ; mutable get_state :
          Mina_base.State_hash.t -> Mina_state.Protocol_state.value Or_error.t
            (** Captured per best-tip, to build a job's proving spec when it is
                dispatched. *)
      }

    let init ~frontier_broadcast_pipe ~logger =
      let t =
        { available_jobs = []
        ; jobs_scheduled = Job_key.Set.empty
        ; get_state = no_get_state
        }
      in
      Pipe_lib.Broadcast_pipe.Reader.iter frontier_broadcast_pipe
        ~f:(fun frontier_opt ->
          ( match frontier_opt with
          | None ->
              [%log debug] "No frontier, setting available work to be empty" ;
              t.available_jobs <- [] ;
              t.get_state <- no_get_state
          | Some frontier ->
              Pipe_lib.Broadcast_pipe.Reader.iter
                (Inputs.Transition_frontier.best_tip_pipe frontier) ~f:(fun _ ->
                  let best_tip_staged_ledger =
                    Inputs.Transition_frontier.best_tip_staged_ledger frontier
                  in
                  let get_state =
                    Inputs.Transition_frontier.get_protocol_state frontier
                  in
                  let start_time = Time.now () in
                  let new_available_jobs =
                    List.filter_map (SL.all_work_jobs best_tip_staged_ledger)
                      ~f:(fun job ->
                        match statement_bundle job with
                        | Some key ->
                            Some (key, job)
                        | None ->
                            [%log warn]
                              "Skipping a work bundle whose statement could \
                               not be formed" ;
                            None )
                  in
                  let end_time = Time.now () in
                  [%log info] "Updating new available work took $time ms"
                    ~metadata:
                      [ ( "time"
                        , `Float
                            (Time.diff end_time start_time |> Time.Span.to_ms)
                        )
                      ] ;
                  let old_available_jobs = t.available_jobs in
                  let old_job_keys =
                    List.map ~f:fst old_available_jobs |> Job_key.Set.of_list
                  in
                  t.available_jobs <- new_available_jobs ;
                  t.get_state <- get_state ;
                  let new_job_keys =
                    List.map ~f:fst new_available_jobs |> Job_key.Set.of_list
                  in
                  let removed_job_keys =
                    Job_key.Set.diff old_job_keys new_job_keys
                  in
                  let added_job_keys =
                    Job_key.Set.diff new_job_keys old_job_keys
                  in
                  List.iter old_available_jobs ~f:(fun (key, job) ->
                      if Job_key.Set.mem removed_job_keys key then
                        [%log internal] "Snark_work_removed"
                          ~metadata:
                            [ ( "work_ids"
                              , Transaction_snark_work.Statement.compact_json
                                  key )
                            ; ("txs", yojson_summary job)
                            ] ) ;
                  List.iter new_available_jobs ~f:(fun (key, job) ->
                      if Job_key.Set.mem added_job_keys key then
                        [%log internal] "Snark_work_added"
                          ~metadata:
                            [ ( "work_ids"
                              , Transaction_snark_work.Statement.compact_json
                                  key )
                            ; ("txs", yojson_summary job)
                            ] ) ;
                  t.jobs_scheduled <-
                    Job_key.Set.inter t.jobs_scheduled new_job_keys ;
                  Deferred.unit )
              |> Deferred.don't_wait_for ) ;
          Deferred.unit )
      |> Deferred.don't_wait_for ;
      t

    let mark_scheduled ~logger t ((key, job) : candidate) =
      [%log internal] "Snark_work_scheduled"
        ~metadata:
          [ ("work_ids", Transaction_snark_work.Statement.compact_json key)
          ; ("txs", yojson_summary job)
          ] ;
      t.jobs_scheduled <- Job_key.Set.add t.jobs_scheduled key

    let does_not_have_better_fee ~snark_pool ~fee
        (statements : Inputs.Transaction_snark_work.Statement.t) : bool =
      Option.value_map ~default:true
        (Inputs.Snark_pool.get_completed_work snark_pool statements)
        ~f:(fun priced_proof ->
          let competing_fee =
            Inputs.Transaction_snark_work.Checked.fee priced_proof
          in
          Fee.compare fee competing_fee < 0 )

    let all_unscheduled_expensive_works ~snark_pool ~fee (t : t) :
        candidate list =
      O1trace.sync_thread "work_lib_all_unscheduled_expensive_works" (fun () ->
          List.filter t.available_jobs ~f:(fun (key, _job) ->
              (not (Job_key.Set.mem t.jobs_scheduled key))
              && does_not_have_better_fee ~snark_pool ~fee key ) )

    (* Building the spec is the one point a job's witness is needed: it is done
       here, for the single bundle being dispatched to a worker. *)
    let schedule_and_build_spec ~logger t ((_key, job) as candidate) =
      mark_scheduled ~logger t candidate ;
      match
        One_or_two.Or_error.map job
          ~f:(SL.single_spec_of_job ~get_state:t.get_state)
      with
      | Ok spec ->
          Some spec
      | Error e ->
          [%log error]
            "Could not build the proving spec for a scheduled job: $error"
            ~metadata:[ ("error", Error_json.error_to_yojson e) ] ;
          None
  end

  let all_pending_work ~snark_pool statements =
    List.filter statements ~f:(fun st ->
        Option.is_none (Inputs.Snark_pool.get_completed_work snark_pool st) )

  (* For consumers that genuinely need the full proving specs of all pending work
     — the GraphQL [pendingSnarkWork] query, used by external workers to fetch
     work — build them here, on request. *)
  let all_work ~snark_pool (state : State.t) =
    O1trace.sync_thread "work_lib_all_unseen_works" (fun () ->
        List.filter_map state.available_jobs ~f:(fun (key, job) ->
            match
              One_or_two.Or_error.map job
                ~f:
                  (Inputs.Staged_ledger.single_spec_of_job
                     ~get_state:state.get_state )
            with
            | Error _ ->
                None
            | Ok spec ->
                let fee_prover_opt =
                  Option.map
                    (Inputs.Snark_pool.get_completed_work snark_pool key)
                    ~f:(fun (p : Inputs.Transaction_snark_work.Checked.t) ->
                      ( Inputs.Transaction_snark_work.Checked.fee p
                      , Inputs.Transaction_snark_work.Checked.prover p ) )
                in
                Some (spec, fee_prover_opt) ) )

  let all_completed_work ~snark_pool statements =
    List.filter_map statements ~f:(fun st ->
        Inputs.Snark_pool.get_completed_work snark_pool st )

  (*Seen/Unseen jobs that are not in the snark pool yet*)
  let pending_work_statements ~snark_pool ~fee_opt (state : State.t) =
    let all_todo_statements = List.map state.available_jobs ~f:fst in
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
    let all_todo_statements = List.map state.available_jobs ~f:fst in
    all_completed_work ~snark_pool all_todo_statements

  module For_tests = struct
    let does_not_have_better_fee = State.does_not_have_better_fee
  end
end
