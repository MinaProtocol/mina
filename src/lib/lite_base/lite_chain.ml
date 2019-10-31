(* TODO: version *)
type t =
  { protocol_state: Protocol_state.Stable.V1.t
  ; proof: Proof.Stable.V1.t
  ; ledger:
      ( Pedersen.Digest.t
      , Public_key.Compressed.Stable.V1.t
      , Account.Stable.V1.t )
      Sparse_ledger_lib.Sparse_ledger.Poly.Stable.V1.t }
[@@deriving bin_io, sexp]
