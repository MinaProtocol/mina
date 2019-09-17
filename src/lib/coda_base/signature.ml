open Core
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Snark_params.Tock.Field.t * Snark_params.Tock.Field.t
      [@@deriving sexp, eq, compare, hash, bin_io, version {asserted}]

      let version_byte = Base58_check.Version_bytes.signature

      (* TODO : version Field in snarky *)
    end

    include T
    include Codable.Make_base58_check (T)
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "signature"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

include Stable.Latest
open Snark_params.Tick

type var = Inner_curve.Scalar.var * Inner_curve.Scalar.var

let dummy : t = Inner_curve.Scalar.(one, one)
