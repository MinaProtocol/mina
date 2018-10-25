module Make
    (Consensus_mechanism : Consensus.Mechanism.S
                           with module Protocol_state.Blockchain_state = Coda_base.
                                                                         Blockchain_state) :
  Blockchain_state_intf.S
  with module Consensus_mechanism := Consensus_mechanism
