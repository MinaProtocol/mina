open Core_kernel

type t = Pickles.Proof.Proofs_verified_2.t
[@@deriving compare, equal, sexp, yojson, hash]

let unwrap = Fn.id

let generate = Fn.id
