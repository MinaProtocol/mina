open Core_kernel

open Dependency_tree

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
    match%map
      variant3
        maybe_a
        (tuple2 maybe_a maybe_a)
        (Option.gen d_gen)
    with
    | `A a -> Merge_up a
    | `B (a1, a2) -> Merge (a1, a2)
    | `C d -> Base d

  let gen_full a_gen d_gen =
    let open Quickcheck.Generator in
    let open Quickcheck.Generator.Let_syntax in
    match%map
      variant3
        a_gen
        (tuple2 a_gen a_gen)
        d_gen
    with
    | `A a -> Merge_up (Some a)
    | `B (a1, a2) -> Merge (Some a1, Some a2)
    | `C d -> Base (Some d)
end

type ('a, 'b, 'd) t =
  { jobs : ('a, 'd) Job.t Ring_buffer.t
  ; data_buffer : 'd Queue.t
  ; deps : int Dependency_tree.Dep_node.t Int.Table.t sexp_opaque
  ; mutable acc : 'b
  }
[@@deriving sexp, bin_io]

let acc {acc} = acc
let jobs {jobs} = jobs

