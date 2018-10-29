open Core_kernel

module Make (Inputs : Inputs.Inputs_intf) = struct
  module Work_spec = Snark_work_lib.Work.Single.Spec

  let statement_pair = function
    | j, None -> (Work_spec.statement j, None)
    | j1, Some j2 -> (Work_spec.statement j1, Some (Work_spec.statement j2))

  module Job_status = struct
    type t = Assigned of Time.t

    let max_age = Time.Span.of_min 2.

    let is_old t ~now =
      match t with Assigned at_time ->
        let delta = Time.diff now at_time in
        Time.Span.( > ) delta max_age
  end

  module State = struct
    module Seen_key = struct
      module T = struct
        type t =
          Inputs.Ledger_proof_statement.t
          * Inputs.Ledger_proof_statement.t option
        [@@deriving compare, sexp]
      end

      include T
      include Comparable.Make (T)
    end

    type t = Job_status.t Seen_key.Map.t

    let init = Seen_key.Map.empty

    let remove_old_assignments t =
      let now = Time.now () in
      Map.filter t ~f:(fun status -> not (Job_status.is_old status ~now))

    let set t x =
      Map.set t ~key:(statement_pair x)
        ~data:(Job_status.Assigned (Time.now ()))
  end

  let pair_to_list = function j, Some j' -> [j; j'] | j, None -> [j]

  let all_works (ledger_builder : Inputs.Ledger_builder.t) (state : State.t) =
    let state = State.remove_old_assignments state in
    let all_jobs = Inputs.Ledger_builder.all_work_pairs ledger_builder in
    let unseen_jobs =
      List.filter all_jobs ~f:(fun js ->
          not @@ Map.mem state (statement_pair js) )
    in
    unseen_jobs
end
