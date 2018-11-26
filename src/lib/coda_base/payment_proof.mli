type t = (Receipt.Chain_hash.t * User_command.t) list
[@@deriving yojson, eq, sexp, bin_io]
