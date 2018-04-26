open Nanobit_base
open Blockchain_snark

type t = Target.t
[@@deriving sexp, bin_io]

let next t ~last ~this =
  Blockchain_state.compute_target last t this

let meets t h =
  Target.meets_target_unchecked t h
