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
  ; capacity: int
  ; mutable acc: int * 'a option
  ; mutable current_data_length: int
  ; mutable base_none_pos: int option }
[@@deriving sexp, bin_io]

module Hash = struct
  type t = Cryptokit.hash
end

(* TODO: This should really be computed iteratively *)
let hash {jobs; acc; current_data_length; base_none_pos} a_to_string
    d_to_string =
  let h = Cryptokit.Hash.sha3 256 in
  Ring_buffer.iter jobs ~f:(function
    | Base None -> h#add_string "Base None"
    | Base (Some x) -> h#add_string ("Base Some " ^ d_to_string x)
    | Merge (None, None) -> h#add_string "Merge None None"
    | Merge (None, Some a) -> h#add_string ("Merge None Some " ^ a_to_string a)
    | Merge (Some a, None) ->
        h#add_string ("Merge Some " ^ a_to_string a ^ " None")
    | Merge (Some a1, Some a2) ->
        h#add_string
          ("Merge Some " ^ a_to_string a1 ^ " Some " ^ a_to_string a2) ) ;
  let i, a = acc in
  let x = base_none_pos in
  h#add_string (Int.to_string i) ;
  ( match a with
  | None -> h#add_string "None"
  | Some a -> h#add_string (a_to_string a) ) ;
  h#add_string (Int.to_string current_data_length) ;
  ( match x with
  | None -> h#add_string "None"
  | Some a -> h#add_string (Int.to_string a) ) ;
  h

let acc {acc} = snd acc

let jobs {jobs} = jobs

let current_data_length {current_data_length} = current_data_length

let parallelism {jobs} = (Ring_buffer.length jobs + 1) / 2

let base_none_pos {base_none_pos} = base_none_pos

let copy {jobs; acc; current_data_length; base_none_pos; capacity} =
  { jobs= Ring_buffer.copy jobs
  ; acc
  ; capacity
  ; current_data_length
  ; base_none_pos }
