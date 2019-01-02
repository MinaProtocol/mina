open Base

type 'var basic =
  | Boolean of 'var
  | Equal of 'var * 'var
  | Square of 'var * 'var
  | R1CS of 'var * 'var * 'var
[@@deriving sexp]

type 'v basic_with_annotation = {basic: 'v basic; annotation: string option}
[@@deriving sexp]

type 'v t = 'v basic_with_annotation list [@@deriving sexp]
