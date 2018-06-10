open Core_kernel
open Nanobit_base
open Snark_params
open Tick

include module type of Blockchain_state

val negative_one : t
val zero : t
val zero_hash : State_hash.t
val compute_target : Block_time.t -> Target.t -> Block_time.t -> Target.t

module Make_update (T : Transaction_snark.Verification.S) : sig
  val update : t -> Block.t -> t Or_error.t

  module Checked : sig
    val update : State_hash.var * var -> Block.var -> (State_hash.var * var * [ `Success of Boolean.var ], _) Checked.t
  end
end

module Checked : sig
  val hash : var -> (State_hash.var, _) Checked.t
  val is_base_hash : State_hash.var -> (Boolean.var, _) Checked.t
end

