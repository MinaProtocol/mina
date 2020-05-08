open Coda_base

val create_with_custom_ledger :
     genesis_consensus_state:Consensus.Data.Consensus_state.Value.t
  -> genesis_ledger:Ledger.t Lazy.t
  -> genesis_constants:Genesis_constants.t
  -> (Protocol_state.Value.t, State_hash.t) With_hash.t

val t :
     genesis_ledger:Ledger.t Lazy.t
  -> genesis_constants:Genesis_constants.t
  -> (Protocol_state.Value.t, State_hash.t) With_hash.t

val compile_time_genesis :
  (Protocol_state.Value.t, State_hash.t) With_hash.t Lazy.t

module For_tests : sig
  val genesis_state_hash : State_hash.t Lazy.t
end
