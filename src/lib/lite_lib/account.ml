open Lite_base
include Lite_base.Account

let digest t =
  Lite_base.Pedersen.digest_fold
    (Lite_base.Pedersen.State.salt
       (Lazy.force Lite_params.pedersen_params)
       (Hash_prefixes.account :> string))
    (fold t)

module Membership_proof = struct
  include Merkle_path

  let check proof ~account ~root =
    Pedersen.Digest.equal
      (Merkle_path.implied_root proof
         Pedersen.(
           digest_fold
             (State.create (Lazy.force Lite_params.pedersen_params))
             (fold account)))
      root
end
