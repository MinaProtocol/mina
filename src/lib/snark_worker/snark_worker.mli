module Prod = Prod

module Intf : module type of Intf

include Intf.S with type ledger_proof := Ledger_proof.t

type Structured_log_events.t +=
  | Generating_snark_work_failed of
      { error : Yojson.Safe.t
      ; work_spec : Work.Spec.t
      ; prover_public_key : Signature_lib.Public_key.Compressed.t
      }
  [@@deriving register_event]
