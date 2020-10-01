type Structured_log_events.t += Starting_transition_frontier_controller
  [@@deriving register_event]

type Structured_log_events.t += Starting_bootstrap_controller
  [@@deriving register_event]

include
  Coda_intf.Transition_router_intf
  with type transition_frontier := Transition_frontier.t
   and type transition_frontier_persistent_root :=
              Transition_frontier.Persistent_root.t
   and type transition_frontier_persistent_frontier :=
              Transition_frontier.Persistent_frontier.t
   and type breadcrumb := Transition_frontier.Breadcrumb.t
   and type network := Coda_networking.t
