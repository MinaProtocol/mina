module Inputs = Inputs
module Cli_helper = Cli_helper
module Rpcs_versioned = Rpcs_versioned
module Concrete_work = Concrete_work

type Structured_log_events.t +=
  | Generating_snark_work_failed of { error : Yojson.Safe.t }
  [@@deriving register_event { msg = "Failed to generate SNARK work: $error" }]
