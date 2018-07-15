open Core

type single = Public_key.Compressed.t * Currency.Fee.Stable.V1.t
[@@deriving bin_io, sexp]

type t = One of single | Two of single * single [@@deriving bin_io, sexp]

let to_list = function One x -> [x] | Two (x, y) -> [x; y]

let of_single_list xs =
  let rec go acc = function
    | x1 :: x2 :: xs -> go (Two (x1, x2) :: acc) xs
    | [] -> acc
    | [x] -> One x :: acc
  in
  go [] xs
