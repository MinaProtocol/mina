type 'proof t =
  { proofs : 'proof One_or_two.t
  ; statements : Transaction_snark.Statement.t One_or_two.t
  ; prover : Signature_lib.Public_key.Compressed.t
  ; fee : Currency.Fee.t
  }
[@@deriving yojson, sexp]

val map : f_proof:('a -> 'b) -> 'a t -> 'b t
