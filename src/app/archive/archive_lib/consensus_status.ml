open Core_kernel

type t = Pending of int | Confirmed | Failure | Unknown

let to_int = function
  | Pending block_confirmation ->
      block_confirmation
  | Confirmed ->
      -1
  | Failure ->
      -2
  | Unknown ->
      -3

let of_int = function
  | pending when pending >= 0 ->
      Some (Pending pending)
  | -1 ->
      Some Confirmed
  | -2 ->
      Some Failure
  | -3 ->
      Some Unknown
  | _ ->
      None

let of_int_exn value = Option.value_exn (of_int value)
