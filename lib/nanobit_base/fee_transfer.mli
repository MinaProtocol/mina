open Core_kernel

type single = Public_key.Compressed.t * Currency.Fee.t
[@@deriving bin_io, sexp, compare, eq]

type t = One of single | Two of single * single
[@@deriving bin_io, sexp, compare, eq]

val to_list : t -> single list

val of_single_list : single list -> t list

val fee_excess : t -> Currency.Fee.t Or_error.t

val receivers : t -> Public_key.Compressed.t list
