open Core_kernel

type ('var, 'value, 'n1, 'n2, 'num_additional_proofs) id =
  ('var * 'value * 'n1 * 'n2 * 'num_additional_proofs) Type_equal.Id.t

type kind = Side_loaded | Compiled

type ('var, 'value, 'n1, 'n2, 'num_additional_proofs) t =
  { kind : kind; id : ('var, 'value, 'n1, 'n2, 'num_additional_proofs) id }
[@@deriving fields]

let create ?(kind = Compiled) name =
  { kind; id = Type_equal.Id.create ~name sexp_of_opaque }
