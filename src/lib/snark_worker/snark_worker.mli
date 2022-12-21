type Structured_log_events.t += Generating_snark_work_failed
  [@@deriving register_event]

module Prod = Prod

module Intf : module type of Intf

include Intf.S with type ledger_proof := Ledger_proof.t
