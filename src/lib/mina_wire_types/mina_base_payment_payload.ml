type ('public_key, 'token_id, 'amount) poly =
  { source_pk : 'public_key
  ; receiver_pk : 'public_key
  ; token_id : 'token_id
  ; amount : 'amount
  }

type t = (Public_key.compressed, Mina_base_token_id.M.t, Currency.M.amount) poly
