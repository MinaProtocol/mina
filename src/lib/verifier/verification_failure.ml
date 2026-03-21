open Core

type t = Verification_failed of Error.t [@@deriving sexp, compare, hash]
