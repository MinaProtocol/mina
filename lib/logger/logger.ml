open Core

type t

module Level = struct
  type t =
    | Warn
    | Log
    | Debug
    | Error
  [@@deriving sexp, bin_io]
end

module Attribute = struct
  type t = string * Sexp.t

  let (:=) k v = (k, v)
end

