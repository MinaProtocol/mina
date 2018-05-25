open Core_kernel
open Nanobit_base
open Snark_params.Tick

type t = private Pedersen.Digest.t

val create : Blockchain_state.t -> Block.Nonce.t -> t

val meets_target_unchecked : t -> Target.t -> bool

