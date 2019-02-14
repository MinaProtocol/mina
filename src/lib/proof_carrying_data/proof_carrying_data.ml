(* A convenient data structure to bundle statements along with their proofs together *)
type ('a, 'b) t = {data: 'a; proof: 'b} [@@deriving sexp, fields, bin_io]
