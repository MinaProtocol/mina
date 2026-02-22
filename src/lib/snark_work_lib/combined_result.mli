type t =
  { results : (Single_spec.t, Ledger_proof.t) Single_result.Poly.t One_or_two.t
  ; fee : Currency.Fee.t
  ; prover : Signature_lib.Public_key.Compressed.t
  }
