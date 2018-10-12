open Core_kernel

type ('time, 'target) t_ = ('time * 'target) list [@@deriving sexp]
