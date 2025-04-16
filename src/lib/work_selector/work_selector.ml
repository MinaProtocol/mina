module Lib = Work_lib.Make (Inputs.Implementation_inputs)
module State = Lib.State

type work =
  (Transaction_witness.t, Ledger_proof.t) Snark_work_lib.Work.Single.Spec.t
[@@deriving yojson]

type snark_pool = Network_pool.Snark_pool.t

module type Selection_method_intf =
  Intf.Selection_method_intf
    with type snark_pool := snark_pool
     and type staged_ledger := Staged_ledger.t
     and type work := work
     and type transition_frontier := Transition_frontier.t
     and module State := State

module Selection_methods = struct
  module Random = Random.Make (Lib)
  module Sequence = Sequence.Make (Lib)
  module Random_offset = Random_offset.Make (Lib)
end

let remove = Lib.State.remove

let pending_work_statements = Lib.pending_work_statements

let all_work = Lib.all_work

let completed_work_statements = Lib.completed_work_statements

module Work_partitioner = Work_partitioner

module Snark_job_state = struct
  type t =
    { work_selector : State.t; work_partitioner : Work_partitioner.State.t }
end

(* This returns work of finer grain (i.e. sub zkapp command level) compared to calling selector directly *)
let request_partitioned_work
    ~(selection_method : (module Selection_method_intf)) ~(logger : Logger.t)
    ~(fee : Currency.Fee.t) ~(snark_pool : snark_pool) ~(selector : State.t)
    ~(partitioner : Work_partitioner.State.t) :
    Work_partitioner.partitioned_work option =
  match Work_partitioner.reissue_old_task partitioner with
  | Some task ->
      Some task
  | None ->
      let (module Work_selection_method) = selection_method in
      let%map instances =
        Work_selection_method.work ~logger ~fee ~snark_pool selector
      in
      failwith "WIP"
