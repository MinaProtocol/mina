open Core_kernel

module Job = struct
  type ('a, 'd) t = Merge of 'a option * 'a option | Base of 'd option
  [@@deriving sexp, bin_io]

  let gen a_gen d_gen =
    let open Quickcheck.Generator in
    let open Quickcheck.Generator.Let_syntax in
    let maybe_a = Option.gen a_gen in
    match%map variant2 (tuple2 maybe_a maybe_a) (Option.gen d_gen) with
    | `A (a1, a2) -> Merge (a1, a2)
    | `B d -> Base d

  let gen_full a_gen d_gen =
    let open Quickcheck.Generator in
    let open Quickcheck.Generator.Let_syntax in
    match%map variant2 (tuple2 a_gen a_gen) d_gen with
    | `A (a1, a2) -> Merge (Some a1, Some a2)
    | `B d -> Base (Some d)
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
  ; mutable recent_tree_data: 'd list sexp_opaque
  ; mutable other_trees_data: 'd list list sexp_opaque
  ; stateful_work_order: int Queue.t
  ; mutable curr_job_seq_no: int }
[@@deriving sexp, bin_io]

module Hash = struct
  type t = Digestif.SHA256.t
end

(* TODO: This should really be computed iteratively *)
let hash
    { jobs
    ; acc
    ; current_data_length
    ; base_none_pos
    ; capacity
    ; level_pointer
    ; curr_job_seq_no; _ } a_to_string d_to_string =
  let h = ref (Digestif.SHA256.init ()) in
  let add_string s = h := Digestif.SHA256.feed_string !h s in
  Ring_buffer.iter jobs ~f:(function
    | Base None -> add_string "Base None"
    | Base (Some x) -> add_string ("Base Some " ^ d_to_string x)
    | Merge (None, None) -> add_string "Merge None None"
    | Merge (None, Some a) -> add_string ("Merge None Some " ^ a_to_string a)
    | Merge (Some a, None) ->
        add_string ("Merge Some " ^ a_to_string a ^ " None")
    | Merge (Some a1, Some a2) ->
        add_string ("Merge Some " ^ a_to_string a1 ^ " Some " ^ a_to_string a2) ) ;
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
  add_string (Int.to_string curr_job_seq_no) ;
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

let curr_job_seq_no s = s.curr_job_seq_no

let copy
    { jobs
    ; acc
    ; current_data_length
    ; base_none_pos
    ; capacity
    ; level_pointer
    ; recent_tree_data
    ; other_trees_data
    ; stateful_work_order
    ; curr_job_seq_no } =
  { jobs= Ring_buffer.copy jobs
  ; acc
  ; capacity
  ; current_data_length
  ; base_none_pos
  ; level_pointer= Array.copy level_pointer
  ; recent_tree_data
  ; other_trees_data
  ; stateful_work_order= Queue.copy stateful_work_order
  ; curr_job_seq_no }
