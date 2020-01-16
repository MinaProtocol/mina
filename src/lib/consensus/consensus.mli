[%%import "../../config.mlh"]

include module type of Intf

[%%if consensus_mechanism = "proof_of_stake"]

include
  module type of Proof_of_stake
  with module Exported := Proof_of_stake.Exported
   and type Data.Proposal_data.t = Proof_of_stake.Data.Proposal_data.t
   and type Data.Consensus_state.Value.t =
              Proof_of_stake.Data.Consensus_state.Value.t

[%%else]

[%%show consesus_mechanism]

[%%error "invalid value for \"consensus_mechanism\""]

[%%endif]

module Proof_of_stake = Proof_of_stake
