type t =
  { token_id : Mina_base_token_id.M.t
  ; token_owner_pk : Public_key.compressed
  ; receiver_pk : Public_key.compressed
  ; account_disabled : bool
  }
