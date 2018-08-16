open Core

type t = Left | Right [@@deriving sexp]

let of_bool = function false -> Left | true -> Right

let to_bool = function Left -> false | Right -> true

let to_int = function Left -> 0 | Right -> 1

let flip = function Left -> Right | Right -> Left

let gen = Quickcheck.Let_syntax.(Quickcheck.Generator.bool >>| of_bool)

let gen_list depth =
  let open Quickcheck.Generator in
  Int.gen_incl 0 (depth - 1) >>= fun l -> list_with_length l gen
