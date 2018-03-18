include Snark_params.Tick.Signature.Private_key

(* TODO: Insecure *)
let create () =
  Bignum.Bigint.random
    Snark_params.Tick.Hash_curve.Params.order
