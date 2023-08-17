open Core_kernel

type Structured_log_events.t += Node_down
  [@@deriving register_event { msg = "Node in lucy network is down" }]

type Structured_log_events.t += Node_stopped
  [@@deriving
    register_event
      { msg = "Node in lucy network has been deliberately stopped" }]

type Structured_log_events.t += Node_started
  [@@deriving register_event { msg = "Node in lucy network has been started" }]
