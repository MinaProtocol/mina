open Core_kernel
open Mina_base

module type Callbacks = sig
  val on_invalid :
       ?reason:[ `Proof | `Signature_or_proof | `Other ]
    -> error:Error.t
    -> aux:Transition_state.aux_data
    -> Substate_types.transition_meta
    -> unit

  val on_add_new : State_hash.t -> unit

  val on_remove : State_hash.t -> unit
end

module Inmem : functor (C : Callbacks) ->
  Substate_types.Transition_states_intf with type state_t = Transition_state.t

type t = Transition_state.t Substate_types.transition_states

val create_inmem : (module Callbacks) -> t

include
  Substate_types.Transition_states_intf
    with type state_t = Transition_state.t
     and type t := t

val iter : f:(state_t -> unit) -> t -> unit
