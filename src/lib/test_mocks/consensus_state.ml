module Unit : Protocols.Coda_pow.Consensus_state_intf = struct
  module Value = struct
    type t = Core.Unit.t

    module Stable = struct
      module V1 = struct
        type t = Core.Unit.t [@@deriving bin_io]
      end
    end
  end

  type var = unit
end
