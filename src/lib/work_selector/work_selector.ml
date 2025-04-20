module Lib = Work_lib.Make (Inputs.Implementation_inputs)
module State = Lib.State

type work = Snark_work_lib.Partitioned.Selector_work.t

type in_memory_work = Snark_work_lib.Partitioned.Selector_work.Stable.Latest.t
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
