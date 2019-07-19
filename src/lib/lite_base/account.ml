open Core_kernel
open Module_version

module Balance = struct
  module V1_make_0 = Nat.Make64 ()

  module V1_make = V1_make_0.Stable.V1

  module Stable = struct
    module V1 = struct
      include V1_make.Stable.V1
      include Registration.Make_latest_version (V1_make.Stable.V1)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "balance_lite"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  include V1_make.Impl
end

module Nonce = struct
  module V1_make_0 = Nat.Make32 ()

  module V1_make = V1_make_0.Stable.V1

  module Stable = struct
    module V1 = struct
      include V1_make.Stable.V1
      include Registration.Make_latest_version (V1_make.Stable.V1)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "nonce_lite"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  include V1_make.Impl
end

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { public_key: Public_key.Compressed.Stable.V1.t
        ; balance: Balance.Stable.V1.t
        ; nonce: Nonce.Stable.V1.t
        ; receipt_chain_hash: Receipt.Chain_hash.t
        ; delegate: Public_key.Compressed.Stable.V1.t
        ; voting_for: State_hash.t }
      [@@deriving bin_io, sexp, to_yojson, eq, version {asserted}]
    end

    include T
  end

  module Latest = V1
end

type t = Stable.Latest.t [@@deriving sexp, to_yojson, eq]

let fold
    { Stable.Latest.public_key
    ; balance
    ; nonce
    ; receipt_chain_hash
    ; delegate
    ; voting_for } =
  let open Fold_lib.Fold in
  Public_key.Compressed.fold public_key
  +> Balance.fold balance +> Nonce.fold nonce
  +> Receipt.Chain_hash.fold receipt_chain_hash
  +> Public_key.Compressed.fold delegate
  +> State_hash.fold voting_for
