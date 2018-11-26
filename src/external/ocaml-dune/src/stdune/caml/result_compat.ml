(** Result type for OCaml < 4.03 *)

type ('a, 'error) result =
  | Ok    of 'a
  | Error of 'error
