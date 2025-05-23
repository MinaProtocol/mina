module Prod = Prod
module Intf = Intf
module Inputs = Prod.Inputs
module Events = Events

module Worker = struct
  include Functor.Make

  module Rpcs_versioned = struct
    module Get_work = Rpc_get_work.Stable
    module Submit_work = Rpc_submit_work.Stable
    module Failed_to_generate_snark = Rpc_failed_to_generate_snark.Stable
  end

  let command = command_from_rpcs (module Rpcs_versioned)
end

include Worker
