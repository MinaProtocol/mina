module Prod = Prod

module Intf = struct
  include Intf

  let command_name = Entry.command_name
end

module Inputs = Prod.Impl
module Events = Events

module Worker = struct
  include Entry

  module Rpcs_versioned = struct
    module Get_work = Rpc_get_work.Stable
    module Submit_work = Rpc_submit_work.Stable
    module Failed_to_generate_snark = Rpc_failed_to_generate_snark.Stable
  end

  let command = command_from_rpcs
end

include Worker

module Rpcs = struct
  module Get_work = Rpc_get_work
  module Submit_work = Rpc_submit_work
  module Failed_to_generate_snark = Rpc_failed_to_generate_snark
end
