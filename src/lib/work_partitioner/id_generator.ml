open Core_kernel

(* NOTE: range is both inclusive *)
type t = { logger : Logger.t; range : int64 * int64; mutable next_id : int64 }

let create ~logger =
  { logger
  ; range = (Int64.min_value, Int64.max_value)
  ; next_id = Int64.min_value
  }

let next_id (t : t) () : Int64.t =
  let open Int64 in
  let result = t.next_id in
  let lower, upper = t.range in
  if equal t.next_id upper then (
    let logger = t.logger in
    [%log warn] "ID generator reaching int64 boundart, recuring from 0" ;
    t.next_id <- lower )
  else t.next_id <- succ t.next_id ;
  result
