(** The transition router is the top-level component responsible for routing
 *  incoming transitions (blocks and headers) from the network to the
 *  appropriate sub-system. It manages the lifecycle between two mutually
 *  exclusive operational modes: the bootstrap controller (used when the node
 *  is too far behind the network to catch up normally) and the transition
 *  frontier controller (used during normal chain participation). On startup,
 *  the router downloads the network's best tip, loads any persisted local
 *  frontier, and decides which mode to enter. While in normal participation
 *  mode, the router continuously monitors incoming transitions and
 *  re-triggers bootstrap whenever the node falls too far behind the canonical
 *  chain.
 *)

type Structured_log_events.t += Starting_transition_frontier_controller
  [@@deriving register_event]

type Structured_log_events.t += Starting_bootstrap_controller
  [@@deriving register_event]

include
  Mina_intf.Transition_router_intf
    with type transition_frontier := Transition_frontier.t
     and type transition_frontier_persistent_root :=
      Transition_frontier.Persistent_root.t
     and type transition_frontier_persistent_frontier :=
      Transition_frontier.Persistent_frontier.t
     and type breadcrumb := Transition_frontier.Breadcrumb.t
     and type network := Mina_networking.t
