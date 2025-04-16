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

(* module that split the work produced by a Work_selector into smaller tasks,
   and issue them to the actual worker. It's also in charge of aggregating
   the response from worker. We have this layer because we don't want to
   touch the Work_selector and break a lot of places.

   Ideally, we should refactor so this integrates into Work_selector
*)
module Work_partitioner = Work_partitioner

module Snark_job_state = struct
  type t =
    { work_selector : State.t; work_partitioner : Work_partitioner.State.t }
end
