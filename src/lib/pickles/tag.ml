type ('var, 'value, 'n1, 'n2) id = ('var * 'value * 'n1 * 'n2) Type_equal.Id.t

type kind = Side_loaded | Compiled

type ('var, 'value, 'n1, 'n2) t =
  { kind : kind; id : ('var, 'value, 'n1, 'n2) id }
[@@deriving fields]

let create ?(kind = Compiled) name =
  { kind; id = Type_equal.Id.create ~name sexp_of_opaque }
