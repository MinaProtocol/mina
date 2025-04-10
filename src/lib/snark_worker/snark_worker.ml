(* module interacting with CLIs *)
module Cli_helper = Cli_helper

(* module providing versioned RPCs *)
module Rpcs_versioned = Rpcs_versioned

(* module containing work type this snark worker could deal with *)
module Concrete_work = Concrete_work

(* module providing swappable implementation for worker *)
module Impl = struct
  module Prod = Worker_impl_prod.Impl
  module Debug = Worker_impl_debug.Impl
end


(* module contains logic that may be shared across coordinator and worker. This
   is needed for backward compatibility reason. *)
module Shared = Shared

type Structured_log_events.t +=
  | Generating_snark_work_failed of { error : Yojson.Safe.t }
  [@@deriving register_event { msg = "Failed to generate SNARK work: $error" }]
