open Async_kernel

module type Inputs_intf = sig
  module Network : sig
    type t

    val high_connectivity : t -> unit Ivar.t

    val peers : t -> Network_peer.Peer.t list
  end

  module Transition_frontier : module type of Transition_frontier

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
  with type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_persistent_root :=
              Inputs.Transition_frontier.Persistent_root.t
   and type breadcrumb := Inputs.Transition_frontier.Breadcrumb.t
   and type network := Inputs.Network.t

include
  Coda_intf.Transition_router_intf
  with type transition_frontier := Transition_frontier.t
   and type transition_frontier_persistent_root :=
              Transition_frontier.Persistent_root.t
   and type breadcrumb := Transition_frontier.Breadcrumb.t
   and type network := Coda_networking.t
