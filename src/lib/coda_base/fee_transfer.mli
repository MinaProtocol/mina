open Core_kernel
open Import

type single = Public_key.Compressed.t * Currency.Fee.t
[@@deriving bin_io, sexp, compare, eq, yojson]

type t = One of single | Two of single * single
[@@deriving bin_io, sexp, compare, eq, yojson]

val to_list : t -> single list

val of_single : single -> t

val of_single_list : single list -> t list

val fee_excess : t -> Currency.Fee.Signed.t Or_error.t

val receivers : t -> Public_key.Compressed.t list
