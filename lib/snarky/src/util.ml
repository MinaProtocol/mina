open Core_kernel

let rec euclid a b =
  let open Bignum.Bigint in
  if b = zero
  then a, one, zero
  else 
    let (d, x, y) = euclid b (a % b) in
    (d, y, x - a / b * y)

let%test_unit "euclid" =
  let open Quickcheck in
  test (Generator.tuple2 Bignum.Bigint.gen_positive Bignum.Bigint.gen_positive) ~f:(fun (a, b) ->
    let open Bignum.Bigint in
    let (d, x, y) = euclid a b in
    assert (a % d = zero);
    assert (b % d = zero);
    assert (d = x * a + y * b))

let bigint_num_bits =
  let rec go acc i =
    if Bignum.Bigint.(acc = zero)
    then i
    else go (Bignum.Bigint.shift_right acc 1) (i + 1)
  in
  fun n -> go n 0
