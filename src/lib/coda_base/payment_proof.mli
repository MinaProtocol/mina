open Receipt_chain_database_lib

type t = (Receipt.Chain_hash.t, User_command.t) Payment_proof.t
[@@deriving eq, sexp, bin_io, yojson]

val initial_receipt : t -> Receipt.Chain_hash.t

val payments : t -> User_command.t list
