open Core_kernel

type t = {pending_coinbases: Pending_coinbase.t; is_new_stack: bool}
[@@deriving bin_io, sexp]
