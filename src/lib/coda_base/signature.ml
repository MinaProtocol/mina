open Core
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      let version = 1

      type t = Snark_params.Tock.Field.t * Snark_params.Tock.Field.t
      [@@deriving sexp, eq, compare, hash, bin_io]
    end

    let to_base64 t = Binable.to_string (module T) t |> Base64.encode_string

    let of_base64_exn s = Base64.decode_exn s |> Binable.of_string (module T)

    include T
    include Registration.Make_latest_version (T)

    include Codable.Make_of_string (struct
      type nonrec t = t

      let to_string = to_base64

      let of_string = of_base64_exn
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

type var = Inner_curve.Scalar.var * Inner_curve.Scalar.var

let dummy : t = Inner_curve.Scalar.(one, one)
