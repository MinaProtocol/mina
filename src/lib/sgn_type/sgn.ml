open Core_kernel
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Pos | Neg
      [@@deriving sexp, bin_io, hash, compare, eq, yojson, version]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "sgn_type_sgn"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* bin_io, version omitted *)
type t = Stable.Latest.t = Pos | Neg
[@@deriving sexp, hash, compare, eq, yojson]
