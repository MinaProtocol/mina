open Core_kernel

module Interval = struct
  (* Semantically (a, b) : t is the closed interval [a, b] *)
  type t = int * int [@@deriving eq]

  let before (_, b1) (a2, _) = b1 <= a2
end

(* Simplest possible implementation. Should be an increasing list of
   disjoint intervals. 
   Semantically is the set of ints corresponding to the union of these 
   ntervals. *)
type t = Interval.t list [@@deriving eq]

let empty : t = []

let union_intervals_exn (a1, b1) (a2, b2) =
  let ( = ) = Int.( = ) in
  if b1 = a2 then `Combine (a1, b2)
  else if b2 = a1 then `Combine (a2, b1)
  else if b1 < a2 then `Disjoint_ordered
  else if b2 < a1 then `Disjoint_inverted
  else failwith "Intervals not disjoint"

let of_interval i = [i]

let rec disjoint_union_exn t1 t2 =
  match (t1, t2) with
  | t, [] | [], t -> t
  | i1 :: t1', i2 :: t2' ->
    match union_intervals_exn i1 i2 with
    | `Combine (a, b) -> (a, b) :: disjoint_union_exn t1' t2'
    | `Disjoint_ordered -> i1 :: disjoint_union_exn t1' t2
    | `Disjoint_inverted -> i2 :: disjoint_union_exn t1 t2'

let rec disjoint t1 t2 =
  match (t1, t2) with
  | _, [] | [], _ -> true
  | i1 :: t1', i2 :: t2' ->
      if Interval.before i1 i2 then disjoint t1' t2
      else if Interval.before i2 i1 then disjoint t1 t2'
      else false

(* Someday: inefficient *)
let of_intervals_exn is =
  match is with
  | [] -> []
  | i :: is ->
      List.fold is ~init:(of_interval i) ~f:(fun acc x ->
          disjoint_union_exn (of_interval x) acc )
