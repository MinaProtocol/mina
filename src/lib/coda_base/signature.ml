open Core

module Stable = struct
  module V1 = struct
    type t = Snark_params.Tock.Field.t * Snark_params.Tock.Field.t
    [@@deriving sexp, eq, compare, hash, bin_io]
  end
end

include Stable.V1
open Snark_params.Tick

type var = Inner_curve.Scalar.var * Inner_curve.Scalar.var

let to_base64 t = Binable.to_string (module Stable.V1) t |> B64.encode

let of_base64_exn s = B64.decode s |> Binable.of_string (module Stable.V1)
