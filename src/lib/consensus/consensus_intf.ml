module type Full = sig
  module Intf : module type of Intf

  include
    module type of Proof_of_stake
      with module Exported := Proof_of_stake.Exported
       and type Data.Block_data.t = Proof_of_stake.Data.Block_data.t
       and type Data.Consensus_state.Value.Stable.V2.t =
        Proof_of_stake.Data.Consensus_state.Value.Stable.V2.t

  module Proof_of_stake = Proof_of_stake
end
