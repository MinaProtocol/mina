open Core_kernel

module Balance = Nat.Make64 ()

module Nonce = Nat.Make32 ()

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { public_key: Public_key.Compressed.Stable.V1.t
        ; balance: Balance.t
        ; nonce: Nonce.t
        ; receipt_chain_hash: Receipt.Chain_hash.t
        ; delegate: Public_key.Compressed.Stable.V1.t
        ; participated: bool }
      [@@deriving bin_io, sexp, eq]
    end

    include T
  end

  module Latest = V1
end

type t = Stable.Latest.t [@@deriving sexp, eq]

let fold
    { Stable.Latest.public_key
    ; balance
    ; nonce
    ; receipt_chain_hash
    ; delegate
    ; participated } =
  let open Fold_lib.Fold in
  Public_key.Compressed.fold public_key
  +> Balance.fold balance +> Nonce.fold nonce
  +> Receipt.Chain_hash.fold receipt_chain_hash
  +> Public_key.Compressed.fold delegate
  +> Fold_lib.Fold.return (participated, false, false)
