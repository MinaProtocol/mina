open Coda_base

val create_with_custom_ledger :
     genesis_consensus_state:Consensus.Data.Consensus_state.Value.t
  -> genesis_ledger:Ledger.t
  -> (Protocol_state.Value.t, State_hash.t) With_hash.t

val t : (Protocol_state.Value.t, State_hash.t) With_hash.t Lazy.t
