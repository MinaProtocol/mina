type t [@@deriving compare, equal, sexp, yojson, hash]

val unwrap : t -> Mina_base.Proof.t

val generate : Mina_base.Proof.t -> t
