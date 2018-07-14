open Core_kernel

module Job = struct
  type ('a, 'd) t =
    | Merge_up of 'a option
    | Merge of 'a option * 'a option
    | Base of 'd option
  [@@deriving sexp, bin_io]

  let gen a_gen d_gen =
    let open Quickcheck.Generator in
    let open Quickcheck.Generator.Let_syntax in
    let maybe_a = Option.gen a_gen in
    match%map variant3 maybe_a (tuple2 maybe_a maybe_a) (Option.gen d_gen) with
    | `A a -> Merge_up a
    | `B (a1, a2) -> Merge (a1, a2)
    | `C d -> Base d

  let gen_full a_gen d_gen =
    let open Quickcheck.Generator in
    let open Quickcheck.Generator.Let_syntax in
    match%map variant3 a_gen (tuple2 a_gen a_gen) d_gen with
    | `A a -> Merge_up (Some a)
    | `B (a1, a2) -> Merge (Some a1, Some a2)
    | `C d -> Base (Some d)
end

module Completed_job = struct
  type ('a, 'b) t = Lifted of 'a | Merged of 'a | Merged_up of 'b
  [@@deriving bin_io, sexp]
end

type ('a, 'b, 'd) t =
  { jobs: ('a, 'd) Job.t Ring_buffer.t
  ; data_buffer: 'd Queue.t
  ; mutable acc: int * 'b
  ; mutable current_data_length: int
  ; mutable enough_steps: bool }
[@@deriving sexp, bin_io]

let acc {acc} = snd acc

let jobs {jobs} = jobs

let data_buffer {data_buffer} = data_buffer

let current_data_length {current_data_length} = current_data_length

let enough_steps {enough_steps} = enough_steps

let copy {jobs; data_buffer; acc; current_data_length; enough_steps} =
  { jobs= Ring_buffer.copy jobs
  ; data_buffer= Queue.copy data_buffer
  ; acc
  ; current_data_length
  ; enough_steps }
