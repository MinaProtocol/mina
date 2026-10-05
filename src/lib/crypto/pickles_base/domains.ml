open Core_kernel

[%%versioned
module Stable = struct
  module V2 = struct
    type t = { h : Domain.Stable.V1.t }
    [@@deriving fields, sexp, compare, yojson]

    let to_latest = Fn.id
  end
end]
