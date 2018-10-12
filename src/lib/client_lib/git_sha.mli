type t [@@deriving eq, sexp, yojson, bin_io]

val of_string : string -> t
