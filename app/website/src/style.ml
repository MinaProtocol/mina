open Core_kernel
open Stationary

type t = string list

let ( + ) = List.append

let of_class s = [s]

let empty = []

let render t =
  let open Html_concise in
  class_ (String.concat ~sep:" " t)

