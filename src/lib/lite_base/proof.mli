open Crypto_params.Tock

module Stable : sig
  module V1 : sig
    type t = (G1.t, G2.t) Snarkette.Bowe_gabizon.Proof.Stable.V1.t
    [@@deriving bin_io, sexp, version]
  end

  module Latest = V1
end

type t = Stable.Latest.t [@@deriving sexp]
