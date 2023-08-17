type Structured_log_events.t += Node_down [@@deriving register_event]

type Structured_log_events.t += Node_stopped [@@deriving register_event]

type Structured_log_events.t += Node_started [@@deriving register_event]
