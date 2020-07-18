open Core_kernel
open Models

type t = [`Success | `Pending | `Failed] [@@deriving to_representatives]

let name = function
  | `Success ->
      "Success"
  | `Pending ->
      "Pending"
  | `Failed ->
      "Failed"

let successful = function
  | `Success ->
      true
  | `Pending ->
      false
  | `Failed ->
      false

let operation t = {Operation_status.status= name t; successful= successful t}

let all = to_representatives |> Lazy.map ~f:(List.map ~f:operation)
