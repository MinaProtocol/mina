type t =
  { protocol_state: Protocol_state.t
  ; proof: Proof.t
  ; ledger:
      ( Pedersen.Digest.t
      , Public_key.Compressed.t
      , Account.t )
      Sparse_ledger_lib.Sparse_ledger.t }
[@@deriving bin_io, sexp]
