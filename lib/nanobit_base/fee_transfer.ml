type single = Public_key.Compressed.t * Currency.Fee.Stable.V1.t
[@@deriving bin_io, sexp]

type t = One of single | Two of single * single [@@deriving bin_io, sexp]

let to_list = function One x -> [x] | Two (x, y) -> [x; y]
