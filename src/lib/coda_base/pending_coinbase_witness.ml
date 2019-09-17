open Core_kernel
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        {pending_coinbases: Pending_coinbase.Stable.V1.t; is_new_stack: bool}
      [@@deriving bin_io, sexp, to_yojson, version]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "pending_coinbase_witness"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

type t = Stable.Latest.t =
  {pending_coinbases: Pending_coinbase.Stable.V1.t; is_new_stack: bool}
[@@deriving to_yojson, sexp]
