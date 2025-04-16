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

open Core_kernel (* Core_kernel imports `Random` and `Sqeuence` *)

open Async

let remove = Lib.State.remove

let pending_work_statements = Lib.pending_work_statements

let all_work = Lib.all_work

let completed_work_statements = Lib.completed_work_statements

module Work_partitioner = Work_partitioner
module Shared = Shared

module Snark_job_state = struct
  type t =
    { work_selector : State.t; work_partitioner : Work_partitioner.State.t }
end

(* This returns work of finer grain (i.e. sub zkapp command level) compared to calling selector directly *)
let request_partitioned_work
    ~(selection_method : (module Selection_method_intf)) ~(logger : Logger.t)
    ~(fee : Currency.Fee.t) ~(snark_pool : snark_pool) ~(selector : State.t)
    ~(partitioner : Work_partitioner.State.t) :
    Work_partitioner.Partitioned_work.t option =
  failwith "TODO"
(* match partitioner.pair_left with *)
(* | Some single_work -> *)
(*     let spec = *)
(*       Work_partitioner.produce_partitioned_work_from_single ~partitioner `Left single_work *)
(*     in *)
(*     Some spec *)
(* | None -> ( *)
(*     match Work_partitioner.reissue_old_task partitioner with *)
(*     | Some task -> *)
(*         Some task *)
(*     | None -> ( *)
(*         let (module Work_selection_method) = selection_method in *)
(*         let open Option.Let_syntax in *)
(*         let%map instances = *)
(*           Work_selection_method.work ~logger ~fee ~snark_pool selector *)
(*         in *)
(*         match instances with *)
(*         | `One instance -> *)
(*             produce_partitioned_work_from_single ~partitioner `One instance *)
(*         | `Two (left, right) -> *)
(*             partitioner.pair_left <- Some left ; *)
(*             produce_partitioned_work_from_single ~partitioner `Right right ) ) *)
