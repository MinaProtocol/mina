open Core_kernel

type ('field, 'bool) t =
  {field_elements: 'field array; bitstrings: 'bool list array}
[@@deriving sexp]

let append t1 t2 =
  { field_elements= Array.append t1.field_elements t2.field_elements
  ; bitstrings= Array.append t1.bitstrings t2.bitstrings }

let field_elements x = {field_elements= x; bitstrings= [||]}

let field x = {field_elements= [|x|]; bitstrings= [||]}

let bitstring x = {field_elements= [||]; bitstrings= [|x|]}

let bitstrings x = {field_elements= [||]; bitstrings= x}
