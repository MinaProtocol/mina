open Snarkette
open Mnt4_80

type t = (G1.t, G2.t) Bowe_gabizon.Proof.Stable.Latest.t
[@@deriving sexp, bin_io]
