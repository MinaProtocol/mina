type t [@@deriving compare, equal, sexp, yojson, hash]

val unwrap : t -> Proof.t

val generate : Proof.t -> t
