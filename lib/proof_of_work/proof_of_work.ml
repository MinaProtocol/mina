open Core_kernel
open Nanobit_base
open Util
open Snark_params.Tick

type t = Pedersen.Digest.t

let create state nonce =
  Pedersen.digest_fold Hash_prefix.proof_of_work
    (Blockchain_state.fold state +> Block.Nonce.Bits.fold nonce)

let meets_target_unchecked (pow : t) (target : Target.t) =
  Bigint.(compare (of_field pow) (of_field (target :> Field.t))) < 0
