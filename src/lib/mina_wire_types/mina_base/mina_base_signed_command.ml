type ('payload, 'pk, 'signature) poly =
  { payload : 'payload; signer : 'pk; signature : 'signature }

type t =
  (Mina_base_signed_command_payload.t, Public_key.t, Mina_base_signature.t) poly
