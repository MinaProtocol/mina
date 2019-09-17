open Coda_base

module Stable = struct
  module V1 = struct
    module T = struct
      type 'proof t = {proof: 'proof; fee: Fee_with_prover.Stable.V1.t}
      [@@deriving bin_io, sexp, fields, yojson, version]
    end

    include T
  end

  module Latest = V1
end

type 'proof t = 'proof Stable.Latest.t =
  {proof: 'proof; fee: Fee_with_prover.Stable.V1.t}
