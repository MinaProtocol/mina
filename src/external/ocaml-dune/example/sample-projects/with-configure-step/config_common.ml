(* Various types used by configure and real_configure.ml *)

type switch =
  | Yes
  | No
  | Auto

let string_of_switch = function
  | Yes  -> "Yes"
  | No   -> "No"
  | Auto -> "Auto"
