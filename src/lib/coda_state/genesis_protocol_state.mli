open Coda_base

val t :
     genesis_ledger:Ledger.t Lazy.t
  -> runtime_config:Runtime_config.t
  -> (Protocol_state.Value.t, State_hash.t) With_hash.t

val for_unit_tests : (Protocol_state.Value.t, State_hash.t) With_hash.t Lazy.t

module For_tests : sig
  val unit_test_genesis_state_hash : State_hash.t Lazy.t
end
