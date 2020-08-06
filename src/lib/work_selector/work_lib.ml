open Core_kernel
open Currency

module Make (Inputs : Intf.Inputs_intf) = struct
  module Work_spec = Snark_work_lib.Work.Single.Spec

  module Job_status = struct
    type t = Assigned of Time.t

    let is_old (Assigned at_time) ~now ~reassignment_wait =
      let max_age = Time.Span.of_ms (Float.of_int reassignment_wait) in
      let delta = Time.diff now at_time in
      Time.Span.( > ) delta max_age
  end

  module State = struct
    module Seen_key = struct
      module T = struct
        type t = Transaction_snark.Statement.t One_or_two.t
        [@@deriving compare, sexp, to_yojson]
      end

      include T
      include Comparable.Make (T)
    end

    type t = {jobs_seen: Job_status.t Seen_key.Map.t; reassignment_wait: int}

    let init ~reassignment_wait =
      {jobs_seen= Seen_key.Map.empty; reassignment_wait}

    let remove_old_assignments {jobs_seen; reassignment_wait} ~logger =
      let now = Time.now () in
      let jobs_seen =
        Map.filteri jobs_seen ~f:(fun ~key:work ~data:status ->
            if Job_status.is_old status ~now ~reassignment_wait then (
              [%log info]
                ~metadata:[("work", Seen_key.to_yojson work)]
                "Waited too long to get work for $work. Ready to be reassigned" ;
              Coda_metrics.(
                Counter.inc_one Snark_work.snark_work_timed_out_rpc) ;
              false )
            else true )
      in
      {jobs_seen; reassignment_wait}

    let remove t x =
      { t with
        jobs_seen=
          Map.remove t.jobs_seen (One_or_two.map ~f:Work_spec.statement x) }

    let set t x =
      { t with
        jobs_seen=
          Map.set t.jobs_seen
            ~key:(One_or_two.map ~f:Work_spec.statement x)
            ~data:(Job_status.Assigned (Time.now ())) }
  end

  let does_not_have_better_fee ~snark_pool ~fee
      (statements : Inputs.Transaction_snark_work.Statement.t) : bool =
    Option.value_map ~default:true
      (Inputs.Snark_pool.get_completed_work snark_pool statements)
      ~f:(fun priced_proof ->
        let competing_fee = Inputs.Transaction_snark_work.fee priced_proof in
        Fee.compare fee competing_fee < 0 )

  module For_tests = struct
    let does_not_have_better_fee = does_not_have_better_fee
  end

  let get_expensive_work ~snark_pool ~fee
      (jobs : ('a, 'b, 'c) Work_spec.t One_or_two.t list) :
      ('a, 'b, 'c) Work_spec.t One_or_two.t list =
    List.filter jobs ~f:(fun job ->
        does_not_have_better_fee ~snark_pool ~fee
          (One_or_two.map job ~f:Work_spec.statement) )

  let all_pending_work ~snark_pool statements =
    List.filter statements ~f:(fun st ->
        Option.is_none (Inputs.Snark_pool.get_completed_work snark_pool st) )

  let all_unseen_works ~get_protocol_state
      (staged_ledger : Inputs.Staged_ledger.t) (state : State.t) =
    let open Or_error.Let_syntax in
    let%map all_jobs =
      Inputs.Staged_ledger.all_work_pairs staged_ledger
        ~get_state:get_protocol_state
    in
    let unseen_jobs =
      List.filter all_jobs ~f:(fun js ->
          not
          @@ Map.mem state.jobs_seen (One_or_two.map ~f:Work_spec.statement js)
      )
    in
    unseen_jobs

  (*Seen/Unseen jobs that are not in the snark pool yet*)
  let pending_work_statements ~snark_pool ~fee_opt ~staged_ledger =
    let all_todo_statements =
      Inputs.Staged_ledger.all_work_statements_exn staged_ledger
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
