include Coda_spec.Transaction_intf.Payment.S
  with module Keypair = Signature_lib.Keypair
   and module Payload = Payment_payload
   and module Signature = Schnorr
