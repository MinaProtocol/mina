open Core_kernel
open Nanobit_base
open Snark_params.Tick

include Data_hash.Small

val create : Blockchain_state.t -> Block.Nonce.t -> t Or_error.t

val meets_target_unchecked : t -> Target.t -> bool

val meets_target_var : var -> Target.Packed.var -> (Boolean.var, _) Checked.t
