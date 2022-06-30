type t =
  { token_id : Mina_base_token_id.t
  ; token_owner_pk : Public_key.Compressed.t
  ; receiver_pk : Public_key.Compressed.t
  ; amount : Currency.Amount.t
  }
