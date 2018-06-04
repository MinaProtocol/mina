open Util
open Snark_params

let merge ~height h1 h2 =
  let open Tick.Pedersen in
  State.digest
    (hash_fold Hash_prefix.merkle_tree.(height)
      (Digest.Bits.fold h1 +> Digest.Bits.fold h2))
