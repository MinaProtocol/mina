(* TODO: version *)
type t =
  { protocol_state: Protocol_state.t
  ; proof: Proof.t
  ; ledger:
      ( Pedersen.Digest.t
      , Public_key.Compressed.Stable.V1.t
      , Account.Stable.V1.t )
      Sparse_ledger_lib.Sparse_ledger.Poly.Stable.Latest.t }
[@@deriving bin_io, sexp]
