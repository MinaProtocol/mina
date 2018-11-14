module Balance = Nat.Make64 ()

module Nonce = Nat.Make32 ()

type t =
  { public_key: Public_key.Compressed.t
  ; balance: Balance.t
  ; nonce: Nonce.t
  ; receipt_chain_hash: Receipt.Chain_hash.t
  ; delegate: Public_key.Compressed.t }
[@@deriving bin_io, sexp, eq]

let fold {public_key; balance; nonce; receipt_chain_hash; delegate} =
  let open Fold_lib.Fold in
  Public_key.Compressed.fold public_key
  +> Balance.fold balance +> Nonce.fold nonce
  +> Receipt.Chain_hash.fold receipt_chain_hash
  +> Public_key.Compressed.fold delegate
