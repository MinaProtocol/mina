open Core_kernel

type t = Verification_failed of Error.t [@@deriving sexp, compare, hash]
