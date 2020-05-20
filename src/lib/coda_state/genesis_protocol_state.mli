open Coda_base

val t :
     genesis_ledger:Ledger.t Lazy.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> genesis_constants:Genesis_constants.t
  -> (Protocol_state.Value.t, State_hash.t) With_hash.t

module For_tests : sig
  val genesis_state : (Protocol_state.Value.t, State_hash.t) With_hash.t Lazy.t

  val genesis_state_hash : State_hash.t Lazy.t
end
