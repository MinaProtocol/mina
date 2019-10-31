open Crypto_params.Tock

(* TODO: version G1, G2, and use %%versioned here *)
module Stable = struct
  module V1 = struct
    module T = struct
      type t = (G1.t, G2.t) Snarkette.Bowe_gabizon.Proof.Stable.V1.t
      [@@deriving sexp, bin_io, version {asserted}]
    end

    include T
  end

  module Latest = V1
end

type t = Stable.Latest.t [@@deriving sexp]
