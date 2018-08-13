open Core

type t = Left | Right

let of_bool = function false -> Left | true -> Right

let to_bool = function Left -> false | Right -> true

let flip = function Left -> Right | Right -> Left

let gen = Quickcheck.Let_syntax.(Quickcheck.Generator.bool >>| of_bool)
