open Core_kernel

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t = { h : Domain.Stable.V1.t }
    [@@deriving fields, sexp, compare, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t = { h : Domain.t }
[@@deriving fields, sexp, compare, yojson]
