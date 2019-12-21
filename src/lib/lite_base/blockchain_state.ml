open Fold_lib
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { staged_ledger_hash: Staged_ledger_hash.t
        ; ledger_hash: Ledger_hash.t
        ; timestamp: Block_time.Stable.V1.t }
      [@@deriving bin_io, eq, sexp, version {asserted}]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "blockchain_state_lite"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

type t = Stable.Latest.t [@@deriving eq, sexp]

let fold ({staged_ledger_hash; ledger_hash; timestamp} : t) =
  let open Fold in
  Staged_ledger_hash.fold staged_ledger_hash
  +> Ledger_hash.fold ledger_hash
  +> Block_time.fold timestamp
