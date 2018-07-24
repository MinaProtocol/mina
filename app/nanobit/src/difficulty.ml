open Nanobit_base
open Blockchain_snark

type t = Target.t [@@deriving sexp, bin_io, compare, eq]

let next t ~last ~this = Blockchain_state.compute_target last t this

let meets t h = Proof_of_work.meets_target_unchecked h t
