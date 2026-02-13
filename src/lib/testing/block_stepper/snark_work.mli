val compute :
     proof_level:Genesis_constants.Proof_level.t
  -> proof_cache_db:Proof_cache_tag.cache_db
  -> signature_kind:Mina_signature_kind.t
  -> logger:Logger.t
  -> fee:Currency.Fee.t
  -> prover_key:Signature_lib.Public_key.Compressed.t
  -> (module Transaction_snark.S)
  -> ( Transaction_witness.t
     , Ledger_proof.Cached.t )
     Snark_work_lib.Work.Single.Spec.t
     One_or_two.t
     list
  -> (   Transaction_snark_work.Statement.t
      -> Transaction_snark_work.Checked.t option )
     Async.Deferred.Or_error.t
