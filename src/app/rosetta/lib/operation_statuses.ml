open Core_kernel
open Models

type t = [`Success | `Pending | `Missing] [@@deriving to_representatives]

let name = function
  | `Success ->
      "Success"
  | `Pending ->
      "Pending"
  | `Missing ->
      "Missing"

let successful = function
  | `Success ->
      true
  | `Pending ->
      false
  | `Missing ->
      false

let operation t = {Operation_status.status= name t; successful= successful t}

let all = to_representatives |> Lazy.map ~f:(List.map ~f:operation)
