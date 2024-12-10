module Prod = Prod

module Intf : module type of Intf

include
  Intf.S
    with type ledger_proof := Ledger_proof.t
     and type ledger_proof_cache_tag := Ledger_proof.Prod.Cache_tag.t

type Structured_log_events.t +=
  | Generating_snark_work_failed of { error : Yojson.Safe.t }
  [@@deriving register_event]
