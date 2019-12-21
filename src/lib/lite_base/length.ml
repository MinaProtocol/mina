open Module_version

module V1_make_0 = Nat.Make32 ()

module V1_make = V1_make_0.Stable.V1

module Stable = struct
  module V1 = struct
    include V1_make.Stable.V1
    include Registration.Make_latest_version (V1_make.Stable.V1)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "length_lite"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

include V1_make.Impl
