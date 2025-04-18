module Lib = Work_lib.Make (Inputs.Implementation_inputs)
module State = Lib.State

type work = Work_lib.work [@@deriving yojson]

type snark_pool = Network_pool.Snark_pool.t

module type Selection_method_intf =
  Intf.Selection_method_intf
    with type snark_pool := snark_pool
     and type staged_ledger := Staged_ledger.t
     and type work := Work_lib.work
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
module Shared = Shared

module Snark_job_state = struct
  type t = { work_selector : State.t; work_partitioner : Work_partitioner.t }
end

(* This returns work in finer grain (i.e. sub zkapp command level) compared to calling selector directly *)

let request_from_selector_and_consume_by_partitioner
    ~(partitioner : Work_partitioner.t)
    ~(selection_method : (module Selection_method_intf)) ~(selector : State.t)
    ~(logger : Logger.t) ~(fee : Currency.Fee.t) ~snark_pool ~key () =
  let (module Work_selection_method) = selection_method in
  let open Core_kernel in
  let open Option.Let_syntax in
  let%map work = Work_selection_method.work ~logger ~fee ~snark_pool selector in

  Work_partitioner.consume_job_from_selector ~fee ~prover:key ~partitioner ~work
    ()

let request_partitioned_work
    ~(selection_method : (module Selection_method_intf)) ~(logger : Logger.t)
    ~(fee : Currency.Fee.t) ~(snark_pool : snark_pool) ~(selector : State.t)
    ~(partitioner : Work_partitioner.t)
    ~(key : Signature_lib.Public_key.Compressed.t) :
    Work_partitioner.Partitioned_work.t option =
  Work_partitioner.attempt_these
    [ Work_partitioner.issue_job_from_partitioner ~partitioner
    ; request_from_selector_and_consume_by_partitioner ~partitioner
        ~selection_method ~selector ~logger ~fee ~snark_pool ~key
    ]

let submit_partitioned_work ~(result : Snark_work_lib.Wire.Result.t) =
  (* match  *)
  failwith "TODO"
