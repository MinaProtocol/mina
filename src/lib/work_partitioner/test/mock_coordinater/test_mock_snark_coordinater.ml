type t =
  { prover : Signature_lib.Public_key.Compressed.Stable.V1.t
  ; spec :
      Snark_work_lib.Selector.Single.Spec.Stable.Latest.t One_or_two.Stable.V1.t
  ; fee : Currency.Fee.Stable.V1.t
  }
[@@deriving of_yojson]
