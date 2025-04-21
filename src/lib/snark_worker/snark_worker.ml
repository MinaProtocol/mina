(* NOTE: These documentation might be helpful
   - https://docs.minaprotocol.com/mina-protocol/snark-workers
*)

(* module interacting with CLIs *)
module Entry = Entry

(* module providing versioned RPCs *)
module Rpcs = struct
  module Get_work = Get_work
  module Submit_work = Submit_work
  module Failed_to_generate_snark = Failed_to_generate_snark
end

(* module providing swappable implementation for worker *)
module Impl = struct
  module Prod = Prod.Impl
  module Debug = Debug.Impl
end

type Structured_log_events.t +=
  | Generating_snark_work_failed of { error : Yojson.Safe.t }
  [@@deriving register_event { msg = "Failed to generate SNARK work: $error" }]
