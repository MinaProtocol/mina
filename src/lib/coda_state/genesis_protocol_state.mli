open Coda_base

val t :
     genesis_ledger:Ledger.t Lazy.t
  -> genesis_constants:Genesis_constants.t
  -> (Protocol_state.Value.t, State_hash.t) With_hash.t
