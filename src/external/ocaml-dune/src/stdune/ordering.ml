type t =
  | Lt
  | Eq
  | Gt

let of_int n =
  if n < 0 then
    Lt
  else if n = 0 then
    Eq
  else
    Gt

let to_int = function
  | Lt -> -1
  | Eq ->  0
  | Gt ->  1

let to_string = function
  | Lt -> "<"
  | Eq -> "="
  | Gt -> ">"

let neq = function
  | Eq -> false
  | Lt | Gt -> true
