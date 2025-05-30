open Core_kernel

(* NOTE: This range is both inclusive *)
let id_lower_bound = Int64.min_value

let id_upper_bound = Int64.max_value

type t = { logger : Logger.t; mutable next_id : int64 }

let create ~logger = { logger; next_id = Int64.min_value }

(* WARN: Job_pool assumes ID to be monotonically increasing with repsect to issued time to be correct *)
let next_id (t : t) () : Int64.t =
  let open Int64 in
  let result = t.next_id in
  if equal t.next_id id_upper_bound then (
    let logger = t.logger in
    [%log warn]
      "ID generator exceeded upper boundary %Ld, recuring from lower boundry \
       %Ld"
      id_upper_bound id_lower_bound ;
    t.next_id <- id_lower_bound )
  else t.next_id <- succ t.next_id ;
  result
