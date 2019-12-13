open Core_kernel

module Signed = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('magnitude, 'sgn) t = {magnitude: 'magnitude; sgn: 'sgn}
      [@@deriving sexp, hash, compare, eq, yojson]
    end
  end]

  type ('magnitude, 'sgn) t = ('magnitude, 'sgn) Stable.Latest.t =
    {magnitude: 'magnitude; sgn: 'sgn}
  [@@deriving sexp, hash, compare, eq, yojson]
end
