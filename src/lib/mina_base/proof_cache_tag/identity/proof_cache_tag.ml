type t = (Nat.N2.n, Nat.N2.n) Pickles.Proof.t [@@deriving sexp, compare, yojson]

let unwrap = Fn.id

let generate = Fn.id
