module Entry = Entry

module Rpcs = struct
  module Get_work = Rpc_get_work
  module Submit_work = Rpc_submit_work
  module Failed_to_generate_snark = Rpc_failed_to_generate_snark
end

module Worker = struct
  module Debug : Intf.Worker = Debug.Impl

  module Prod : Intf.Worker = Prod.Impl
end

module Events = Events
