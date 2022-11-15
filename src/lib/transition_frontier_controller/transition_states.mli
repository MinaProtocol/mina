open Core_kernel
open Mina_base

module type Inmem_context = sig
  val on_invalid :
       error:Error.t
    -> aux:Transition_state.aux_data
    -> Substate.transition_meta
    -> unit

  val on_add_new : State_hash.t -> unit

  val on_remove : State_hash.t -> unit
end

module Inmem : functor (C : Inmem_context) ->
  Substate_types.Transition_states_intf with type state_t = Transition_state.t

type t = Transition_state.t Substate_types.transition_states

val create_inmem : (module Inmem_context) -> t

include
  Substate_types.Transition_states_intf
    with type state_t = Transition_state.t
     and type t := t
