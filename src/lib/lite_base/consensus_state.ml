open Fold_lib
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { length: Length.Stable.V1.t
        ; signer_public_key: Public_key.Compressed.Stable.V1.t }
      [@@deriving eq, bin_io, sexp, version]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "consensus_state_lite"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

type t = Stable.Latest.t =
  { length: Length.Stable.Latest.t
  ; signer_public_key: Public_key.Compressed.Stable.Latest.t }
[@@deriving eq, sexp]

let length_in_triples =
  Length.length_in_triples + Public_key.Compressed.length_in_triples

let fold {length; signer_public_key} =
  Fold.(Length.fold length +> Public_key.Compressed.fold signer_public_key)
