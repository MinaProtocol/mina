type t =
  { results : Single_result.Stable.Latest.t One_or_two.t
  ; fee : Currency.Fee.t
  ; prover : Signature_lib.Public_key.Compressed.t
  }
