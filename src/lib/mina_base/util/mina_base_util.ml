[%%import "/src/config.mlh"]

open Core_kernel

let field_of_bool =
  Snark_params.Step.(fun b -> if b then Field.one else Field.zero)

let bit_length_to_triple_length n =
  let r = n mod 3 in
  let k = n / 3 in
  if r = 0 then k else k + 1

let split_last_exn =
  let rec go acc x xs =
    match xs with [] -> (List.rev acc, x) | x' :: xs -> go (x :: acc) x' xs
  in
  function [] -> failwith "split_last: Empty list" | x :: xs -> go [] x xs

let two_to_the i = Bignum_bigint.(pow (of_int 2) (of_int i))
