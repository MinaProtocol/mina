(* NOTE: These documentation might be helpful
   - https://docs.minaprotocol.com/mina-protocol/snark-workers
*)

(* module interacting with CLIs *)
module Entry = Entry

(* module providing versioned RPCs *)
module Rpcs = struct
  module Get_work = Rpc_get_work
  module Submit_work = Rpc_submit_work
  module Failed_to_generate_snark = Rpc_failed_to_generate_snark
end

(* module providing workers Implementations *)
module Worker = struct
  module Debug : Intf.Worker = Debug.Impl

  module Prod : Intf.Worker = Prod.Impl
end

(* module providing all structured log events *)
module Events = Events
