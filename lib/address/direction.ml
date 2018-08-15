open Core

type t = Left | Right

let of_bool = function false -> Left | true -> Right

let to_bool = function Left -> false | Right -> true

let flip = function Left -> Right | Right -> Left

let gen = Quickcheck.Let_syntax.(Quickcheck.Generator.bool >>| of_bool)

let gen_list depth =
  let open Quickcheck.Generator in
  let open Let_syntax in
  let%bind l = Int.gen_incl 0 (depth - 1) in
  list_with_length l (Bool.gen >>| fun b -> if b then `Right else `Left)
