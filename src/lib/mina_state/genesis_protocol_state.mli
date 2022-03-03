open Mina_base

val t :
     genesis_ledger:Mina_ledger.Ledger.t Lazy.t
  -> genesis_epoch_data:Consensus.Genesis_epoch_data.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> consensus_constants:Consensus.Constants.t
  -> Protocol_state.Value.t State_hash.With_state_hashes.t
