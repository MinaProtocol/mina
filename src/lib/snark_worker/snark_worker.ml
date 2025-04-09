module Cli_helper = Cli_helper
module Rpcs_versioned = Rpcs_versioned
module Concrete_work = Concrete_work

module Impl = struct
  module Prod = Worker_impl_prod.Impl
  module Debug = Worker_impl_debug.Impl
end

type Structured_log_events.t +=
  | Generating_snark_work_failed of { error : Yojson.Safe.t }
  [@@deriving register_event { msg = "Failed to generate SNARK work: $error" }]
