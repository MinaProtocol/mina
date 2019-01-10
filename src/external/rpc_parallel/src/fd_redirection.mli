type t =
  [ `Dev_null
  | `File_append of string
  | `File_truncate of string
  ] [@@deriving sexp]
