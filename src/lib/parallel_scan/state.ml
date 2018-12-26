open Core_kernel

module Job = struct
  type created_time = int [@@deriving sexp, bin_io]

  (*A merge node can have zero components, one component (either the left or the right), or two components in which case there is an integer representing a place in the order of creation*)
  type 'a merge =
    | Empty
    | Lcomp of 'a
    | Rcomp of 'a
    | Bcomp of ('a * 'a * created_time)
  [@@deriving sexp, bin_io]

  type ('a, 'd) t = Merge of 'a merge | Base of ('d * created_time) option
  [@@deriving sexp, bin_io]

  let gen a_gen d_gen =
    let open Quickcheck.Generator in
    let open Quickcheck.Generator.Let_syntax in
    (*let maybe_a = Option.gen a_gen in
    let maybe_int = Option.gen Int.gen in*)
    match%map
      variant2
        (variant4 Bool.gen a_gen a_gen (tuple3 a_gen a_gen Int.gen))
        (Option.gen (tuple2 d_gen Int.gen))
    with
    | `A (`A _) -> Merge Empty
    | `A (`B a) -> Merge (Lcomp a)
    | `A (`C a) -> Merge (Rcomp a)
    | `A (`D a) -> Merge (Bcomp a)
    | `B d -> Base d

  let gen_full a_gen d_gen =
    let open Quickcheck.Generator in
    let open Quickcheck.Generator.Let_syntax in
    match%map variant2 (tuple3 a_gen a_gen Int.gen) (tuple2 d_gen Int.gen) with
    | `A (a1, a2, o) -> Merge (Bcomp (a1, a2, o))
    | `B (d, o) -> Base (Some (d, o))
end

module Completed_job = struct
  type 'a t = Lifted of 'a | Merged of 'a [@@deriving bin_io, sexp]
end

type ('a, 'd) t =
  { jobs: ('a, 'd) Job.t Ring_buffer.t
  ; level_pointer: int Array.t
  ; capacity: int
  ; mutable acc: int * 'a option
  ; mutable current_data_length: int
  ; mutable base_none_pos: int option
  ; mutable recent_tree_data: 'd list
  ; mutable other_trees_data: 'd list list
  ; stateful_work_order: int Queue.t }
[@@deriving sexp, bin_io]

module Hash = struct
  type t = Digestif.SHA256.t
end

(* TODO: This should really be computed iteratively *)
let hash
    {jobs; acc; current_data_length; base_none_pos; capacity; level_pointer; _}
    a_to_string d_to_string =
  let h = ref (Digestif.SHA256.init ()) in
  let add_string s = h := Digestif.SHA256.feed_string !h s in
  Ring_buffer.iter jobs ~f:(function
    | Base None -> add_string "Base None"
    | Base (Some (x, _)) -> add_string ("Base Some " ^ d_to_string x)
    | Merge Empty -> add_string "Merge Empty"
    | Merge (Rcomp a) -> add_string ("Merge Rcomp " ^ a_to_string a)
    | Merge (Lcomp a) -> add_string ("Merge Lcomp " ^ a_to_string a)
    | Merge (Bcomp (a1, a2, _)) ->
        add_string ("Merge Bcomp " ^ a_to_string a1 ^ " " ^ a_to_string a2) ) ;
  let i, a = acc in
  let x = base_none_pos in
  add_string (Int.to_string capacity) ;
  add_string (Int.to_string i) ;
  add_string
    (Array.fold level_pointer ~init:"" ~f:(fun s a -> s ^ Int.to_string a)) ;
  ( match a with
  | None -> add_string "None"
  | Some a -> add_string (a_to_string a) ) ;
  add_string (Int.to_string current_data_length) ;
  ( match x with
  | None -> add_string "None"
  | Some a -> add_string (Int.to_string a) ) ;
  Digestif.SHA256.get !h

let acc s = snd s.acc

let jobs s = s.jobs

let level_pointer s = s.level_pointer

let current_data_length s = s.current_data_length

let parallelism s = (Ring_buffer.length s.jobs + 1) / 2

let base_none_pos s = s.base_none_pos

let recent_tree_data s = s.recent_tree_data

let other_trees_data s = s.other_trees_data

let stateful_work_order s = s.stateful_work_order

let copy
    { jobs
    ; acc
    ; current_data_length
    ; base_none_pos
    ; capacity
    ; level_pointer
    ; recent_tree_data
    ; other_trees_data
    ; stateful_work_order } =
  { jobs= Ring_buffer.copy jobs
  ; acc
  ; capacity
  ; current_data_length
  ; base_none_pos
  ; level_pointer= Array.copy level_pointer
  ; recent_tree_data
  ; other_trees_data
  ; stateful_work_order= Queue.copy stateful_work_order }
