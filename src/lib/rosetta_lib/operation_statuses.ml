open Core_kernel
open Rosetta_models

type t = [ `Success | `Failed ] [@@deriving to_representatives]

let name = function `Success -> "Success" | `Failed -> "Failed"

let successful = function `Success -> true | `Failed -> false

let operation t =
  { Operation_status.status = name t; successful = successful t }

let all = to_representatives |> Lazy.map ~f:(List.map ~f:operation)
