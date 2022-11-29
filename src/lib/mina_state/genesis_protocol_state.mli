open Mina_base

val t :
     genesis_ledger:Mina_ledger.Ledger.t Lazy.t
  -> genesis_epoch_data:Consensus.Genesis_epoch_data.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> consensus_constants:Consensus.Constants.t
  -> genesis_body_reference:Consensus.Body_reference.t
  -> Protocol_state.Value.t State_hash.With_state_hashes.t
