open Core_kernel
open Coda_base
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { state_hash: State_hash.Stable.V1.t
        ; frontier_hash: Frontier_hash.Stable.V1.t }
      [@@deriving bin_io, yojson, version]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "transition_frontier_root_identifier"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

include Stable.Latest
