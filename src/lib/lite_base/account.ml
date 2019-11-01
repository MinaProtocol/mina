open Core_kernel

module Balance = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Nat.Inputs_64.Stable.V1.t Nat.T.Stable.V1.t
      [@@deriving eq, sexp, to_yojson, compare]

      let to_latest = Fn.id
    end
  end]

  include Nat.Make64 ()
end

module Nonce = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Nat.Inputs_32.Stable.V1.t Nat.T.Stable.V1.t
      [@@deriving eq, sexp, to_yojson, compare]

      let to_latest = Fn.id
    end
  end]

  include Nat.Make32 ()
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
