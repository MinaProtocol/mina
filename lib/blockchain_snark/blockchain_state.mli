module Make
    (Consensus_mechanism : Consensus.Mechanism.S
                           with type Proof.t = Snark_params.Tock.Proof.t) :
  Blockchain_state_intf.S
  with module Consensus_mechanism := Consensus_mechanism
