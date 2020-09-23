open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = {h: Domain.Stable.V1.t; x: Domain.Stable.V1.t}
    [@@deriving fields, sexp, compare]

    let to_latest = Fn.id
  end
end]
