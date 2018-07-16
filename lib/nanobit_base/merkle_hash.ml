open Core
open Util
open Snark_params

type t = Tick.Pedersen.Digest.t
[@@deriving sexp, hash, compare, bin_io, eq]

let merge ~height h1 h2 =
  let open Tick.Pedersen in
  State.digest
    (hash_fold
       Hash_prefix.merkle_tree.(height)
       (Digest.Bits.fold h1 +> Digest.Bits.fold h2))

let empty_hash =
  Tick.Pedersen.hash_bigstring
    (Bigstring.of_string "nothing up my sleeve")

