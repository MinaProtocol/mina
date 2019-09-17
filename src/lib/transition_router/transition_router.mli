open Async_kernel
open Coda_base
open Pipe_lib
open Coda_transition

module type Inputs_intf = sig
  include Coda_intf.Inputs_intf

  module Network : sig
    type t

    val high_connectivity : t -> unit Ivar.t

    val peers : t -> Network_peer.Peer.t list
  end

  module Transition_frontier : Coda_intf.Transition_frontier_intf

  module Transition_frontier_controller :
    Coda_intf.Transition_frontier_controller_intf
    with type transition_frontier := Transition_frontier.t
     and type breadcrumb := Transition_frontier.Breadcrumb.t
     and type network := Network.t

  module Bootstrap_controller :
    Coda_intf.Bootstrap_controller_intf
    with type network := Network.t
     and type transition_frontier := Transition_frontier.t
end

module Make (Inputs : Inputs_intf) :
  Coda_intf.Transition_router_intf
  with type verifier := Inputs.Verifier.t
   and type external_transition := Inputs.External_transition.t
   and type external_transition_validated :=
              Inputs.External_transition.Validated.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_persistent_root :=
              Inputs.Transition_frontier.Persistent_root.t
   and type breadcrumb := Inputs.Transition_frontier.Breadcrumb.t
   and type network := Inputs.Network.t

open Coda_transition

include
  Coda_intf.Transition_router_intf
  with type verifier := Verifier.t
   and type external_transition := External_transition.t
   and type external_transition_validated := External_transition.Validated.t
   and type transition_frontier := Transition_frontier.t
   and type transition_frontier_persistent_root :=
              Transition_frontier.Persistent_root.t
   and type breadcrumb := Transition_frontier.Breadcrumb.t
   and type network := Network.t
