open Base
open Snark_params

module Witness : sig
  type ('state, 'update) t =
    {proof: Tock.Proof.t; previous_state: 'state; update: 'update}
end

val input_size : int

module Verification_keys : sig
  type t

  val create :
    wrap_vk:Tock.Verification_key.t -> step_vk:Tick.Verification_key.t -> t
end

module Make (Inputs : Intf.Step_inputs_intf) : sig
  open Inputs
  open Tick.Run

  module Witness : sig
    type t = (State.Unchecked.t, Update.Unchecked.t) Witness.t
  end

  val instance_hash :
    Verification_keys.t -> State.Unchecked.t -> Tick.Pedersen.Digest.t

  val constraint_system : unit -> R1CS_constraint_system.t

  val check_constraints :
       ?handler:Handler.t
    -> Verification_keys.t
    -> State.Unchecked.t
    -> Witness.t
    -> unit Base.Or_error.t

  val prove :
       ?handler:Handler.t
    -> Verification_keys.t
    -> Proving_key.t
    -> State.Unchecked.t
    -> Witness.t
    -> (Tick.Pedersen.Digest.t * Proof.t) Or_error.t
end
