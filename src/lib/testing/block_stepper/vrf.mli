val get_epoch_data_at_slot :
     context:(module Consensus.Intf.CONTEXT)
  -> consensus_state:Consensus.Data.Consensus_state.Value.t
  -> local_state:Consensus.Data.Local_state.t
  -> slot:int
  -> Consensus.Data.Epoch_data_for_vrf.t
     * Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t

val find_next_winning_slot :
     context:(module Consensus.Intf.CONTEXT)
  -> keypair:Signature_lib.Keypair.t
  -> start_slot:int
  -> epoch_data_for_vrf:Consensus.Data.Epoch_data_for_vrf.t
  -> ledger_snapshot:Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t
  -> ( ( Consensus.Data.Slot_won.t
       * Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t )
     * int )
     option
     Async.Deferred.t
