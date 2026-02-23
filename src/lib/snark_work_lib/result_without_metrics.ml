(*NOTE: This type is used by GraphQL endpoints and standalone snark worker *)
type 'proof t =
  { proofs : 'proof One_or_two.t
  ; statements : Transaction_snark.Statement.t One_or_two.t
  ; prover : Signature_lib.Public_key.Compressed.t
  ; fee : Currency.Fee.t
  }
[@@deriving yojson, sexp]

let map ~f_proof { proofs; statements; prover; fee } =
  { proofs = One_or_two.map ~f:f_proof proofs; statements; prover; fee }
