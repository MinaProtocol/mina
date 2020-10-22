open Core_kernel

type ('var, 'value, 'n1, 'n2) tag = ('var * 'value * 'n1 * 'n2) Type_equal.Id.t

type kind = Side_loaded | Compiled

type ('var, 'value, 'n1, 'n2) t = {kind: kind; id: ('var, 'value, 'n1, 'n2) tag}
[@@deriving fields]

val create : name:string -> ('var, 'value, 'n1, 'n2) t
