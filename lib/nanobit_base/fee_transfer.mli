type single = Public_key.Compressed.t * Currency.Fee.t
[@@deriving bin_io, sexp]

type t = One of single | Two of single * single [@@deriving bin_io, sexp]

val to_list : t -> single list

val of_single_list : single list -> t list
