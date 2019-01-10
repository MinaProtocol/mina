(* chunk.ml -- chunks of triples, used for memoized Pedersen hashes *)

open Core
open Tuple_lib

type t = bool Triple.t list

(* increasing the size should improve Pedersen hash performance, at the cost of increased compile time

   a larger size reduces the size of the memoized hashes outer array slightly, but each increment doubles the
    size of each inner array

   a size of 3 gives reasonable compile times, 4 starts to get unreasonable

*)

let size = 3

let to_int t =
  if not (Int.equal (List.length t) size) then
    failwith "to_int: invalid chunk size" ;
  let shift_and_add accum triple =
    let n =
      match triple with
      | false, false, false -> 0
      | false, false, true -> 1
      | false, true, false -> 2
      | false, true, true -> 3
      | true, false, false -> 4
      | true, false, true -> 5
      | true, true, false -> 6
      | true, true, true -> 7
    in
    (accum lsl 3) + n
  in
  List.fold t ~init:0 ~f:shift_and_add

let max_int =
  (* 3 because triples *)
  let num_bits = size * 3 in
  int_of_float (2. ** float_of_int num_bits) - 1

let of_int n : t =
  if n > max_int then
    failwith "of_int: integer value too great to represent in a chunk" ;
  let not_zero n = not (Int.equal n 0) in
  let rec loop ~sz n accum =
    if sz <= 0 && n <= 0 then accum
    else
      let triple =
        ( not_zero (n land 0b100)
        , not_zero (n land 0b010)
        , not_zero (n land 0b001) )
      in
      loop ~sz:(sz - 1) (n lsr 3) (triple :: accum)
  in
  loop ~sz:size n []

let%test_unit "Test chunk integer conversions" =
  for n = 0 to max_int do
    let chunk = of_int n in
    let m = to_int chunk in
    assert (Int.equal n m)
  done
