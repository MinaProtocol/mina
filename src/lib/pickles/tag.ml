open Core_kernel

type ('var, 'value, 'max_branching, 'num_rules) tag =
  ('var * 'value * 'max_branching * 'num_rules) Type_equal.Id.t

type kind = Side_loaded | Compiled

type ('var, 'value, 'max_branching, 'num_rules) t =
  {kind: kind; id: ('var, 'value, 'max_branching, 'num_rules) tag}
[@@deriving fields]

let create ~name =
  {kind= Compiled; id= Type_equal.Id.create ~name sexp_of_opaque}
