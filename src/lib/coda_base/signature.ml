open Core
open Module_version
open Snark_params.Tick

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Field.t * Inner_curve.Scalar.t
      [@@deriving sexp, eq, compare, hash, bin_io, version {asserted}]

      let version_byte = Base58_check.Version_bytes.signature

      (* TODO : version Field in snarky *)
    end

    include T
    include Codable.Make_base58_check (T)
    include Registration.Make_latest_version (T)

    include Codable.Make_of_string (struct
      type nonrec t = t

      let to_string = to_base58_check

      let of_string = of_base58_check_exn
    end)
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

type var = Field.Var.t * Inner_curve.Scalar.var

let dummy : t = (Field.one, Inner_curve.Scalar.one)
