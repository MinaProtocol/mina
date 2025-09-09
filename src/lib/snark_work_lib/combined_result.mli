type t =
  { spec_with_proof :
      (Single_spec.t * Ledger_proof.t * Mina_stdlib.Time.Span.t) One_or_two.t
  ; fee : Currency.Fee.t
  ; prover : Signature_lib.Public_key.Compressed.t
  }
