open Core_kernel

type ('var, 'value, 'ret_var, 'ret_value, 'n1, 'n2) tag =
  ('var * 'value * 'ret_var * 'ret_value * 'n1 * 'n2) Type_equal.Id.t

type kind = Side_loaded | Compiled

type ('var, 'value, 'ret_var, 'ret_value, 'n1, 'n2) t =
  { kind : kind; id : ('var, 'value, 'ret_var, 'ret_value, 'n1, 'n2) tag }
[@@deriving fields]

val create : name:string -> ('var, 'value, 'ret_var, 'ret_value, 'n1, 'n2) t
