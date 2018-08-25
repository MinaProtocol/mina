module Make
    (Consensus_mechanism : Consensus.Mechanism.S)
  : Blockchain_state_intf.S
  with module Consensus_mechanism := Consensus_mechanism
