open Mina_base
open Mina_state

val compute :
     proof_level:Genesis_constants.Proof_level.t
  -> proof_cache_db:Proof_cache_tag.cache_db
  -> signature_kind:Mina_signature_kind.t
  -> logger:Logger.t
  -> protocol_states:Protocol_state.value State_hash.Map.t
  -> prover:Signature_lib.Public_key.Compressed.t
  -> (module Transaction_snark.S)
  -> Staged_ledger.t
  -> (   Transaction_snark_work.Statement.t
      -> Transaction_snark_work.Checked.t option )
     Async.Deferred.t
