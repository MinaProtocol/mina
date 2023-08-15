open Core_kernel

type Structured_log_events.t += Node_down
  [@@deriving register_event { msg = "Node in lucy network is down" }]
