open Module_version

module V1_make = Nat.V1_64_make ()

module Stable = struct
  module V1 = struct
    module T = struct
      type t = V1_make.Stable.V1.t
      [@@deriving bin_io, eq, sexp, compare, version]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "nonce_lite"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

include V1_make.Importable
