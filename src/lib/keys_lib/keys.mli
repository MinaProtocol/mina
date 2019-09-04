open Base
open Snark_params
open Coda_state

module type S = sig
  val transaction_snark_keys : Transaction_snark.Keys.Verification.t

  val create_state_proof :
       Tick.Handler.t
    -> Protocol_state.value
    -> ( Protocol_state.value
       , Snark_transition.value )
       Transition_system.Step.Witness.t
    -> Tock.Proof.t Or_error.t

  val check_constraints :
       Tick.Handler.t
    -> Protocol_state.value
    -> ( Protocol_state.value
       , Snark_transition.value )
       Transition_system.Step.Witness.t
    -> unit Or_error.t

  val verify_state_proof : Protocol_state.value -> Tock.Proof.t -> bool
end

val create : unit -> (module S) Async.Deferred.t
