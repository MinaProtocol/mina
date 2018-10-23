type ('payload, 'pk, 'signature) t_ =
  {payload: 'payload; sender: 'pk; signature: 'signature}

type t =
  (Payment_payload.Stable.V1.t, Signature_lib.Public_key.Stable.V1.t, Schnorr.Signature.t) t_

include Coda_spec.Transaction_intf.Payment.S
  with module Keypair = Signature_lib.Keypair
   and module Payload = Payment_payload
   and module Signature = Schnorr
   and type Stable.V1.t = t
   and type t := t
