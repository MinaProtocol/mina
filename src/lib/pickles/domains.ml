open Core_kernel
open Import

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      {h: Domain.Stable.V1.t; k: Domain.Stable.V1.t; x: Domain.Stable.V1.t}
    [@@deriving version, fields, bin_io, sexp, compare]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t = {h: Domain.t; k: Domain.t; x: Domain.t}
[@@deriving fields, sexp, compare]
