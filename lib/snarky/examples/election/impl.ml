open Snarky
module Backend = Backends.Bn128
module M = Snark.Make(Backend)
include M

let backend_bigint_of_bigint n =
  Backend.Bigint.R.of_decimal_string
    (Bignum.Bigint.to_string n)
;;

let bigint_of_backend_bigint n =
  let rec go i two_to_the_i acc =
    if i = Field.size_in_bits
    then acc
    else
      let acc' =
        if Bigint.test_bit n i
        then Bignum.Bigint.(acc + two_to_the_i)
        else acc
      in
      go (i + 1) Bignum.Bigint.(two_to_the_i + two_to_the_i) acc'
  in
  go 0 Bignum.Bigint.one Bignum.Bigint.zero

