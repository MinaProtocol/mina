open Core
open Snarky
open Snark
module B = Bigint

let bigint_to_field (type f) ~m:((module M) : f m) =
  let open M in
  Fn.compose Bigint.to_field Bigint.of_bignum_bigint

let bigint_of_field (type f) ~m:((module M) : f m) =
  let open M in
  Fn.compose Bigint.to_bignum_bigint Bigint.of_field
