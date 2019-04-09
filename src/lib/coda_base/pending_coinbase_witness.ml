open Core_kernel

(* TODO: version *)
type t =
  {pending_coinbases: Pending_coinbase.Stable.Latest.t; is_new_stack: bool}
[@@deriving bin_io, sexp]
