open Core_kernel

type ('var, 'value, 'n1, 'n2) t = ('var * 'value * 'n1 * 'n2) Type_equal.Id.t

let create ~name = Type_equal.Id.create ~name sexp_of_opaque
