open Snarkette
open Mnt4_80

type t =
  { protocol_state: Protocol_state.Stable.V1.t
  ; proof: (G1.t, G2.t) Bowe_gabizon.Proof.Stable.V1.t
  ; ledger:
      ( Pedersen.Digest.t
      , Public_key.Compressed.Stable.V1.t
      , Account.Stable.V1.t )
      Sparse_ledger_lib.Sparse_ledger.Poly.Stable.V1.t }
[@@deriving sexp, bin_io]
