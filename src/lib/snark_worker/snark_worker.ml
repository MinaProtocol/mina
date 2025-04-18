(* NOTE: These documentation might be helpful
   - https://docs.minaprotocol.com/mina-protocol/snark-workers
*)

(* module interacting with CLIs *)
module Entry = Entry

(* module providing versioned RPCs *)
module Rpcs_versioned = Rpcs_versioned

(* module providing swappable implementation for worker *)
module Impl = struct
  module Prod = Worker_impl_prod.Impl
  module Debug = Worker_impl_debug.Impl
end

type Structured_log_events.t +=
  | Generating_snark_work_failed of { error : Yojson.Safe.t }
  [@@deriving register_event { msg = "Failed to generate SNARK work: $error" }]
