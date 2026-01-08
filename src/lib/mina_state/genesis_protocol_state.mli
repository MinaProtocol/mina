open Mina_base

val t :
     genesis_ledger:Genesis_ledger.Packed.t
  -> genesis_epoch_data:Genesis_ledger.Packed.t Consensus.Genesis_data.Epoch.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> consensus_constants:Consensus.Constants.t
  -> genesis_body_reference:Consensus.Body_reference.t
  -> Protocol_state.Value.t State_hash.With_state_hashes.t
