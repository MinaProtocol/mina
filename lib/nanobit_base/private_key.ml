include Snark_params.Tick.Signature.Private_key

let create () =
  if Insecure.private_key_generation
  then
    Bignum.Bigint.random
      Snark_params.Tick.Hash_curve.Params.order
  else
    failwith "Insecure.private_key_generation"
