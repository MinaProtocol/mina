open Core_kernel
open Coda_base

[%%versioned
module Stable = struct
  module V1 = struct
    type 'proof t = {proof: 'proof; fee: Fee_with_prover.Stable.V1.t}
    [@@deriving compare, fields, sexp, yojson]
  end
end]

type 'proof t = 'proof Stable.Latest.t =
  {proof: 'proof; fee: Fee_with_prover.Stable.V1.t}
[@@deriving compare, sexp, yojson]
