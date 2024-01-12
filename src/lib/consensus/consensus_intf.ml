module type Full = sig
  [%%import "../../config.mlh"]

  module Intf : module type of Intf

  [%%if consensus_mechanism = "proof_of_stake"]

  include
    module type of Proof_of_stake
      with module Exported := Proof_of_stake.Exported
       and type Data.Block_data.t = Proof_of_stake.Data.Block_data.t
       and type Data.Consensus_state.Value.Stable.V2.t =
        Proof_of_stake.Data.Consensus_state.Value.Stable.V2.t

  [%%else]

  [%%show consensus_mechanism]

  [%%optcomp.error "invalid value for \"consensus_mechanism\""]

  [%%endif]

  module Proof_of_stake = Proof_of_stake
  module Graphql_scalars = Graphql_scalars
end
