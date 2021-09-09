open Snarky
module Backend = Backends.Bn128.Default

let backend_bigint_of_bigint n =
  Backend.Bigint.R.of_decimal_string (Bigint.to_string n)

module M = Snark.Make (Backend)

let bigint_of_backend_bigint n =
  let rec go i two_to_the_i acc =
    if i = M.Field.size_in_bits then acc
    else
      let acc' =
        if M.Bigint.test_bit n i then Bigint.(acc + two_to_the_i) else acc
      in
      go (i + 1) Bigint.(two_to_the_i + two_to_the_i) acc'
  in
  go 0 Bigint.one Bigint.zero

include M
