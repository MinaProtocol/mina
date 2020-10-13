open Core_kernel
open Pickles_types

type ('var, 'value, 'n1, 'n2) tag = ('var * 'value * 'n1 * 'n2) Type_equal.Id.t

type kind = Side_loaded | Compiled

type ('var, 'value, 'n1, 'n2) t = {kind: kind; id: ('var, 'value, 'n1, 'n2) tag}
[@@deriving fields]

let create ~name =
  {kind= Compiled; id= Type_equal.Id.create ~name sexp_of_opaque}

let side_loaded id = {kind= Side_loaded; id}
