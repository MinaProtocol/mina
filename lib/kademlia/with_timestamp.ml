open Core_kernel

type 'a t =
  { data : 'a
  ; timestamp : Time.t sexp_opaque
  }
[@@deriving sexp]
