module Prod = Prod

module Intf : module type of Intf

include Intf.S with type ledger_proof := Ledger_proof.t

type Structured_log_events.t +=
  | Generating_snark_work_failed of { error : Yojson.Safe.t }
  [@@deriving register_event]
